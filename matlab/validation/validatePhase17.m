function results = validatePhase17(varargin)
% validatePhase17  Run complete Phase 17 clinical validation
%
%   results = validatePhase17()
%   results = validatePhase17('Verbose', true)

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'NumBootstrap', 100, @isnumeric);
    parse(p, varargin{:});

    verbose = p.Results.Verbose;
    numBootstrap = p.Results.NumBootstrap;

    if verbose
        fprintf('====================================================\n');
        fprintf('      DR SCREENING AI — MODEL VALIDATION\n');
        fprintf('====================================================\n');
        fprintf('Date: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    end

    % Load test predictions
    predFile = 'results/transfer_learning/predictions/tl_predictions.csv';
    T = readtable(predFile);

    trueLabels = T.true_grade;
    predictions = T.predicted_grade;

    % If scores not available, run inference to get them
    if ~ismember('score_G0', T.Properties.VariableNames)
        if verbose; fprintf('Running inference to get class scores...\n'); end
        cfgTL = transferLearningConfig();
        load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');

        numSamples = height(T);
        scores = zeros(numSamples, 5);

        for i = 1:numSamples
            imgPath = T.image_id{i};
            % Try to find the full path
            if exist(imgPath, 'file')
                img = imread(imgPath);
            else
                % Search in datasets
                dataset = T.dataset{i};
                if contains(dataset, 'APTOS')
                    searchPath = fullfile('data', 'raw', 'APTOS2019', 'train_images', [imgPath '.png']);
                else
                    searchPath = fullfile('data', 'raw', 'IDRiD', 'images', [imgPath '.jpg']);
                end
                if exist(searchPath, 'file')
                    img = imread(searchPath);
                else
                    scores(i, :) = [0.2 0.2 0.2 0.2 0.2];
                    continue;
                end
            end

            % Preprocess
            imgR = imresize(img, cfgTL.image.size, 'bicubic');
            mn = [0.485 0.456 0.406]; sd = [0.229 0.224 0.225];
            n = double(imgR)/255;
            for c = 1:3
                n(:,:,c) = (n(:,:,c) - mn(c)) / sd(c);
            end

            % Classify
            [~, scores_i] = classify(trainedNetTL, n);
            scores(i, :) = scores_i;
        end
    else
        scores = [T.score_G0, T.score_G1, T.score_G2, T.score_G3, T.score_G4];
    end

    if verbose
        fprintf('Test Images: %d\n\n', height(T));
    end

    % === 5-Class Classification ===
    if verbose; fprintf('--- 5-Class Classification ---\n'); end
    perfMetrics = evaluateModelPerformance(predictions, trueLabels);

    % === Referable DR ===
    if verbose; fprintf('\n--- Referable DR (G2+) ---\n'); end
    refMetrics = evaluateReferableDR(predictions, trueLabels);

    % === ROC Analysis ===
    if verbose; fprintf('\n--- ROC Analysis ---\n'); end
    [macroAUC, fpr, tpr] = plotROCCurve(scores, trueLabels);

    % === Confusion Matrix ===
    if verbose; fprintf('\n--- Confusion Matrix ---\n'); end
    plotConfusionMatrix(perfMetrics.confusionMatrix);

    % === Confidence Intervals ===
    if verbose; fprintf('\n--- Confidence Intervals ---\n'); end
    ci = calculateConfidenceIntervals(predictions, trueLabels, scores, ...
        'NumBootstrap', numBootstrap);

    % === Compile Results ===
    results = struct();
    results.testSamples = height(T);
    results.perfMetrics = perfMetrics;
    results.refMetrics = refMetrics;
    results.macroAUC = macroAUC;
    results.ci = ci;

    % === Print Final Summary ===
    if verbose
        fprintf('\n====================================================\n');
        fprintf('      FINAL VALIDATION SUMMARY\n');
        fprintf('====================================================\n');
        fprintf('Test Images: %d\n\n', height(T));

        fprintf('5-Class Classification\n');
        fprintf('--------------------------------\n');
        fprintf('Accuracy:          %.1f%%\n', perfMetrics.accuracy*100);
        fprintf('Balanced Accuracy: %.1f%%\n', perfMetrics.balancedAccuracy*100);
        fprintf('Macro F1:          %.1f%%\n', perfMetrics.macroF1*100);

        fprintf('\nReferable DR (G2+)\n');
        fprintf('--------------------------------\n');
        fprintf('Sensitivity:       %.1f%%\n', refMetrics.sensitivity*100);
        fprintf('Specificity:       %.1f%%\n', refMetrics.specificity*100);
        fprintf('PPV:               %.1f%%\n', refMetrics.ppv*100);
        fprintf('NPV:               %.1f%%\n', refMetrics.npv*100);
        fprintf('AUC:               %.3f\n', macroAUC);

        fprintf('\n95%% Confidence Intervals\n');
        fprintf('--------------------------------\n');
        fprintf('Sensitivity:       [%.1f%%, %.1f%%]\n', ...
            ci.sensitivity.ci(1)*100, ci.sensitivity.ci(2)*100);
        fprintf('Specificity:       [%.1f%%, %.1f%%]\n', ...
            ci.specificity.ci(1)*100, ci.specificity.ci(2)*100);
        fprintf('AUC:               [%.3f, %.3f]\n', ...
            ci.auc.ci(1), ci.auc.ci(2));

        fprintf('\nSIH Requirements\n');
        fprintf('--------------------------------\n');
        if refMetrics.sihSensitivityPass
            fprintf('Sensitivity >90%%:  PASS (%.1f%%)\n', refMetrics.sensitivity*100);
        else
            fprintf('Sensitivity >90%%:  FAIL (%.1f%%)\n', refMetrics.sensitivity*100);
        end
        if refMetrics.sihSpecificityPass
            fprintf('Specificity >85%%:  PASS (%.1f%%)\n', refMetrics.specificity*100);
        else
            fprintf('Specificity >85%%:  FAIL (%.1f%%)\n', refMetrics.specificity*100);
        end
        if refMetrics.sihOverallPass
            fprintf('Overall:           PASS\n');
        else
            fprintf('Overall:           FAIL\n');
        end

        fprintf('\n====================================================\n');
    end
end
