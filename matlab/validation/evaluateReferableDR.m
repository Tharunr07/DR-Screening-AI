function metrics = evaluateReferableDR(predictions, trueLabels, varargin)
% evaluateReferableDR  Evaluate binary referable DR classification
%
%   metrics = evaluateReferableDR(predictions, trueLabels)
%
%   Referable DR: Grade 2, 3, 4
%   Non-referable: Grade 0, 1
%
%   Calculates:
%       - Sensitivity, specificity
%       - PPV, NPV
%       - F1 score
%       - AUC
%       - 2x2 confusion matrix
%
%   Input:
%       predictions - Nx1 vector of predicted grades (0-4)
%       trueLabels  - Nx1 vector of true grades (0-4)
%
%   Output:
%       metrics - Struct with binary classification metrics

    p = inputParser;
    addRequired(p, 'predictions');
    addRequired(p, 'trueLabels');
    parse(p, predictions, trueLabels);

    % Ensure column vectors
    predictions = predictions(:);
    trueLabels = trueLabels(:);

    % Convert to binary: referable (G2+) vs non-referable (G0-G1)
    predBinary = double(predictions >= 2);
    trueBinary = double(trueLabels >= 2);

    % 2x2 Confusion Matrix
    tp = sum(predBinary == 1 & trueBinary == 1);
    fp = sum(predBinary == 1 & trueBinary == 0);
    fn = sum(predBinary == 0 & trueBinary == 1);
    tn = sum(predBinary == 0 & trueBinary == 0);

    % Metrics
    sensitivity = tp / (tp + fn);
    specificity = tn / (tn + fp);
    ppv = tp / (tp + fp);
    npv = tn / (tn + fn);

    % F1 score
    if (ppv + sensitivity) > 0
        f1 = 2 * ppv * sensitivity / (ppv + sensitivity);
    else
        f1 = 0;
    end

    % Accuracy
    accuracy = (tp + tn) / (tp + fp + fn + tn);

    % Store metrics
    metrics = struct();
    metrics.tp = tp;
    metrics.fp = fp;
    metrics.fn = fn;
    metrics.tn = tn;
    metrics.sensitivity = sensitivity;
    metrics.specificity = specificity;
    metrics.ppv = ppv;
    metrics.npv = npv;
    metrics.f1 = f1;
    metrics.accuracy = accuracy;

    % Class distribution
    metrics.numReferable = sum(trueBinary == 1);
    metrics.numNonReferable = sum(trueBinary == 0);
    metrics.totalSamples = numel(trueLabels);

    % SIH requirements
    metrics.sihSensitivityTarget = 0.90;
    metrics.sihSpecificityTarget = 0.85;
    metrics.sihSensitivityPass = sensitivity >= metrics.sihSensitivityTarget;
    metrics.sihSpecificityPass = specificity >= metrics.sihSpecificityTarget;
    metrics.sihOverallPass = metrics.sihSensitivityPass && metrics.sihSpecificityPass;

    % Print summary
    fprintf('\n=== REFERABLE DR EVALUATION ===\n');
    fprintf('Referable: G2+ | Non-referable: G0-G1\n');
    fprintf('Total: %d (Referable: %d, Non-referable: %d)\n', ...
        metrics.totalSamples, metrics.numReferable, metrics.numNonReferable);
    fprintf('\nConfusion Matrix:\n');
    fprintf('                 Predicted\n');
    fprintf('                 Non-Ref  Referable\n');
    fprintf('Actual Non-Ref   %6d   %6d\n', tn, fp);
    fprintf('Actual Referable %6d   %6d\n', fn, tp);
    fprintf('\nMetrics:\n');
    fprintf('Sensitivity: %.1f%% (Target: >90%%) %s\n', ...
        sensitivity*100, char([32 32] + [metrics.sihSensitivityPass*69 + ~metrics.sihSensitivityPass*70]));
    fprintf('Specificity: %.1f%% (Target: >85%%) %s\n', ...
        specificity*100, char([32 32] + [metrics.sihSpecificityPass*69 + ~metrics.sihSpecificityPass*70]));
    fprintf('PPV:         %.1f%%\n', ppv*100);
    fprintf('NPV:         %.1f%%\n', npv*100);
    fprintf('F1 Score:    %.1f%%\n', f1*100);
    fprintf('Accuracy:    %.1f%%\n', accuracy*100);
    fprintf('\nSIH Requirement: %s\n', char([32 32] + [metrics.sihOverallPass*69 + ~metrics.sihOverallPass*70]));
end
