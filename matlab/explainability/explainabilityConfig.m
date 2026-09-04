function cfg = explainabilityConfig()
% explainabilityConfig  Central config for Phase 5 Explainability
%
%   cfg = explainabilityConfig()
%
%   All thresholds PROVISIONAL / THEORETICAL. NOT clinically validated.

    thisFile = mfilename('fullpath');
    thisDir  = fileparts(thisFile);
    matlabDir = fileparts(thisDir);
    projectRoot = fileparts(matlabDir);

    cfg.projectRoot = char(projectRoot);
    cfg.version = '5.0.0';
    cfg.date    = '2026-08-31';
    cfg.seed    = 42;
    cfg.status  = 'PROVISIONAL / THEORETICAL — NOT clinically validated';

    % Paths
    cfg.paths.manifest     = fullfile(projectRoot, 'data', 'processed', 'manifest.csv');
    cfg.paths.splitDir     = fullfile(projectRoot, 'data', 'splits');
    cfg.paths.qualityCSV   = fullfile(projectRoot, 'results', 'quality', 'quality_results.csv');
    cfg.paths.structureCSV = fullfile(projectRoot, 'results', 'phase3', 'structure_results.csv');
    cfg.paths.phase4CSV    = fullfile(projectRoot, 'results', 'classification', 'classification_predictions.csv');
    cfg.paths.phase4Metrics = fullfile(projectRoot, 'results', 'classification', 'classification_metrics.json');
    cfg.paths.phase4RefMetrics = fullfile(projectRoot, 'results', 'classification', 'referable_metrics.json');
    cfg.paths.phase4ConfMat = fullfile(projectRoot, 'results', 'classification', 'confusion_matrix.csv');

    % Output paths
    cfg.paths.outputDir    = fullfile(projectRoot, 'results', 'explainability');
    cfg.paths.overlayDir   = fullfile(cfg.paths.outputDir, 'images');
    cfg.paths.heatmapDir   = fullfile(cfg.paths.outputDir, 'images');
    cfg.paths.reportDir    = fullfile(cfg.paths.outputDir, 'reports');
    cfg.paths.reviewDir    = fullfile(cfg.paths.outputDir, 'review');
    cfg.paths.contribDir   = fullfile(cfg.paths.outputDir, 'contributions');
    cfg.paths.spatialDir   = fullfile(cfg.paths.outputDir, 'spatial');
    cfg.paths.testDir      = fullfile(cfg.paths.outputDir, 'test');

    % Ensure output dirs
    dirs = {cfg.paths.outputDir, cfg.paths.overlayDir, cfg.paths.reportDir, ...
            cfg.paths.reviewDir, cfg.paths.contribDir, cfg.paths.spatialDir, cfg.paths.testDir};
    for d = 1:numel(dirs)
        if ~exist(dirs{d}, 'dir'), mkdir(dirs{d}); end
    end

    % DR grade levels (must match Phase 4)
    cfg.grades = 0:4;
    cfg.gradeLabels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
    cfg.nGrades = 5;

    % Referable DR definition (must match Phase 4)
    cfg.referable.threshold = 2;
    cfg.referable.grades = [2 3 4];

    % Feature names (must match Phase 4 buildClassificationFeatures)
    cfg.featureNames = {
        'quality_score', ...
        'retinal_area_fraction', 'fov_radius', ...
        'od_detected', 'od_radius', 'od_confidence', ...
        'fovea_detected', 'fovea_confidence', ...
        'vessel_area_fraction', 'vessel_density', ...
        'ma_count', 'ma_area', 'ma_confidence', ...
        'he_count', 'he_area', 'he_confidence', ...
        'ex_count', 'ex_area', 'ex_area_fraction', 'ex_confidence', ...
        'nv_present', 'nv_score', 'nv_confidence', ...
        'total_lesions', 'total_lesion_area'
    };
    cfg.nFeatures = numel(cfg.featureNames);

    % Permutation importance settings
    cfg.permutation.nRepeats = 10;
    cfg.permutation.metric = 'auc';  % 'auc' | 'accuracy'

    % Calibration settings
    cfg.calibration.nBins = 10;

    % Overlay settings
    cfg.overlay.lesionAlpha = 0.4;
    cfg.overlay.lesionColors.MA = [1 0 0];       % Red
    cfg.overlay.lesionColors.HE = [1 0 1];       % Magenta
    cfg.overlay.lesionColors.EX = [1 1 0];       % Yellow
    cfg.overlay.lesionColors.NV = [0 1 1];       % Cyan
    cfg.overlay.structureColors.OD = [0 1 0];    % Green
    cfg.overlay.structureColors.fovea = [0 0 1]; % Blue
    cfg.overlay.structureColors.vessel = [0 1 0]; % Green
    cfg.overlay.structureColors.fov = [1 1 1];   % White
    cfg.overlay.figureWidth = 1200;
    cfg.overlay.figureHeight = 900;

    % Output file names
    cfg.output.featureImportanceCSV = 'feature_importance.csv';
    cfg.output.featureImportanceJSON = 'feature_importance.json';
    cfg.output.contributionsCSV = 'feature_contributions.csv';
    cfg.output.calibrationJSON = 'calibration.json';
    cfg.output.calibrationBinsCSV = 'calibration_bins.csv';
    cfg.output.calibrationPlot = 'calibration_diagram.png';
    cfg.output.phase5Summary = 'phase5_summary.json';
    cfg.output.validationDoc = 'PHASE5_EXPLAINABILITY_VALIDATION.md';
    cfg.output.mainDoc = 'PHASE5_EXPLAINABILITY.md';
end
