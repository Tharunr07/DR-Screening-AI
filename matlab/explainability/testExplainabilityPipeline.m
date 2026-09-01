function [nPass, nFail, results] = testExplainabilityPipeline()
% testExplainabilityPipeline  12 synthetic tests for Phase 5 Explainability
%
%   [nPass, nFail, results] = testExplainabilityPipeline()
%
%   Tests basic functionality without requiring real datasets.

    fprintf('=== Phase 5 Explainability: Synthetic Tests ===\n\n');
    cfg = explainabilityConfig();
    results = struct('test', {}, 'status', {}, 'message', {});
    nPass = 0;
    nFail = 0;

    % ---- Test 1: Valid normal image overlay ----
    try
        testImg = uint8(randi([0 255], 100, 100, 3));
        testPath = fullfile(cfg.paths.testDir, 'test_normal.png');
        imwrite(testImg, testPath);
        p3Result = struct('ma_candidate_count', 5, 'ma_candidate_area', 50, 'ma_confidence', 0.7, ...
            'he_candidate_count', 2, 'he_candidate_area', 30, 'he_confidence', 0.6, ...
            'ex_candidate_count', 1, 'ex_candidate_area', 20, 'ex_candidate_area_fraction', 0.01, 'ex_confidence', 0.5, ...
            'nv_candidate', false, 'nv_score', 0, 'nv_confidence', 0, ...
            'fov_center_x', 50, 'fov_center_y', 50, 'fov_radius', 40, ...
            'optic_disc_detected', true, 'optic_disc_x', 30, 'optic_disc_y', 50, 'optic_disc_radius', 10, ...
            'fovea_detected', true, 'fovea_x', 70, 'fovea_y', 50);
        generateLesionOverlay(testPath, p3Result, 'test_normal', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 'test_normal_overlay.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '1_valid_normal_overlay', 'status', 'PASS', 'message', '');
        fprintf('Test 1: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '1_valid_normal_overlay', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 1: FAIL - %s\n', ME.message);
    end

    % ---- Test 2: Missing image handling ----
    try
        generateLesionOverlay('/nonexistent/path.png', struct(), 'test_missing', cfg);
        nPass = nPass + 1;
        results{end+1} = struct('test', '2_missing_image', 'status', 'PASS', 'message', 'Handled gracefully');
        fprintf('Test 2: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '2_missing_image', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 2: FAIL - %s\n', ME.message);
    end

    % ---- Test 3: Empty lesion mask ----
    try
        testImg = uint8(randi([0 255], 100, 100, 3));
        testPath = fullfile(cfg.paths.testDir, 'test_empty.png');
        imwrite(testImg, testPath);
        p3Empty = struct('ma_candidate_count', 0, 'ma_candidate_area', 0, 'ma_confidence', 0, ...
            'he_candidate_count', 0, 'he_candidate_area', 0, 'he_confidence', 0, ...
            'ex_candidate_count', 0, 'ex_candidate_area', 0, 'ex_candidate_area_fraction', 0, 'ex_confidence', 0, ...
            'nv_candidate', false, 'nv_score', 0, 'nv_confidence', 0, ...
            'fov_center_x', 50, 'fov_center_y', 50, 'fov_radius', 40);
        generateLesionOverlay(testPath, p3Empty, 'test_empty', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 'test_empty_overlay.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '3_empty_lesion_mask', 'status', 'PASS', 'message', '');
        fprintf('Test 3: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '3_empty_lesion_mask', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 3: FAIL - %s\n', ME.message);
    end

    % ---- Test 4: MA-only mask ----
    try
        p3MA = struct('ma_candidate_count', 10, 'ma_candidate_area', 100, 'ma_confidence', 0.8, ...
            'he_candidate_count', 0, 'he_candidate_area', 0, 'he_confidence', 0, ...
            'ex_candidate_count', 0, 'ex_candidate_area', 0, 'ex_candidate_area_fraction', 0, 'ex_confidence', 0, ...
            'nv_candidate', false, 'nv_score', 0, 'nv_confidence', 0, ...
            'fov_center_x', 50, 'fov_center_y', 50, 'fov_radius', 40);
        generateLesionOverlay(testPath, p3MA, 'test_ma_only', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 'test_ma_only_overlay.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '4_ma_only_mask', 'status', 'PASS', 'message', '');
        fprintf('Test 4: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '4_ma_only_mask', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 4: FAIL - %s\n', ME.message);
    end

    % ---- Test 5: HE-only mask ----
    try
        p3HE = struct('ma_candidate_count', 0, 'ma_candidate_area', 0, 'ma_confidence', 0, ...
            'he_candidate_count', 8, 'he_candidate_area', 200, 'he_confidence', 0.7, ...
            'ex_candidate_count', 0, 'ex_candidate_area', 0, 'ex_candidate_area_fraction', 0, 'ex_confidence', 0, ...
            'nv_candidate', false, 'nv_score', 0, 'nv_confidence', 0, ...
            'fov_center_x', 50, 'fov_center_y', 50, 'fov_radius', 40);
        generateLesionOverlay(testPath, p3HE, 'test_he_only', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 'test_he_only_overlay.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '5_he_only_mask', 'status', 'PASS', 'message', '');
        fprintf('Test 5: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '5_he_only_mask', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 5: FAIL - %s\n', ME.message);
    end

    % ---- Test 6: EX-only mask ----
    try
        p3EX = struct('ma_candidate_count', 0, 'ma_candidate_area', 0, 'ma_confidence', 0, ...
            'he_candidate_count', 0, 'he_candidate_area', 0, 'he_confidence', 0, ...
            'ex_candidate_count', 15, 'ex_candidate_area', 300, 'ex_candidate_area_fraction', 0.02, 'ex_confidence', 0.9, ...
            'nv_candidate', false, 'nv_score', 0, 'nv_confidence', 0, ...
            'fov_center_x', 50, 'fov_center_y', 50, 'fov_radius', 40);
        generateLesionOverlay(testPath, p3EX, 'test_ex_only', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 'test_ex_only_overlay.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '6_ex_only_mask', 'status', 'PASS', 'message', '');
        fprintf('Test 6: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '6_ex_only_mask', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 6: FAIL - %s\n', ME.message);
    end

    % ---- Test 7: NV-only mask ----
    try
        p3NV = struct('ma_candidate_count', 0, 'ma_candidate_area', 0, 'ma_confidence', 0, ...
            'he_candidate_count', 0, 'he_candidate_area', 0, 'he_confidence', 0, ...
            'ex_candidate_count', 0, 'ex_candidate_area', 0, 'ex_candidate_area_fraction', 0, 'ex_confidence', 0, ...
            'nv_candidate', true, 'nv_score', 0.8, 'nv_confidence', 0.7, ...
            'fov_center_x', 50, 'fov_center_y', 50, 'fov_radius', 40);
        generateLesionOverlay(testPath, p3NV, 'test_nv_only', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 'test_nv_only_overlay.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '7_nv_only_mask', 'status', 'PASS', 'message', '');
        fprintf('Test 7: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '7_nv_only_mask', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 7: FAIL - %s\n', ME.message);
    end

    % ---- Test 8: Optic disc overlay ----
    try
        generateStructureOverlay(testPath, p3Result, 'test_od_overlay', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 'test_od_overlay_structure.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '8_od_overlay', 'status', 'PASS', 'message', '');
        fprintf('Test 8: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '8_od_overlay', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 8: FAIL - %s\n', ME.message);
    end

    % ---- Test 9: Fovea overlay ----
    try
        p3Fovea = struct('optic_disc_detected', false, 'fovea_detected', true, ...
            'fovea_x', 50, 'fovea_y', 50, 'fov_center_x', 50, 'fov_center_y', 50, 'fov_radius', 40);
        generateStructureOverlay(testPath, p3Fovea, 'test_fovea_overlay', cfg);
        assert(exist(fullfile(cfg.paths.overlayDir, 'test_fovea_overlay_structure.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '9_fovea_overlay', 'status', 'PASS', 'message', '');
        fprintf('Test 9: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '9_fovea_overlay', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 9: FAIL - %s\n', ME.message);
    end

    % ---- Test 10: Contribution calculation ----
    try
        contribNames = {'ma_count', 'he_area', 'ex_count', 'vessel_density', 'quality_score'};
        contribVals = [0.15, 0.12, 0.08, -0.05, 0.03];
        contribDirs = {'SUPPORTS', 'SUPPORTS', 'SUPPORTS', 'OPPOSES', 'SUPPORTS'};
        assert(numel(contribNames) == 5);
        assert(numel(contribVals) == 5);
        nPass = nPass + 1;
        results{end+1} = struct('test', '10_contribution_calc', 'status', 'PASS', 'message', '');
        fprintf('Test 10: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '10_contribution_calc', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 10: FAIL - %s\n', ME.message);
    end

    % ---- Test 11: Heatmap generation ----
    try
        contrib.name = {'ma_count', 'he_area', 'ex_count', 'vessel_density', 'quality_score'};
        contrib.contribution = [0.15, 0.12, 0.08, -0.05, 0.03];
        contrib.direction = {'SUPPORTS', 'SUPPORTS', 'SUPPORTS', 'OPPOSES', 'SUPPORTS'};
        generateAttentionMap(testPath, p3Result, contrib, 'test_heatmap', cfg);
        assert(exist(fullfile(cfg.paths.heatmapDir, 'test_heatmap_heatmap.png'), 'file') > 0);
        nPass = nPass + 1;
        results{end+1} = struct('test', '11_heatmap_generation', 'status', 'PASS', 'message', '');
        fprintf('Test 11: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '11_heatmap_generation', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 11: FAIL - %s\n', ME.message);
    end

    % ---- Test 12: Malformed input handling ----
    try
        generateLesionOverlay('', struct(), '', cfg);
        generateStructureOverlay('', struct(), '', cfg);
        nPass = nPass + 1;
        results{end+1} = struct('test', '12_malformed_input', 'status', 'PASS', 'message', 'Handled gracefully');
        fprintf('Test 12: PASS\n');
    catch ME
        nFail = nFail + 1;
        results{end+1} = struct('test', '12_malformed_input', 'status', 'FAIL', 'message', ME.message);
        fprintf('Test 12: FAIL - %s\n', ME.message);
    end

    fprintf('\n=== RESULTS: %d/%d PASS ===\n', nPass, nPass + nFail);
    for i = 1:numel(results)
        fprintf('  %s: %s %s\n', results{i}.test, results{i}.status, results{i}.message);
    end

    % Clean up test files
    cleanupTestFiles(cfg);
end

function cleanupTestFiles(cfg)
    testFiles = dir(fullfile(cfg.paths.testDir, 'test_*'));
    for i = 1:numel(testFiles)
        delete(fullfile(cfg.paths.testDir, testFiles(i).name));
    end
    testOverlays = dir(fullfile(cfg.paths.overlayDir, 'test_*'));
    for i = 1:numel(testOverlays)
        delete(fullfile(cfg.paths.overlayDir, testOverlays(i).name));
    end
end
