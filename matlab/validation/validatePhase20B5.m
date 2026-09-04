function result = validatePhase20B5(varargin)
% validatePhase20B5  Validation test suite for Phase 20B.5 exudate correction
%
%   result = validatePhase20B5()
%   result = validatePhase20B5('Verbose', true)
%
%   PROJECT POLICY (20B.4 lesson): a detector suite MUST prove positive
%   detection, not only zeros. T17/T18 assert deliberately inserted
%   exudate-like objects ARE detected, with localization; T14/T15/T16
%   assert disc/vessel/border brightness is NOT reported as exudate.
%
%   Passing software tests does not establish clinical exudate detection
%   accuracy. Frozen classifier and held-out test set untouched (no test
%   reads test.csv).

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'OutputDir', fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20b5_validation'), @ischar);
    parse(p, varargin{:});

    verbose = p.Results.Verbose;
    outputDir = p.Results.OutputDir;
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    result = struct();
    result.tests = {};
    result.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    if verbose
        fprintf('=== PHASE 20B.5 VALIDATION ===\n');
        fprintf('Date: %s\n\n', result.timestamp);
    end

    result.tests{end+1} = runTest('T01: function exists', @testFunctionExists, verbose);
    result.tests{end+1} = runTest('T02: output structure', @testOutputStructure, verbose);
    result.tests{end+1} = runTest('T03: binary mask', @testBinaryMask, verbose);
    result.tests{end+1} = runTest('T04: correct dimensions', @testDimensions, verbose);
    result.tests{end+1} = runTest('T05: finite values', @testFiniteValues, verbose);
    result.tests{end+1} = runTest('T06: uint8 input', @testUint8, verbose);
    result.tests{end+1} = runTest('T07: double input', @testDouble, verbose);
    result.tests{end+1} = runTest('T08: grayscale input (no crash)', @testGrayscale, verbose);
    result.tests{end+1} = runTest('T09: small image (no crash)', @testSmallImage, verbose);
    result.tests{end+1} = runTest('T10: blank image -> none', @testBlackImage, verbose);
    result.tests{end+1} = runTest('T11: white image -> none', @testWhiteImage, verbose);
    result.tests{end+1} = runTest('T12: uniform gray -> none', @testGrayImage, verbose);
    result.tests{end+1} = runTest('T13: random noise -> none', @testNoiseImage, verbose);
    result.tests{end+1} = runTest('T14: optic disc NOT exudate', @testDiscOnly, verbose);
    result.tests{end+1} = runTest('T15: bright vessel NOT exudate', @testBrightVessel, verbose);
    result.tests{end+1} = runTest('T16: border artifact -> none', @testBorderArtifact, verbose);
    result.tests{end+1} = runTest('T17: SINGLE positive exudate', @testSingleExudate, verbose);
    result.tests{end+1} = runTest('T18: MULTIPLE positive exudates', @testMultipleExudates, verbose);
    result.tests{end+1} = runTest('T19: exudate near vessel kept', @testExudateNearVessel, verbose);
    result.tests{end+1} = runTest('T20: exudate near disc kept', @testExudateNearDisc, verbose);
    result.tests{end+1} = runTest('T21: deterministic behavior', @testDeterministic, verbose);
    result.tests{end+1} = runTest('T22: FOV handling', @testFOVHandling, verbose);
    result.tests{end+1} = runTest('T23: boundary rejection', @testBoundaryRejection, verbose);
    result.tests{end+1} = runTest('T24: diagnostic mode', @testDiagnosticOutput, verbose);
    result.tests{end+1} = runTest('T25: extractLesionEvidence compatibility', @testAggregatorCompatibility, verbose);
    result.tests{end+1} = runTest('T26: uneven illumination -> none', @testIllumination, verbose);

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
    if verbose; fprintf('  %-38s ', name); end
    try
        testFunc();
        result.passed = true;
        if verbose; fprintf('PASS\n'); end
    catch ME
        result.error = ME.message;
        if verbose; fprintf('FAIL: %s\n', ME.message); end
    end
end

% ---------------- structural ----------------

function testFunctionExists()
    assert(exist('detectExudates', 'file') > 0, 'detectExudates.m not found');
end

function testOutputStructure()
    e = detectExudates(createFundus());
    for f = {'count', 'mask', 'locations', 'areas', 'totalArea', 'confidence'}
        assert(isfield(e, f{1}), ['Missing field: ' f{1}]);
    end
