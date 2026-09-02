function analysis = analyzeFailures(predictions, trueLabels, scores, varargin)
% analyzeFailures  Analyze why the model fails on certain cases
%
%   analysis = analyzeFailures(predictions, trueLabels, scores)
%
    % Analyzes:
    % - Grade confusion patterns
    % - Confidence distribution of errors
    % - Common misclassification patterns

    p = inputParser;
    addRequired(p, 'predictions');
    addRequired(p, 'trueLabels');
    addRequired(p, 'scores');
    parse(p, predictions, trueLabels, scores);

    predictions = predictions(:);
    trueLabels = trueLabels(:);

    analysis = struct();

    % === 1. Grade-wise confusion patterns ===
    numClasses = 5;
    classNames = {'G0', 'G1', 'G2', 'G3', 'G4'};

    confusionPatterns = struct();
    for i = 1:numClasses
        for j = 1:numClasses
            if i ~= j
                idx = find(trueLabels == i & predictions == j);
                if ~isempty(idx)
                    fieldname = [classNames{i} '_to_' classNames{j}];
                    confusionPatterns.(fieldname).count = numel(idx);
                    confusionPatterns.(fieldname).indices = idx;
                    confusionPatterns.(fieldname).avgConfidence = mean(scores(idx, j));
                end
            end
        end
    end
    analysis.confusionPatterns = confusionPatterns;

    % === 2. Analyze referable misses (G2+ predicted as G0-G1) ===
    referableTrue = trueLabels >= 2;
    referablePred = predictions >= 2;

    % False negatives: truly referable but predicted non-referable
    fnIdx = find(referableTrue == 1 & referablePred == 0);
    analysis.fnIndices = fnIdx;
    analysis.fnCount = numel(fnIdx);

    if ~isempty(fnIdx)
        analysis.fnTrueGrades = trueLabels(fnIdx);
        analysis.fnPredGrades = predictions(fnIdx);
        analysis.fnConfidence = max(scores(fnIdx, :), [], 2);
        analysis.fnAvgConfidence = mean(analysis.fnConfidence);

        % Grade distribution of false negatives
        analysis.fnGradeDist = zeros(1, numClasses);
        for g = 1:numClasses
            analysis.fnGradeDist(g) = sum(trueLabels(fnIdx) == g-1);
        end
    end

    % False positives: non-referable predicted as referable
    fpIdx = find(referableTrue == 0 & referablePred == 1);
    analysis.fpIndices = fpIdx;
    analysis.fpCount = numel(fpIdx);

    if ~isempty(fpIdx)
        analysis.fpTrueGrades = trueLabels(fpIdx);
        analysis.fpPredGrades = predictions(fpIdx);
    end

    % === 3. Confidence analysis ===
    correctMask = predictions == trueLabels;
    incorrectMask = ~correctMask;

    analysis.correctConfidence = mean(max(scores(correctMask, :), [], 2));
    analysis.incorrectConfidence = mean(max(scores(incorrectMask, :), [], 2));

    % === 4. Class imbalance impact ===
    classCounts = histcounts(trueLabels, 0:4);
    analysis.classCounts = classCounts;
    analysis.minClassCount = min(classCounts);
    analysis.maxClassCount = max(classCounts);
    analysis.imbalanceRatio = analysis.maxClassCount / analysis.minClassCount;

    % === 5. Specific failure patterns ===
    % G3 and G4 have low sensitivity
    g3Idx = find(trueLabels == 3);
    g4Idx = find(trueLabels == 4);

    analysis.g3_total = numel(g3Idx);
    analysis.g3_correct = sum(predictions(g3Idx) == 3);
    analysis.g3_accuracy = analysis.g3_correct / analysis.g3_total;

    analysis.g4_total = numel(g4Idx);
    analysis.g4_correct = sum(predictions(g4Idx) == 4);
    analysis.g4_accuracy = analysis.g4_correct / analysis.g4_total;

    % === 6. Domain shift analysis ===
    % Check if errors are concentrated in one dataset
    if iscell(trueLabels)
        % If we have dataset info
        analysis.domainAnalysis = 'Dataset info not available in this format';
    end

    % Print summary
    fprintf('\n=== FAILURE ANALYSIS ===\n');

    fprintf('\n1. Grade Confusion Patterns:\n');
    patternNames = fieldnames(confusionPatterns);
    for i = 1:numel(patternNames)
        p = confusionPatterns.(patternNames{i});
        fprintf('  %s: %d cases (avg confidence: %.2f)\n', ...
            patternNames{i}, p.count, p.avgConfidence);
    end

    fprintf('\n2. Referable DR Misses:\n');
    fprintf('  False Negatives: %d (truly referable, predicted non-referable)\n', analysis.fnCount);
    fprintf('  False Positives: %d (non-referable, predicted referable)\n', analysis.fpCount);

    if ~isempty(fnIdx)
        fprintf('  FN True Grade Distribution:\n');
        for g = 1:numClasses
            fprintf('    %s: %d\n', classNames{g}, analysis.fnGradeDist(g));
        end
        fprintf('  FN Avg Confidence: %.2f\n', analysis.fnAvgConfidence);
    end

    fprintf('\n3. Class Imbalance:\n');
    fprintf('  Min class: %d samples\n', analysis.minClassCount);
    fprintf('  Max class: %d samples\n', analysis.maxClassCount);
    fprintf('  Imbalance ratio: %.1fx\n', analysis.imbalanceRatio);

    fprintf('\n4. Severe DR Detection:\n');
    fprintf('  G3 (Severe): %d/%d correct (%.1f%%)\n', ...
        analysis.g3_correct, analysis.g3_total, analysis.g3_accuracy*100);
    fprintf('  G4 (PDR): %d/%d correct (%.1f%%)\n', ...
        analysis.g4_correct, analysis.g4_total, analysis.g4_accuracy*100);

    fprintf('\n5. Confidence Analysis:\n');
    fprintf('  Correct predictions avg confidence: %.2f\n', analysis.correctConfidence);
    fprintf('  Incorrect predictions avg confidence: %.2f\n', analysis.incorrectConfidence);
end
