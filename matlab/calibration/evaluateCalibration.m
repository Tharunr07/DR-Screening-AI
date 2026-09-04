function cal = evaluateCalibration(net, testImds, testLabels, varargin)
% evaluateCalibration  Evaluate confidence calibration of DR classifier
%
%   cal = evaluateCalibration(net, testImds, testLabels)
%
%   Computes:
%       - Expected Calibration Error (ECE)
%       - Brier score
%       - Reliability curve data
%       - Confidence distribution
%       - Per-grade calibration
%
%   Input:
%       net         - Trained network (frozen Phase 8)
%       testImds    - Test image datastore
%       testLabels  - True labels (categorical or numeric)
%
%   Output:
%       cal - Struct with calibration metrics

    p = inputParser;
    addRequired(p, 'net');
    addRequired(p, 'testImds');
    addRequired(p, 'testLabels');
    addParameter(p, 'NumBins', 10, @isnumeric);
    parse(p, net, testImds, testLabels, varargin{:});

    numBins = p.Results.NumBins;

    % Initialize output
    cal = struct();
    cal.ece = 0;
    cal.brier = 0;
    cal.reliability = struct();
    cal.confidenceDist = struct();
    cal.perGrade = struct();
    cal.referableCal = struct();

    try
        % Get predictions and scores
        % Manually preprocess images for consistent input size
        numSamples = numel(testImds.Files);
        scores = zeros(numSamples, 5);
        YPred = categorical(zeros(numSamples, 1), 0:4);

        for i = 1:numSamples
            img = readimage(testImds, i);
            n = preprocessFundus(img, [224 224]);
            [pred_i, scores_i] = classify(net, n);
            YPred(i) = pred_i;
            scores(i, :) = scores_i;
        end

        % Convert to numeric
        if iscategorical(testLabels)
            YTrue = double(testLabels) - 1;
        else
            YTrue = double(testLabels);
        end

        YPredNum = double(YPred) - 1;

        % Referable probabilities (sum of grades 2-4)
        if size(scores, 2) >= 3
            refProb = sum(scores(:, 3:5), 2);
        else
            refProb = max(scores, [], 2);
        end

        % True referable status
        refTrue = double(YTrue >= 2);

        % Predicted referable
        refPred = double(refProb >= 0.1951);

        % === ECE (Expected Calibration Error) ===
        % Bin predictions by confidence
        binEdges = linspace(0, 1, numBins + 1);
        binConf = zeros(numBins, 1);
        binAcc = zeros(numBins, 1);
        binCount = zeros(numBins, 1);

        for b = 1:numBins
            inBin = refProb >= binEdges(b) & refProb < binEdges(b + 1);
            if b == numBins
                inBin = refProb >= binEdges(b) & refProb <= binEdges(b + 1);
            end

            binCount(b) = sum(inBin);
            if binCount(b) > 0
                binConf(b) = mean(refProb(inBin));
                binAcc(b) = mean(refTrue(inBin));
            else
                binConf(b) = (binEdges(b) + binEdges(b + 1)) / 2;
                binAcc(b) = binConf(b);
            end
        end

        % ECE = weighted average of |accuracy - confidence|
        cal.ece = sum(binCount .* abs(binAcc - binConf)) / sum(binCount);

        % === Brier Score ===
        % Mean squared difference between predicted probability and outcome
        cal.brier = mean((refProb - refTrue).^2);

        % === Reliability Curve Data ===
        cal.reliability.binConfidence = binConf;
        cal.reliability.binAccuracy = binAcc;
        cal.reliability.binCount = binCount;
        cal.reliability.binEdges = binEdges;

        % === Confidence Distribution ===
        cal.confidenceDist.mean = mean(refProb);
        cal.confidenceDist.std = std(refProb);
        cal.confidenceDist.median = median(refProb);
        cal.confidenceDist.min = min(refProb);
        cal.confidenceDist.max = max(refProb);

        % === Per-Grade Calibration ===
        grades = unique(YTrue);
        cal.perGrade.grades = grades;
        cal.perGrade.meanConf = zeros(numel(grades), 1);
        cal.perGrade.accuracy = zeros(numel(grades), 1);
        cal.perGrade.count = zeros(numel(grades), 1);

        for g = 1:numel(grades)
            gradeIdx = YTrue == grades(g);
            cal.perGrade.count(g) = sum(gradeIdx);
            if cal.perGrade.count(g) > 0
                cal.perGrade.meanConf(g) = mean(max(scores(gradeIdx, :), [], 2));
                cal.perGrade.accuracy(g) = mean(YPredNum(gradeIdx) == grades(g));
            end
        end

        % === Referable Calibration ===
        % Compare confidence vs accuracy for referable decision
        cal.referableCal.ece = cal.ece;
        cal.referableCal.brier = cal.brier;
        cal.referableCal.sensitivity = sum(refPred == 1 & refTrue == 1) / max(1, sum(refTrue == 1));
        cal.referableCal.specificity = sum(refPred == 0 & refTrue == 0) / max(1, sum(refTrue == 0));

        % High-confidence error analysis
        highConfThresh = 0.8;
        highConfMask = refProb >= highConfThresh;
        cal.referableCal.highConfCount = sum(highConfMask);
        if cal.referableCal.highConfCount > 0
            cal.referableCal.highConfError = mean(refTrue(highConfMask) ~= refPred(highConfMask));
        else
            cal.referableCal.highConfError = 0;
        end

    catch ME
        cal.error = ME.message;
    end
end
