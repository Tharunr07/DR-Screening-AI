function cfg = datasetConfig(projectRoot)
% datasetConfig  Central configuration for DR screening Phase 1
%
%   cfg = datasetConfig()  auto-detects project root (one level above matlab/)
%   cfg = datasetConfig(projectRoot)  uses explicit root
%
%   Returns struct with:
%     .projectRoot, .dataRawRoot, .aptosRoot, .idridRoot, .driveRoot,
%     .messidor2Root, .processedRoot, .splitsRoot, .resultsRoot, .docsRoot
%     .manifestPath, .manifestMatPath
%     .supportedExtensions, .supportedExtensionsDot
%     .splitRatios, .randomSeed
%     .referableThreshold  (DR grades >=2 are referable)
%
%   All paths are configurable via projectRoot. No hard-coded absolute paths
%   outside cfg.
%
%   Phase 1 scope only: no preprocessing / quality / grading parameters.

    if nargin < 1 || isempty(projectRoot)
        % This file is at <projectRoot>/matlab/data/datasetConfig.m
        thisFile = mfilename('fullpath');
        thisDir  = fileparts(thisFile);               % .../matlab/data
        matlabDir = fileparts(thisDir);               % .../matlab
        projectRoot = fileparts(matlabDir);           % .../DR_Screening
    end

    cfg.projectRoot    = char(projectRoot);
    cfg.dataRawRoot    = fullfile(cfg.projectRoot, 'data', 'raw');
    cfg.aptosRoot      = fullfile(cfg.dataRawRoot, 'APTOS2019');
    cfg.idridRoot      = fullfile(cfg.dataRawRoot, 'IDRiD');
    cfg.driveRoot      = fullfile(cfg.dataRawRoot, 'DRIVE');
    cfg.messidor2Root  = fullfile(cfg.dataRawRoot, 'Messidor2');

    cfg.processedRoot  = fullfile(cfg.projectRoot, 'data', 'processed');
    cfg.splitsRoot     = fullfile(cfg.projectRoot, 'data', 'splits');
    cfg.resultsRoot    = fullfile(cfg.projectRoot, 'results');
    cfg.docsRoot       = fullfile(cfg.projectRoot, 'docs');
    cfg.matlabDataRoot = fullfile(cfg.projectRoot, 'matlab', 'data');

    % Manifest locations (both csv and mat for convenience)
    cfg.manifestPath    = fullfile(cfg.processedRoot, 'manifest.csv');
    cfg.manifestMatPath = fullfile(cfg.processedRoot, 'manifest.mat');
    cfg.auditJsonPath   = fullfile(cfg.resultsRoot, 'audit_results.json');
    cfg.auditMatPath    = fullfile(cfg.resultsRoot, 'audit_results.mat');
    cfg.auditReportPath = fullfile(cfg.docsRoot, 'PHASE1_AUDIT_REPORT.md');

    % Supported image formats (lowercase, no dot for internal compare)
    cfg.supportedExtensions    = {'png','jpg','jpeg','tif','tiff','bmp','ppm','pgm'};
    cfg.supportedExtensionsDot = cellfun(@(x) ['.' x], cfg.supportedExtensions, 'UniformOutput', false);

    % Reproducible split parameters
    % Stratified by dr_grade where available, grouped by patient_id
    cfg.splitRatios = struct('train', 0.70, 'val', 0.15, 'test', 0.15);
    cfg.randomSeed  = 42;  % documented and stored in split metadata

    % Referable DR definition (for future evaluation, NOT used for training in Phase 1)
    % Non-referable: 0,1   Referable: 2,3,4
    cfg.referableGrades    = [2, 3, 4];
    cfg.nonReferableGrades = [0, 1];
    cfg.referableThreshold = 2; % dr_grade >= 2 => referable

    % Leakage policy constants
    cfg.externalDatasets = {'Messidor2'}; % must remain isolated

    % Ensure output directories exist (do not touch raw/)
    ensureDir(cfg.processedRoot);
    ensureDir(cfg.splitsRoot);
    ensureDir(cfg.resultsRoot);
    ensureDir(cfg.docsRoot);
end

function ensureDir(p)
    if ~exist(p, 'dir')
        mkdir(p);
    end
end