end

function testBinaryMask()
    e = detectExudates(createFundus());
    assert(islogical(e.mask), 'mask must be logical');
end

function testDimensions()
    img = createFundus();
    e = detectExudates(img);
    assert(size(e.mask, 1) == size(img, 1) && size(e.mask, 2) == size(img, 2), ...
        'mask dims must match image');
end

function testFiniteValues()
    e = detectExudates(createFundusWithExudate());
    assert(isfinite(e.count) && isfinite(e.totalArea) && isfinite(e.confidence), ...
        'scalars must be finite');
    assert(e.confidence >= 0 && e.confidence <= 1, 'heuristic confidence must be in [0,1]');
    if ~isempty(e.locations)
        assert(all(isfinite(e.locations(:))), 'locations must be finite');
    end
end

% ---------------- input handling ----------------

function testUint8()
    e = detectExudates(uint8(createFundus() * 255));
    assert(isstruct(e) && e.count >= 0, 'uint8 must be handled');
end

function testDouble()
    e = detectExudates(createFundus());
    assert(isstruct(e) && e.count >= 0, 'double must be handled');
end

function testGrayscale()
    e = detectExudates(uint8(rand(224, 224) * 200));
    assert(isstruct(e) && e.count == 0, 'grayscale must return empty evidence, not crash');
end

function testSmallImage()
    e = detectExudates(uint8(rand(32, 32, 3) * 200));
    assert(isstruct(e), 'small image must not crash');
end

% ---------------- adversarial negatives ----------------

function testBlackImage()
    e = detectExudates(zeros(224, 224, 3, 'uint8'));
    assert(e.count == 0, 'black image must yield no candidates');
end

function testWhiteImage()
    e = detectExudates(255 * ones(224, 224, 3, 'uint8'));
    assert(e.count == 0, 'uniform white must yield no candidates');
end

function testGrayImage()
    e = detectExudates(128 * ones(224, 224, 3, 'uint8'));
    assert(e.count == 0, 'uniform gray must yield no candidates');
end

function testNoiseImage()
    rng(42);
    e = detectExudates(uint8(rand(224, 224, 3) * 255));
    assert(e.count <= 2, ...
        sprintf('random noise must yield ≤2 candidates (got %d)', e.count));
end

function testDiscOnly()
    % Bright sharp-edged disc, no lesions: disc must be localized (gate
    % proof) and NOT reported as exudate.
    e = detectExudates(createDiscPhantom(), 'Diagnostic', true);
    assert(e.count == 0, 'optic disc must NOT be reported as exudate');
    assert(any(e.discMask(:)), 'disc mask must localize the phantom disc');
end

function testBrightVessel()
    % Bright thin full-width line (vessel reflex mimic): elongated shape
    % must reject it.
    e = detectExudates(createBrightVesselPhantom());
    assert(e.count == 0, 'bright vessel streak must NOT be exudate');
end

function testBorderArtifact()
    % Bright crescent hugging the image edge (glare mimic).
    e = detectExudates(createBorderPhantom());
    assert(e.count == 0, 'border artifact must be rejected');
end

% ---------------- MANDATORY positives ----------------

function testSingleExudate()
    % POLICY: at least one test asserts synthetic_exudate_detected == TRUE,
    % with localization (detection must come from the inserted object).
    e = detectExudates(createFundusWithExudate());
    assert(e.count > 0, 'inserted exudate-like object MUST be detected');
    [X, Y] = meshgrid(1:224, 1:224);
    zone = X >= 140 & X <= 160 & Y >= 70 & Y <= 90;
    assert(sum(e.mask(zone)) > 0, 'detection must localize to the inserted object');
end

function testMultipleExudates()
    e = detectExudates(createFundusWithExudates());
    assert(e.count >= 2, 'multiple inserted exudates must be detected');
end

function testExudateNearVessel()
    % Exudate 10px from a dark vessel arc: undilated vessel exclusion must
    % preserve it (no excessive dilation).
    e = detectExudates(createExudateNearVessel());
    assert(e.count > 0, 'exudate near vessel must be kept');
end

function testExudateNearDisc()
    % Bright disc + exudate outside the disc exclusion zone: disc masked,
    % exudate kept.
    e = detectExudates(createExudateNearDisc(), 'Diagnostic', true);
    assert(e.count > 0, 'exudate near disc must be kept');
    assert(any(e.discMask(:)), 'disc must still be localized');
