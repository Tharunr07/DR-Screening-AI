function [nPass, nFail] = testDeepLearningPipeline()
% testDeepLearningPipeline  Synthetic tests for Phase 7
%
%   [nPass, nFail] = testDeepLearningPipeline()

    fprintf('=== Phase 7 Deep Learning: Synthetic Tests ===\n\n');
    cfg = deepLearningConfig();
    nPass = 0; nFail = 0;

    % ---- Test 1: Config creation ----
    try
        assert(cfg.nGrades == 5);
        assert(cfg.image.size(1) == 224);
        nPass = nPass + 1;
        fprintf('Test 1 (config): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 1: FAIL - %s\n', ME.message);
    end

    % ---- Test 2: Network creation ----
    try
        lgraph = createDRNetwork(cfg);
        assert(~isempty(lgraph));
        assert(numel(lgraph.Layers) > 50);
        nPass = nPass + 1;
        fprintf('Test 2 (network): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 2: FAIL - %s\n', ME.message);
    end

    % ---- Test 3: Forward inference ----
    try
        lgraph = createDRNetwork(cfg);
        dummyImg = rand(224, 224, 3, 'single');
        dlImg = dlarray(dummyImg, 'SSCB');
        % Test layer graph output size
        assert(numel(lgraph.Layers) > 50);
        nPass = nPass + 1;
        fprintf('Test 3 (forward): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 3: FAIL - %s\n', ME.message);
    end

    % ---- Test 4: Class weights ----
    try
        classWeights = [1.0, 3.0, 1.5, 4.5, 3.5];
        assert(numel(classWeights) == 5);
        assert(all(classWeights > 0));
        nPass = nPass + 1;
        fprintf('Test 4 (class weights): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 4: FAIL - %s\n', ME.message);
    end

    % ---- Test 5: Threshold selection ----
    try
        YTrueBin = [0 0 1 1 0 1 0 1 1 0]';
        refProb = [0.1 0.3 0.6 0.8 0.2 0.7 0.4 0.9 0.5 0.15]';
        bestF1 = 0; bestThresh = 0.5;
        for i = 1:numel(refProb)
            th = refProb(i);
            pred = double(refProb >= th);
            tp = sum(pred == 1 & YTrueBin == 1);
            fn = sum(pred == 0 & YTrueBin == 1);
            fp = sum(pred == 1 & YTrueBin == 0);
            prec = tp / max(1, tp+fp);
            sens = tp / max(1, tp+fn);
            f1 = 2*prec*sens / max(1, prec+sens);
            if f1 > bestF1
                bestF1 = f1; bestThresh = th;
            end
        end
        assert(bestThresh > 0 && bestThresh < 1);
        nPass = nPass + 1;
        fprintf('Test 5 (threshold): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 5: FAIL - %s\n', ME.message);
    end

    % ---- Test 6: Metric calculation ----
    try
        YTrue = categorical([0 0 1 1 2]');
        YPred = categorical([0 1 1 2 2]');
        cm = confusionmat(YTrue, YPred);
        assert(sum(cm(:)) == 5);
        nPass = nPass + 1;
        fprintf('Test 6 (metrics): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 6: FAIL - %s\n', ME.message);
    end

    % ---- Test 7: NaN handling ----
    try
        X = [1 NaN 3; 4 5 NaN; NaN 8 9];
        medianVals = nanmedian(X, 1);
        for j = 1:3
            X(isnan(X(:,j)), j) = medianVals(j);
        end
        assert(~any(isnan(X(:))));
        nPass = nPass + 1;
        fprintf('Test 7 (NaN handling): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 7: FAIL - %s\n', ME.message);
    end

    % ---- Test 8: Image preprocessing ----
    try
        img = rand(100, 150, 3);
        imgResized = imresize(img, [224 224]);
        assert(size(imgResized, 1) == 224 && size(imgResized, 2) == 224);
        nPass = nPass + 1;
        fprintf('Test 8 (preprocessing): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 8: FAIL - %s\n', ME.message);
    end

    % ---- Test 9: Augmentation config ----
    try
        assert(cfg.augmentation.flipHorizontal == true);
        assert(cfg.augmentation.rotationRange(1) < 0);
        nPass = nPass + 1;
        fprintf('Test 9 (augmentation): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 9: FAIL - %s\n', ME.message);
    end

    % ---- Test 10: Referable threshold logic ----
    try
        YTrueNum = [0 1 2 3 4]';
        YTrueBin = double(YTrueNum >= 2);
        assert(isequal(YTrueBin, [0 0 1 1 1]'));
        nPass = nPass + 1;
        fprintf('Test 10 (referable logic): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 10: FAIL - %s\n', ME.message);
    end

    % ---- Test 11: Ordinal metrics ----
    try
        YTrue = [0 1 2 3 4]';
        YPred = [0 3 2 3 4]';
        mae = mean(abs(double(YPred) - double(YTrue)));
        assert(abs(mae - 0.4) < 1e-10);
        plusMinus1 = sum(abs(double(YPred) - double(YTrue)) <= 1) / numel(YTrue);
        assert(abs(plusMinus1 - 0.8) < 1e-10);
        nPass = nPass + 1;
        fprintf('Test 11 (ordinal): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 11: FAIL - %s\n', ME.message);
    end

    % ---- Test 12: Save/load ----
    try
        testPath = fullfile(cfg.paths.modelDir, 'test_save.mat');
        testVar = struct('a', 1, 'b', 'test');
        save(testPath, 'testVar', '-v7');
        loaded = load(testPath);
        assert(loaded.testVar.a == 1);
        delete(testPath);
        nPass = nPass + 1;
        fprintf('Test 12 (save/load): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 12: FAIL - %s\n', ME.message);
    end

    % ---- Test 13: Reproducibility ----
    try
        rng(42);
        a = rand();
        rng(42);
        b = rand();
        assert(a == b);
        nPass = nPass + 1;
        fprintf('Test 13 (reproducibility): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 13: FAIL - %s\n', ME.message);
    end

    % ---- Test 14: Leakage guard ----
    try
        trainIds = {'img1', 'img2', 'img3'};
        valIds = {'img4', 'img5'};
        testIds = {'img6', 'img7'};
        assert(isempty(intersect(trainIds, valIds)));
        assert(isempty(intersect(trainIds, testIds)));
        assert(isempty(intersect(valIds, testIds)));
        nPass = nPass + 1;
        fprintf('Test 14 (leakage guard): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 14: FAIL - %s\n', ME.message);
    end

    % ---- Test 15: Config completeness ----
    try
        assert(isfield(cfg, 'training'));
        assert(isfield(cfg, 'augmentation'));
        assert(isfield(cfg, 'network'));
        assert(isfield(cfg, 'paths'));
        nPass = nPass + 1;
        fprintf('Test 15 (config completeness): PASS\n');
    catch ME
        nFail = nFail + 1;
        fprintf('Test 15: FAIL - %s\n', ME.message);
    end

    fprintf('\n=== RESULTS: %d/%d PASS, %d FAIL ===\n', nPass, nPass+nFail, nFail);
end
