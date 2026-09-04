function results = validatePhase16A(varargin)
% validatePhase16A  Validate Phase 16A clinical consistency + quality gating
%
%   results = validatePhase16A()
%   results = validatePhase16A('Verbose', true)

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    verbose = p.Results.Verbose;
    passed = 0;
    total = 10;
    results = struct();

    if verbose
        fprintf('=== PHASE 16A VALIDATION ===\n');
        fprintf('Date: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    end

    % Load config
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');

    % TEST 1: Clinical logic function exists
    try
        assert(exist('applyClinicalLogic', 'file') > 0);
        results.functionExists = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Clinical logic function exists... PASS\n'); end
    catch
        results.functionExists = 'FAIL';
        if verbose; fprintf('TEST: Clinical logic function exists... FAIL\n'); end
    end

    % TEST 2: Poor quality image rejected
    try
        quality.status = 'POOR';
        quality.brightness = 20;
        quality.contrast = 10;
        quality.sharpness = 50;
        scores = [0.8 0.1 0.05 0.03 0.02];
        evidence = struct('microaneurysms', struct('count', 0), ...
            'hemorrhages', struct('count', 0), ...
            'exudates', struct('count', 0), ...
            'neovascularization', struct('detected', false));

        result = applyClinicalLogic(0, scores, evidence, quality);
        assert(strcmp(result.status, 'UNGRADABLE'));
        assert(strcmp(result.referableDecision, 'RECAPTURE'));
        results.poorQualityRejected = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Poor quality image rejected... PASS\n'); end
    catch ME
        results.poorQualityRejected = 'FAIL';
        if verbose; fprintf('TEST: Poor quality image rejected... FAIL (%s)\n', ME.message); end
    end

    % TEST 3: Good quality image graded
    try
        quality.status = 'GOOD';
        quality.brightness = 120;
        quality.contrast = 45;
        quality.sharpness = 200;
        scores = [0.1 0.1 0.6 0.1 0.1];
        evidence = struct('microaneurysms', struct('count', 2), ...
            'hemorrhages', struct('count', 1), ...
            'exudates', struct('count', 0), ...
            'neovascularization', struct('detected', false));

        result = applyClinicalLogic(2, scores, evidence, quality);
        assert(strcmp(result.status, 'GRADED'));
        assert(result.gradeNum == 2);
        results.goodQualityGraded = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Good quality image graded... PASS\n'); end
    catch ME
        results.goodQualityGraded = 'FAIL';
        if verbose; fprintf('TEST: Good quality image graded... FAIL (%s)\n', ME.message); end
    end

    % TEST 4: Referable consistency (G0 = non-referable)
    try
        quality.status = 'GOOD';
        scores = [0.8 0.1 0.05 0.03 0.02];
        evidence = struct('microaneurysms', struct('count', 0), ...
            'hemorrhages', struct('count', 0), ...
            'exudates', struct('count', 0), ...
            'neovascularization', struct('detected', false));

        result = applyClinicalLogic(0, scores, evidence, quality);
        assert(~result.referable);
        assert(strcmp(result.referableDecision, 'NON-REFERABLE'));
        results.referableG0 = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: G0 is non-referable... PASS\n'); end
    catch ME
        results.referableG0 = 'FAIL';
        if verbose; fprintf('TEST: G0 is non-referable... FAIL (%s)\n', ME.message); end
    end

    % TEST 5: Referable consistency (G2 = referable)
    try
        scores = [0.05 0.05 0.7 0.1 0.1];
        evidence = struct('microaneurysms', struct('count', 3), ...
            'hemorrhages', struct('count', 1), ...
            'exudates', struct('count', 1), ...
            'neovascularization', struct('detected', false));

        result = applyClinicalLogic(2, scores, evidence, quality);
        assert(result.referable);
        assert(strcmp(result.referableDecision, 'REFERABLE'));
        results.referableG2 = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: G2 is referable... PASS\n'); end
    catch ME
        results.referableG2 = 'FAIL';
        if verbose; fprintf('TEST: G2 is referable... FAIL (%s)\n', ME.message); end
    end

    % TEST 6: Confidence level classification
    try
        quality.status = 'GOOD';
        % High confidence
        scores_high = [0.9 0.05 0.02 0.02 0.01];
        evidence = struct('microaneurysms', struct('count', 0), ...
            'hemorrhages', struct('count', 0), ...
            'exudates', struct('count', 0), ...
            'neovascularization', struct('detected', false));
        result_high = applyClinicalLogic(0, scores_high, evidence, quality);
        assert(strcmp(result_high.confidenceLevel, 'HIGH'));

        % Low confidence
        scores_low = [0.25 0.2 0.2 0.2 0.15];
        result_low = applyClinicalLogic(0, scores_low, evidence, quality);
        assert(strcmp(result_low.confidenceLevel, 'LOW'));

        results.confidenceLevel = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Confidence level classification... PASS\n'); end
    catch ME
        results.confidenceLevel = 'FAIL';
        if verbose; fprintf('TEST: Confidence level classification... FAIL (%s)\n', ME.message); end
    end

    % TEST 7: Lesion-classifier consistency (consistent case)
    try
        quality.status = 'GOOD';
        scores = [0.05 0.05 0.7 0.1 0.1];
        evidence = struct('microaneurysms', struct('count', 3), ...
            'hemorrhages', struct('count', 1), ...
            'exudates', struct('count', 1), ...
            'neovascularization', struct('detected', false));

        result = applyClinicalLogic(2, scores, evidence, quality);
        assert(strcmp(result.consistency, 'CONSISTENT'));
        assert(isempty(result.consistencyWarning));
        results.consistencyCheck = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Lesion-classifier consistency (consistent)... PASS\n'); end
    catch ME
        results.consistencyCheck = 'FAIL';
        if verbose; fprintf('TEST: Lesion-classifier consistency... FAIL (%s)\n', ME.message); end
    end

    % TEST 8: Lesion-classifier inconsistency (Grade 0 with lesions)
    try
        quality.status = 'GOOD';
        scores = [0.8 0.1 0.05 0.03 0.02];
        evidence = struct('microaneurysms', struct('count', 15), ...
            'hemorrhages', struct('count', 5), ...
            'exudates', struct('count', 0), ...
            'neovascularization', struct('detected', false));

        result = applyClinicalLogic(0, scores, evidence, quality);
        assert(~strcmp(result.consistency, 'CONSISTENT'));
        assert(~isempty(result.consistencyWarning));
        results.consistencyInconsistency = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Lesion-classifier inconsistency detected... PASS\n'); end
    catch ME
        results.consistencyInconsistency = 'FAIL';
        if verbose; fprintf('TEST: Lesion-classifier inconsistency... FAIL (%s)\n', ME.message); end
    end

    % TEST 9: API works with clinical logic
    try
        T = readtable('data/splits/test.csv');
        % Find a good quality image
        imgPath = '';
        for i = 1:min(10, height(T))
            testPath = T.file_path_absolute{i};
            if exist(testPath, 'file')
                img = imread(testPath);
                gray = rgb2gray(img);
                brightness = mean(gray(:));
                contrast = std(double(gray(:)));
                if brightness >= 40 && brightness <= 220 && contrast >= 20
                    imgPath = testPath;
                    break;
                end
            end
        end

        if isempty(imgPath)
            % Skip test if no good quality image found
            results.apiIntegration = 'SKIP';
            if verbose; fprintf('TEST: API works with clinical logic... SKIP (no good quality image)\n'); end
        else
            result = runDRScreening(imgPath, 'Verbose', false);
            assert(result.success);
            assert(isfield(result, 'confidenceLevel'));
            assert(isfield(result.report, 'consistency') || strcmp(result.report.status, 'UNGRADABLE'));
            results.apiIntegration = 'PASS';
            passed = passed + 1;
            if verbose; fprintf('TEST: API works with clinical logic... PASS\n'); end
        end
    catch ME
        results.apiIntegration = 'FAIL';
        if verbose; fprintf('TEST: API works with clinical logic... FAIL (%s)\n', ME.message); end
    end

    % TEST 10: Recommendation generation
    try
        quality.status = 'GOOD';
        scores = [0.05 0.05 0.7 0.1 0.1];
        evidence = struct('microaneurysms', struct('count', 3), ...
            'hemorrhages', struct('count', 1), ...
            'exudates', struct('count', 1), ...
            'neovascularization', struct('detected', false));

        result = applyClinicalLogic(2, scores, evidence, quality);
        assert(~isempty(result.recommendation));
        assert(contains(result.recommendation, 'ophthalmologist'));
        results.recommendation = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Recommendation generation... PASS\n'); end
    catch ME
        results.recommendation = 'FAIL';
        if verbose; fprintf('TEST: Recommendation generation... FAIL (%s)\n', ME.message); end
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
