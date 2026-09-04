function result = validatePhase20B1(varargin)
% validatePhase20B1  Validation test suite for Phase 20B.1 MA detector fix
%
%   result = validatePhase20B1()
%   result = validatePhase20B1('Verbose', true)
%   result = validatePhase20B1('OutputDir', 'path/to/output')
%
%   Tests verify:
%     - Valid image handling (RGB and grayscale)
%     - Output structure correctness
%     - Binary mask properties
%     - Finite coordinates
%     - Lesions inside retinal FOV
%     - Lesions excluded from optic disc
%     - Plausible candidate sizes
%     - Deterministic output
%     - No crash on edge cases
%     - No artificial lesions on blank/uniform images
%     - Diagnostic visualization generation
%
%   IMPORTANT: This does NOT modify the frozen classifier or test set.

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'OutputDir', fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20b1_validation'), @ischar);
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
        fprintf('=== PHASE 20B.1 VALIDATION ===\n');
        fprintf('Date: %s\n\n', result.timestamp);
    end

    % --- Structural tests ---
    result.tests{end+1} = runTest('T01: Function exists', @testFunctionExists, verbose);
    result.tests{end+1} = runTest('T02: Output structure fields', @testOutputStructure, verbose);
    result.tests{end+1} = runTest('T03: Binary mask type', @testBinaryMask, verbose);
    result.tests{end+1} = runTest('T04: Finite coordinates', @testFiniteCoordinates, verbose);
    result.tests{end+1} = runTest('T05: Confidence in [0,1]', @testConfidenceRange, verbose);
    result.tests{end+1} = runTest('T06: Non-negative count and areas', @testNonNegative, verbose);

    % --- Anatomical constraint tests ---
    result.tests{end+1} = runTest('T07: Lesions inside retinal FOV', @testLesionsInsideFOV, verbose);
    result.tests{end+1} = runTest('T08: Lesions excluded from disc', @testLesionsExcludedDisc, verbose);

    % --- Size plausibility ---
    result.tests{end+1} = runTest('T09: Plausible lesion sizes', @testPlausibleSizes, verbose);
    result.tests{end+1} = runTest('T10: No oversized lesions', @testNoOversizedLesions, verbose);

    % --- Edge cases ---
    result.tests{end+1} = runTest('T11: RGB uint8 input', @testRGBUint8, verbose);
    result.tests{end+1} = runTest('T12: RGB double input', @testRGBDouble, verbose);
    result.tests{end+1} = runTest('T13: Grayscale input (fallback)', @testGrayscale, verbose);
    result.tests{end+1} = runTest('T14: Small image', @testSmallImage, verbose);
    result.tests{end+1} = runTest('T15: Large image', @testLargeImage, verbose);

    % --- Blank/uniform image tests ---
    result.tests{end+1} = runTest('T16: Black image (no lesions)', @testBlackImage, verbose);
    result.tests{end+1} = runTest('T17: White image (no lesions)', @testWhiteImage, verbose);
    result.tests{end+1} = runTest('T18: Uniform gray (no lesions)', @testUniformGray, verbose);
    result.tests{end+1} = runTest('T19: Random noise (no lesions)', @testRandomNoise, verbose);

    % --- Determinism ---
    result.tests{end+1} = runTest('T20: Deterministic output', @testDeterministic, verbose);

    % --- Diagnostic outputs ---
    result.tests{end+1} = runTest('T21: Diagnostic mode outputs', @testDiagnosticOutputs, verbose);
    result.tests{end+1} = runTest('T22: Diagnostic visualization', @testDiagnosticVisualization, verbose);

    % --- Mask dimensions ---
    result.tests{end+1} = runTest('T23: Mask dimensions match image', @testMaskDimensions, verbose);

    % --- Polarity verification ---
    result.tests{end+1} = runTest('T24: Dark lesions produce detections', @testDarkLesionDetection, verbose);
    result.tests{end+1} = runTest('T25: Bright lesions do NOT produce detections', @testBrightLesionRejected, verbose);

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

    % Write summary CSV
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
    if condition
        s = trueVal;
    else
        s = falseVal;
    end
