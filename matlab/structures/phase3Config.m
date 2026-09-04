function cfg = phase3Config(projectRoot)
% phase3Config  Centralized RESEARCH PROTOTYPE config for Phase 3
%
%   cfg = phase3Config()  auto-detects project root
%   cfg = phase3Config(projectRoot)
%
%   All thresholds are PROVISIONAL / THEORETICAL.
%   They are NOT clinically validated.
%   See docs/PHASE3_IMPLEMENTATION_REPORT.md

    if nargin < 1 || isempty(projectRoot)
        thisFile = mfilename('fullpath');
        thisDir  = fileparts(thisFile);
        matlabDir = fileparts(thisDir);
        projectRoot = fileparts(matlabDir);
    end

    cfg.projectRoot = char(projectRoot);
    cfg.version = '3.0.0';
    cfg.date    = '2026-08-31';
    cfg.scope   = 'APTOS2019,IDRiD,DRIVE (development); Messidor2 (external observe only)';
    cfg.status  = 'PROVISIONAL / THEORETICAL — NOT clinically validated';

    % Processing resolution (max dimension for metrics, full for output)
    cfg.processing.maxDim = 512;

    % ---- Retinal FOV ----
    cfg.fov = struct();
    cfg.fov.label = 'PROVISIONAL';
    cfg.fov.otsuClampLow = 12;
    cfg.fov.otsuClampHigh = 35;
    cfg.fov.minAreaFraction = 0.08;
    cfg.fov.fallbackThreshold = 15;
    cfg.fov.morphDiskRadius = 5;
    cfg.fov.minComponentFraction = 0.005;

    % ---- Optic Disc ----
    cfg.opticDisc = struct();
    cfg.opticDisc.label = 'PROVISIONAL';
    cfg.opticDisc.greenBrightPrctile = 95;
    cfg.opticDisc.minRadiusFrac = 0.01;
    cfg.opticDisc.maxRadiusFrac = 0.15;
    cfg.opticDisc.circularityThresh = 0.4;
    cfg.opticDisc.brightnessThresh = 0.7;
    cfg.opticDisc.vesselConvergenceThresh = 0.3;

    % ---- Fovea ----
    cfg.fovea = struct();
    cfg.fovea.label = 'PROVISIONAL';
    cfg.fovea.typicalDistanceDiscDiameters = 2.5;
    cfg.fovea.typicalAngleDeg = 15;
    cfg.fovea.searchRadiusFrac = 0.25;
    cfg.fovea.darknessPrctile = 25;

    % ---- Vessel Segmentation ----
    cfg.vessels = struct();
    cfg.vessels.label = 'PROVISIONAL';
    cfg.vessels.greenChannelWeight = 0.7;
    cfg.vessels.matchedFilterScales = [1 2 3];
    cfg.vessels.matchedFilterLength = 9;
    cfg.vessels.hysteresisLow = 0.05;
    cfg.vessels.hysteresisHigh = 0.15;
    cfg.vessels.minVesselArea = 5;
    cfg.vessels.skeletonMinLength = 10;

    % ---- Microaneurysm Detection ----
    cfg.ma = struct();
    cfg.ma.label = 'PROVISIONAL';
    cfg.ma.greenBackgroundSigma = 30;
    cfg.ma.detectionScales = [1 2 3 4];
    cfg.ma.minArea = 3;
    cfg.ma.maxArea = 200;
    cfg.ma.circularityMin = 0.3;
    cfg.ma.contrastThresh = 0.05;
    cfg.ma.vesselExclusionDist = 3;

    % ---- Hemorrhage Detection ----
    cfg.he = struct();
    cfg.he.label = 'PROVISIONAL';
    cfg.he.darkIntensityThresh = 80;
    cfg.he.greenDarkThresh = 0.3;
    cfg.he.minArea = 20;
    cfg.he.maxArea = 5000;
    cfg.he.morphOpenRadius = 1;
    cfg.he.morphCloseRadius = 2;
    cfg.he.vesselExclusionDist = 5;

    % ---- Exudate Detection ----
    cfg.ex = struct();
    cfg.ex.label = 'PROVISIONAL';
    cfg.ex.brightPrctile = 95;
    cfg.ex.minArea = 10;
    cfg.ex.maxArea = 10000;
    cfg.ex.odExclusionRadiusFrac = 1.5;
    cfg.ex.localContrastThresh = 0.1;
    cfg.ex.morphOpenRadius = 1;

    % ---- Neovascularization ----
    cfg.nv = struct();
    cfg.nv.label = 'PROVISIONAL';
    cfg.nv.abnormalDensityThresh = 2.0;
    cfg.nv.tortuosityThresh = 0.5;
    cfg.nv.fineVesselThresh = 0.02;
    cfg.nv.minClusterArea = 50;

    % ---- Paths ----
    cfg.resultsRoot = fullfile(cfg.projectRoot, 'results', 'phase3');
    cfg.structureResultsPath = fullfile(cfg.resultsRoot, 'structure_results.csv');
    cfg.lesionResultsPath = fullfile(cfg.resultsRoot, 'lesion_results.csv');
    cfg.metricsPath = fullfile(cfg.resultsRoot, 'phase3_metrics.json');
    cfg.manifestPath = fullfile(cfg.projectRoot, 'data', 'processed', 'manifest.csv');
    cfg.qualityResultsPath = fullfile(cfg.projectRoot, 'results', 'quality', 'quality_results.csv');
    cfg.idridRegistryPath = fullfile(cfg.projectRoot, 'results', 'idrid_annotation_registry.csv');
    cfg.driveRegistryPath = fullfile(cfg.projectRoot, 'results', 'drive_vessel_registry.csv');

    % Ensure output dir
    if ~exist(cfg.resultsRoot, 'dir'), mkdir(cfg.resultsRoot); end
end