end

function testDeterministic()
    img = createFundusWithExudate();
    e1 = detectExudates(img);
    e2 = detectExudates(img);
    assert(e1.count == e2.count && isequal(e1.mask, e2.mask), ...
        'repeat calls must agree exactly');
end

% ---------------- gates / compatibility ----------------

function testFOVHandling()
    % Bright blob OUTSIDE the retinal FOV (dark corner) must not count.
    % NOTE: painted per-channel — a 2-D mask on a 3-D array would assign
    % linearly (first page only), not the blob (bug caught in review).
    img = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    m = sqrt((X - 12).^2 + (Y - 12).^2) < 6;
    for ch = 1:3
        plane = img(:, :, ch);
        plane(m) = 1.0;
        img(:, :, ch) = plane;
    end
    e = detectExudates(img);
    assert(e.count == 0, 'extra-FOV bright blob must be rejected');
end

function testBoundaryRejection()
    % Bright compact dot AT the image corner: shape/size pass, gate kills.
    img = createFundus();
    img(4:14, 4:14, 1) = 1.0;
    img(4:14, 4:14, 2) = 0.95;
    img(4:14, 4:14, 3) = 0.7;
    e = detectExudates(img);
    assert(e.count == 0, 'corner dot must be boundary-rejected');
end

function testDiagnosticOutput()
    e = detectExudates(createFundusWithExudate(), 'Diagnostic', true);
    for f = {'retinalMask', 'vesselMask', 'discMask', 'rawCandidates', ...
             'filteredCandidates', 'labels'}
        assert(isfield(e, f{1}), ['Missing diagnostic field: ' f{1}]);
    end
    assert(islogical(e.rawCandidates) && islogical(e.filteredCandidates), ...
        'diagnostic masks must be logical');
    assert(isequal(size(e.labels), size(e.mask)), 'labels must match mask size');
end

function testAggregatorCompatibility()
    e = extractLesionEvidence(createFundus());
    assert(isfield(e, 'exudates'), 'aggregator must return exudates');
    x = e.exudates;
    for f = {'count', 'mask', 'locations', 'areas', 'totalArea', 'confidence'}
        assert(isfield(x, f{1}), ['aggregator exudates missing: ' f{1}]);
    end
    assert(ischar(e.severity) && ischar(e.summary), 'severity/summary must be text');
end

function testIllumination()
    % Strong smooth illumination gradient, no lesions: the large bright
    % center must die at the size gate, not reported.
    e = detectExudates(createIlluminationPhantom());
    assert(e.count == 0, 'uneven illumination must yield no candidates');
end

% ---------------- synthetic phantoms ----------------
% Positive fixtures use FIXED seeds (20B.2 lesson): the seed fixes
% geometry for reproducibility; detector determinism is T21's job.

function img = createFundus()
    img = zeros(224, 224, 3);
    [X, Y] = meshgrid(1:224, 1:224);
    d = sqrt((X - 112).^2 + (Y - 112).^2) / 112;
    b = max(0, 1 - d * 0.85);
    img(:, :, 1) = b * 0.72 + rand(224, 224) * 0.03;
    img(:, :, 2) = b * 0.40 + rand(224, 224) * 0.025;
    img(:, :, 3) = b * 0.20 + rand(224, 224) * 0.02;
end

function img = createFundusWithExudate()
    % One bright yellow-white compact blob (r=6) at rows 70-90/cols 140-160.
    s = rng;
    rng(11, 'twister');
    imgD = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    m = sqrt((X - 150).^2 + (Y - 80).^2) < 6;
    imgD(:, :, 1) = min(1, imgD(:, :, 1) + m * 0.45);
    imgD(:, :, 2) = min(1, imgD(:, :, 2) + m * 0.40);
    imgD(:, :, 3) = min(1, imgD(:, :, 3) + m * 0.15);
    rng(s);
    img = max(0, min(1, imgD));
end

function img = createFundusWithExudates()
    % Three separated bright blobs (r=5..7).
    s = rng;
    rng(23, 'twister');
    imgD = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    blobs = [150, 80, 6; 80, 150, 5; 180, 170, 7];
    for k = 1:size(blobs, 1)
        m = sqrt((X - blobs(k, 1)).^2 + (Y - blobs(k, 2)).^2) < blobs(k, 3);
        imgD(:, :, 1) = min(1, imgD(:, :, 1) + m * 0.45);
        imgD(:, :, 2) = min(1, imgD(:, :, 2) + m * 0.40);
        imgD(:, :, 3) = min(1, imgD(:, :, 3) + m * 0.15);
    end
    rng(s);
    img = max(0, min(1, imgD));
