function calibration = computeCalibration(refProb, YTrue, cfg)
% computeCalibration  Evaluate referable probability calibration
%
%   calibration = computeCalibration(refProb, YTrue, cfg)
%
%   Computes:
%   - Reliability diagram data (bins, mean predicted, observed frequency)
%   - Brier score
%   - Expected Calibration Error (ECE)
%   - Maximum Calibration Error (MCE)
%   - Sample counts per bin
%
%   Clearly distinguishes DISCRIMINATION (AUC) from CALIBRATION (Brier, ECE).

    if nargin < 3, cfg = explainabilityConfig(); end

    nBins = cfg.calibration.nBins;
    YTrueBin = double(YTrue >= cfg.referable.threshold);

    % Create equal-width bins [0, 0.1), [0.1, 0.2), ..., [0.9, 1.0]
    binEdges = linspace(0, 1, nBins + 1);
    binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
    binCounts = zeros(nBins, 1);
    binTruePositives = zeros(nBins, 1);
    binMeanPredicted = zeros(nBins, 1);
    binObservedFreq = zeros(nBins, 1);

    for b = 1:nBins
        lo = binEdges(b);
        hi = binEdges(b + 1);
        if b == nBins
            inBin = (refProb >= lo) & (refProb <= hi);
        else
            inBin = (refProb >= lo) & (refProb < hi);
        end
        binCounts(b) = sum(inBin);
        if binCounts(b) > 0
            binMeanPredicted(b) = mean(refProb(inBin));
            binObservedFreq(b) = mean(YTrueBin(inBin));
        else
            binMeanPredicted(b) = binCenters(b);
            binObservedFreq(b) = NaN;
        end
        binTruePositives(b) = sum(YTrueBin(inBin));
    end

    % Brier score: mean((predicted - actual)^2)
    brierScore = mean((refProb - YTrueBin).^2);

    % Expected Calibration Error (ECE)
    validBins = binCounts > 0;
    ece = 0;
    for b = 1:nBins
        if validBins(b)
            ece = ece + (binCounts(b) / numel(refProb)) * abs(binMeanPredicted(b) - binObservedFreq(b));
        end
    end

    % Maximum Calibration Error (MCE)
    mce = 0;
    for b = 1:nBins
        if validBins(b)
            err = abs(binMeanPredicted(b) - binObservedFreq(b));
            if err > mce, mce = err; end
        end
    end

    % Discrimination metrics (from Phase 4, preserved)
    [~, ~, ~, aucVal] = perfcurve(YTrueBin, refProb, 1);

    % Build output
    calibration = struct();
    calibration.method = 'Platt scaling bins';
    calibration.n_bins = nBins;
    calibration.n_samples = numel(refProb);
    calibration.n_referable = sum(YTrueBin);
    calibration.n_non_referable = sum(~YTrueBin);

    calibration.brier_score = brierScore;
    calibration.ece = ece;
    calibration.mce = mce;
    calibration.auc = aucVal;

    calibration.bins = struct();
    calibration.bins.edges = binEdges;
    calibration.bins.centers = binCenters;
    calibration.bins.counts = binCounts;
    calibration.bins.mean_predicted = binMeanPredicted;
    calibration.bins.observed_frequency = binObservedFreq;
    calibration.bins.true_positives = binTruePositives;

    % Save calibration JSON
    calJson = struct();
    calJson.method = 'Platt scaling bins';
    calJson.disclaimer = 'Calibration of SVM posterior probabilities. Distinguish from discrimination (AUC).';
    calJson.n_bins = nBins;
    calJson.n_samples = numel(refProb);
    calJson.brier_score = brierScore;
    calJson.ece = ece;
    calJson.mce = mce;
    calJson.auc = aucVal;
    calJson.discrimination_auc = aucVal;
    calJson.calibration_brier = brierScore;
    calJson.calibration_ece = ece;
    calJson.calibration_mce = mce;
    calJson.bins = struct();
    for b = 1:nBins
        binName = sprintf('bin_%d', b);
        calJson.bins.(binName) = struct( ...
            'edge_lo', binEdges(b), ...
            'edge_hi', binEdges(b+1), ...
            'count', binCounts(b), ...
            'mean_predicted', binMeanPredicted(b), ...
            'observed_frequency', binObservedFreq(b), ...
            'true_positives', binTruePositives(b));
    end

    jsonStr = jsonencode(calJson, 'PrettyPrint', true);
    fid = fopen(fullfile(cfg.paths.outputDir, cfg.output.calibrationJSON), 'w');
    fwrite(fid, jsonStr, 'char');
    fclose(fid);

    % Save calibration bins CSV
    T = table(binCenters(:), binCounts(:), binMeanPredicted(:), ...
        binObservedFreq(:), binTruePositives(:), ...
        'VariableNames', {'bin_center', 'count', 'mean_predicted', ...
        'observed_frequency', 'true_positives'});
    writetable(T, fullfile(cfg.paths.outputDir, cfg.output.calibrationBinsCSV));

    % Generate reliability diagram plot
    hFig = figure('Visible', 'off', 'Position', [100 100 800 600]);
    validB = find(validBins);
    if ~isempty(validB)
        plot([0 1], [0 1], 'k--', 'LineWidth', 1.5); hold on;
        plot(binMeanPredicted(validB), binObservedFreq(validB), 'bo-', 'LineWidth', 2, 'MarkerSize', 8);
        xlabel('Mean Predicted Probability', 'FontSize', 12);
        ylabel('Observed Frequency', 'FontSize', 12);
        title(sprintf('Reliability Diagram (ECE=%.4f, Brier=%.4f)', ece, brierScore), 'FontSize', 14);
        legend('Perfect Calibration', 'Model', 'Location', 'northwest');
        grid on;
        axis([0 1 0 1]);
    end
    hold off;
    saveas(hFig, fullfile(cfg.paths.outputDir, cfg.output.calibrationPlot));
    close(hFig);

    fprintf('[computeCalibration] Brier=%.4f, ECE=%.4f, MCE=%.4f, AUC=%.4f\n', brierScore, ece, mce, aucVal);
end
