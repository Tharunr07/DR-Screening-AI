function results = evaluateHandcraftedEX(manifest, indices)
% evaluateHandcraftedEX  Run handcrafted EX detector and compute metrics
%   manifest: dataset manifest
%   indices: indices to evaluate

    nImages = numel(indices);
    fprintf('Evaluating handcrafted EX on %d images...\n', nImages);

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

        % Run handcrafted detector
        ev = detectExudates(img);
        predMask = double(ev.mask);

        % Resize pred to match GT if needed
        if ~isequal(size(predMask), size(gt))
            predMask = imresize(predMask, size(gt), 'nearest');
        end

        % Metrics
        emptyGT(i) = sum(gt(:)) == 0;
        if emptyGT(i) && sum(predMask(:)) == 0
            diceScores(i) = 1;
            iouScores(i) = 1;
            precisionScores(i) = 1;
            recallScores(i) = 1;
        elseif emptyGT(i) && sum(predMask(:)) > 0
            diceScores(i) = 0;
            iouScores(i) = 0;
            precisionScores(i) = 0;
            recallScores(i) = 0;
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
end
