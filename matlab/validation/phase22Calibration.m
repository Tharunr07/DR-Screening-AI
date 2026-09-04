function phase22Calibration()
% phase22Calibration  Phase 22 — Confidence Calibration & Review Routing
%
%   Measures calibration quality and evaluates post-hoc calibration methods
%   without changing the classifier.

    fprintf('============================================================\n');
    fprintf('  Phase 22: Confidence Calibration & Review Routing\n');
    fprintf('============================================================\n\n');

    outputDir = 'results/phase22_calibration';
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    % Load corrected predictions
    T = readtable('data/splits/val_classifier_corrected.csv', 'TextType', 'string');
    n = height(T);
    fprintf('Loaded %d validation images\n\n', n);

    trueG = T.dr_grade;
    predG = T.predicted_grade;

    % Extract probability matrix (P_G0..P_G4)
    probRaw = [T.P_G0, T.P_G1, T.P_G2, T.P_G3, T.P_G4];

    % Per-image confidence = max probability
    confRaw = max(probRaw, [], 2);

    %% ====================================================================
    %  TASK 2: MEASURE RAW CALIBRATION
    %  ====================================================================
    fprintf('--- TASK 2: Raw Calibration Metrics ---\n\n');

    [eceRaw, mceRaw, brierRaw, nllRaw, binDataRaw] = computeCalibrationMetrics(probRaw, trueG, predG);

    fprintf('RAW calibration:\n');
    fprintf('  ECE: %.4f\n', eceRaw);
    fprintf('  MCE: %.4f\n', mceRaw);
    fprintf('  Brier: %.4f\n', brierRaw);
    fprintf('  NLL: %.4f\n', nllRaw);
    fprintf('  Accuracy: %.1f%%\n', sum(predG == trueG)/n*100);

    % Referable metrics
    refTrue = trueG >= 2;
    refPred = predG >= 2;
    sensRef = sum(refTrue & refPred) / sum(refTrue);
    specRef = sum(~refTrue & ~refPred) / sum(~refTrue);
    fprintf('  Referable sensitivity: %.1f%%\n', sensRef*100);
    fprintf('  Referable specificity: %.1f%%\n', specRef*100);

    %% ====================================================================
    %  TASK 3: EVALUATE CALIBRATION METHODS
    %  ====================================================================
    fprintf('\n--- TASK 3: Post-Hoc Calibration Methods ---\n\n');

    % Split into calibration set (60%) and validation set (40%)
    rng(42);
    nCal = round(0.6 * n);
    idx = randperm(n);
    calIdx = idx(1:nCal);
    valIdx = idx(nCal+1:end);

    fprintf('Split: %d calibration, %d validation\n', nCal, numel(valIdx));

    % --- Temperature Scaling ---
    fprintf('\nTemperature Scaling:\n');
    probCal_TS = temperatureScalingFit(probRaw(calIdx,:), trueG(calIdx));
    probVal_TS = temperatureScalingApply(probRaw(valIdx,:), probCal_TS);

    [eceTS, mceTS, brierTS, nllTS, ~] = computeCalibrationMetrics(probVal_TS, trueG(valIdx), predG(valIdx));
    fprintf('  ECE: %.4f (was %.4f)\n', eceTS, eceRaw);
    fprintf('  MCE: %.4f (was %.4f)\n', mceTS, mceRaw);
    fprintf('  Brier: %.4f (was %.4f)\n', brierTS, brierRaw);
    fprintf('  NLL: %.4f (was %.4f)\n', nllTS, nllRaw);

    % Apply to full dataset for comparison
    probFull_TS = temperatureScalingFit(probRaw(calIdx,:), trueG(calIdx));
    probAll_TS = temperatureScalingApply(probRaw, probFull_TS);
    [eceAllTS, mceAllTS, brierAllTS, nllAllTS, ~] = computeCalibrationMetrics(probAll_TS, trueG, predG);
    fprintf('  Full dataset ECE: %.4f, MCE: %.4f, Brier: %.4f, NLL: %.4f\n', eceAllTS, mceAllTS, brierAllTS, nllAllTS);

    % --- Isotonic Regression ---
    fprintf('\nIsotonic Regression:\n');
    try
        probVal_IR = isotonicCalibrationFit(probRaw(calIdx,:), trueG(calIdx), probRaw(valIdx,:));
        [eceIR, mceIR, brierIR, nllIR, ~] = computeCalibrationMetrics(probVal_IR, trueG(valIdx), predG(valIdx));
        fprintf('  ECE: %.4f (was %.4f)\n', eceIR, eceRaw);
        fprintf('  MCE: %.4f (was %.4f)\n', mceIR, mceRaw);
        fprintf('  Brier: %.4f (was %.4f)\n', brierIR, brierRaw);
        fprintf('  NLL: %.4f (was %.4f)\n', nllIR, nllRaw);

        % Full dataset isotonic
        probAll_IR = isotonicCalibrationFit(probRaw(calIdx,:), trueG(calIdx), probRaw);
        [eceAllIR, mceAllIR, brierAllIR, nllAllIR, ~] = computeCalibrationMetrics(probAll_IR, trueG, predG);
        fprintf('  Full dataset ECE: %.4f, MCE: %.4f, Brier: %.4f, NLL: %.4f\n', eceAllIR, mceAllIR, brierAllIR, nllAllIR);
        isotonicOK = true;
    catch me
        fprintf('  Isotonic regression failed: %s\n', me.message);
        eceIR = NaN; mceIR = NaN; brierIR = NaN; nllIR = NaN;
        eceAllIR = NaN; mceAllIR = NaN; brierAllIR = NaN; nllAllIR = NaN;
        probAll_IR = probRaw;
        isotonicOK = false;
    end

    %% ====================================================================
    %  TASK 4: CONFIDENCE-BASED REVIEW ROUTING
    %  ====================================================================
    fprintf('\n--- TASK 4: Confidence-Based Review Routing ---\n\n');

    thresholds = [0.50, 0.70, 0.90];
    routingResults = {};

    for t = 1:numel(thresholds)
        thresh = thresholds(t);

        % Auto-accept above threshold
        autoMask = confRaw >= thresh;
        reviewMask = ~autoMask;

        nAuto = sum(autoMask);
        nReview = sum(reviewMask);

        % Auto-accept accuracy
        autoCorrect = sum(predG(autoMask) == trueG(autoMask));
        autoAcc = autoCorrect / nAuto;

        % Auto-accept referable metrics
        autoRefTrue = trueG(autoMask) >= 2;
        autoRefPred = predG(autoMask) >= 2;
        autoSens = sum(autoRefTrue & autoRefPred) / sum(autoRefTrue);
        autoSpec = sum(~autoRefTrue & ~autoRefPred) / sum(~autoRefTrue);

        % Review set accuracy
        reviewCorrect = sum(predG(reviewMask) == trueG(reviewMask));
        reviewAcc = reviewCorrect / nReview;

        % False negatives in auto-accept
        autoFN = sum(autoRefTrue & ~autoRefPred);
        autoFP = sum(~autoRefTrue & autoRefPred);

        fprintf('Threshold >= %.2f:\n', thresh);
        fprintf('  Auto-accept: %d images (%.1f%%)\n', nAuto, nAuto/n*100);
        fprintf('  Review: %d images (%.1f%%)\n', nReview, nReview/n*100);
        fprintf('  Auto accuracy: %.1f%%\n', autoAcc*100);
        fprintf('  Auto referable sens: %.1f%%, spec: %.1f%%\n', autoSens*100, autoSpec*100);
        fprintf('  Auto FN: %d, FP: %d\n', autoFN, autoFP);
        fprintf('  Review accuracy: %.1f%%\n', reviewAcc*100);

        % Per-class recall in auto-accept
        for g = 0:4
            gTrue = trueG(autoMask) == g;
            gPred = predG(autoMask) == g;
            if sum(gTrue) > 0
                recall = sum(gPred & gTrue) / sum(gTrue);
                fprintf('  G%d recall in auto: %.1f%%\n', g, recall*100);
            end
        end

        routingResults{t} = struct('threshold', thresh, ...
            'nAuto', nAuto, 'nReview', nReview, ...
            'autoAcc', autoAcc, 'autoSens', autoSens, 'autoSpec', autoSpec, ...
            'autoFN', autoFN, 'autoFP', autoFP, 'reviewAcc', reviewAcc);
        fprintf('\n');
    end

    %% ====================================================================
    %  TASK 5: HIGH-CONFIDENCE ERROR ANALYSIS
    %  ====================================================================
    fprintf('--- TASK 5: High-Confidence Error Analysis ---\n\n');

    % Load Phase 21 high-confidence wrong predictions
    hcWrong = readtable('results/phase21_error_analysis/high_confidence_wrong.csv', 'TextType', 'string');
    fprintf('High-confidence wrong predictions: %d images\n', height(hcWrong));

    % Add calibrated probabilities
    for i = 1:height(hcWrong)
        imgId = hcWrong.image_id(i);
        match = T.image_id == imgId;
        if any(match)
            rawProb = probRaw(match, :);
            calProb = probAll_TS(match, :);
            hcWrong.raw_confidence(i) = max(rawProb);
            hcWrong.calibrated_confidence(i) = max(calProb);
            hcWrong.calibrated_grade(i) = find(calProb == max(calProb)) - 1;
        end
    end

    % How many errors have reduced confidence after calibration?
    if ismember('raw_confidence', hcWrong.Properties.VariableNames)
        reducedConf = sum(hcWrong.calibrated_confidence < hcWrong.raw_confidence);
        fprintf('  Errors with reduced confidence after TS: %d/%d (%.1f%%)\n', ...
            reducedConf, height(hcWrong), reducedConf/height(hcWrong)*100);
        fprintf('  Mean raw conf: %.4f\n', mean(hcWrong.raw_confidence));
        fprintf('  Mean calibrated conf: %.4f\n', mean(hcWrong.calibrated_confidence));
        fprintf('  Mean reduction: %.4f\n', mean(hcWrong.raw_confidence - hcWrong.calibrated_confidence));
    end

    %% ====================================================================
    %  TASK 6: GRADE VS REFERABLE ROUTING
    %  ====================================================================
    fprintf('\n--- TASK 6: Grade vs Referable Routing ---\n\n');

    % Five-class routing
    fprintf('FIVE-CLASS ROUTING (>=0.9 confidence):\n');
    autoMask5 = confRaw >= 0.90;
    fprintf('  Auto-accept: %d (%.1f%%), accuracy: %.1f%%\n', ...
        sum(autoMask5), sum(autoMask5)/n*100, sum(predG(autoMask5)==trueG(autoMask5))/sum(autoMask5)*100);

    % Binary referable routing
    % Use max of P(G2)+P(G3)+P(G4) vs P(G0)+P(G1) as confidence
    refProb = probRaw(:,3) + probRaw(:,4) + probRaw(:,5);
    nonRefProb = probRaw(:,1) + probRaw(:,2);
    refConf = max(refProb, nonRefProb);

    fprintf('\nBINARY REFERABLE ROUTING (>=0.9 confidence):\n');
    autoMaskRef = refConf >= 0.90;
    fprintf('  Auto-accept: %d (%.1f%%)\n', sum(autoMaskRef), sum(autoMaskRef)/n*100);
    if sum(autoMaskRef) > 0
        autoRefAcc = sum((refPred(autoMaskRef) == refTrue(autoMaskRef))) / sum(autoMaskRef);
        fprintf('  Accuracy: %.1f%%\n', autoRefAcc*100);
    end

    % Calibrated referable routing
    refProbCal = probAll_TS(:,3) + probAll_TS(:,4) + probAll_TS(:,5);
    nonRefProbCal = probAll_TS(:,1) + probAll_TS(:,2);
    refConfCal = max(refProbCal, nonRefProbCal);

    fprintf('\nCALIBRATED BINARY REFERABLE ROUTING (>=0.9):\n');
    autoMaskRefCal = refConfCal >= 0.90;
    fprintf('  Auto-accept: %d (%.1f%%)\n', sum(autoMaskRefCal), sum(autoMaskRefCal)/n*100);
    if sum(autoMaskRefCal) > 0
        autoRefAccCal = sum((refPred(autoMaskRefCal) == refTrue(autoMaskRefCal))) / sum(autoMaskRefCal);
        fprintf('  Accuracy: %.1f%%\n', autoRefAccCal*100);
    end

    %% ====================================================================
    %  TASK 7: DECISION TABLE
    %  ====================================================================
    fprintf('\n--- TASK 7: Decision Table ---\n\n');

    fprintf('%-20s %-8s %-8s %-8s %-8s %-10s %-10s %-10s\n', ...
        'Method', 'ECE', 'MCE', 'Brier', 'NLL', 'Accuracy', 'Ref Sens', 'Ref Spec');
    fprintf('%-20s %-8.4f %-8.4f %-8.4f %-8.4f %-10.1f %-10.1f %-10.1f\n', ...
        'Raw', eceRaw, mceRaw, brierRaw, nllRaw, ...
        sum(predG==trueG)/n*100, sensRef*100, specRef*100);

    % Temperature scaled metrics on full set
    predG_TS = applyCalibratedPrediction(probAll_TS);
    accTS = sum(predG_TS == trueG)/n*100;
    refPred_TS = predG_TS >= 2;
    sensRefTS = sum(refTrue & refPred_TS)/sum(refTrue)*100;
    specRefTS = sum(~refTrue & ~refPred_TS)/sum(~refTrue)*100;
    fprintf('%-20s %-8.4f %-8.4f %-8.4f %-8.4f %-10.1f %-10.1f %-10.1f\n', ...
        'Temperature Scaled', eceAllTS, mceAllTS, brierAllTS, nllAllTS, accTS, sensRefTS, specRefTS);

    if isotonicOK
        predG_IR = applyCalibratedPrediction(probAll_IR);
        accIR = sum(predG_IR == trueG)/n*100;
        refPred_IR = predG_IR >= 2;
        sensRefIR = sum(refTrue & refPred_IR)/sum(refTrue)*100;
        specRefIR = sum(~refTrue & ~refPred_IR)/sum(~refTrue)*100;
        fprintf('%-20s %-8.4f %-8.4f %-8.4f %-8.4f %-10.1f %-10.1f %-10.1f\n', ...
            'Isotonic', eceAllIR, mceAllIR, brierAllIR, nllAllIR, accIR, sensRefIR, specRefIR);
    else
        fprintf('%-20s (not available)\n', 'Isotonic');
    end

    %% ====================================================================
    %  TASK 8: REPRODUCIBILITY
    %  ====================================================================
    fprintf('\n--- TASK 8: Reproducibility ---\n\n');

    fprintf('RNG seed: 42 (fixed)\n');
    fprintf('Results deterministic: Yes (no stochastic components after fitting)\n');
    fprintf('Temperature scaling T parameter: %.4f\n', probCal_TS.temperature);
    fprintf('Isotonic regression: uses monotone fit (deterministic given same data)\n');

    %% ====================================================================
    %  TASK 9: NINE IMAGE REVALIDATION
    %  ====================================================================
    fprintf('\n--- TASK 9: Nine Image Reference Set ---\n\n');

    refImages = {'01499815e469','0097f532ac9f','00836aaacf06','009c019a7309', ...
                 '00e4ddff966a','01d9477b1171','fda39982a810','fe3b0e50be78','ff0740cb484a'};
    refReasons = {'Primary case','Corrected FP','Comparison','Comparison', ...
                  'Comparison','Comparison','G3 outlier','Corrected FP','G2 outlier'};

    nineResults = table();
    for i = 1:numel(refImages)
        imgId = refImages{i};
        match = T.image_id == imgId;
        if ~any(match), continue; end

        row = T(match,:);
        rawProb = probRaw(match,:);
        calProb = probAll_TS(match,:);

        idx = size(nineResults,1)+1;
        nineResults.image_id(idx) = string(imgId);
        nineResults.reason(idx) = string(refReasons{i});
        nineResults.true_grade(idx) = row.dr_grade;
        nineResults.pred_grade(idx) = row.predicted_grade;
        nineResults.raw_conf(idx) = max(rawProb);
        nineResults.cal_conf(idx) = max(calProb);
        nineResults.raw_grade(idx) = row.predicted_grade;
        nineResults.cal_grade(idx) = find(calProb == max(calProb)) - 1;
        nineResults.review_raw(idx) = string(decisionLabel(max(rawProb)));
        nineResults.review_cal(idx) = string(decisionLabel(max(calProb)));

        fprintf('  %s: True G%d, Pred G%d (raw=%.3f, cal=%.3f) -> Raw: %s, Cal: %s\n', ...
            imgId, row.dr_grade, row.predicted_grade, max(rawProb), max(calProb), ...
            decisionLabel(max(rawProb)), decisionLabel(max(calProb)));
    end

    %% ====================================================================
    %  TASK 11: WRITE OUTPUTS
    %  ====================================================================
    fprintf('\n--- Writing outputs ---\n');

    % Raw calibration metrics
    Tr = table();
    Tr.metric = ["ECE"; "MCE"; "Brier"; "NLL"; "Accuracy"; "RefSens"; "RefSpec"];
    Tr.value = [eceRaw; mceRaw; brierRaw; nllRaw; sum(predG==trueG)/n*100; sensRef*100; specRef*100];
    writetable(Tr, fullfile(outputDir, 'raw_calibration_metrics.csv'));
    fprintf('  raw_calibration_metrics.csv\n');

    % Temperature scaling metrics
    Tt = table();
    Tt.metric = ["ECE"; "MCE"; "Brier"; "NLL"; "Accuracy"; "RefSens"; "RefSpec"; "Temperature"];
    Tt.value = [eceAllTS; mceAllTS; brierAllTS; nllAllTS; accTS; sensRefTS; specRefTS; probCal_TS.temperature];
    writetable(Tt, fullfile(outputDir, 'temperature_scaling_metrics.csv'));
    fprintf('  temperature_scaling_metrics.csv\n');

    % Isotonic metrics
    if isotonicOK
        Ti = table();
        Ti.metric = ["ECE"; "MCE"; "Brier"; "NLL"; "Accuracy"; "RefSens"; "RefSpec"];
        Ti.value = [eceAllIR; mceAllIR; brierAllIR; nllAllIR; accIR; sensRefIR; specRefIR];
        writetable(Ti, fullfile(outputDir, 'isotonic_metrics.csv'));
        fprintf('  isotonic_metrics.csv\n');
    end

    % Confidence bins
    writetable(struct2table(binDataRaw), fullfile(outputDir, 'confidence_bins.csv'));
    fprintf('  confidence_bins.csv\n');

    % Review threshold analysis
    Trt = table();
    for t = 1:numel(routingResults)
        r = routingResults{t};
        idx = size(Trt,1)+1;
        Trt.threshold(idx) = r.threshold;
        Trt.n_auto(idx) = r.nAuto;
        Trt.n_review(idx) = r.nReview;
        Trt.auto_accuracy(idx) = r.autoAcc;
        Trt.auto_sensitivity(idx) = r.autoSens;
        Trt.auto_specificity(idx) = r.autoSpec;
        Trt.auto_FN(idx) = r.autoFN;
        Trt.auto_FP(idx) = r.autoFP;
        Trt.review_accuracy(idx) = r.reviewAcc;
    end
    writetable(Trt, fullfile(outputDir, 'review_threshold_analysis.csv'));
    fprintf('  review_threshold_analysis.csv\n');

    % High-confidence errors
    writetable(hcWrong, fullfile(outputDir, 'high_confidence_errors.csv'));
    fprintf('  high_confidence_errors.csv\n');

    % Nine image revalidation
    writetable(nineResults, fullfile(outputDir, 'nine_image_revalidation.csv'));
    fprintf('  nine_image_revalidation.csv\n');

    % Calibration comparison
    Tcomp = table();
    Tcomp.method = ["Raw"; "TemperatureScaled"];
    Tcomp.ECE = [eceRaw; eceAllTS];
    Tcomp.MCE = [mceRaw; mceAllTS];
    Tcomp.Brier = [brierRaw; brierAllTS];
    Tcomp.NLL = [nllRaw; nllAllTS];
    Tcomp.Accuracy = [sum(predG==trueG)/n*100; accTS];
    Tcomp.RefSens = [sensRef*100; sensRefTS];
    Tcomp.RefSpec = [specRef*100; specRefTS];
    if isotonicOK
        Tcomp.method(end+1) = "Isotonic";
        Tcomp.ECE(end+1) = eceAllIR;
        Tcomp.MCE(end+1) = mceAllIR;
        Tcomp.Brier(end+1) = brierAllIR;
        Tcomp.NLL(end+1) = nllAllIR;
        Tcomp.Accuracy(end+1) = accIR;
        Tcomp.RefSens(end+1) = sensRefIR;
        Tcomp.RefSpec(end+1) = specRefIR;
    end
    writetable(Tcomp, fullfile(outputDir, 'calibration_comparison.csv'));
    fprintf('  calibration_comparison.csv\n');

    %% ====================================================================
    %  TASK 12: FINAL DECISION
    %  ====================================================================
    fprintf('\n--- TASK 12: Final Decision ---\n\n');

    eceImprovement = eceRaw - eceAllTS;
    brierImprovement = brierRaw - brierAllTS;
    accChange = accTS - sum(predG==trueG)/n*100;

    fprintf('Temperature scaling effect:\n');
    fprintf('  ECE: %.4f -> %.4f (improvement: %.4f)\n', eceRaw, eceAllTS, eceImprovement);
    fprintf('  Brier: %.4f -> %.4f (improvement: %.4f)\n', brierRaw, brierAllTS, brierImprovement);
    fprintf('  Accuracy: %.1f%% -> %.1f%% (change: %+.1f%%)\n', ...
        sum(predG==trueG)/n*100, accTS, accChange);
    fprintf('  Ref Sens: %.1f%% -> %.1f%%\n', sensRef*100, sensRefTS);
    fprintf('  Ref Spec: %.1f%% -> %.1f%%\n', specRef*100, specRefTS);

    if eceImprovement > 0.01 && brierImprovement > 0.001
        decision = 'A. CALIBRATION BENEFICIAL';
    elseif eceImprovement < 0.005
        decision = 'B. CALIBRATION NOT BENEFICIAL';
    else
        decision = 'C. INCONCLUSIVE';
    end

    fprintf('\nDECISION: %s\n', decision);

    fprintf('\n============================================================\n');
    fprintf('  Phase 22 COMPLETE\n');
    fprintf('============================================================\n');
