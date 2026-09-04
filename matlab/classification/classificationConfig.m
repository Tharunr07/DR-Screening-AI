function cfg = classificationConfig()
% classificationConfig  Central config for Phase 4 DR classification
%
%   cfg = classificationConfig()
%
%   All thresholds PROVISIONAL / THEORETICAL. NOT clinically validated.

    thisFile = mfilename('fullpath');
    thisDir  = fileparts(thisFile);
    matlabDir = fileparts(thisDir);
    projectRoot = fileparts(matlabDir);

    cfg.projectRoot = char(projectRoot);
    cfg.version = '4.0.0';
    cfg.date    = '2026-08-31';
    cfg.seed    = 42;
    cfg.status  = 'PROVISIONAL / THEORETICAL — NOT clinically validated';

    % Paths
    cfg.paths.manifest     = fullfile(projectRoot, 'data', 'processed', 'manifest.csv');
    cfg.paths.splitDir     = fullfile(projectRoot, 'data', 'splits');
    cfg.paths.qualityCSV   = fullfile(projectRoot, 'results', 'quality', 'quality_results.csv');
    cfg.paths.structureCSV = fullfile(projectRoot, 'results', 'phase3', 'structure_results.csv');
    cfg.paths.outputDir    = fullfile(projectRoot, 'results', 'classification');

    % Ensure output dir
    if ~exist(cfg.paths.outputDir, 'dir'), mkdir(cfg.paths.outputDir); end

    % DR grade levels
    cfg.grades = 0:4;
    cfg.gradeLabels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
    cfg.nGrades = 5;

    % Referable DR definition
    cfg.referable.threshold = 2;
    cfg.referable.grades = [2 3 4];
    cfg.referable.nonGrades = [0 1];

    % Datasets with DR labels
    cfg.labeledDatasets = {'APTOS2019', 'IDRiD'};
    cfg.unlabeledDatasets = {'DRIVE'};       % no DR grades
    cfg.externalDatasets = {'Messidor2'};    % external, labels unknown

    % Class imbalance
    cfg.imbalance.strategy = 'cost-sensitive';  % 'cost-sensitive' | 'none'

    % Classification
    cfg.classifier.type = 'ecoc-svm';  % 'ecoc-svm' | 'ensemble' | 'logistic'
    cfg.classifier.seed = 42;

    % Features from Phase 2/3
    cfg.features.qualityFields = {'overall_quality_score'};
    cfg.features.structureFields = {
        'retinal_area_fraction', 'fov_radius', ...
        'optic_disc_detected', 'optic_disc_radius', 'optic_disc_confidence', ...
        'fovea_detected', 'fovea_confidence', ...
        'vessel_area_fraction', 'vessel_density'
    };
    cfg.features.lesionFields = {
        'ma_candidate_count', 'ma_candidate_area', 'ma_confidence', ...
        'he_candidate_count', 'he_candidate_area', 'he_confidence', ...
        'ex_candidate_count', 'ex_candidate_area', 'ex_candidate_area_fraction', 'ex_confidence', ...
        'nv_candidate', 'nv_score', 'nv_confidence'
    };

    % Output file names
    cfg.output.predictions = 'classification_predictions.csv';
    cfg.output.metrics     = 'classification_metrics.json';
    cfg.output.referable   = 'referable_metrics.json';
    cfg.output.confusion   = 'confusion_matrix.csv';
    cfg.output.featureImp  = 'feature_importance.csv';
    cfg.output.calibration = 'calibration_results.json';
    cfg.output.summary     = 'classification_summary.md';
end