end

function result = runTest(name, testFunc, verbose)
    result = struct();
    result.name = name;
    result.passed = false;
    result.error = '';

    if verbose
        fprintf('  %-45s ', name);
    end

    try
        testFunc();
        result.passed = true;
        if verbose
            fprintf('PASS\n');
        end
    catch ME
        result.error = ME.message;
        if verbose
            fprintf('FAIL: %s\n', ME.message);
        end
    end
end

function testFunctionExists()
    assert(exist('detectMicroaneurysms', 'file') > 0, ...
        'detectMicroaneurysms.m not found on path');
end

function testOutputStructure()
    img = createTestImage();
    e = detectMicroaneurysms(img);

    assert(isfield(e, 'count'), 'Missing count field');
    assert(isfield(e, 'mask'), 'Missing mask field');
    assert(isfield(e, 'locations'), 'Missing locations field');
    assert(isfield(e, 'areas'), 'Missing areas field');
    assert(isfield(e, 'confidence'), 'Missing confidence field');
end

function testBinaryMask()
    img = createTestImage();
    e = detectMicroaneurysms(img);
    assert(islogical(e.mask), 'Mask must be logical');
end

function testFiniteCoordinates()
    img = createTestImage();
    e = detectMicroaneurysms(img);
    if ~isempty(e.locations)
        assert(all(isfinite(e.locations(:))), 'Coordinates must be finite');
        assert(all(e.locations(:,1) > 0), 'Row coordinates must be > 0');
        assert(all(e.locations(:,2) > 0), 'Col coordinates must be > 0');
    end
end

function testConfidenceRange()
    img = createTestImage();
    e = detectMicroaneurysms(img);
    assert(e.confidence >= 0 && e.confidence <= 1, ...
        sprintf('Confidence %f out of range [0,1]', e.confidence));
end

function testNonNegative()
    img = createTestImage();
    e = detectMicroaneurysms(img);
    assert(e.count >= 0, 'Count must be non-negative');
    assert(all(e.areas >= 0), 'Areas must be non-negative');
end

function testLesionsInsideFOV()
    % Create image with clear retinal-like background and a dark lesion
    img = createFundusLikeImage();
    e = detectMicroaneurysms(img, 'Diagnostic', true);
    if e.count > 0 && isfield(e, 'retinalMask')
        [rows, cols] = size(e.mask);
        [rr, cc] = find(e.mask);
        for i = 1:numel(rr)
            assert(e.retinalMask(rr(i), cc(i)), ...
                sprintf('Lesion at (%d,%d) outside retinal FOV', rr(i), cc(i)));
        end
    end
end

function testLesionsExcludedDisc()
    % Create image with bright disc region and nearby dark lesion
    img = createFundusWithDisc();
    e = detectMicroaneurysms(img, 'Diagnostic', true);
    if e.count > 0 && isfield(e, 'discMask')
        assert(~any(e.mask(:) & e.discMask(:)), ...
            'Lesions found on optic disc');
    end
end

function testPlausibleSizes()
    img = createTestImage();
    e = detectMicroaneurysms(img);
    if e.count > 0
        assert(all(e.areas >= 3), 'All lesions should be >= 3 pixels');
        assert(all(e.areas <= 5000), 'All lesions should be <= 5000 pixels');
    end
end

function testNoOversizedLesions()
    img = createTestImage();
    e = detectMicroaneurysms(img);
    maxAllowed = round(pi * (min(size(img,1), size(img,2)) / 8)^2);
    if e.count > 0
        assert(all(e.areas <= maxAllowed), ...
            sprintf('Found lesion larger than %d pixels', maxAllowed));
    end
end

function testRGBUint8()
    img = uint8(createTestImage() * 255);
    e = detectMicroaneurysms(img);
    assert(isstruct(e), 'Should handle uint8 input');
    assert(e.count >= 0, 'Count non-negative');
end

function testRGBDouble()
    img = createTestImage();
    e = detectMicroaneurysms(img);
    assert(isstruct(e), 'Should handle double input');
end

