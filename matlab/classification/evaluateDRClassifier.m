function metrics = evaluateDRClassifier(YTrue, YPred, classScores, cfg)
% evaluateDRClassifier  Compute five-class DR classification metrics
%
%   metrics = evaluateDRClassifier(YTrue, YPred, classScores, cfg)

    if nargin < 4, cfg = classificationConfig(); end

    classes = cfg.grades;
    nClasses = numel(classes);

    % Confusion matrix
    confMat = zeros(nClasses, nClasses);
    for i = 1:numel(YTrue)
        trueIdx = find(classes == YTrue(i), 1);
        predIdx = find(classes == YPred(i), 1);
        if ~isempty(trueIdx) && ~isempty(predIdx)
            confMat(trueIdx, predIdx) = confMat(trueIdx, predIdx) + 1;
        end
    end

    % Per-class metrics
    perClass = struct();
    for g = 1:nClasses
        tp = confMat(g, g);
        fn = sum(confMat(g, :)) - tp;
        fp = sum(confMat(:, g)) - tp;
        tn = sum(confMat(:)) - tp - fn - fp;

        perClass(g).class = classes(g);
        perClass(g).sensitivity = tp / max(1, tp + fn);
        perClass(g).specificity = tn / max(1, tn + fp);
        perClass(g).precision = tp / max(1, tp + fp);
        perClass(g).f1 = 2 * perClass(g).precision * perClass(g).sensitivity / ...
            max(1, perClass(g).precision + perClass(g).sensitivity);
        perClass(g).support = sum(confMat(g, :));
    end

    % Overall metrics
    accuracy = trace(confMat) / max(1, sum(confMat(:)));
    macroSensitivity = mean([perClass.sensitivity]);
    macroPrecision = mean([perClass.precision]);
    macroF1 = mean([perClass.f1]);
    balancedAccuracy = macroSensitivity;

    % ROC-AUC (one-vs-rest)
    if ~isempty(classScores) && size(classScores, 2) == nClasses
        aucs = zeros(1, nClasses);
        for g = 1:nClasses
            binaryTrue = double(YTrue == classes(g));
            [~, ~, ~, aucs(g)] = perfcurve(binaryTrue, classScores(:, g), 1);
        end
        macroAUC = mean(aucs);
    else
        aucs = NaN(1, nClasses);
        macroAUC = NaN;
    end

    metrics = struct();
    metrics.accuracy = accuracy;
    metrics.balancedAccuracy = balancedAccuracy;
    metrics.macroSensitivity = macroSensitivity;
    metrics.macroPrecision = macroPrecision;
    metrics.macroF1 = macroF1;
    metrics.macroAUC = macroAUC;
    metrics.confusionMatrix = confMat;
    metrics.perClass = perClass;
    metrics.classAUCs = aucs;
    metrics.nSamples = numel(YTrue);
end
