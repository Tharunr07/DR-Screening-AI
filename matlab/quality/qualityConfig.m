function cfg = qualityConfig(projectRoot)
% qualityConfig  Centralized RESEARCH PROTOTYPE thresholds for Phase 2
%
%   cfg = qualityConfig()  auto-detects project root
%   cfg = qualityConfig(projectRoot)
%
%   All thresholds are explicitly marked THEORETICAL / INITIAL.
%   They are NOT clinically validated. See docs/PHASE2_QUALITY_ASSESSMENT.md
%   "This is a research prototype and the quality thresholds are not clinically validated."
%
%   Thresholds were chosen from:
%     - literature (Laplacian variance, Tenengrad typical ranges)
%     - robust statistics on a small synthetic pilot (see tests/)
%     - percentile analysis will be re-run by calibrateQualityThresholds.m on real data
%
%   QUALITY LABELS = NOT AVAILABLE  (no human quality labels at Phase 2 start)
%
%   Version: 2.0.0  Date: 2026-08-30  Scope: APTOS2019 + IDRiD + DRIVE (dev), Messidor2 (external observe only)

    if nargin < 1 || isempty(projectRoot)
        thisFile = mfilename('fullpath');
        thisDir  = fileparts(thisFile);               % .../matlab/quality
        matlabDir = fileparts(thisDir);               % .../matlab
        projectRoot = fileparts(matlabDir);           % .../DR_Screening
    end

    cfg.projectRoot = char(projectRoot);
    cfg.version = '2.0.0';
    cfg.date    = '2026-08-30';
    cfg.scope   = 'APTOS2019,IDRiD,DRIVE (development); Messidor2 (external observe only)';
    cfg.status  = 'THEORETICAL / INITIAL — NOT clinically validated';
    cfg.labelsAvailable = false; % QUALITY LABELS = NOT AVAILABLE

    % -----------------------------------------------------------------
    % Focus / Sharpness
    % variance of Laplacian computed on grayscale, normalized to [0,255] range
    % Tenengrad = mean of Sobel gradient magnitude squared
    % -----------------------------------------------------------------
    cfg.focus = struct();
    cfg.focus.label = 'THEORETICAL';
    cfg.focus.laplacian = struct('good', 30, 'borderline', 10); % var(Lap) <10 UNGRADABLE, 10-30 BORDERLINE, >30 GOOD (lenient for real)
    cfg.focus.tenengrad = struct('good', 500, 'borderline', 150); % mean Sobel^2 (lowered from 4000)
    cfg.focus.brenner   = struct('good', 5e5, 'borderline', 1e5);
    cfg.focus.edgeDensity = struct('good', 0.0005, 'borderline', 0.0002); % edge pixels / retinal pixels (very lenient)

    % -----------------------------------------------------------------
    % Illumination  (computed inside retinal mask only)
    % -----------------------------------------------------------------
    cfg.illumination = struct();
    cfg.illumination.label = 'THEORETICAL';
    cfg.illumination.mean = struct('low', 55, 'high', 185); % mean gray inside retina; <55 underexposed, >185 overexposed
    cfg.illumination.darkFraction = struct('good', 0.22, 'borderline', 0.35); % pixels <30 / retinal pixels (lenient)
    cfg.illumination.saturatedFraction = struct('good', 0.025, 'borderline', 0.06); % pixels >250
    cfg.illumination.uniformity = struct('good', 0.38, 'borderline', 0.55); % std/mean  (higher = less uniform, lenient)
    cfg.illumination.statusDark = 'DARK';
    cfg.illumination.statusBright = 'BRIGHT_SATURATED';

    % -----------------------------------------------------------------
    % Field of View
    % -----------------------------------------------------------------
    cfg.fov = struct();
    cfg.fov.label = 'THEORETICAL';
    cfg.fov.areaFraction = struct('good', 0.18, 'borderline', 0.10); % retinal pixels / image pixels (lenient)
    cfg.fov.completeness = struct('good', 0.65, 'borderline', 0.45); % border pixels that are retinal / ideal ellipse perimeter (lenient)
    cfg.fov.truncation = struct('borderTouchFraction', 0.50); % retinal mask touches image border >50% => truncated (very lenient)

    % -----------------------------------------------------------------
    % Glare / Saturation artifacts
    % -----------------------------------------------------------------
    cfg.glare = struct();
    cfg.glare.label = 'THEORETICAL';
    cfg.glare.fraction = struct('good', 0.04, 'borderline', 0.08); % saturated pixels inside retina (lenient)
    cfg.glare.regionCount = struct('good', 7, 'borderline', 12);
    cfg.glare.largestRegionFraction = struct('good', 0.03, 'borderline', 0.06); % largest connected saturated component / retinal area (lenient)
    cfg.glare.saturationThreshold = 250; % 0-255

    % -----------------------------------------------------------------
    % Vignetting  (radial falloff)
    % -----------------------------------------------------------------
    cfg.vignetting = struct();
    cfg.vignetting.label = 'THEORETICAL';
    cfg.vignetting.score = struct('good', 0.35, 'borderline', 0.55); % (centerMean - peripheryMean)/centerMean (lenient)
    cfg.vignetting.rings = 4; % number of radial rings for profile

    % -----------------------------------------------------------------
    % Contrast
    % -----------------------------------------------------------------
    cfg.contrast = struct();
    cfg.contrast.label = 'THEORETICAL';
    cfg.contrast.std = struct('good', 14, 'borderline', 8); % std inside retina (lowered for synthetic/low-contrast fundus)
    cfg.contrast.rms = struct('good', 0.10, 'borderline', 0.06); % RMS contrast (std/mean)
    cfg.contrast.percentileSpread = struct('good', 40, 'borderline', 22); % p95 - p5
    cfg.contrast.entropy = struct('good', 0.6, 'borderline', 0.3); % Shannon entropy (bits) inside retina (lowered for synthetic)

    % -----------------------------------------------------------------
    % Retinal visibility
    % -----------------------------------------------------------------
    cfg.retinal = struct();
    cfg.retinal.label = 'THEORETICAL';
    cfg.retinal.areaFraction = struct('good', 0.28, 'borderline', 0.16); % same as FOV but kept separate for visibility logic
    cfg.retinal.visibleFraction = struct('good', 0.78, 'borderline', 0.60); % usable retina / retinal mask (not dark/saturated)
    cfg.retinal.obscuredFraction = struct('good', 0.22, 'borderline', 0.40); % 1 - visible

    % -----------------------------------------------------------------
    % Quality decision
    % -----------------------------------------------------------------
    cfg.decision = struct();
    cfg.decision.label = 'THEORETICAL';
    cfg.decision.maxBorderlineMetrics = 4; % 1-4 borderline metrics => BORDERLINE, >4 or any UNGRADABLE => UNGRADABLE (lenient)
    % Weights for RESEARCH PROTOTYPE QUALITY SCORE (sum to 1, for normalized 0-100 score)
    cfg.decision.weights = struct('focus',0.22,'illumination',0.18,'fov',0.18,'glare',0.12,'vignetting',0.08,'contrast',0.12,'retinal',0.10);

    % -----------------------------------------------------------------
    % Enhancement  (conservative, adaptive)
    % -----------------------------------------------------------------
    cfg.enhancement = struct();
    cfg.enhancement.label = 'THEORETICAL';
    cfg.enhancement.applyCLAHE = true;
    cfg.enhancement.claheClipLimit = 2.0;
    cfg.enhancement.claheTileSize = [8 8];
    cfg.enhancement.illuminationNormalization = true;
    cfg.enhancement.illuminationSigma = 30; % large Gaussian for background estimation
    cfg.enhancement.denoising = true;
    cfg.enhancement.medianFilterSize = 3;
    cfg.enhancement.colorCorrection = false; % off by default, enable only for severe color cast

    % -----------------------------------------------------------------
    % Recapture feedback  (machine + human readable)
    % -----------------------------------------------------------------
    cfg.recapture = struct();
    cfg.recapture.map = containers.Map( ...
        {'UNREADABLE_IMAGE','LOW_FOCUS','INSUFFICIENT_FOV','EXCESSIVE_GLARE','SEVERE_DARK','SEVERE_BRIGHT','SEVERE_VIGNETTING','LOW_CONTRAST','MULTIPLE_FAILURES'}, ...
        {'RECAPTURE_UNREADABLE','RECAPTURE_BLUR','RECAPTURE_INSUFFICIENT_FOV','RECAPTURE_EXCESSIVE_GLARE','RECAPTURE_SEVERE_UNDEREXPOSURE','RECAPTURE_SEVERE_OVEREXPOSURE','RECAPTURE_SEVERE_VIGNETTING','RECAPTURE_LOW_CONTRAST','RECAPTURE_MULTIPLE_QUALITY_FAILURES'} ...
    );

    % -----------------------------------------------------------------
    % Paths
    % -----------------------------------------------------------------
    cfg.resultsQualityRoot = fullfile(cfg.projectRoot, 'results', 'quality');
    cfg.examplesRoot       = fullfile(cfg.resultsQualityRoot, 'examples');
    cfg.manifestPath       = fullfile(cfg.projectRoot, 'data', 'processed', 'manifest.csv');
    cfg.manifestWithQualityPath = fullfile(cfg.projectRoot, 'data', 'processed', 'manifest_with_quality.csv');
    cfg.qualityResultsPath = fullfile(cfg.resultsQualityRoot, 'quality_results.csv');
    cfg.qualitySummaryPath = fullfile(cfg.resultsQualityRoot, 'quality_summary.json');
    cfg.qualityThresholdsPath = fullfile(cfg.resultsQualityRoot, 'quality_thresholds.json');
    cfg.enhancementResultsPath = fullfile(cfg.resultsQualityRoot, 'enhancement_results.csv');

    % Ensure dirs
    ensureDir(cfg.resultsQualityRoot);
    ensureDir(cfg.examplesRoot);
end

function ensureDir(p)
    if ~exist(p, 'dir')
        mkdir(p);
    end
end
