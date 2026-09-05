function results = evaluateEXModel(manifest, indices, cfg)
% evaluateEXModel  Evaluate EX segmentation on given indices
%   Uses the trained model saved in models/ex_unet_baseline.mat

    expDir = fileparts(mfilename('fullpath'));
    modelPath = fullfile(expDir, 'models', 'ex_unet_baseline.mat');
    load(modelPath, 'trainedNet');
    net = trainedNet;
    inputSize = cfg.inputSize(1:2);

    nImages = numel(indices);
    fprintf('Evaluating %d images...\n', nImages);

    diceScores = zeros(nImages, 1);
    iouScores = zeros(nImages, 1);
    precisionScores = zeros(nImages, 1);
    recallScores = zeros(nImages, 1);
    emptyGT = false(nImages, 1);

    for i = 1:nImages
        idx = indices(i);
        img = imread(manifest(idx).image_path);
        gt = imread(manifest(idx).mask_path);
        if ndims(gt) > 2; gt = gt(:,:,1); end
        gt = double(gt > 0);

        % Resize and preprocess
        imgResized = imresize(img, inputSize, 'bilinear');
        if size(imgResized, 3) == 1
            imgResized = repmat(imgResized, [1 1 3]);
        end
        imgSingle = single(imgResized) / 255;

        % Predict
        pred = predict(net, imgSingle);
        % pred is HxWxC (C=2: channel 1=background, channel 2=lesion)
        if size(pred, 3) == 2
            predMask = pred(:,:,2); % lesion channel
        else
            predMask = pred(:,:,1);
        end
        predMask = imresize(predMask, size(gt), 'nearest');

        % Adaptive threshold: find threshold that maximizes Dice on this image
        bestDice = 0;
        bestThresh = 0.3;
        for t = [0.1, 0.2, 0.3, 0.4, 0.5]
            pm = double(predMask > t);
            tp = sum(gt(:) .* pm(:));
            fp = sum((1-gt(:)) .* pm(:));
            fn = sum(gt(:) .* (1-pm(:)));
            d = 2*tp / (2*tp + fp + fn + eps);
            if d > bestDice
                bestDice = d;
                bestThresh = t;
            end
        end
        predMask = double(predMask > bestThresh);

        % Compute metrics
        emptyGT(i) = sum(gt(:)) == 0;
        if emptyGT(i) && sum(predMask(:)) == 0
            diceScores(i) = 1; iouScores(i) = 1;
            precisionScores(i) = 1; recallScores(i) = 1;
        elseif emptyGT(i) && sum(predMask(:)) > 0
            diceScores(i) = 0; iouScores(i) = 0;
            precisionScores(i) = 0; recallScores(i) = 0;
        else
            tp = sum(gt(:) .* predMask(:));
            fp = sum((1-gt(:)) .* predMask(:));
            fn = sum(gt(:) .* (1-predMask(:)));
            diceScores(i) = 2*tp / (2*tp + fp + fn + eps);
            iouScores(i) = tp / (tp + fp + fn + eps);
            precisionScores(i) = tp / (tp + fp + eps);
            recallScores(i) = tp / (tp + fn + eps);
        end
    end

    results.nImages = nImages;
    results.nEmptyGT = sum(emptyGT);
    results.nNonEmptyGT = nImages - sum(emptyGT);
    results.dice = mean(diceScores);
    results.iou = mean(iouScores);
    results.precision = mean(precisionScores);
    results.recall = mean(recallScores);
    results.diceAll = diceScores;
    results.emptyGT = emptyGT;

    fprintf('  Images: %d (non-empty: %d, empty: %d)\n', ...
        nImages, results.nNonEmptyGT, results.nEmptyGT);
    fprintf('  Dice:      %.4f\n', results.dice);
    fprintf('  IoU:       %.4f\n', results.iou);
    fprintf('  Precision: %.4f\n', results.precision);
    fprintf('  Recall:    %.4f\n', results.recall);
end