end

%% ====================================================================
%  HELPER FUNCTIONS
%  ====================================================================

function label = decisionLabel(conf)
    if conf >= 0.90
        label = "AUTO-ACCEPT";
    elseif conf >= 0.70
        label = "LIKELY-AUTO";
    elseif conf >= 0.50
        label = "REVIEW-RECOMMENDED";
    else
        label = "REVIEW-REQUIRED";
    end
end

function predG = applyCalibratedPrediction(prob)
    [~, predIdx] = max(prob, [], 2);
    predG = predIdx - 1;
end

function [ece, mce, brier, nll, binData] = computeCalibrationMetrics(prob, trueG, predG)
    n = size(prob, 1);
    nClasses = size(prob, 2);
    nBins = 10;
    binEdges = linspace(0, 1, nBins + 1);

    brier = 0;
    nll = 0;
    for i = 1:n
        onehot = zeros(1, nClasses);
        onehot(trueG(i) + 1) = 1;
        brier = brier + sum((prob(i,:) - onehot).^2);
        pCorrect = max(prob(i,:));
        if pCorrect > 0
            nll = nll - log(pCorrect);
        else
            nll = nll - log(1e-10);
        end
    end
    brier = brier / n;
    nll = nll / n;

    % ECE and MCE
    confMax = max(prob, [], 2);
    correct = (predG == trueG);

    binData = struct();
    binData.bin_center = zeros(nBins, 1);
    binData.bin_count = zeros(nBins, 1);
    binData.bin_accuracy = zeros(nBins, 1);
    binData.bin_confidence = zeros(nBins, 1);
    binData.bin_gap = zeros(nBins, 1);

    ece = 0;
    mce = 0;
    for b = 1:nBins
        mask = confMax >= binEdges(b) & confMax < binEdges(b+1);
        if b == nBins
            mask = confMax >= binEdges(b) & confMax <= binEdges(b+1);
        end
        nBin = sum(mask);
        binData.bin_center(b) = (binEdges(b) + binEdges(b+1)) / 2;
        binData.bin_count(b) = nBin;
        if nBin > 0
            binData.bin_accuracy(b) = sum(correct(mask)) / nBin;
            binData.bin_confidence(b) = mean(confMax(mask));
            binData.bin_gap(b) = abs(binData.bin_confidence(b) - binData.bin_accuracy(b));
            ece = ece + (nBin / n) * binData.bin_gap(b);
            mce = max(mce, binData.bin_gap(b));
        end
    end
