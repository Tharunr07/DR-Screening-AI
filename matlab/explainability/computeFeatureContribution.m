function contributions = computeFeatureContribution(drModel, refModel, XTest, imageIds, drTrainInfo, refTrainInfo, cfg)
% computeFeatureContribution  Perturbation-based per-image feature contribution
%
%   contributions = computeFeatureContribution(drModel, refModel, XTest, imageIds, drTrainInfo, refTrainInfo, cfg)
%
%   For each test image and each feature, replaces that feature with the
%   training-set median and measures the change in prediction probability.
%   This is a local perturbation explanation (NOT SHAP).

    if nargin < 7, cfg = explainabilityConfig(); end

    nSamples = size(XTest, 1);
    nFeatures = size(XTest, 2);
    featureNames = cfg.featureNames;
    featureMedian = drTrainInfo.featureMedian;
    refMedian = refTrainInfo.featureMedian;

    % Handle NaN: replace with training medians
    XTestClean = XTest;
    for j = 1:nFeatures
        nanIdx = isnan(XTestClean(:, j));
        XTestClean(nanIdx, j) = featureMedian(j);
    end

    % Compute original predictions
    [YPredOrig, ~, classScoresOrig] = predict(drModel, XTestClean);
    ecocOrig = classScoresOrig;
    expOrig = exp(ecocOrig);
    probOrig = expOrig ./ sum(expOrig, 2);

    XTestRef = XTestClean;
    for j = 1:nFeatures
        nanIdx = isnan(XTestRef(:, j));
        XTestRef(nanIdx, j) = refMedian(j);
    end
    [~, ~, refScoresOrig] = predict(refModel, XTestRef);
    refProbOrig = refScoresOrig(:, 1);

    % Storage for all contributions
    allContrib = struct();
    allContrib.image_id = {};
    allContrib.feature_name = {};
    allContrib.feature_index = [];
    allContrib.original_value = [];
    allContrib.median_value = [];
    allContrib.original_ref_prob = [];
    allContrib.perturbed_ref_prob = [];
    allContrib.contribution = [];
    allContrib.direction = {};

    for i = 1:nSamples
        xOrig = XTestClean(i, :);
        origRefProb = refProbOrig(i);
        origClass = YPredOrig(i);
        origProb = probOrig(i, :);

        for j = 1:nFeatures
            % Replace feature j with median
            xPert = xOrig;
            xPert(j) = featureMedian(j);

            % Predict with perturbed feature
            [~, ~, classScoresPert] = predict(drModel, xPert);
            ecocPert = classScoresPert;
            expPert = exp(ecocPert);
            probPert = expPert ./ sum(expPert, 2);

            xPertRef = xPert;
            [~, ~, refScoresPert] = predict(refModel, xPertRef);
            refProbPert = refScoresPert(:, 1);

            % Contribution = original probability - perturbed probability
            % Positive contribution means the original feature value
            % pushed the probability UP (supported the prediction)
            contrib = origRefProb - refProbPert;

            if contrib > 0.001
                direction = 'SUPPORTS';
            elseif contrib < -0.001
                direction = 'OPPOSES';
            else
                direction = 'NEUTRAL';
            end

            idx = numel(allContrib.image_id) + 1;
            allContrib.image_id{idx} = imageIds{i};
            allContrib.feature_name{idx} = featureNames{j};
            allContrib.feature_index(idx) = j;
            allContrib.original_value(idx) = xOrig(j);
            allContrib.median_value(idx) = featureMedian(j);
            allContrib.original_ref_prob(idx) = origRefProb;
            allContrib.perturbed_ref_prob(idx) = refProbPert;
            allContrib.contribution(idx) = contrib;
            allContrib.direction{idx} = direction;
        end

        if mod(i, 50) == 0
            fprintf('[computeFeatureContribution] Processed %d/%d images\n', i, nSamples);
        end
    end

    % Build output table
    nRows = numel(allContrib.image_id);
    T = table(allContrib.image_id(:), allContrib.feature_name(:), allContrib.feature_index(:), ...
        allContrib.original_value(:), allContrib.median_value(:), ...
        allContrib.original_ref_prob(:), allContrib.perturbed_ref_prob(:), ...
        allContrib.contribution(:), allContrib.direction(:), ...
        'VariableNames', {'image_id', 'feature_name', 'feature_index', ...
        'original_value', 'median_value', ...
        'original_ref_prob', 'perturbed_ref_prob', ...
        'contribution', 'direction'});
    writetable(T, fullfile(cfg.paths.outputDir, cfg.output.contributionsCSV));

    % Build per-image summary
    contributions = struct();
    contributions.image_ids = imageIds;
    contributions.nSamples = nSamples;
    contributions.nFeatures = nFeatures;
    contributions.feature_names = featureNames;
    contributions.details = T;

    % Per-image top contributions
    contributions.topFeatures = cell(nSamples, 1);
    for i = 1:nSamples
        imgId = imageIds{i};
        imgMask = strcmp(T.image_id, imgId);
        imgTable = T(imgMask, :);
        [~, sortIdx] = sort(abs(imgTable.contribution), 'descend');
        topN = min(5, height(imgTable));
        topFeatures = struct();
        topFeatures.name = {};
        topFeatures.contribution = [];
        topFeatures.direction = {};
        for k = 1:topN
            topFeatures.name{k} = imgTable.feature_name{sortIdx(k)};
            topFeatures.contribution(k) = imgTable.contribution(sortIdx(k));
            topFeatures.direction{k} = imgTable.direction{sortIdx(k)};
        end
        contributions.topFeatures{i} = topFeatures;
    end

    fprintf('[computeFeatureContribution] Saved %d contribution rows for %d images\n', nRows, nSamples);
end
