function result = validatePhase20B2(varargin)
% validatePhase20B2  Validation test suite for Phase 20B.2 NV detector fix
%
%   result = validatePhase20B2()
%   result = validatePhase20B2('Verbose', true)
%
%   Tests verify:
%     - Function existence and output structure
%     - Valid RGB image handling (uint8, double)
%     - Grayscale input (graceful handling)
%     - Binary mask properties
%     - Mask dimensions match image
%     - Deterministic output
%     - Finite coordinates/features
%     - FOV constraint (no detections outside retina)
%     - Optic-disc exclusion
%     - No giant rectangular detections
%     - Blank/uniform images produce no detections
%     - Normal vessel-only synthetic image should NOT be NV
%     - Dark-cluster synthetic image should be detected as NV
%     - Diagnostic mode outputs
%
%   IMPORTANT: This does NOT modify the frozen classifier or test set.

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'OutputDir', fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20b2_validation'), @ischar);
    parse(p, varargin{:});

    verbose = p.Results.Verbose;
    outputDir = p.Results.OutputDir;

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    result = struct();
    result.tests = {};
    result.passed = 0;
    result.failed = 0;
    result.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    if verbose
        fprintf('=== PHASE 20B.2 VALIDATION ===\n');
        fprintf('Date: %s\n\n', result.timestamp);
    end

    % --- Structural tests ---
    result.tests{end+1} = runTest('T01: Function exists', @testFunctionExists, verbose);
    result.tests{end+1} = runTest('T02: Output structure fields', @testOutputStructure, verbose);
    result.tests{end+1} = runTest('T03: Binary mask type', @testBinaryMask, verbose);
    result.tests{end+1} = runTest('T04: Mask dimensions match image', @testMaskDimensions, verbose);
    result.tests{end+1} = runTest('T05: Confidence in [0,1]', @testConfidenceRange, verbose);
    result.tests{end+1} = runTest('T06: Finite features', @testFiniteFeatures, verbose);

    % --- Input handling ---
    result.tests{end+1} = runTest('T07: RGB uint8 input', @testRGBUint8, verbose);
    result.tests{end+1} = runTest('T08: RGB double input', @testRGBDouble, verbose);
    result.tests{end+1} = runTest('T09: Grayscale input', @testGrayscale, verbose);
    result.tests{end+1} = runTest('T10: Small image', @testSmallImage, verbose);

    % --- Anatomical constraints ---
    result.tests{end+1} = runTest('T11: No detections outside FOV', @testFOVConstraint, verbose);
    result.tests{end+1} = runTest('T12: Optic-disc exclusion', @testDiscExclusion, verbose);

    % --- False positive prevention ---
    result.tests{end+1} = runTest('T13: Black image (no NV)', @testBlackImage, verbose);
    result.tests{end+1} = runTest('T14: White image (no NV)', @testWhiteImage, verbose);
    result.tests{end+1} = runTest('T15: Uniform gray (no NV)', @testUniformGray, verbose);
    result.tests{end+1} = runTest('T16: Random noise (no NV)', @testRandomNoise, verbose);
    result.tests{end+1} = runTest('T17: Normal vessels only (no NV)', @testNormalVesselsOnly, verbose);
    result.tests{end+1} = runTest('T18: No giant rectangles', @testNoGiantRectangles, verbose);

    % --- True positive detection ---
    result.tests{end+1} = runTest('T19: NV-like cluster detected', @testNVClusterDetected, verbose);

    % --- Determinism ---
    result.tests{end+1} = runTest('T20: Deterministic output', @testDeterministic, verbose);

    % --- Diagnostic outputs ---
    result.tests{end+1} = runTest('T21: Diagnostic mode outputs', @testDiagnosticOutputs, verbose);
    result.tests{end+1} = runTest('T22: Diagnostic visualization', @testDiagnosticVisualization, verbose);

    % --- Summary ---
    result.passed = sum(cellfun(@(t) t.passed, result.tests));
    result.failed = sum(cellfun(@(t) ~t.passed, result.tests));
    result.total = numel(result.tests);

    if verbose
        fprintf('\n=== VALIDATION SUMMARY ===\n');
        fprintf('Passed: %d/%d\n', result.passed, result.total);
        fprintf('Failed: %d/%d\n', result.failed, result.total);

        if result.failed == 0
            fprintf('ALL TESTS PASSED\n');
        else
            fprintf('FAILED TESTS:\n');
            for i = 1:numel(result.tests)
                if ~result.tests{i}.passed
                    fprintf('  %s: %s\n', result.tests{i}.name, result.tests{i}.error);
                end
            end
        end
    end

    % Save results
    save(fullfile(outputDir, 'validation_result.mat'), 'result');
    names = cellfun(@(t) t.name, result.tests, 'UniformOutput', false)';
    statuses = cellfun(@(t) iff(t.passed, 'PASS', 'FAIL'), result.tests, 'UniformOutput', false)';
    errors = cellfun(@(t) t.error, result.tests, 'UniformOutput', false)';
    T = table(names, statuses, errors, 'VariableNames', {'Test', 'Status', 'Error'});
    writetable(T, fullfile(outputDir, 'validation_tests.csv'));

    if verbose
        fprintf('\nResults saved to: %s\n', outputDir);
    end
