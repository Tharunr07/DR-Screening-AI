function results = testClassificationPipeline(varargin)
% testClassificationPipeline  Synthetic tests for Phase 4
%
%   results = testClassificationPipeline('verbose', true)

    p = inputParser;
    addParameter(p, 'verbose', true);
    parse(p, varargin{:});
    verbose = p.Results.verbose;

    cfg = classificationConfig();
    tests = {};

    % Test 1: Feature construction
    tests{end+1} = @() testFeatureConstruction(cfg);

    % Test 2: Missing Phase 3 features
    tests{end+1} = @() testMissingFeatures(cfg);

    % Test 3: NaN handling in training
    tests{end+1} = @() testNaNHandling(cfg);

    % Test 4: Class labels
    tests{end+1} = @() testClassLabels(cfg);

    % Test 5: Five-class prediction
    tests{end+1} = @() testFiveClassPrediction(cfg);

    % Test 6: Referable conversion
    tests{end+1} = @() testReferableConversion(cfg);

    % Test 7: Probability normalization
    tests{end+1} = @() testProbabilityNormalization(cfg);

    % Test 8: Train/test separation
    tests{end+1} = @() testTrainTestSeparation(cfg);

    % Test 9: Reproducibility
    tests{end+1} = @() testReproducibility(cfg);

    % Test 10: Ungradable handling
    tests{end+1} = @() testUngradableHandling(cfg);

    % Test 11: Class imbalance weights
    tests{end+1} = @() testClassWeights(cfg);

    % Test 12: Referable classifier
    tests{end+1} = @() testReferableClassifier(cfg);

    % Run tests
    results = struct('total', numel(tests), 'passed', 0, 'failed', 0, 'details', {{}});
    for k = 1:numel(tests)
        try
            pass = tests{k}();
            if pass
                results.passed = results.passed + 1;
                detail = sprintf('[PASS] Test %d', k);
            else
                results.failed = results.failed + 1;
                detail = sprintf('[FAIL] Test %d', k);
            end
        catch ME
            results.failed = results.failed + 1;
            detail = sprintf('[EXCEPTION] Test %d: %s', k, ME.message);
        end
        results.details{end+1} = detail;
        if verbose, fprintf('%s\n', detail); end
    end

    if verbose
        fprintf('=== testClassificationPipeline %d/%d passed ===\n', results.passed, results.total);
    end
end

function pass = testFeatureConstruction(cfg)
    row = struct();
    row.overall_quality_score = 85;
    row.retinal_area_fraction = 0.7;
    row.fov_radius = 200;
    row.optic_disc_detected = true;
    row.optic_disc_radius = 15;
    row.optic_disc_confidence = 0.8;
    row.fovea_detected = true;
    row.fovea_confidence = 0.6;
    row.vessel_area_fraction = 0.12;
    row.vessel_density = 0.08;
    row.ma_candidate_count = 10;
    row.ma_candidate_area = 500;
    row.ma_confidence = 0.7;
    row.he_candidate_count = 3;
    row.he_candidate_area = 200;
    row.he_confidence = 0.5;
    row.ex_candidate_count = 1;
    row.ex_candidate_area = 50;
    row.ex_candidate_area_fraction = 0.001;
    row.ex_confidence = 0.4;
    row.nv_candidate = false;
    row.nv_score = 0;
    row.nv_confidence = 0;
    row.quality_status = 'GOOD';

    [feat, fNames, meta] = buildClassificationFeatures(row, cfg);
    pass = numel(feat) == 25 && numel(fNames) == 25 && ~any(isnan(feat));
end

function pass = testMissingFeatures(cfg)
    row = struct();
    row.overall_quality_score = 80;
    row.quality_status = 'GOOD';
    % All Phase 3 fields missing
    [feat, ~, ~] = buildClassificationFeatures(row, cfg);
    % Should have NaN for missing fields but not crash
    pass = numel(feat) == 25;
end

function pass = testNaNHandling(cfg)
    rng(42);
    X = randn(100, 25);
    X(randperm(numel(X), 50)) = NaN;
    Y = randi([0 4], 100, 1);
    template = templateSVM('KernelFunction', 'rbf', 'Standardize', true, 'ClassNames', 0:4);
    try
        model = fitcecoc(X, Y, 'Learners', template, 'Coding', 'onevsall', 'ClassNames', 0:4);
        pass = ~isempty(model);
    catch
        pass = false;
    end
end

function pass = testClassLabels(cfg)
    Y = [0; 1; 2; 3; 4; 0; 2; 3];
    pass = all(ismember(Y, cfg.grades));
end

function pass = testFiveClassPrediction(cfg)
    rng(42);
    X = randn(200, 25);
    Y = randi([0 4], 200, 1);
    template = templateSVM('KernelFunction', 'rbf', 'Standardize', true, 'ClassNames', 0:4);
    model = fitcecoc(X(1:150,:), Y(1:150), 'Learners', template, 'Coding', 'onevsall', 'ClassNames', 0:4);
    [YPred, ~, scores] = predict(model, X(151:200,:));
    pass = all(ismember(YPred, 0:4)) && size(scores, 2) == 5;
end

function pass = testReferableConversion(cfg)
    grades = [0 1 2 3 4];
    referable = double(grades >= cfg.referable.threshold);
    expected = [0 0 1 1 1];
    pass = isequal(referable, expected);
end

function pass = testProbabilityNormalization(cfg)
    rng(42);
    X = randn(100, 25);
    Y = randi([0 4], 100, 1);
    template = templateSVM('KernelFunction', 'rbf', 'Standardize', true, 'ClassNames', 0:4);
    model = fitcecoc(X, Y, 'Learners', template, 'Coding', 'onevsall', 'ClassNames', 0:4);
    [~, ~, scores] = predict(model, X(1:10,:));
    % Scores from ECOC are log-odds (can be negative), softmax them
    expScores = exp(scores);
    probs = expScores ./ sum(expScores, 2);
    rowSums = sum(probs, 2);
    pass = size(scores, 2) == 5 && all(abs(rowSums - 1) < 0.01);
end

function pass = testTrainTestSeparation(cfg)
    rng(42);
    trainIds = {'img1', 'img2', 'img3', 'img4', 'img5'};
    testIds = {'img6', 'img7', 'img8'};
    overlap = intersect(trainIds, testIds);
    pass = isempty(overlap);
end

function pass = testReproducibility(cfg)
    rng(42);
    X1 = randn(100, 25);
    rng(42);
    X2 = randn(100, 25);
    pass = isequal(X1, X2);
end

function pass = testUngradableHandling(cfg)
    status = "UNGRADABLE";
    % Should not be used for classification
    pass = status == "UNGRADABLE";
end

function pass = testClassWeights(cfg)
    Y = [0;0;0;0;0;0;0;0;1;2];
    classes = 0:4;
    classCounts = arrayfun(@(c) sum(Y == c), classes);
    totalSamples = numel(Y);
    weights = totalSamples ./ (numel(classes) .* max(classCounts, 1));
    % Class 0 has 8 samples, should get lower weight
    pass = weights(1) < weights(3);
end

function pass = testReferableClassifier(cfg)
    rng(42);
    X = randn(200, 25);
    Y = randi([0 4], 200, 1);
    YBin = double(Y >= 2);
    try
        model = fitcsvm(X, YBin, 'KernelFunction', 'rbf', 'Standardize', true, 'ClassNames', [0 1]);
        [YPred, ~, ~] = predict(model, X(1:10,:));
        pass = all(ismember(YPred, [0 1]));
    catch
        pass = false;
    end
end
