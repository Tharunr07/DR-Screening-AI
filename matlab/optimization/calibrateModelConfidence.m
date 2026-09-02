function results = calibrateModelConfidence(scores, trueLabels, varargin)
% calibrateModelConfidence  Calibrate model confidence scores
%
%   results = calibrateModelConfidence(scores, trueLabels)
%
%   Applies temperature scaling for calibration.
%   Evaluates ECE and Brier score before/after calibration.

    p = inputParser;
    addRequired(p, 'scores');
    addRequired(p, 'trueLabels');
    parse(p, scores, trueLabels);

    trueLabels = trueLabels(:);
    numSamples = numel(trueLabels);
    numClasses = size(scores, 2);

    results = struct();

    % === Original calibration metrics ===
    % ECE (Expected Calibration Error)
    numBins = 10;
    binEdges = linspace(0, 1, numBins + 1);

    eceOrig = 0;
    for i = 1:numBins
        binMask = max(scores, [], 2) >= binEdges(i) & max(scores, [], 2) < binEdges(i+1);
        if sum(binMask) > 0
            binConfidence = mean(max(scores(binMask, :), [], 2));
            [~, predLabels] = max(scores(binMask, :), [], 2);
            binAccuracy = mean(double(predLabels == trueLabels(binMask) + 1));
            eceOrig = eceOrig + sum(binMask)/numSamples * abs(binAccuracy - binConfidence);
        end
    end

    % Brier score
    brierOrig = 0;
    for i = 1:numSamples
        oneHot = zeros(1, numClasses);
        oneHot(trueLabels(i) + 1) = 1;
        brierOrig = brierOrig + sum((scores(i, :) - oneHot).^2);
    end
    brierOrig = brierOrig / numSamples;

    results.original = struct();
    results.original.ece = eceOrig;
    results.original.brier = brierOrig;

    % === Temperature Scaling ===
    % Find optimal temperature on a validation split (use 20% of data)
    rng(42);
    valIdx = randperm(numSamples, round(0.2 * numSamples));
    trainIdx = setdiff(1:numSamples, valIdx);

    trainScores = scores(trainIdx, :);
    trainLabels = trueLabels(trainIdx);
    valScores = scores(valIdx, :);
    valLabels = trueLabels(valIdx);

    % Grid search for temperature
    temps = linspace(0.5, 5.0, 20);
    valECE = zeros(size(temps));

    for t = 1:numel(temps)
        temp = temps(t);
        % Apply temperature scaling
        scaledScores = softmax(log(trainScores + 1e-10) / temp, 2);

        % Compute ECE on validation set
        valScaledScores = softmax(log(valScores + 1e-10) / temp, 2);
        eceVal = 0;
        for b = 1:numBins
            binMask = max(valScaledScores, [], 2) >= binEdges(b) & ...
                      max(valScaledScores, [], 2) < binEdges(b+1);
            if sum(binMask) > 0
                binConfidence = mean(max(valScaledScores(binMask, :), [], 2));
                [~, binPredLabels] = max(valScaledScores(binMask, :), [], 2);
                binAccuracy = mean(double(binPredLabels == valLabels(binMask) + 1));
                eceVal = eceVal + sum(binMask)/numel(valLabels) * abs(binAccuracy - binConfidence);
            end
        end
        valECE(t) = eceVal;
    end

    [~, bestTempIdx] = min(valECE);
    bestTemp = temps(bestTempIdx);

    % Apply temperature scaling to all scores
    calibratedScores = softmax(log(scores + 1e-10) / bestTemp, 2);

    % Compute calibrated ECE
    eceCalib = 0;
    for b = 1:numBins
        binMask = max(calibratedScores, [], 2) >= binEdges(b) & ...
                  max(calibratedScores, [], 2) < binEdges(b+1);
        if sum(binMask) > 0
            binConfidence = mean(max(calibratedScores(binMask, :), [], 2));
            [~, predLabels] = max(calibratedScores(binMask, :), [], 2);
            binAccuracy = mean(double(predLabels == trueLabels(binMask) + 1));
            eceCalib = eceCalib + sum(binMask)/numSamples * abs(binAccuracy - binConfidence);
        end
    end

    % Compute calibrated Brier score
    brierCalib = 0;
    for i = 1:numSamples
        oneHot = zeros(1, numClasses);
        oneHot(trueLabels(i) + 1) = 1;
        brierCalib = brierCalib + sum((calibratedScores(i, :) - oneHot).^2);
    end
    brierCalib = brierCalib / numSamples;

    results.calibrated = struct();
    results.calibrated.temperature = bestTemp;
    results.calibrated.ece = eceCalib;
    results.calibrated.brier = brierCalib;
    results.calibrated.scores = calibratedScores;

    % === Print Summary ===
    fprintf('\n=== CALIBRATION RESULTS ===\n');
    fprintf('\nOriginal:\n');
    fprintf('  ECE: %.4f\n', eceOrig);
    fprintf('  Brier: %.4f\n', brierOrig);

    fprintf('\nCalibrated (Temperature = %.2f):\n', bestTemp);
    fprintf('  ECE: %.4f\n', eceCalib);
    fprintf('  Brier: %.4f\n', brierCalib);

    fprintf('\nImprovement:\n');
    fprintf('  ECE: %.4f → %.4f (%.1f%% reduction)\n', ...
        eceOrig, eceCalib, (eceOrig - eceCalib)/eceOrig*100);
    fprintf('  Brier: %.4f → %.4f (%.1f%% reduction)\n', ...
        brierOrig, brierCalib, (brierOrig - brierCalib)/brierOrig*100);
end