end

function s = iff(condition, trueVal, falseVal)
    if condition; s = trueVal; else; s = falseVal; end
end

function result = runTest(name, testFunc, verbose)
    result = struct();
    result.name = name;
    result.passed = false;
    result.error = '';
    if verbose; fprintf('  %-45s ', name); end
    try
        testFunc();
        result.passed = true;
        if verbose; fprintf('PASS\n'); end
    catch ME
        result.error = ME.message;
        if verbose; fprintf('FAIL: %s\n', ME.message); end
    end
end

function testFunctionExists()
    assert(exist('detectNeovascularization', 'file') > 0, ...
        'detectNeovascularization.m not found on path');
end

function testOutputStructure()
    img = createFundusLikeImage();
    e = detectNeovascularization(img);
    assert(isfield(e, 'detected'), 'Missing detected field');
    assert(isfield(e, 'mask'), 'Missing mask field');
    assert(isfield(e, 'density'), 'Missing density field');
    assert(isfield(e, 'irregularity'), 'Missing irregularity field');
    assert(isfield(e, 'confidence'), 'Missing confidence field');
end

function testBinaryMask()
    img = createFundusLikeImage();
    e = detectNeovascularization(img);
    assert(islogical(e.mask), 'Mask must be logical');
end

function testMaskDimensions()
    img = createFundusLikeImage();
    e = detectNeovascularization(img);
    [rows, cols, ~] = size(img);
    assert(size(e.mask, 1) == rows, 'Mask height mismatch');
    assert(size(e.mask, 2) == cols, 'Mask width mismatch');
end

function testConfidenceRange()
    img = createFundusLikeImage();
    e = detectNeovascularization(img);
    assert(e.confidence >= 0 && e.confidence <= 1, ...
        sprintf('Confidence %f out of range [0,1]', e.confidence));
end

function testFiniteFeatures()
    img = createFundusLikeImage();
    e = detectNeovascularization(img);
    assert(isfinite(e.density), 'Density must be finite');
    assert(isfinite(e.irregularity), 'Irregularity must be finite');
    assert(isfinite(e.confidence), 'Confidence must be finite');
end

function testRGBUint8()
    img = uint8(createFundusLikeImage() * 255);
    e = detectNeovascularization(img);
    assert(isstruct(e), 'Should handle uint8 input');
end

function testRGBDouble()
    img = createFundusLikeImage();
    e = detectNeovascularization(img);
    assert(isstruct(e), 'Should handle double input');
end

function testGrayscale()
    grayImg = uint8(rand(224, 224) * 200);
    try
        e = detectNeovascularization(grayImg);
        assert(isstruct(e), 'Should return struct for grayscale');
    catch ME
        if ~contains(ME.message, 'size')
            rethrow(ME);
        end
    end
end

function testSmallImage()
    img = uint8(rand(32, 32, 3) * 200);
    e = detectNeovascularization(img);
    assert(isstruct(e), 'Should handle small image');
end