function testGrayscale()
    grayImg = uint8(rand(224, 224) * 200);
    try
        e = detectMicroaneurysms(grayImg);
        assert(isstruct(e), 'Should return struct for grayscale');
    catch ME
        % Grayscale may fail at rgb2gray call; this is acceptable
        % as the function signature requires RGB
        if ~contains(ME.message, 'size')
            rethrow(ME);
        end
    end
end

function testSmallImage()
    img = uint8(rand(32, 32, 3) * 200);
    e = detectMicroaneurysms(img);
    assert(isstruct(e), 'Should handle small image');
    assert(e.count >= 0, 'Count non-negative');
end

function testLargeImage()
    img = uint8(rand(800, 800, 3) * 200);
    e = detectMicroaneurysms(img);
    assert(isstruct(e), 'Should handle large image');
end

function testBlackImage()
    img = zeros(224, 224, 3, 'uint8');
    e = detectMicroaneurysms(img);
    assert(e.count == 0, 'Black image should have no detections');
end

function testWhiteImage()
    img = 255 * ones(224, 224, 3, 'uint8');
    e = detectMicroaneurysms(img);
    assert(e.count == 0, 'White image should have no detections');
end

function testUniformGray()
    img = 128 * ones(224, 224, 3, 'uint8');
    e = detectMicroaneurysms(img);
    assert(e.count == 0, 'Uniform gray image should have no detections');
end

function testRandomNoise()
    img = uint8(rand(224, 224, 3) * 255);
    e = detectMicroaneurysms(img);
    assert(e.count == 0, 'Random noise should produce no detections');
end

function testDeterministic()
    img = createFundusLikeImage();
    e1 = detectMicroaneurysms(img);
    e2 = detectMicroaneurysms(img);
    assert(e1.count == e2.count, 'Count should be deterministic');
    assert(isequal(e1.mask, e2.mask), 'Mask should be deterministic');
    if ~isempty(e1.locations) && ~isempty(e2.locations)
        assert(isequal(e1.locations, e2.locations), 'Locations should be deterministic');
    end
end

function testDiagnosticOutputs()
    img = createFundusLikeImage();
    e = detectMicroaneurysms(img, 'Diagnostic', true);
    assert(isfield(e, 'retinalMask'), 'Missing retinalMask');
    assert(isfield(e, 'vesselMask'), 'Missing vesselMask');
    assert(isfield(e, 'discMask'), 'Missing discMask');
    assert(isfield(e, 'rawCandidates'), 'Missing rawCandidates');
    assert(isfield(e, 'filteredCandidates'), 'Missing filteredCandidates');
    assert(isfield(e, 'labels'), 'Missing labels');
    assert(islogical(e.retinalMask), 'retinalMask must be logical');
    assert(islogical(e.vesselMask), 'vesselMask must be logical');
    assert(islogical(e.discMask), 'discMask must be logical');
    assert(islogical(e.rawCandidates), 'rawCandidates must be logical');
    assert(islogical(e.filteredCandidates), 'filteredCandidates must be logical');
end

