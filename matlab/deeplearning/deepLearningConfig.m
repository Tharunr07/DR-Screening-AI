function cfg = deepLearningConfig()
% deepLearningConfig  Central config for Phase 7 Deep Learning DR Classification
%
%   cfg = deepLearningConfig()

    thisFile = mfilename('fullpath');
    thisDir  = fileparts(thisFile);
    matlabDir = fileparts(thisDir);
    projectRoot = fileparts(matlabDir);

    cfg.projectRoot = char(projectRoot);
    cfg.version = '7.0.0';
    cfg.date    = '2026-09-01';
    cfg.seed    = 42;
    cfg.status  = 'RESEARCH PROTOTYPE — NOT clinically validated';

    % Paths
    cfg.paths.manifest    = fullfile(projectRoot, 'data', 'processed', 'manifest.csv');
    cfg.paths.splitDir    = fullfile(projectRoot, 'data', 'splits');
    cfg.paths.qualityCSV  = fullfile(projectRoot, 'results', 'quality', 'quality_results.csv');
    cfg.paths.structureCSV = fullfile(projectRoot, 'results', 'phase3', 'structure_results.csv');
    cfg.paths.phase4CSV   = fullfile(projectRoot, 'results', 'classification', 'classification_predictions.csv');
    cfg.paths.outputDir   = fullfile(projectRoot, 'results', 'deep_learning');
    cfg.paths.modelDir    = fullfile(cfg.paths.outputDir, 'models');
    cfg.paths.figDir      = fullfile(cfg.paths.outputDir, 'figures');
    cfg.paths.predDir     = fullfile(cfg.paths.outputDir, 'predictions');

    % Ensure output dirs
    dirs = {cfg.paths.outputDir, cfg.paths.modelDir, cfg.paths.figDir, cfg.paths.predDir};
    for d = 1:numel(dirs)
        if ~exist(dirs{d}, 'dir'), mkdir(dirs{d}); end
    end

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

    % Image preprocessing
    cfg.image.size = [224 224];  % ResNet-18 input size
    cfg.image.resizeMethod = 'bicubic';
    cfg.image.normalize = true;  % ImageNet normalization

    % Training
    cfg.training.maxEpochs = 8;
    cfg.training.miniBatchSize = 64;
    cfg.training.initialLearnRate = 1e-3;
    cfg.training.learnRateSchedule = 'piecewise';
    cfg.training.learnRateDropPeriod = 5;
    cfg.training.learnRateDropFactor = 0.1;
    cfg.training.l2Regularization = 1e-4;
    cfg.training.validationFrequency = 20;
    cfg.training.verbose = true;
    cfg.training.plots = 'none';

    % Augmentation
    cfg.augmentation.enable = true;
    cfg.augmentation.flipHorizontal = true;
    cfg.augmentation.rotationRange = [-10 10];
    cfg.augmentation.translationRange = [-10 10];
    cfg.augmentation.scaleRange = [0.9 1.1];
    cfg.augmentation.brightnessRange = [0.8 1.2];
    cfg.augmentation.contrastRange = [0.8 1.2];

    % Class imbalance
    cfg.imbalance.strategy = 'class-weighted';
    cfg.imbalance.beta = 0.999;

    % Network
    cfg.network.architecture = 'resnet18';
    cfg.network.pretrained = false;
    cfg.network.inputSize = [224 224 3];

    % Quality gating
    cfg.quality.includeBorderline = true;
    cfg.quality.includeUngradable = false;  % exclude from training

    % Output file names
    cfg.output.predictions = 'dl_predictions.csv';
    cfg.output.metrics = 'dl_metrics.json';
    cfg.output.referable = 'dl_referable_metrics.json';
    cfg.output.comparison = 'phase7_comparison.json';
    cfg.output.summary = 'phase7_summary.json';
end
