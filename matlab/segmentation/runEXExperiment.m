function runEXExperiment()
% runEXExperiment  Complete EX segmentation baseline experiment

    fprintf('============================================\n');
    fprintf('  EX LEARNED SEGMENTATION BASELINE\n');
    fprintf('============================================\n\n');

    expDir = fileparts(mfilename('fullpath'));
    rng(42);

    %% Step 1: Load manifest
    fprintf('=== STEP 1: LOAD MANIFEST ===\n');
    load(fullfile(expDir, 'manifest.mat'), 'manifest');
    fprintf('Loaded %d entries\n', numel(manifest));

    %% Step 2: Split data
    fprintf('\n=== STEP 2: DATA SPLIT ===\n');
    trainMask = strcmp({manifest.split}, 'train');
    trainIndices = find(trainMask);
    n = numel(trainIndices);
    perm = randperm(n);
    nTrain = round(n * 0.8);
    trainIdx = trainIndices(perm(1:nTrain));
    valIdx = trainIndices(perm(nTrain+1:end));
    testIdx = find(strcmp({manifest.split}, 'test'));
    extIdx = find(strcmp({manifest.split}, 'external_test'));
    fprintf('Train: %d, Val: %d, Test: %d, Ext: %d\n', ...
        numel(trainIdx), numel(valIdx), numel(testIdx), numel(extIdx));

    %% Step 3: Load and preprocess data
    fprintf('\n=== STEP 3: LOAD DATA ===\n');
    inputSize = [256 256];

    [trainImages, trainMasksCat] = loadEXData(manifest, trainIdx, inputSize);
    fprintf('Train: %s images, %s masks\n', mat2str(size(trainImages)), mat2str(size(trainMasksCat)));

    [valImages, valMasksCat] = loadEXData(manifest, valIdx, inputSize);
    fprintf('Val: %s images, %s masks\n', mat2str(size(valImages)), mat2str(size(valMasksCat)));

    %% Step 4: Build network
    fprintf('\n=== STEP 4: BUILD NETWORK ===\n');
    net = unet([inputSize 3], 2, ...
        'EncoderDepth', 3, ...
        'NumFirstEncoderFilters', 32);
    fprintf('Small U-Net: 3 encoder levels, 32 initial filters\n');

    %% Step 5: Train
    fprintf('\n=== STEP 5: TRAINING ===\n');
    outputDir = fullfile(expDir, 'models');
    if ~exist(outputDir, 'dir'); mkdir(outputDir); end

    opts = trainingOptions('adam', ...
        'MaxEpochs', 50, ...
        'MiniBatchSize', 2, ...
        'InitialLearnRate', 5e-4, ...
        'ValidationData', {valImages, valMasksCat}, ...
        'ValidationFrequency', 11, ...
        'ValidationPatience', 20, ...
        'OutputNetwork', 'best-validation', ...
        'CheckpointPath', outputDir, ...
        'Plots', 'none', ...
        'Verbose', true, ...
        'Shuffle', 'every-epoch', ...
        'ExecutionEnvironment', 'cpu');

    tic;
    [trainedNet, trainInfo] = trainnet(trainImages, trainMasksCat, net, 'crossentropy', opts);
    trainTime = toc;
    fprintf('\nTraining complete: %.1f min\n', trainTime/60);

    %% Step 6: Save model
    modelPath = fullfile(outputDir, 'ex_unet_baseline.mat');
    save(modelPath, 'trainedNet', 'inputSize', 'trainTime');
    fprintf('Model saved: %s\n', modelPath);

    %% Step 7: Evaluate
    fprintf('\n=== STEP 7: EVALUATION ===\n');
    cfg = struct('inputSize', [inputSize 3]);

    fprintf('\n--- IDRiD Validation ---\n');
    valResults = evaluateEXModel(manifest, valIdx, cfg);

    fprintf('\n--- IDRiD Locked Test ---\n');
    testResults = evaluateEXModel(manifest, testIdx, cfg);

    fprintf('\n--- DDR External Test ---\n');
    extResults = evaluateEXModel(manifest, extIdx, cfg);

    %% Step 8: Handcrafted comparison
    fprintf('\n=== STEP 8: HANDCRAFTED COMPARISON ===\n');
    fprintf('Running handcrafted on IDRiD test...\n');
    hcResults = evaluateHandcraftedEX(manifest, testIdx);

    fprintf('\nRunning handcrafted on DDR...\n');
    hcExtResults = evaluateHandcraftedEX(manifest, extIdx);

    %% Step 9: Save results
    fprintf('\n=== STEP 9: SAVE RESULTS ===\n');
    results = struct();
    results.manifest = manifest;
    results.trainIdx = trainIdx;
    results.valIdx = valIdx;
    results.testIdx = testIdx;
    results.extIdx = extIdx;
    results.valResults = valResults;
    results.testResults = testResults;
    results.extResults = extResults;
    results.hcResults = hcResults;
    results.hcExtResults = hcExtResults;
    results.trainTime = trainTime;
    results.trainInfo = trainInfo;
    results.cfg = cfg;
    results.date = datestr(now);

    resultsPath = fullfile(expDir, 'results', 'ex_baseline_results.mat');
    save(resultsPath, 'results');
    fprintf('Results saved: %s\n', resultsPath);

    %% Summary
    fprintf('\n============================================\n');
    fprintf('  EXPERIMENT SUMMARY\n');
    fprintf('============================================\n');
    fprintf('Dataset: IDRiD EX (%d train, %d val, %d test)\n', ...
        numel(trainIdx), numel(valIdx), numel(testIdx));
    fprintf('Training: %d epochs, Adam, lr=%e, batch=%d, CPU\n', ...
        30, 1e-4, 4);
    fprintf('Time: %.1f min\n', trainTime/60);
    fprintf('\n                  Learned U-Net    Handcrafted\n');
    fprintf('IDRiD Test Dice:  %.4f          %.4f\n', testResults.dice, hcResults.dice);
    fprintf('IDRiD Test IoU:   %.4f          %.4f\n', testResults.iou, hcResults.iou);
    fprintf('IDRiD Test Prec:  %.4f          %.4f\n', testResults.precision, hcResults.precision);
    fprintf('IDRiD Test Rec:   %.4f          %.4f\n', testResults.recall, hcResults.recall);
    fprintf('DDR Ext Dice:     %.4f          %.4f\n', extResults.dice, hcExtResults.dice);
    fprintf('DDR Ext IoU:      %.4f          %.4f\n', extResults.iou, hcExtResults.iou);
    fprintf('\n============================================\n');
end

function [images, masksCat] = loadEXData(manifest, indices, inputSize)
% loadEXData  Load and preprocess images and masks for trainnet
    n = numel(indices);
    images = zeros(inputSize(1), inputSize(2), 3, n, 'single');
    masksRaw = zeros(inputSize(1), inputSize(2), 1, n, 'uint8');
    for i = 1:n
        idx = indices(i);
        img = imread(manifest(idx).image_path);
        img = imresize(img, inputSize, 'bilinear');
        images(:,:,:,i) = single(img) / 255;

        mask = imread(manifest(idx).mask_path);
        if ndims(mask) > 2; mask = mask(:,:,1); end
        mask = imresize(mask, inputSize, 'nearest');
        masksRaw(:,:,1,i) = uint8(mask > 0);
    end
    masksCat = categorical(masksRaw, [0 1], {'background', 'lesion'});
end
