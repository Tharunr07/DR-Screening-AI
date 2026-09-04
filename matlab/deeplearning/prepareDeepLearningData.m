function [imdsTrain, imdsVal, imdsTest, classWeights, meta] = prepareDeepLearningData(cfg)
% prepareDeepLearningData  Create image datastores for deep learning training
%
%   [imdsTrain, imdsVal, imdsTest, classWeights, meta] = prepareDeepLearningData(cfg)
%
%   Creates imageDatastore objects with labels for train/val/test splits.
%   Handles quality gating and class weighting.

    if nargin < 1, cfg = deepLearningConfig(); end

    % Load splits
    trainT = readtable(fullfile(cfg.paths.splitDir, 'train.csv'), 'TextType', 'string');
    valT = readtable(fullfile(cfg.paths.splitDir, 'val.csv'), 'TextType', 'string');
    testT = readtable(fullfile(cfg.paths.splitDir, 'test.csv'), 'TextType', 'string');

    % Load quality results
    Tq = readtable(cfg.paths.qualityCSV, 'TextType', 'string');

    % Filter to labeled images only
    trainT = trainT(~isnan(trainT.dr_grade), :);
    valT = valT(~isnan(valT.dr_grade), :);
    testT = testT(~isnan(testT.dr_grade), :);

    fprintf('[prepareDLData] Labeled: train=%d val=%d test=%d\n', ...
        height(trainT), height(valT), height(testT));

    % Apply quality gating to training set
    if ~cfg.quality.includeBorderline || ~cfg.quality.includeUngradable
        trainT = applyQualityGating(trainT, Tq, cfg);
        fprintf('[prepareDLData] After quality gating: train=%d\n', height(trainT));
    end

    % Create image file paths and labels
    [trainPaths, trainLabels] = buildPathLabels(trainT, cfg);
    [valPaths, valLabels] = buildPathLabels(valT, cfg);
    [testPaths, testLabels] = buildPathLabels(testT, cfg);

    % Create datastores (augmentedImageDatastore will handle resizing)
    % Filter out empty paths first
    validTrain = ~cellfun('isempty', trainPaths);
    trainPaths = trainPaths(validTrain);
    trainLabels = trainLabels(validTrain);

    validVal = ~cellfun('isempty', valPaths);
    valPaths = valPaths(validVal);
    valLabels = valLabels(validVal);

    validTest = ~cellfun('isempty', testPaths);
    testPaths = testPaths(validTest);
    testLabels = testLabels(validTest);

    imdsTrain = imageDatastore(trainPaths, 'Labels', categorical(trainLabels));
    imdsVal = imageDatastore(valPaths, 'Labels', categorical(valLabels));
    imdsTest = imageDatastore(testPaths, 'Labels', categorical(testLabels));

    % Compute class weights
    classCounts = zeros(1, 5);
    for g = 0:4
        classCounts(g+1) = sum(trainLabels == g);
    end
    beta = cfg.imbalance.beta;
    effectiveNum = 1 - beta.^classCounts;
    classWeights = (1 - beta) ./ max(effectiveNum, 1e-6);
    classWeights = classWeights / min(classWeights);

    fprintf('[prepareDLData] Class weights: ');
    for g = 1:5, fprintf('%d:%.3f ', g-1, classWeights(g)); end
    fprintf('\n');

    % Save metadata
    meta = struct();
    meta.nTrain = numel(trainPaths);
    meta.nVal = numel(valPaths);
    meta.nTest = numel(testPaths);
    meta.trainPaths = trainPaths;
    meta.trainLabels = trainLabels;
    meta.valPaths = valPaths;
    meta.valLabels = valLabels;
    meta.testPaths = testPaths;
    meta.testLabels = testLabels;
    meta.classWeights = classWeights;
    meta.trainImageIds = trainT.image_id(validTrain);
    meta.valImageIds = valT.image_id(validVal);
    meta.testImageIds = testT.image_id(validTest);
    meta.trainDatasets = trainT.dataset(validTrain);
    meta.valDatasets = valT.dataset(validVal);
    meta.testDatasets = testT.dataset(validTest);
end

function filteredT = applyQualityGating(T, Tq, cfg)
    % Merge quality status
    qualityStatus = repmat("UNKNOWN", height(T), 1);
    for i = 1:height(T)
        qIdx = find(Tq.image_id == T.image_id(i), 1);
        if ~isempty(qIdx)
            qualityStatus(i) = Tq.quality_status(qIdx);
        end
    end

    % Filter
    keep = true(height(T), 1);
    for i = 1:height(T)
        if qualityStatus(i) == "UNGRADABLE" && ~cfg.quality.includeUngradable
            keep(i) = false;
        end
        if qualityStatus(i) == "BORDERLINE" && ~cfg.quality.includeBorderline
            keep(i) = false;
        end
    end

    filteredT = T(keep, :);
end

function [paths, labels] = buildPathLabels(T, cfg)
    paths = cell(height(T), 1);
    labels = zeros(height(T), 1);

    % Load manifest for file paths
    manifest = readtable(cfg.paths.manifest, 'TextType', 'string');

    for i = 1:height(T)
        imgId = T.image_id(i);

        % Find in manifest
        mIdx = find(manifest.image_id == imgId, 1);
        if ~isempty(mIdx)
            imgPath = manifest.file_path_absolute{mIdx};
            if exist(imgPath, 'file')
                paths{i} = imgPath;
            else
                % Try relative path
                imgPath = fullfile(cfg.projectRoot, manifest.file_path{mIdx});
                if exist(imgPath, 'file')
                    paths{i} = imgPath;
                else
                    paths{i} = '';
                end
            end
        else
            paths{i} = '';
        end

        labels(i) = T.dr_grade(i);
    end

    % Remove entries with empty paths
    valid = ~cellfun('isempty', paths);
    paths = paths(valid);
    labels = labels(valid);
end

function out = preprocessImage(in, cfg)
    % Resize and normalize image
    img = in{1};
    img = imresize(img, cfg.image.size, cfg.image.resizeMethod);

    % ImageNet normalization
    if cfg.image.normalize
        meanRGB = [0.485 0.456 0.406];
        stdRGB = [0.229 0.224 0.225];
        img = double(img) / 255;
        for c = 1:3
            img(:,:,c) = (img(:,:,c) - meanRGB(c)) / stdRGB(c);
        end
    end

    out = {img};
end
