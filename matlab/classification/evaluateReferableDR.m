function metrics = evaluateReferableDR(YTrue, refPred, refProb, cfg)
% evaluateReferableDR  Compute binary referable-DR metrics
%
%   metrics = evaluateReferableDR(YTrue, refPred, refProb, cfg)

    if nargin < 4, cfg = classificationConfig(); end

    YTrueBin = double(YTrue >= cfg.referable.threshold);

    tp = sum(refPred == 1 & YTrueBin == 1);
    fn = sum(refPred == 0 & YTrueBin == 1);
    fp = sum(refPred == 1 & YTrueBin == 0);
    tn = sum(refPred == 0 & YTrueBin == 0);

    sensitivity = tp / max(1, tp + fn);
    specificity = tn / max(1, tn + fp);
    precision   = tp / max(1, tp + fp);
    npv         = tn / max(1, tn + fn);
    f1          = 2 * precision * sensitivity / max(1, precision + sensitivity);
    accuracy    = (tp + tn) / max(1, tp + tn + fp + fn);

    % ROC-AUC
    [fpr, tpr, ~, aucVal] = perfcurve(YTrueBin, refProb, 1);

    % PR-AUC (manual computation)
    [sortedProb, sortIdx] = sort(refProb, 'descend');
    sortedTrue = YTrueBin(sortIdx);
    tpCum = cumsum(sortedTrue);
    precArr = tpCum ./ (1:numel(sortedTrue))';
    recArr = tpCum ./ max(1, sum(YTrueBin == 1));
    % Remove duplicates and add endpoints
    precArr = [1; precArr]; recArr = [0; recArr];
    prAUC = trapz(recArr, precArr);
    if isnan(prAUC), prAUC = 0; end

    metrics = struct();
    metrics.sensitivity = sensitivity;
    metrics.specificity = specificity;
    metrics.precision = precision;
    metrics.npv = npv;
    metrics.f1 = f1;
    metrics.accuracy = accuracy;
    metrics.auc = aucVal;
    metrics.prAUC = prAUC;
    metrics.tp = tp;
    metrics.fn = fn;
    metrics.fp = fp;
    metrics.tn = tn;
    metrics.nSamples = numel(YTrueBin);
    metrics.nReferable = sum(YTrueBin == 1);
    metrics.nNonReferable = sum(YTrueBin == 0);

    fprintf('[evaluateReferableDR] sens=%.4f spec=%.4f prec=%.4f F1=%.4f AUC=%.4f\n', ...
        sensitivity, specificity, precision, f1, aucVal);
end
