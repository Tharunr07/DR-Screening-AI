function results = evaluateDomainRobustness(predictions, trueLabels, scores, datasetNames, varargin)
% evaluateDomainRobustness  Evaluate model performance across datasets
%
%   results = evaluateDomainRobustness(predictions, trueLabels, scores, datasetNames)
%
%   Analyzes performance differences between APTOS and IDRiD datasets.

    p = inputParser;
    addRequired(p, 'predictions');
    addRequired(p, 'trueLabels');
    addRequired(p, 'scores');
    addRequired(p, 'datasetNames');
    parse(p, predictions, trueLabels, scores, datasetNames);

    predictions = predictions(:);
    trueLabels = trueLabels(:);
    datasetNames = datasetNames(:);

    results = struct();

    % Get unique datasets
    uniqueDatasets = unique(datasetNames);
    numDatasets = numel(uniqueDatasets);

    % Per-dataset analysis
    for d = 1:numDatasets
        dataset = uniqueDatasets{d};
        datasetIdx = strcmp(datasetNames, dataset);

        datasetPred = predictions(datasetIdx);
        datasetTrue = trueLabels(datasetIdx);
        datasetScores = scores(datasetIdx, :);

        % 5-class metrics
        numClasses = 5;
        classNames = {'G0', 'G1', 'G2', 'G3', 'G4'};
        confusionMat = zeros(numClasses, numClasses);

        for i = 1:numel(datasetTrue)
            trueGrade = datasetTrue(i) + 1;
            predGrade = datasetPred(i) + 1;
            confusionMat(trueGrade, predGrade) = confusionMat(trueGrade, predGrade) + 1;
        end

        % Per-class accuracy
        perClassAcc = zeros(1, numClasses);
        for c = 1:numClasses
            classIdx = find(datasetTrue == c-1);
            if ~isempty(classIdx)
                perClassAcc(c) = sum(datasetPred(classIdx) == c-1) / numel(classIdx);
            end
        end

        % Binary referable metrics
        referableTrue = double(datasetTrue >= 2);
        referablePred = double(datasetPred >= 2);

        tp = sum(referablePred == 1 & referableTrue == 1);
        fp = sum(referablePred == 1 & referableTrue == 0);
        fn = sum(referablePred == 0 & referableTrue == 1);
        tn = sum(referablePred == 0 & referableTrue == 0);

        sensitivity = tp / (tp + fn);
        specificity = tn / (tn + fp);
        accuracy = (tp + tn) / (tp + fp + fn + tn);

        % Store results
        results.(dataset) = struct();
        results.(dataset).numSamples = sum(datasetIdx);
        results.(dataset).confusionMat = confusionMat;
        results.(dataset).perClassAcc = perClassAcc;
        results.(dataset).accuracy = accuracy;
        results.(dataset).sensitivity = sensitivity;
        results.(dataset).specificity = specificity;
        results.(dataset).classCounts = histcounts(datasetTrue, 0:5);
    end

    % Cross-dataset comparison
    if numDatasets == 2
        ds1 = uniqueDatasets{1};
        ds2 = uniqueDatasets{2};

        results.comparison = struct();
        results.comparison.sensitivityDiff = results.(ds1).sensitivity - results.(ds2).sensitivity;
        results.comparison.specificityDiff = results.(ds1).specificity - results.(ds2).specificity;
        results.comparison.accuracyDiff = results.(ds1).accuracy - results.(ds2).accuracy;
    end

    % Print summary
    fprintf('\n=== DOMAIN ROBUSTNESS ANALYSIS ===\n');

    for d = 1:numDatasets
        dataset = uniqueDatasets{d};
        res = results.(dataset);

        fprintf('\n%s (%d images):\n', dataset, res.numSamples);
        fprintf('  Accuracy: %.1f%%\n', res.accuracy*100);
        fprintf('  Sensitivity: %.1f%%\n', res.sensitivity*100);
        fprintf('  Specificity: %.1f%%\n', res.specificity*100);

        fprintf('  Per-class accuracy:\n');
        classNames = {'G0', 'G1', 'G2', 'G3', 'G4'};
        for c = 1:5
            fprintf('    %s: %.1f%% (%d samples)\n', classNames{c}, ...
                res.perClassAcc(c)*100, res.classCounts(c));
        end
    end

    if numDatasets == 2
        fprintf('\nCross-dataset comparison:\n');
        fprintf('  Sensitivity difference: %.1f%%\n', results.comparison.sensitivityDiff*100);
        fprintf('  Specificity difference: %.1f%%\n', results.comparison.specificityDiff*100);
        fprintf('  Accuracy difference: %.1f%%\n', results.comparison.accuracyDiff*100);
    end

    fprintf('\n=== ANALYSIS COMPLETE ===\n');
end