end

function img = createDiscPhantom()
    % Bright sharp-edged disc (r=20), no lesions.
    imgD = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    m = sqrt((X - 160).^2 + (Y - 110).^2) < 20;
    imgD(:, :, 1) = min(1, imgD(:, :, 1) + m * 0.35);
    imgD(:, :, 2) = min(1, imgD(:, :, 2) + m * 0.30);
    imgD(:, :, 3) = min(1, imgD(:, :, 3) + m * 0.15);
    img = max(0, min(1, imgD));
end

function img = createBrightVesselPhantom()
    % Bright thin full-width streak (vessel reflex mimic).
    imgD = createFundus();
    for x = 1:224
        y = max(1, min(224, round(110 + 12 * sin(x / 45))));
        for dy = -1:0
            yy = max(1, min(224, y + dy));
            imgD(yy, x, 1) = min(1, imgD(yy, x, 1) + 0.35);
            imgD(yy, x, 2) = min(1, imgD(yy, x, 2) + 0.30);
            imgD(yy, x, 3) = min(1, imgD(yy, x, 3) + 0.10);
        end
    end
    img = max(0, min(1, imgD));
end

function img = createBorderPhantom()
    % Bright crescent along the left edge (glare mimic).
    imgD = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    m = X < 14 & Y > 40 & Y < 184;
    imgD(:, :, 1) = min(1, imgD(:, :, 1) + m * 0.35);
    imgD(:, :, 2) = min(1, imgD(:, :, 2) + m * 0.30);
    img = max(0, min(1, imgD));
end

function img = createExudateNearVessel()
    % Dark vessel arc + bright blob 10px away (undilated exclusion test).
    s = rng;
    rng(37, 'twister');
    imgD = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    for x = 60:170
        y = round(150 + 10 * sin(x / 40));
        y = max(1, min(224, y));
        for dy = -1:1
            yy = max(1, min(224, y + dy));
            imgD(yy, x, 1) = imgD(yy, x, 1) * 0.55;
            imgD(yy, x, 2) = imgD(yy, x, 2) * 0.25;
        end
    end
    m = sqrt((X - 115).^2 + (Y - 128).^2) < 6;
    imgD(:, :, 1) = min(1, imgD(:, :, 1) + m * 0.45);
    imgD(:, :, 2) = min(1, imgD(:, :, 2) + m * 0.40);
    imgD(:, :, 3) = min(1, imgD(:, :, 3) + m * 0.15);
    rng(s);
    img = max(0, min(1, imgD));
end

function img = createExudateNearDisc()
    % Bright disc (r=20) at (150,150) + blob at (100,100), clear of mask.
    s = rng;
    rng(51, 'twister');
    imgD = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    md = sqrt((X - 150).^2 + (Y - 150).^2) < 20;
    imgD(:, :, 1) = min(1, imgD(:, :, 1) + md * 0.35);
    imgD(:, :, 2) = min(1, imgD(:, :, 2) + md * 0.30);
    imgD(:, :, 3) = min(1, imgD(:, :, 3) + md * 0.15);
    m = sqrt((X - 100).^2 + (Y - 100).^2) < 6;
    imgD(:, :, 1) = min(1, imgD(:, :, 1) + m * 0.45);
    imgD(:, :, 2) = min(1, imgD(:, :, 2) + m * 0.40);
    imgD(:, :, 3) = min(1, imgD(:, :, 3) + m * 0.15);
    rng(s);
    img = max(0, min(1, imgD));
end

function img = createIlluminationPhantom()
    % Strong smooth central illumination dome, no lesions.
    imgD = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    d = sqrt((X - 112).^2 + (Y - 112).^2) / 112;
    dome = max(0, 1 - d * 0.5) * 0.25;
    imgD(:, :, 1) = min(1, imgD(:, :, 1) + dome);
    imgD(:, :, 2) = min(1, imgD(:, :, 2) + dome);
    imgD(:, :, 3) = min(1, imgD(:, :, 3) + dome * 0.5);
    img = max(0, min(1, imgD));
end