function testFOVConstraint()
    img = createFundusLikeImage();
    e = detectNeovascularization(img, 'Diagnostic', true);
    if e.detected && isfield(e, 'retinalMask') && any(e.mask(:))
        [rows, cols] = size(e.mask);
        [rr, cc] = find(e.mask);
        for i = 1:numel(rr)
            assert(e.retinalMask(rr(i), cc(i)), ...
                sprintf('NV at (%d,%d) outside retinal FOV', rr(i), cc(i)));
        end
    end
end

function testDiscExclusion()
    img = createFundusWithDisc();
    e = detectNeovascularization(img, 'Diagnostic', true);
    if e.detected && isfield(e, 'discMask') && any(e.mask(:))
        overlap = sum(e.mask(:) & e.discMask(:));
        totalNV = sum(e.mask(:));
        assert(overlap / totalNV < 0.1, ...
            sprintf('NV mask overlaps disc by %.1f%%', 100*overlap/totalNV));
    end
end

function testBlackImage()
    img = zeros(224, 224, 3, 'uint8');
    e = detectNeovascularization(img);
    assert(~e.detected, 'Black image should not detect NV');
end

function testWhiteImage()
    img = 255 * ones(224, 224, 3, 'uint8');
    e = detectNeovascularization(img);
    assert(~e.detected, 'White image should not detect NV');
end

function testUniformGray()
    img = 128 * ones(224, 224, 3, 'uint8');
    e = detectNeovascularization(img);
    assert(~e.detected, 'Uniform gray image should not detect NV');
end

function testRandomNoise()
    img = uint8(rand(224, 224, 3) * 255);
    e = detectNeovascularization(img);
    assert(~e.detected, 'Random noise should not detect NV');
end

function testNormalVesselsOnly()
    % Create fundus with only normal (smooth, parallel) vessels
    img = createFundusWithNormalVessels();
    e = detectNeovascularization(img);
    assert(~e.detected, ...
        'Normal vessels only should NOT be detected as NV');
end

function testNoGiantRectangles()
    img = createFundusLikeImage();
    e = detectNeovascularization(img);
    if e.detected && any(e.mask(:))
        cc = bwconncomp(e.mask);
        stats = regionprops(cc, 'Area', 'BoundingBox');
        [rows, cols] = size(e.mask);
        maxAllowedArea = round(rows * cols * 0.15);
        for i = 1:numel(stats)
            assert(stats(i).Area < maxAllowedArea, ...
                sprintf('NV region %d has area %d (>15%% of image)', i, stats(i).Area));
            bbox = stats(i).BoundingBox;
            aspectRatio = max(bbox(3), bbox(4)) / max(1, min(bbox(3), bbox(4)));
            assert(aspectRatio < 5, ...
                sprintf('NV region %d has aspect ratio %.1f (>5)', i, aspectRatio));
        end
    end
end

function testNVClusterDetected()
    % Frond phantom must trigger detection DRIVEN BY THE FROND (not by
    % border junk or background): require mask pixels inside the frond
    % patch (rows 40-80, cols 150-190).
    img = createFundusWithNVCluster();
    e = detectNeovascularization(img);
    assert(e.detected, ...
        'NV-like cluster on fundus-like background should be detected');
    [X, Y] = meshgrid(1:224, 1:224);
    frondZone = X >= 125 & X <= 165 & Y >= 55 & Y <= 90;
    assert(sum(e.mask(frondZone)) > 0, ...
        'Detection must localize to the frond patch');
end

function testDeterministic()
    img = createFundusLikeImage();
    e1 = detectNeovascularization(img);
    e2 = detectNeovascularization(img);
    assert(e1.detected == e2.detected, 'Detection should be deterministic');
    assert(isequal(e1.mask, e2.mask), 'Mask should be deterministic');
end

