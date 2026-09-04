function result = validatePhase20B4(varargin)
% validatePhase20B4  Validation test suite for Phase 20B.4 hemorrhage fix
%
%   result = validatePhase20B4()
%   result = validatePhase20B4('Verbose', true)
%
%   24 tests: structure, input handling, 11 adversarial synthetics,
%   anatomical gates (vessel/disc/boundary), determinism, diagnostics,
%   and downstream compatibility (extractLesionEvidence, GUI).
%
%   Passing synthetic tests do NOT establish clinical hemorrhage-detection
%   accuracy. No lesion-level ground truth exists; no sensitivity or
%   specificity is reported. Frozen classifier and held-out test set are
%   untouched (no test here reads test.csv).

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'OutputDir', fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20b4_validation'), @ischar);
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
        fprintf('=== PHASE 20B.4 VALIDATION ===\n');
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
    result.tests{end+1} = runTest('T10: black image -> none', @testBlackImage, verbose);
    result.tests{end+1} = runTest('T11: white image -> none', @testWhiteImage, verbose);
    result.tests{end+1} = runTest('T12: uniform gray -> none', @testGrayImage, verbose);
    result.tests{end+1} = runTest('T13: random noise -> none', @testNoiseImage, verbose);
    result.tests{end+1} = runTest('T14: vessel-only -> none', @testVesselOnly, verbose);
    result.tests{end+1} = runTest('T15: disc-only -> none', @testDiscOnly, verbose);
    result.tests{end+1} = runTest('T16: border artifact -> none', @testBorderArtifact, verbose);
    result.tests{end+1} = runTest('T17: hemorrhage-like object detected', @testHemorrhageLike, verbose);
    result.tests{end+1} = runTest('T18: deterministic result', @testDeterministic, verbose);
    result.tests{end+1} = runTest('T19: vessel exclusion gate', @testVesselExclusion, verbose);
    result.tests{end+1} = runTest('T20: disc exclusion gate', @testDiscExclusion, verbose);
    result.tests{end+1} = runTest('T21: boundary rejection gate', @testBoundaryRejection, verbose);
    result.tests{end+1} = runTest('T22: diagnostic output', @testDiagnosticOutput, verbose);
    result.tests{end+1} = runTest('T23: GUI compatibility', @testGUICompatibility, verbose);
    result.tests{end+1} = runTest('T24: extractLesionEvidence compatibility', @testAggregatorCompatibility, verbose);

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
    if verbose; fprintf('  %-42s ', name); end
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
    assert(exist('detectHemorrhages', 'file') > 0, 'detectHemorrhages.m not found');
end

function testOutputStructure()
    e = detectHemorrhages(createFundus());
    for f = {'count', 'mask', 'locations', 'areas', 'totalArea', 'confidence'}
        assert(isfield(e, f{1}), ['Missing field: ' f{1}]);
    end
end

function testBinaryMask()
    e = detectHemorrhages(createFundus());
    assert(islogical(e.mask), 'mask must be logical');
end

function testDimensions()
    img = createFundus();
    e = detectHemorrhages(img);
    assert(size(e.mask, 1) == size(img, 1) && size(e.mask, 2) == size(img, 2), ...
        'mask dims must match image');
end

function testFiniteValues()
    e = detectHemorrhages(createFundusWithHE());
    assert(isfinite(e.count) && isfinite(e.totalArea) && isfinite(e.confidence), ...
        'scalars must be finite');
    assert(e.confidence >= 0 && e.confidence <= 1, 'confidence must be in [0,1]');
    if ~isempty(e.locations)
        assert(all(isfinite(e.locations(:))), 'locations must be finite');
    end
    if ~isempty(e.areas)
        assert(all(e.areas >= 0), 'areas must be non-negative');
    end
end

% ---------------- input handling ----------------

function testUint8()
    e = detectHemorrhages(uint8(createFundus() * 255));
    assert(isstruct(e) && e.count >= 0, 'uint8 must be handled');
end

function testDouble()
    e = detectHemorrhages(createFundus());
    assert(isstruct(e) && e.count >= 0, 'double must be handled');