end

function params = temperatureScalingFit(prob, trueG)
    % Find optimal temperature via grid search minimizing NLL
    n = size(prob, 1);
    bestT = 1.0;
    bestNLL = Inf;

    for T = 0.5:0.01:10.0
        scaled = prob .^ (1/T);
        scaled = scaled ./ sum(scaled, 2);
        nll = 0;
        for i = 1:n
            pCorrect = scaled(i, trueG(i) + 1);
            if pCorrect > 0
                nll = nll - log(pCorrect);
            else
                nll = nll - log(1e-10);
            end
        end
        nll = nll / n;
        if nll < bestNLL
            bestNLL = nll;
            bestT = T;
        end
    end

    params.temperature = bestT;
end

function probScaled = temperatureScalingApply(prob, params)
    T = params.temperature;
    scaled = prob .^ (1/T);
    probScaled = scaled ./ sum(scaled, 2);
end

function probCal = isotonicCalibrationFit(probTrain, trueTrain, probTest)
    nClasses = size(probTrain, 2);
    probCal = probTest;

    for c = 1:nClasses
        % Binary: is this class the true class?
        binaryTrue = (trueTrain == (c-1));
        scoresTrain = probTrain(:, c);
        scoresTest = probTest(:, c);

        % Sort by score
        [sortedScores, sortIdx] = sort(scoresTrain);
        sortedTrue = binaryTrue(sortIdx);

        % Pool adjacent violators (isotonic regression)
        nT = numel(sortedScores);
        fitted = sortedTrue;
        for iter = 1:100
            changed = false;
            for j = 2:nT
                if fitted(j) < fitted(j-1)
                    avg = (fitted(j) + fitted(j-1)) / 2;
                    fitted(j-1) = avg;
                    fitted(j) = avg;
                    changed = true;
                end
            end
            if ~changed, break; end
        end

        % Map test scores to isotonic fit
        for i = 1:numel(scoresTest)
            s = scoresTest(i);
            % Find nearest training score
            [~, nearestIdx] = min(abs(sortedScores - s));
            probCal(i, c) = fitted(nearestIdx);
        end

        % Renormalize
        probCal = probCal ./ sum(probCal, 2);
    end
end
