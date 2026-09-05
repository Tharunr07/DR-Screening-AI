function trainEXSegmentation()
% trainEXSegmentation  Train baseline U-Net for EX segmentation
%   Reads manifest, splits data, trains, evaluates

    fprintf('=== EX LEARNED SEGMENTATION BASELINE ===\n\n');

    %% Configuration
    cfg = struct();
    cfg.inputSize = [256 256 3];
    cfg.numClasses = 2;
    cfg.maxEpochs = 30;
    cfg.miniBatchSize = 4;
    cfg.initialLearnRate = 1e-4;
    cfg.validationFrequency = 5;
    cfg.seed = 42;
    cfg.experimentDir = fileparts(mfilename('fullpath'));

    fprintf('Configuration:\n');
    fprintf('  Input size: %dx%dx%d\n', cfg.inputSize(1), cfg.inputSize(2), cfg.inputSize(3));
    fprintf('  Max epochs: %d\n', cfg.maxEpochs);
    fprintf('  Batch size: %d\n', cfg.miniBatchSize);
    fprintf('  Learning rate: %e\n', cfg.initialLearnRate);
    fprintf('  Seed: %d\n', cfg.seed);

    %% Load manifest
    load(fullfile(cfg.experimentDir, 'manifest.mat'), 'manifest');
    fprintf('\nManifest loaded: %d entries\n', numel(manifest));

    %% Split data
    rng(cfg.seed);
    trainMask = strcmp({manifest.split}, 'train');
    trainIndices = find(trainMask);
    n = numel(trainIndices);
    perm = randperm(n);
    nTrain = round(n * 0.8);
    trainIdx = trainIndices(perm(1:nTrain));
    valIdx = trainIndices(perm(nTrain+1:end));

    fprintf('Split: %d train, %d val\n', numel(trainIdx), numel(valIdx));

    %% Prepare datastores
    trainImages = {manifest(trainIdx).image_path};
    trainMasks = {manifest(trainIdx).mask_path};
    valImages = {manifest(valIdx).image_path};
    valMasks = {manifest(valIdx).mask_path};

    trainImds = imageDatastore(trainImages);
    trainPxds = pixelLabelDatastore(trainMasks, [0 255], [0 1]);
    trainDs = combine(trainImds, trainPxds);

    valImds = imageDatastore(valImages);
    valPxds = pixelLabelDatastore(valMasks, [0 255], [0 1]);
    valDs = combine(valImds, valPxds);

    % Augmentation
    aug = imageDataAugmenter( ...
        'RandXReflection', true, ...
        'RandYReflection', true, ...
        'RandRotation', [-15 15], ...
        'RandScale', [0.9 1.1]);

    trainAuDs = augmentedImageDatastore(cfg.inputSize(1:2), trainDs, ...
        'DataAugmentation', aug, ...
        'ColorPreprocessing', 'rgb2gray');

    valAuDs = augmentedImageDatastore(cfg.inputSize(1:2), valDs, ...
        'ColorPreprocessing', 'rgb2gray');

    fprintf('Datastores created.\n');

    %% Build network
    fprintf('\nBuilding network...\n');
    lgraph = unetLayers(cfg.inputSize(1:2), cfg.numClasses, ...
        'EncoderDepth', 3, ...
        'NumFirstEncoderFilters', 32);

    fprintf('Network built.\n');
    analyzeNetwork(lgraph);

    %% Training options
    outputDir = fullfile(cfg.experimentDir, 'models');
    if ~exist(outputDir, 'dir'); mkdir(outputDir); end

    opts = trainingOptions('adam', ...
        'MaxEpochs', cfg.maxEpochs, ...
        'MiniBatchSize', cfg.miniBatchSize, ...
        'InitialLearnRate', cfg.initialLearnRate, ...
        'ValidationData', valAuDs, ...
        'ValidationFrequency', cfg.validationFrequency, ...
        'ValidationPatience', 10, ...
        'OutputNetwork', 'best-validation', ...
        'CheckpointPath', outputDir, ...
        'Plots', 'none', ...
        'Verbose', true, ...
        'Shuffle', 'every-epoch', ...
        'ExecutionEnvironment', 'cpu');

    %% Train
    fprintf('\n=== TRAINING START ===\n');
    tic;
    [net, info] = trainnet(trainAuDs, lgraph, 'crossentropy', opts);
    trainTime = toc;
    fprintf('\n=== TRAINING COMPLETE ===\n');
    fprintf('Training time: %.1f seconds (%.1f minutes)\n', trainTime, trainTime/60);
    fprintf('Best validation loss: %.4f\n', min(info.ValidationLoss));

    %% Save model
    modelPath = fullfile(outputDir, 'ex_unet_baseline.mat');
    save(modelPath, 'net', 'cfg', 'info', 'trainTime');
    fprintf('Model saved: %s\n', modelPath);

    %% Quick validation evaluation
    fprintf('\n=== QUICK VALIDATION ===\n');
    evaluateEXModel(net, manifest, valIdx, cfg);

    fprintf('\n=== TRAINING PIPELINE COMPLETE ===\n');
end