end

function testGrayscale()
    e = detectHemorrhages(uint8(rand(224, 224) * 200));  % 2-D input
    assert(isstruct(e) && e.count == 0, 'grayscale must return empty evidence, not crash');
end

function testSmallImage()
    e = detectHemorrhages(uint8(rand(32, 32, 3) * 200));
    assert(isstruct(e), 'small image must not crash');
end

% ---------------- adversarial synthetics ----------------

function testBlackImage()
    e = detectHemorrhages(zeros(224, 224, 3, 'uint8'));
    assert(e.count == 0, 'black image must yield no candidates');
end

function testWhiteImage()
    e = detectHemorrhages(255 * ones(224, 224, 3, 'uint8'));
    assert(e.count == 0, 'white image must yield no candidates');
end

function testGrayImage()
    e = detectHemorrhages(128 * ones(224, 224, 3, 'uint8'));
    assert(e.count == 0, 'uniform gray must yield no candidates');
end

function testNoiseImage()
    rng(42);
    e = detectHemorrhages(uint8(rand(224, 224, 3) * 255));
    assert(e.count <= 2, ...
        sprintf('random noise must yield ≤2 candidates (got %d)', e.count));
end

function testVesselOnly()
    % Smooth dark-red curvilinear structures: the old detector's main FP.
    e = detectHemorrhages(createVesselPhantom());
    assert(e.count == 0, 'normal vessels must not be hemorrhages');
end

function testDiscOnly()
    % Bright disc on clean fundus: no dark candidates expected.
    e = detectHemorrhages(createDiscPhantom());
    assert(e.count == 0, 'disc-only image must yield no candidates');
end

function testBorderArtifact()
    % Dark crescent hugging the image edge (illumination/FOV artifact).
    e = detectHemorrhages(createBorderPhantom());
    assert(e.count == 0, 'border artifact must be rejected');
end

function testHemorrhageLike()
    % Dark, compact, red-dominant blob inside the retina: must be found.
    e = detectHemorrhages(createFundusWithHE());
    assert(e.count > 0, 'hemorrhage-like object must be detected');
end

function testDeterministic()
    img = createFundusWithHE();
    e1 = detectHemorrhages(img);
    e2 = detectHemorrhages(img);
    assert(e1.count == e2.count && isequal(e1.mask, e2.mask), ...
        'repeat calls must agree exactly');
end

% ---------------- anatomical gates ----------------

function testVesselExclusion()
    e = detectHemorrhages(createVesselPhantom(), 'Diagnostic', true);
    assert(e.count == 0, 'vessel phantom must be fully excluded');
    assert(any(e.vesselMask(:)), 'vessel mask must actually cover the phantom vessels');
end

function testDiscExclusion()
    e = detectHemorrhages(createDiscPhantom(), 'Diagnostic', true);
    assert(any(e.discMask(:)), 'disc mask must localize the phantom disc');
    if e.count > 0
        overlap = sum(e.mask(:) & e.discMask(:)) / max(1, sum(e.mask(:)));
        assert(overlap < 0.1, 'detections must not sit on the disc');
    end
end

function testBoundaryRejection()
    % Dark compact dot AT the image corner: shape/size pass, gate must kill.
    img = createFundus();
    imgD = double(img);
    imgD(4:14, 4:14, 1) = 0.35;
    imgD(4:14, 4:14, 2) = 0.12;
    imgD(4:14, 4:14, 3) = 0.10;
    e = detectHemorrhages(uint8(imgD));
    assert(e.count == 0, 'corner dot must be boundary-rejected');
end

function testDiagnosticOutput()
    e = detectHemorrhages(createFundusWithHE(), 'Diagnostic', true);
    for f = {'retinalMask', 'vesselMask', 'discMask', 'rawCandidates', ...
             'filteredCandidates', 'labels'}
        assert(isfield(e, f{1}), ['Missing diagnostic field: ' f{1}]);
    end
    assert(islogical(e.rawCandidates) && islogical(e.filteredCandidates), ...
        'diagnostic masks must be logical');
    assert(isequal(size(e.labels), size(e.mask)), 'labels must match mask size');