function testDiagnosticOutputs()
    img = createFundusLikeImage();
    e = detectNeovascularization(img, 'Diagnostic', true);
    assert(isfield(e, 'retinalMask'), 'Missing retinalMask');
    assert(isfield(e, 'discMask'), 'Missing discMask');
    assert(isfield(e, 'vesselMask'), 'Missing vesselMask');
    assert(isfield(e, 'majorMask'), 'Missing majorMask');
    assert(isfield(e, 'fineMask'), 'Missing fineMask');
    assert(isfield(e, 'densityMap'), 'Missing densityMap');
    assert(isfield(e, 'rawNV'), 'Missing rawNV');
    assert(isfield(e, 'labels'), 'Missing labels');
    assert(islogical(e.retinalMask), 'retinalMask must be logical');
    assert(islogical(e.vesselMask), 'vesselMask must be logical');
    assert(islogical(e.fineMask), 'fineMask must be logical');
end

function testDiagnosticVisualization()
    img = createFundusWithNVCluster();
    outputDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20b2_validation');

    e = detectNeovascularization(img, 'Diagnostic', true);

    fig = figure('Visible', 'off', 'Position', [100 50 1400 700]);

    subplot(2, 5, 1); imshow(img); title('Original');
    subplot(2, 5, 2); imshow(e.retinalMask); title('Retinal FOV');
    subplot(2, 5, 3); imshow(e.discMask); title('Optic Disc');
    subplot(2, 5, 4); imshow(e.vesselMask); title('All Vessels');
    subplot(2, 5, 5); imshow(e.majorMask); title('Major Vessels');
    subplot(2, 5, 6); imshow(e.fineMask); title('Fine Vessels');
    subplot(2, 5, 7); imshow(img); hold on;
    if any(e.densityMap(:))
        resizedDM = imresize(e.densityMap, [size(img,1) size(img,2)]);
        imagesc(resizedDM, 'AlphaData', 0.4);
        colormap(gca, hot);
    end
    title('Density Map');

    subplot(2, 5, 8); imshow(img); hold on;
    if any(e.rawNV(:))
        imshowpair(img, e.rawNV, 'blend');
    end
    title('Raw NV Candidates');

    subplot(2, 5, 9); imshow(img); hold on;
    if e.detected && any(e.mask(:))
        imshowpair(img, e.mask, 'blend');
    end
    nvStr = 'NONE';
    if e.detected; nvStr = 'DETECTED'; end
    title(sprintf('Final NV: %s', nvStr));

    subplot(2, 5, 10); axis off;
    text(0.1, 0.9, sprintf('Detected: %d', e.detected), 'FontSize', 11);
    text(0.1, 0.75, sprintf('Density: %.4f', e.density), 'FontSize', 11);
    text(0.1, 0.6, sprintf('Irregularity: %.4f', e.irregularity), 'FontSize', 11);
    text(0.1, 0.45, sprintf('Confidence: %.4f', e.confidence), 'FontSize', 11);
    title('Summary');

    saveas(fig, fullfile(outputDir, 'diagnostic_visualization.png'));
    close(fig);

    assert(exist(fullfile(outputDir, 'diagnostic_visualization.png'), 'file') > 0, ...
        'Visualization file not created');
end

% --- Test image generators ---

function img = createFundusLikeImage()
    img = zeros(224, 224, 3, 'uint8');
    [X, Y] = meshgrid(1:224, 1:224);
    centerDist = sqrt((X-112).^2 + (Y-112).^2) / 112;
    brightness = max(0, 1 - centerDist * 0.8);
    img(:,:,1) = uint8(brightness * 180 + rand(224, 224) * 10);
    img(:,:,2) = uint8(brightness * 100 + rand(224, 224) * 8);
    img(:,:,3) = uint8(brightness * 50 + rand(224, 224) * 5);
end

function img = createFundusWithDisc()
    img = createFundusLikeImage();
    imgD = double(img);
    [X, Y] = meshgrid(1:224, 1:224);
    discDist = sqrt((X-150).^2 + (Y-150).^2);
    discRegion = discDist < 20;
    imgD(:,:,1) = imgD(:,:,1) + discRegion * 80;
    imgD(:,:,2) = imgD(:,:,2) + discRegion * 60;
    imgD(:,:,3) = imgD(:,:,3) + discRegion * 30;
    img = uint8(min(imgD, 255));
end

