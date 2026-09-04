function results = predictDRSeverity(drModel, refModel, XTest, imageIds, datasets, drTrainInfo, refTrainInfo, cfg)
% predictDRSeverity  Generate predictions for test images
%
%   results = predictDRSeverity(drModel, refModel, XTest, imageIds, datasets, drTrainInfo, refTrainInfo, cfg)

    if nargin < 8, cfg = classificationConfig(); end

    nSamples = size(XTest, 1);
    classes = cfg.grades;

    % Handle NaN
    featureMedian = drTrainInfo.featureMedian;
    XTestClean = XTest;
    for j = 1:size(XTest, 2)
        nanIdx = isnan(XTestClean(:, j));
        XTestClean(nanIdx, j) = featureMedian(j);
    end

    % Five-class prediction
    [YPred, ~, classScores] = predict(drModel, XTestClean);

    % Referable DR prediction
    if ~isempty(refModel)
        refMedian = refTrainInfo.featureMedian;
        XTestRef = XTestClean;
        for j = 1:size(XTestRef, 2)
            nanIdx = isnan(XTestRef(:, j));
            XTestRef(nanIdx, j) = refMedian(j);
        end
        [refPred, ~, refScores] = predict(refModel, XTestRef);
        % scores(:,1) = P(class=0), scores(:,2) = P(class=1)
        % fitPosterior may reverse column order; use scores(:,1) for P(referable=1)
        refProb = refScores(:, 1);
    else
        refPred = double(YPred >= cfg.referable.threshold);
        refProb = zeros(nSamples, 1);
        for i = 1:nSamples
            refProb(i) = sum(classScores(i, cfg.referable.grades + 1));
        end
    end

    % Build results table
    results = struct();
    results.image_id = string(imageIds);
    results.dataset = string(datasets);
    results.predicted_grade = YPred(:);
    results.referable_pred = refPred(:);
    results.referable_probability = refProb(:);

    % Class probabilities (softmax ECOC scores to get proper probabilities)
    ecocScores = classScores;
    expScores = exp(ecocScores);
    normScores = expScores ./ sum(expScores, 2);
    for g = 0:4
        results.(sprintf('prob_level_%d', g)) = normScores(:, g + 1);
    end

    % Confidence = max probability
    results.confidence_score = max(normScores, [], 2);

    % Classification status
    results.classification_status = repmat("COMPLETED", nSamples, 1);
end
