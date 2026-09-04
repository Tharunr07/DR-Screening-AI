function results = validatePhase13(varargin)
% validatePhase13  Comprehensive validation for Phase 13 calibration + usability
%
%   results = validatePhase13()
%   results = validatePhase13('Verbose', true)
%
%   Tests:
%       1. Functions exist
%       2. Calibration metrics
%       3. Reliability curve data
%       4. ECE calculation
%       5. Brier score calculation
%       6. Confidence distribution
%       7. Per-grade calibration
%       8. Review timing
%       9. Report generation timing
%      10. End-to-end pipeline

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    verbose = p.Results.Verbose;
    passed = 0;
    total = 10;
    results = struct();

    if verbose
        fprintf('=== PHASE 13 VALIDATION ===\n');
        fprintf('Date: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    end

    % Load config
    cfgTL = transferLearningConfig();

    % Load test set
    T = readtable('data/splits/test.csv');
    numSamples = min(50, height(T));
    idx = randperm(height(T), numSamples);
    testPaths = T.file_path_absolute(idx);
    testLabels = categorical(T.dr_grade(idx));

    % Load model
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');

    % Create test image datastore
    testImds = imageDatastore(testPaths, 'Labels', testLabels);

    % TEST 1: Functions exist
    try
        assert(exist('evaluateCalibration', 'file') > 0);
        assert(exist('plotCalibrationCurve', 'file') > 0);
        assert(exist('measureReviewTime', 'file') > 0);
        results.functionsExist = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Functions exist... PASS\n'); end
    catch
        results.functionsExist = 'FAIL';
        if verbose; fprintf('TEST: Functions exist... FAIL\n'); end
    end

    % TEST 2: Calibration metrics
    try
        cal = evaluateCalibration(trainedNetTL, testImds, testLabels);
        assert(isfield(cal, 'ece'));
        assert(isfield(cal, 'brier'));
        assert(isfield(cal, 'reliability'));
        results.calibrationMetrics = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Calibration metrics... PASS\n'); end
    catch
        results.calibrationMetrics = 'FAIL';
        if verbose; fprintf('TEST: Calibration metrics... FAIL\n'); end
    end

    % TEST 3: Reliability curve data
    try
        assert(isfield(cal.reliability, 'binConfidence'));
        assert(isfield(cal.reliability, 'binAccuracy'));
        assert(isfield(cal.reliability, 'binCount'));
        assert(numel(cal.reliability.binConfidence) == 10);
        results.reliabilityCurve = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Reliability curve data... PASS\n'); end
    catch
        results.reliabilityCurve = 'FAIL';
        if verbose; fprintf('TEST: Reliability curve data... FAIL\n'); end
    end

    % TEST 4: ECE calculation
    try
        assert(isnumeric(cal.ece));
        assert(cal.ece >= 0);
        assert(cal.ece <= 1);
        results.eceCalculation = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: ECE calculation... PASS (ECE=%.3f)\n', cal.ece); end
    catch
        results.eceCalculation = 'FAIL';
        if verbose; fprintf('TEST: ECE calculation... FAIL\n'); end
    end

    % TEST 5: Brier score calculation
    try
        assert(isnumeric(cal.brier));
        assert(cal.brier >= 0);
        assert(cal.brier <= 1);
        results.brierScore = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Brier score... PASS (Brier=%.3f)\n', cal.brier); end
    catch
        results.brierScore = 'FAIL';
        if verbose; fprintf('TEST: Brier score... FAIL\n'); end
    end

    % TEST 6: Confidence distribution
    try
        assert(isfield(cal.confidenceDist, 'mean'));
        assert(isfield(cal.confidenceDist, 'std'));
        assert(isfield(cal.confidenceDist, 'median'));
        assert(cal.confidenceDist.mean >= 0);
        assert(cal.confidenceDist.mean <= 1);
        results.confidenceDist = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Confidence distribution... PASS\n'); end
    catch
        results.confidenceDist = 'FAIL';
        if verbose; fprintf('TEST: Confidence distribution... FAIL\n'); end
    end

    % TEST 7: Per-grade calibration
    try
        assert(isfield(cal.perGrade, 'grades'));
        assert(isfield(cal.perGrade, 'meanConf'));
        assert(isfield(cal.perGrade, 'accuracy'));
        assert(isfield(cal.perGrade, 'count'));
        assert(numel(cal.perGrade.grades) >= 1);
        results.perGradeCal = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Per-grade calibration... PASS\n'); end
    catch
        results.perGradeCal = 'FAIL';
        if verbose; fprintf('TEST: Per-grade calibration... FAIL\n'); end
    end

    % TEST 8: Review timing
    try
        timing = measureReviewTime('NumTrials', 3, 'Verbose', false);
        assert(isfield(timing, 'totalPipeline'));
        assert(isfield(timing, 'stats'));
        assert(timing.stats.totalPipeline.median > 0);
        results.reviewTiming = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Review timing... PASS (median=%.3f sec)\n', timing.stats.totalPipeline.median); end
    catch
        results.reviewTiming = 'FAIL';
        if verbose; fprintf('TEST: Review timing... FAIL\n'); end
    end

    % TEST 9: Report generation timing
    try
        assert(isfield(timing.stats, 'reportGeneration'));
        assert(timing.stats.reportGeneration.median >= 0);
        results.reportTiming = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Report generation timing... PASS\n'); end
    catch
        results.reportTiming = 'FAIL';
        if verbose; fprintf('TEST: Report generation timing... FAIL\n'); end
    end

    % TEST 10: End-to-end pipeline
    try
        % Complete pipeline: classify + calibrate + time
        scores = zeros(numSamples, 5);
        for i = 1:numSamples
            img = readimage(testImds, i);
            n = preprocessFundus(img, [224 224]);
            [~, scores_i] = classify(trainedNetTL, n);
            scores(i, :) = scores_i;
        end
        assert(size(scores, 1) == numSamples);
        assert(size(scores, 2) == 5);

        % Referable probabilities
        refProb = sum(scores(:, 3:5), 2);
        assert(all(refProb >= 0 & refProb <= 1));

        % Check calibration metrics are reasonable
        assert(cal.ece < 1, 'ECE out of range');
        assert(cal.brier < 1, 'Brier out of range');

        results.endToEnd = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: End-to-end pipeline... PASS\n'); end
    catch ME
        results.endToEnd = 'FAIL';
        if verbose; fprintf('TEST: End-to-end pipeline... FAIL (%s)\n', ME.message); end
    end

    % Summary
    if verbose
        fprintf('\n=== VALIDATION SUMMARY ===\n');
        fprintf('Passed: %d/%d\n', passed, total);
        fprintf('Failed: %d/%d\n', total - passed, total);
        if passed == total
            fprintf('ALL TESTS PASSED\n');
        else
            fprintf('SOME TESTS FAILED\n');
        end
    end

    results.passed = passed;
    results.total = total;
end
