function cfg = transferLearningConfig()
% transferLearningConfig  Central config for Phase 8 Transfer Learning
%
%   cfg = transferLearningConfig()

    thisFile = mfilename('fullpath');
    thisDir  = fileparts(thisFile);
    matlabDir = fileparts(thisDir);
    projectRoot = fileparts(matlabDir);

    cfg.projectRoot = char(projectRoot);
    cfg.version = '8.0.0';
    cfg.date    = '2026-09-01';
    cfg.seed    = 42;
    cfg.status  = 'RESEARCH PROTOTYPE — NOT clinically validated';

    % Paths
    cfg.paths.manifest    = fullfile(projectRoot, 'data', 'processed', 'manifest.csv');
    cfg.paths.splitDir    = fullfile(projectRoot, 'data', 'splits');
    cfg.paths.qualityCSV  = fullfile(projectRoot, 'results', 'quality', 'quality_results.csv');
    cfg.paths.structureCSV = fullfile(projectRoot, 'results', 'phase3', 'structure_results.csv');
    cfg.paths.phase4CSV   = fullfile(projectRoot, 'results', 'classification', 'classification_predictions.csv');
    cfg.paths.phase7CSV   = fullfile(projectRoot, 'results', 'deep_learning', 'predictions', 'dl_predictions.csv');
    cfg.paths.outputDir   = fullfile(projectRoot, 'results', 'transfer_learning');
    cfg.paths.modelDir    = fullfile(cfg.paths.outputDir, 'models');
    cfg.paths.figDir      = fullfile(cfg.paths.outputDir, 'figures');
    cfg.paths.predDir     = fullfile(cfg.paths.outputDir, 'predictions');

    % Pretrained weights (converted from PyTorch torchvision)
    cfg.paths.pretrainedWeights = fullfile(tempdir, 'resnet18_matlab', 'resnet18_matlab_weights.mat');

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

    % Image preprocessing (same as Phase 7 for fair comparison)
    cfg.image.size = [224 224];
    cfg.image.resizeMethod = 'bicubic';
    cfg.image.normalize = true;  % ImageNet normalization

    % Training — transfer learning specific
    % Phase 7 audit found: 8 epochs on CPU was insufficient for untrained ResNet-18
    % With pretrained weights, convergence should be faster
    cfg.training.maxEpochs = 8;
    cfg.training.miniBatchSize = 32;
    cfg.training.initialLearnRate = 1e-4;  % Lower LR for fine-tuning
    cfg.training.learnRateSchedule = 'piecewise';
    cfg.training.learnRateDropPeriod = 5;
    cfg.training.learnRateDropFactor = 0.1;
    cfg.training.l2Regularization = 1e-4;
    cfg.training.validationFrequency = 40;
    cfg.training.verbose = true;
    cfg.training.plots = 'none';

    % Fine-tuning strategy
    cfg.finetune.freezeBackbone = true;  % Freeze backbone initially
    cfg.finetune.unfreezeAfterEpoch = 5;  % Unfreeze after N epochs
    cfg.finetune.backboneLRfactor = 0.1;  % Backbone LR = base LR * factor

    % Augmentation (same as Phase 7 for fair comparison)
    cfg.augmentation.enable = true;
    cfg.augmentation.flipHorizontal = true;
    cfg.augmentation.rotationRange = [-10 10];
    cfg.augmentation.translationRange = [-10 10];
    cfg.augmentation.scaleRange = [0.9 1.1];

    % Class imbalance (same as Phase 7)
    cfg.imbalance.strategy = 'class-weighted';
    cfg.imbalance.beta = 0.999;

    % Network
    cfg.network.architecture = 'resnet18';
    cfg.network.pretrained = true;
    cfg.network.inputSize = [224 224 3];

    % Quality gating (same as Phase 7)
    cfg.quality.includeBorderline = true;
    cfg.quality.includeUngradable = false;

    % Output file names
    cfg.output.predictions = 'tl_predictions.csv';
    cfg.output.metrics = 'tl_metrics.json';
    cfg.output.referable = 'tl_referable_metrics.json';
    cfg.output.comparison = 'phase8_comparison.json';
    cfg.output.summary = 'phase8_summary.json';
end