function img = createFundusWithNormalVessels()
    % Create fundus with smooth, parallel vessel-like structures
    img = createFundusLikeImage();
    imgD = double(img);

    % Two smooth, parallel dark lines (normal vessels)
    for x = 1:224
        % Vessel 1: gentle arc
        y1 = round(100 + 15 * sin(x/50));
        y1 = max(1, min(224, y1));
        imgD(y1, x, 2) = imgD(y1, x, 2) * 0.3;
        imgD(y1+1, x, 2) = imgD(y1+1, x, 2) * 0.5;

        % Vessel 2: gentle arc, offset
        y2 = round(140 + 10 * sin(x/40 + 1));
        y2 = max(1, min(224, y2));
        imgD(y2, x, 2) = imgD(y2, x, 2) * 0.3;
        imgD(y2-1, x, 2) = imgD(y2-1, x, 2) * 0.5;
    end

    img = uint8(max(0, min(imgD, 255)));
end

function img = createFundusWithNVCluster()
    % Peripheral proliferative frond on a vessel-bearing fundus.
    %
    % Morphology model (documented): a cluster of short (8-14px), thin,
    % dark-red segments at mixed orientations in a peripheral patch —
    % dense, connected, irregular, and peripheral, unlike smooth normal
    % vessels. Two smooth background arcs provide the normal-vessel
    % baseline the adaptive density gate contrasts against (real retinas
    % are never vessel-free).
    % NOTE (Phase 20B.4): FIXED RNG seed. The seed fixes the geometry so
    % the test is reproducible (an unseeded draw made T19 flaky across
    % runs). Detector determinism is covered separately by T20.
    s = rng;
    rng(7, 'twister');
    imgD = double(createFundusLikeImage()) / 255;

    % Background normal vessels (smooth arcs, full-width)
    for x = 1:224
        y1 = max(1, min(224, round(100 + 15 * sin(x / 50))));
        y2 = max(1, min(224, round(150 + 10 * sin(x / 40 + 1))));
        for dy = -1:1
            yy1 = max(1, min(224, y1 + dy));
            yy2 = max(1, min(224, y2 + dy));
            imgD(yy1, x, 1) = imgD(yy1, x, 1) * 0.55;
            imgD(yy1, x, 2) = imgD(yy1, x, 2) * 0.25;
            imgD(yy2, x, 1) = imgD(yy2, x, 1) * 0.55;
            imgD(yy2, x, 2) = imgD(yy2, x, 2) * 0.25;
        end
    end

    % Peripheral frond in two tiers (sea-fan morphology): a sparse fan of
    % 30 segments over +/-14px plus a dense 25-segment core over +/-7px.
    % Center (145,72): d~=0.45 from image center (inside the FOV mask with
    % margin) and normDist~=0.33 (peripheral). An earlier revision sat at
    % d~=0.7 straddling the FOV rim and was excluded once the FOV gate
    % became real (Phase 20B.5 cross-phase fix) — correctly, since a
    % rim-straddling lesion is half outside the visible retina.
    for tier = 1:2
        if tier == 1
            nSeg = 30; spread = 14; baseLen = 10; lenVar = 6;
        else
            nSeg = 25; spread = 7; baseLen = 8; lenVar = 5;
        end
        for sg = 1:nSeg
            cr = 72 + (rand - 0.5) * 2 * spread;
            cc0 = 145 + (rand - 0.5) * 2 * spread;
            ang = rand * 180;
            ln = baseLen + rand * lenVar;
            t = linspace(-ln / 2, ln / 2, 20);
            rr = round(cr + t * sind(ang));
            ccr = round(cc0 + t * cosd(ang));
            ok = rr >= 2 & rr <= 223 & ccr >= 2 & ccr <= 223;
            rr = rr(ok);
            ccr = ccr(ok);
            idx = sub2ind([224, 224], rr, ccr);
            ch2 = imgD(:, :, 2); ch1 = imgD(:, :, 1);
            ch2(idx) = ch2(idx) * 0.3;
            ch1(idx) = ch1(idx) * 0.55;
            imgD(:, :, 2) = ch2; imgD(:, :, 1) = ch1;
        end
    end

    img = uint8(max(0, min(1, imgD)) * 255);
    rng(s);  % restore caller RNG state
end