end

% ---------------- compatibility ----------------

function testGUICompatibility()
    % drScreeningGUIv2 + export path consume .count and .detected-style fields.
    f = which('drScreeningGUIv2');
    assert(~isempty(f), 'GUI not on path');
    txt = fileread(f);
    assert(~isempty(strfind(txt, 'hemorrhages.count')), 'GUI must read hemorrhages.count');
    e = detectHemorrhages(createFundusWithHE());
    assert(isfield(e, 'count') && isnumeric(e.count), 'count field required by GUI');
end

function testAggregatorCompatibility()
    e = extractLesionEvidence(createFundus());
    assert(isfield(e, 'hemorrhages'), 'aggregator must return hemorrhages');
    h = e.hemorrhages;
    for f = {'count', 'mask', 'locations', 'areas', 'totalArea', 'confidence'}
        assert(isfield(h, f{1}), ['aggregator hemorrhages missing: ' f{1}]);
    end
    assert(ischar(e.severity) && ischar(e.summary), 'severity/summary must be text');
end

% ---------------- synthetic phantoms ----------------

function img = createFundus()
    % Smooth fundus-like background: dark corners, warm center, mild noise.
    img = zeros(224, 224, 3);
    [X, Y] = meshgrid(1:224, 1:224);
    d = sqrt((X - 112).^2 + (Y - 112).^2) / 112;
    b = max(0, 1 - d * 0.85);
    img(:, :, 1) = b * 0.72 + rand(224, 224) * 0.03;
    img(:, :, 2) = b * 0.40 + rand(224, 224) * 0.025;
    img(:, :, 3) = b * 0.20 + rand(224, 224) * 0.02;
end

function img = createFundusWithHE()
    % One dark-red compact blot (r=8) at (140, 90): R>=G preserved.
    imgD = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    m = sqrt((X - 90).^2 + (Y - 140).^2) < 8;
    imgD(:, :, 1) = imgD(:, :, 1) - m * 0.35;
    imgD(:, :, 2) = imgD(:, :, 2) - m * 0.30;
    imgD(:, :, 3) = imgD(:, :, 3) - m * 0.10;
    img = max(0, min(1, imgD));
end

function img = createVesselPhantom()
    % Two smooth dark-red arcs spanning the frame (normal-vessel mimic).
    imgD = createFundus();
    for x = 1:224
        y1 = round(100 + 15 * sin(x / 50));
        y2 = round(150 + 10 * sin(x / 40 + 1));
        for dy = -1:1
            yy1 = max(1, min(224, y1 + dy));
            yy2 = max(1, min(224, y2 + dy));
            imgD(yy1, x, 1) = imgD(yy1, x, 1) * 0.55;
            imgD(yy1, x, 2) = imgD(yy1, x, 2) * 0.25;
            imgD(yy2, x, 1) = imgD(yy2, x, 1) * 0.55;
            imgD(yy2, x, 2) = imgD(yy2, x, 2) * 0.25;
        end
    end
    img = max(0, min(1, imgD));
end

function img = createDiscPhantom()
    % Bright disc-like region, no dark lesions.
    imgD = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    m = sqrt((X - 160).^2 + (Y - 110).^2) < 20;
    imgD(:, :, 1) = min(1, imgD(:, :, 1) + m * 0.35);
    imgD(:, :, 2) = min(1, imgD(:, :, 2) + m * 0.30);
    imgD(:, :, 3) = min(1, imgD(:, :, 3) + m * 0.15);
    img = imgD;
end

function img = createBorderPhantom()
    % Dark crescent along the left edge (vignetting mimic).
    imgD = createFundus();
    [X, Y] = meshgrid(1:224, 1:224);
    m = X < 14 & Y > 40 & Y < 184;
    imgD(:, :, 1) = imgD(:, :, 1) - m * 0.30;
    imgD(:, :, 2) = imgD(:, :, 2) - m * 0.25;
    img = max(0, imgD);
end
