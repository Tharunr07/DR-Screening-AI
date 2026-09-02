function comparison = comparePhase19(baseline, optimized, varargin)
% comparePhase19  Compare baseline vs optimized model performance
%
%   comparison = comparePhase19(baseline, optimized)
%
%   Compares Phase 17 baseline with Phase 19 optimized results.

    p = inputParser;
    addRequired(p, 'baseline');
    addRequired(p, 'optimized');
    parse(p, baseline, optimized);

    comparison = struct();

    % === Sensitivity comparison ===
    comparison.sensitivity = struct();
    comparison.sensitivity.baseline = baseline.refMetrics.sensitivity;
    comparison.sensitivity.optimized = optimized.refMetrics.sensitivity;
    comparison.sensitivity.diff = optimized.refMetrics.sensitivity - baseline.refMetrics.sensitivity;
    comparison.sensitivity.improved = optimized.refMetrics.sensitivity > baseline.refMetrics.sensitivity;

    % === Specificity comparison ===
    comparison.specificity = struct();
    comparison.specificity.baseline = baseline.refMetrics.specificity;
    comparison.specificity.optimized = optimized.refMetrics.specificity;
    comparison.specificity.diff = optimized.refMetrics.specificity - baseline.refMetrics.specificity;
    comparison.specificity.improved = optimized.refMetrics.specificity > baseline.refMetrics.specificity;

    % === AUC comparison ===
    comparison.auc = struct();
    comparison.auc.baseline = baseline.macroAUC;
    comparison.auc.optimized = optimized.macroAUC;
    comparison.auc.diff = optimized.macroAUC - baseline.macroAUC;
    comparison.auc.improved = optimized.macroAUC > baseline.macroAUC;

    % === Accuracy comparison ===
    comparison.accuracy = struct();
    comparison.accuracy.baseline = baseline.perfMetrics.accuracy;
    comparison.accuracy.optimized = optimized.perfMetrics.accuracy;
    comparison.accuracy.diff = optimized.perfMetrics.accuracy - baseline.perfMetrics.accuracy;
    comparison.accuracy.improved = optimized.perfMetrics.accuracy > baseline.perfMetrics.accuracy;

    % === SIH requirements ===
    comparison.sih = struct();
    comparison.sih.baselineMet = baseline.refMetrics.sihOverallPass;
    comparison.sih.optimizedMet = optimized.refMetrics.sihOverallPass;
    comparison.sih.nowMet = optimized.refMetrics.sihOverallPass && ~baseline.refMetrics.sihOverallPass;

    % === Per-class comparison ===
    comparison.perClass = struct();
    classNames = {'G0', 'G1', 'G2', 'G3', 'G4'};
    for c = 1:5
        comparison.perClass.(classNames{c}) = struct();
        comparison.perClass.(classNames{c}).baselineSens = baseline.perfMetrics.perClassMetrics{c}.sensitivity;
        comparison.perClass.(classNames{c}).optimizedSens = optimized.perfMetrics.perClassMetrics{c}.sensitivity;
        comparison.perClass.(classNames{c}).diff = optimized.perfMetrics.perClassMetrics{c}.sensitivity - ...
            baseline.perfMetrics.perClassMetrics{c}.sensitivity;
    end

    % === Print summary ===
    fprintf('\n=== PHASE 19 COMPARISON ===\n');

    fprintf('\nMetric Comparison:\n');
    fprintf('%-15s %10s %10s %10s %10s\n', 'Metric', 'Baseline', 'Optimized', 'Change', 'Status');
    fprintf('%-15s %10s %10s %10s %10s\n', '-------', '--------', '---------', '------', '------');

    fprintf('%-15s %9.1f%% %9.1f%% %+.1f%% %10s\n', 'Sensitivity', ...
        comparison.sensitivity.baseline*100, comparison.sensitivity.optimized*100, ...
        comparison.sensitivity.diff*100, ternary(comparison.sensitivity.improved, 'IMPROVED', 'unchanged'));

    fprintf('%-15s %9.1f%% %9.1f%% %+.1f%% %10s\n', 'Specificity', ...
        comparison.specificity.baseline*100, comparison.specificity.optimized*100, ...
        comparison.specificity.diff*100, ternary(comparison.specificity.improved, 'IMPROVED', 'unchanged'));

    fprintf('%-15s %9.3f %9.3f %+.3f %10s\n', 'AUC', ...
        comparison.auc.baseline, comparison.auc.optimized, ...
        comparison.auc.diff, ternary(comparison.auc.improved, 'IMPROVED', 'unchanged'));

    fprintf('%-15s %9.1f%% %9.1f%% %+.1f%% %10s\n', 'Accuracy', ...
        comparison.accuracy.baseline*100, comparison.accuracy.optimized*100, ...
        comparison.accuracy.diff*100, ternary(comparison.accuracy.improved, 'IMPROVED', 'unchanged'));

    fprintf('\nSIH Requirements:\n');
    fprintf('  Baseline: %s\n', ternary(comparison.sih.baselineMet, 'PASS', 'FAIL'));
    fprintf('  Optimized: %s\n', ternary(comparison.sih.optimizedMet, 'PASS', 'FAIL'));
    if comparison.sih.nowMet
        fprintf('  ** NOW MEETS SIH REQUIREMENTS **\n');
    end

    fprintf('\nPer-Class Sensitivity Change:\n');
    for c = 1:5
        fprintf('  %s: %.1f%% → %.1f%% (%+.1f%%)\n', classNames{c}, ...
            comparison.perClass.(classNames{c}).baselineSens*100, ...
            comparison.perClass.(classNames{c}).optimizedSens*100, ...
            comparison.perClass.(classNames{c}).diff*100);
    end
end

function result = ternary(condition, trueVal, falseVal)
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end
