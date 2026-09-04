function [nPass, nFail, results] = testExplainabilityPipeline()
% testExplainabilityPipeline  15 synthetic tests for Phase 5.1 Explainability
%
%   [nPass, nFail, results] = testExplainabilityPipeline()
%
%   Tests:
%   1-4: Even/odd dimension handling
%   5-8: Real binary lesion mask loading and edge cases
%   9-12: Individual lesion type overlays (MA/HE/EX/NV)
%   13: No synthetic lesion placement
%   14: Independent artifact failure handling
%   15: Human-review provenance fields

    fprintf('=== Phase 5.1 Explainability: Synthetic Tests (15) ===\n\n');
    cfg = explainabilityConfig();
    results = struct('test', {}, 'status', {}, 'message', {});
    nPass = 0;
    nFail = 0;

    testDir = fullfile(cfg.paths.testDir);
    if ~exist(testDir, 'dir'), mkdir(testDir); end
    maskDir = fullfile(cfg.projectRoot, 'results', 'phase3', 'phase3_masks', 'test');
    if ~exist(maskDir, 'dir'), mkdir(maskDir); end

    % ---- Test 1: Even dimensions panel ----
    try
        testImg = uint8(randi([0 255], 100, 100, 3));
        testPath = fullfile(testDir, 't1.png');
        imwrite(testImg, testPath);
        imgHeight = 100; imgWidth = 100;
        maMask = false(100, 100); maMask(20:30, 20:30) = true;
        heMask = false(100, 100); heMask(60:80, 60:80) = true;
        exMask = false(100, 100); vesselMask = false(100, 100); fovMask = true(100, 100);
        save(fullfile(maskDir, 'test_t1.mat'), 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth');
        p3 = struct('dataset', 'test', 'ma_candidate_count', 5, 'he_candidate_count', 3, 'ex_candidate_count', 0);
        [status, ~] = generateLesionOverlay(testPath, p3, 't1', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 't1_overlay.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '1_even_dimensions', 'status', 'PASS', 'message', '');
        fprintf('Test 1 (even dims): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '1_even_dimensions', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 1: FAIL - %s\n', ME.message);
    end

    % ---- Test 2: Odd height panel ----
    try
        testImg = uint8(randi([0 255], 101, 100, 3));
        testPath = fullfile(testDir, 't2.png');
        imwrite(testImg, testPath);
        imgHeight = 101; imgWidth = 100;
        maMask = false(101, 100); heMask = false(101, 100); exMask = false(101, 100);
        vesselMask = false(101, 100); fovMask = true(101, 100);
        save(fullfile(maskDir, 'test_t2.mat'), 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth');
        p3 = struct('dataset', 'test', 'ma_candidate_count', 0, 'he_candidate_count', 0, 'ex_candidate_count', 0);
        [status, ~] = generateEvidenceOverlay(testPath, p3, struct('referable_pred', 0), struct('name', {}, 'contribution', []), 't2', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 't2_evidence.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '2_odd_height', 'status', 'PASS', 'message', '');
        fprintf('Test 2 (odd height): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '2_odd_height', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 2: FAIL - %s\n', ME.message);
    end

    % ---- Test 3: Odd width panel ----
    try
        testImg = uint8(randi([0 255], 100, 101, 3));
        testPath = fullfile(testDir, 't3.png');
        imwrite(testImg, testPath);
        imgHeight = 100; imgWidth = 101;
        maMask = false(100, 101); heMask = false(100, 101); exMask = false(100, 101);
        vesselMask = false(100, 101); fovMask = true(100, 101);
        save(fullfile(maskDir, 'test_t3.mat'), 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth');
        p3 = struct('dataset', 'test', 'ma_candidate_count', 0, 'he_candidate_count', 0, 'ex_candidate_count', 0);
        [status, ~] = generateEvidenceOverlay(testPath, p3, struct('referable_pred', 0), struct('name', {}, 'contribution', []), 't3', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 't3_evidence.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '3_odd_width', 'status', 'PASS', 'message', '');
        fprintf('Test 3 (odd width): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '3_odd_width', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 3: FAIL - %s\n', ME.message);
    end

    % ---- Test 4: Odd height + odd width panel ----
    try
        testImg = uint8(randi([0 255], 101, 101, 3));
        testPath = fullfile(testDir, 't4.png');
        imwrite(testImg, testPath);
        imgHeight = 101; imgWidth = 101;
        maMask = false(101, 101); heMask = false(101, 101); exMask = false(101, 101);
        vesselMask = false(101, 101); fovMask = true(101, 101);
        save(fullfile(maskDir, 'test_t4.mat'), 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth');
        p3 = struct('dataset', 'test', 'ma_candidate_count', 0, 'he_candidate_count', 0, 'ex_candidate_count', 0);
        [status, ~] = generateEvidenceOverlay(testPath, p3, struct('referable_pred', 0), struct('name', {}, 'contribution', []), 't4', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 't4_evidence.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '4_odd_both', 'status', 'PASS', 'message', '');
        fprintf('Test 4 (odd both): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '4_odd_both', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 4: FAIL - %s\n', ME.message);
    end

    % ---- Test 5: Real binary lesion mask ----
    try
        testImg = uint8(randi([0 255], 80, 80, 3));
        testPath = fullfile(testDir, 't5.png');
        imwrite(testImg, testPath);
        imgHeight = 80; imgWidth = 80;
        maMask = false(80, 80); maMask(10:20, 10:20) = true;
        heMask = false(80, 80); heMask(40:60, 40:60) = true;
        exMask = false(80, 80); exMask(30:40, 60:75) = true;
        vesselMask = false(80, 80); fovMask = true(80, 80);
        save(fullfile(maskDir, 'test_t5.mat'), 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth');
        p3 = struct('dataset', 'test', 'ma_candidate_count', 3, 'he_candidate_count', 2, 'ex_candidate_count', 1);
        [status, maskInfo] = generateLesionOverlay(testPath, p3, 't5', cfg);
        assert(strcmp(status, 'SUCCESS') || strcmp(status, 'SUCCESS_EMPTY'));
        assert(maskInfo.ma == true);
        assert(maskInfo.he == true);
        assert(maskInfo.ex == true);
        nPass = nPass + 1;
        results{end+1} = struct('test', '5_real_binary_mask', 'status', 'PASS', 'message', '');
        fprintf('Test 5 (real mask): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '5_real_binary_mask', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 5: FAIL - %s\n', ME.message);
    end

    % ---- Test 6: Empty lesion mask ----
    try
        testImg = uint8(randi([0 255], 80, 80, 3));
        testPath = fullfile(testDir, 't6.png');
        imwrite(testImg, testPath);
        imgHeight = 80; imgWidth = 80;
        maMask = false(80, 80); heMask = false(80, 80); exMask = false(80, 80);
        vesselMask = false(80, 80); fovMask = true(80, 80);
        save(fullfile(maskDir, 'test_t6.mat'), 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth');
        p3 = struct('dataset', 'test', 'ma_candidate_count', 0, 'he_candidate_count', 0, 'ex_candidate_count', 0);
        [status, maskInfo] = generateLesionOverlay(testPath, p3, 't6', cfg);
        assert(strcmp(status, 'SUCCESS') || strcmp(status, 'SUCCESS_EMPTY'));
        assert(maskInfo.ma == false);
        assert(maskInfo.he == false);
        assert(maskInfo.ex == false);
        nPass = nPass + 1;
        results{end+1} = struct('test', '6_empty_mask', 'status', 'PASS', 'message', '');
        fprintf('Test 6 (empty mask): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '6_empty_mask', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 6: FAIL - %s\n', ME.message);
    end

    % ---- Test 7: Mismatched mask dimensions ----
    try
        testImg = uint8(randi([0 255], 80, 80, 3));
        testPath = fullfile(testDir, 't7.png');
        imwrite(testImg, testPath);
        imgHeight = 120; imgWidth = 120;
        maMask = false(120, 120); maMask(10:20, 10:20) = true;
        heMask = false(120, 120); exMask = false(120, 120);
        vesselMask = false(120, 120); fovMask = true(120, 120);
        save(fullfile(maskDir, 'test_t7.mat'), 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth');
        p3 = struct('dataset', 'test', 'ma_candidate_count', 1, 'he_candidate_count', 0, 'ex_candidate_count', 0);
        [status, maskInfo] = generateLesionOverlay(testPath, p3, 't7', cfg);
        assert(strcmp(status, 'SUCCESS') || strcmp(status, 'SUCCESS_EMPTY'));
        nPass = nPass + 1;
        results{end+1} = struct('test', '7_mismatched_dims', 'status', 'PASS', 'message', '');
        fprintf('Test 7 (mismatched dims): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '7_mismatched_dims', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 7: FAIL - %s\n', ME.message);
    end

    % ---- Test 8: Missing mask file ----
    try
        testImg = uint8(randi([0 255], 80, 80, 3));
        testPath = fullfile(testDir, 't8.png');
        imwrite(testImg, testPath);
        p3 = struct('dataset', 'test', 'ma_candidate_count', 0, 'he_candidate_count', 0, 'ex_candidate_count', 0);
        [status, maskInfo] = generateLesionOverlay(testPath, p3, 'nonexistent_xyz', cfg);
        assert(strcmp(status, 'UNAVAILABLE'));
        assert(strcmp(maskInfo.source, 'NO_MASK_FILE'));
        nPass = nPass + 1;
        results{end+1} = struct('test', '8_missing_mask', 'status', 'PASS', 'message', '');
        fprintf('Test 8 (missing mask): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '8_missing_mask', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 8: FAIL - %s\n', ME.message);
    end

    % ---- Test 9: MA overlay only ----
    try
        testImg = uint8(randi([0 255], 80, 80, 3));
        testPath = fullfile(testDir, 't9.png');
        imwrite(testImg, testPath);
        imgHeight = 80; imgWidth = 80;
        maMask = false(80, 80); maMask(20:40, 20:40) = true;
        heMask = false(80, 80); exMask = false(80, 80);
        vesselMask = false(80, 80); fovMask = true(80, 80);
        save(fullfile(maskDir, 'test_t9.mat'), 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth');
        p3 = struct('dataset', 'test', 'ma_candidate_count', 2, 'he_candidate_count', 0, 'ex_candidate_count', 0);
        [status, maskInfo] = generateLesionOverlay(testPath, p3, 't9', cfg);
        assert(maskInfo.ma == true);
        assert(maskInfo.he == false);
        assert(maskInfo.ex == false);
        nPass = nPass + 1;
        results{end+1} = struct('test', '9_ma_overlay', 'status', 'PASS', 'message', '');
        fprintf('Test 9 (MA only): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '9_ma_overlay', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 9: FAIL - %s\n', ME.message);
    end

    % ---- Test 10: HE overlay only ----
    try
        testImg = uint8(randi([0 255], 80, 80, 3));
        testPath = fullfile(testDir, 't10.png');
        imwrite(testImg, testPath);
        imgHeight = 80; imgWidth = 80;
        maMask = false(80, 80); heMask = false(80, 80); heMask(30:50, 30:50) = true;
        exMask = false(80, 80); vesselMask = false(80, 80); fovMask = true(80, 80);
        save(fullfile(maskDir, 'test_t10.mat'), 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth');
        p3 = struct('dataset', 'test', 'ma_candidate_count', 0, 'he_candidate_count', 2, 'ex_candidate_count', 0);
        [status, maskInfo] = generateLesionOverlay(testPath, p3, 't10', cfg);
        assert(maskInfo.ma == false);
        assert(maskInfo.he == true);
        assert(maskInfo.ex == false);
        nPass = nPass + 1;
        results{end+1} = struct('test', '10_he_overlay', 'status', 'PASS', 'message', '');
        fprintf('Test 10 (HE only): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '10_he_overlay', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 10: FAIL - %s\n', ME.message);
    end

    % ---- Test 11: EX overlay only ----
    try
        testImg = uint8(randi([0 255], 80, 80, 3));
        testPath = fullfile(testDir, 't11.png');
        imwrite(testImg, testPath);
        imgHeight = 80; imgWidth = 80;
        maMask = false(80, 80); heMask = false(80, 80);
        exMask = false(80, 80); exMask(10:30, 50:70) = true;
        vesselMask = false(80, 80); fovMask = true(80, 80);
        save(fullfile(maskDir, 'test_t11.mat'), 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth');
        p3 = struct('dataset', 'test', 'ma_candidate_count', 0, 'he_candidate_count', 0, 'ex_candidate_count', 1);
        [status, maskInfo] = generateLesionOverlay(testPath, p3, 't11', cfg);
        assert(maskInfo.ma == false);
        assert(maskInfo.he == false);
        assert(maskInfo.ex == true);
        nPass = nPass + 1;
        results{end+1} = struct('test', '11_ex_overlay', 'status', 'PASS', 'message', '');
        fprintf('Test 11 (EX only): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '11_ex_overlay', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 11: FAIL - %s\n', ME.message);
    end

    % ---- Test 12: NV overlay (no mask, returns UNAVAILABLE) ----
    try
        testImg = uint8(randi([0 255], 80, 80, 3));
        testPath = fullfile(testDir, 't12.png');
        imwrite(testImg, testPath);
        p3 = struct('dataset', 'test', 'ma_candidate_count', 0, 'he_candidate_count', 0, 'ex_candidate_count', 0);
        [status, ~] = generateAttentionMap(testPath, p3, struct('name', {}, 'contribution', []), 'nonexistent_nv', cfg);
        assert(strcmp(status, 'UNAVAILABLE'));
        nPass = nPass + 1;
        results{end+1} = struct('test', '12_nv_unavailable', 'status', 'PASS', 'message', '');
        fprintf('Test 12 (NV unavailable): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '12_nv_unavailable', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 12: FAIL - %s\n', ME.message);
    end

    % ---- Test 13: No synthetic lesion placement ----
    try
        f1 = fileread(fullfile(fileparts(mfilename('fullpath')), 'generateLesionOverlay.m'));
        f2 = fileread(fullfile(fileparts(mfilename('fullpath')), 'generateAttentionMap.m'));
        f3 = fileread(fullfile(fileparts(mfilename('fullpath')), 'generateEvidenceOverlay.m'));
        hasRng1 = ~isempty(regexp(f1, 'rng\(', 'once'));
        hasRng2 = ~isempty(regexp(f2, 'genMask', 'once'));
        hasRand1 = ~isempty(regexp(f1, '2\*pi\*rand\(\)', 'once'));
        hasRand2 = ~isempty(regexp(f2, '2\*pi\*rand\(\)', 'once'));
        assert(~hasRng1 && ~hasRng2 && ~hasRand1 && ~hasRand2, 'Synthetic lesion placement still present');
        nPass = nPass + 1;
        results{end+1} = struct('test', '13_no_synthetic_placement', 'status', 'PASS', 'message', '');
        fprintf('Test 13 (no synthetic): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '13_no_synthetic_placement', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 13: FAIL - %s\n', ME.message);
    end

    % ---- Test 14: Independent artifact failure handling ----
    try
        f = fileread(fullfile(fileparts(mfilename('fullpath')), 'generateEvidenceOverlay.m'));
        hasStatus = ~isempty(regexp(f, '\[status', 'once'));
        assert(hasStatus, 'generateEvidenceOverlay does not return status');
        f2 = fileread(fullfile(fileparts(mfilename('fullpath')), 'generateAttentionMap.m'));
        hasStatus2 = ~isempty(regexp(f2, '\[status', 'once'));
        assert(hasStatus2, 'generateAttentionMap does not return status');
        nPass = nPass + 1;
        results{end+1} = struct('test', '14_independent_failure', 'status', 'PASS', 'message', '');
        fprintf('Test 14 (independent failure): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '14_independent_failure', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 14: FAIL - %s\n', ME.message);
    end

    % ---- Test 15: Human-review provenance fields ----
    try
        f = fileread(fullfile(fileparts(mfilename('fullpath')), 'generateHumanReviewReport.m'));
        hasProvenance = ~isempty(regexp(f, 'evidence_provenance', 'once'));
        hasLesionSource = ~isempty(regexp(f, 'lesion_mask_source', 'once'));
        hasRealMask = ~isempty(regexp(f, 'REAL_PHASE3_MASK', 'once'));
        assert(hasProvenance && hasLesionSource && hasRealMask, 'Missing provenance fields');
        nPass = nPass + 1;
        results{end+1} = struct('test', '15_provenance_fields', 'status', 'PASS', 'message', '');
        fprintf('Test 15 (provenance): PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '15_provenance_fields', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 15: FAIL - %s\n', ME.message);
    end

    fprintf('\n=== RESULTS: %d/%d PASS, %d FAIL ===\n', nPass, nPass+nFail, nFail);
end