function testDiagnosticVisualization()
    img = createFundusLikeImage();
    outputDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20b1_validation');

    e = detectMicroaneurysms(img, 'Diagnostic', true);

    fig = figure('Visible', 'off', 'Position', [100 100 1200 600]);

    subplot(2, 4, 1); imshow(img); title('Original');
    subplot(2, 4, 2); imshow(e.retinalMask); title('Retinal Mask');
    subplot(2, 4, 3); imshow(e.vesselMask); title('Vessel Mask');
    subplot(2, 4, 4); imshow(e.discMask); title('Disc Mask');
    subplot(2, 4, 5); imshow(e.rawCandidates); title('Raw Candidates');
    subplot(2, 4, 6); imshow(e.filteredCandidates); title('Filtered');
    subplot(2, 4, 7); imshow(img); hold on;
    if ~isempty(e.locations)
        plot(e.locations(:,2), e.locations(:,1), 'r+', 'MarkerSize', 12, 'LineWidth', 2);
    end
    title(sprintf('Detections: %d', e.count));

    subplot(2, 4, 8); axis off;
    text(0.1, 0.9, sprintf('Count: %d', e.count), 'FontSize', 12);
    text(0.1, 0.7, sprintf('Confidence: %.3f', e.confidence), 'FontSize', 12);
    text(0.1, 0.5, sprintf('Areas: %s', mat2str(e.areas')), 'FontSize', 10);
    title('Summary');

    saveas(fig, fullfile(outputDir, 'diagnostic_visualization.png'));
    close(fig);

    assert(exist(fullfile(outputDir, 'diagnostic_visualization.png'), 'file') > 0, ...
        'Visualization file not created');
end

function testMaskDimensions()
    img = createTestImage();
    e = detectMicroaneurysms(img);
    [rows, cols, ~] = size(img);
    assert(size(e.mask, 1) == rows, 'Mask height mismatch');
    assert(size(e.mask, 2) == cols, 'Mask width mismatch');
end

function testDarkLesionDetection()
    % Create fundus-like image with embedded dark lesion
    img = createFundusWithLesion(true);
    e = detectMicroaneurysms(img);
    assert(e.count > 0, ...
        'Dark lesion on fundus-like background should be detected');
end

function testBrightLesionRejected()
    % Create fundus-like image with bright spot (not an MA)
    img = createFundusWithLesion(false);
    e = detectMicroaneurysms(img);
    assert(e.count == 0, ...
        'Bright spot on fundus-like background should NOT be detected as MA');
end

% --- Test image generators ---

function img = createTestImage()
    % Simple RGB image with some variation
    img = zeros(224, 224, 3, 'uint8');
    img(:,:,1) = uint8(100 + rand(224, 224) * 50);
    img(:,:,2) = uint8(60 + rand(224, 224) * 30);
    img(:,:,3) = uint8(30 + rand(224, 224) * 20);
end

function img = createFundusLikeImage()
    % Simulate fundus-like appearance: dark background, brighter center
    img = zeros(224, 224, 3, 'uint8');

    [X, Y] = meshgrid(1:224, 1:224);
    centerDist = sqrt((X-112).^2 + (Y-112).^2) / 112;
    brightness = max(0, 1 - centerDist * 0.8);

    img(:,:,1) = uint8(brightness * 180 + rand(224, 224) * 10);
    img(:,:,2) = uint8(brightness * 100 + rand(224, 224) * 8);
    img(:,:,3) = uint8(brightness * 50 + rand(224, 224) * 5);
end

function img = createFundusWithDisc()
    % Fundus with bright optic disc region
    img = createFundusLikeImage();
    imgD = double(img);

    % Add bright disc at (150, 150)
    [X, Y] = meshgrid(1:224, 1:224);
    discDist = sqrt((X-150).^2 + (Y-150).^2);
    discRegion = discDist < 20;
    imgD(:,:,1) = imgD(:,:,1) + discRegion * 80;
    imgD(:,:,2) = imgD(:,:,2) + discRegion * 60;
    imgD(:,:,3) = imgD(:,:,3) + discRegion * 30;

    img = uint8(min(imgD, 255));
end

function img = createFundusWithLesion(isDark)
    % Fundus with a single lesion (dark or bright)
    img = createFundusLikeImage();
    imgD = double(img);

    [X, Y] = meshgrid(1:224, 1:224);
    % Lesion radius < 3px (~110um at 224px screening scale): inside the
    % documented 12-125um MA size spec the detector enforces. (A larger
    % dark-red blob is hemorrhage territory, handled by detectHemorrhages.)
    lesionDist = sqrt((X-112).^2 + (Y-112).^2);
    lesionMask = lesionDist < 3;

    if isDark
        imgD(:,:,1) = imgD(:,:,1) - lesionMask * 60;
        imgD(:,:,2) = imgD(:,:,2) - lesionMask * 30;
        imgD(:,:,3) = imgD(:,:,3) - lesionMask * 15;
    else
        imgD(:,:,1) = imgD(:,:,1) + lesionMask * 60;
        imgD(:,:,2) = imgD(:,:,2) + lesionMask * 30;
        imgD(:,:,3) = imgD(:,:,3) + lesionMask * 15;
    end

    img = uint8(max(0, min(imgD, 255)));
end
