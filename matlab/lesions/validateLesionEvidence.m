function validation = validateLesionEvidence(varargin)
% validateLesionEvidence  Test suite for lesion evidence extraction
%
%   validation = validateLesionEvidence()
%   validation = validateLesionEvidence('Verbose', true)

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    verbose = p.Results.Verbose;

    validation = struct();
    validation.tests = {};
    validation.passed = 0;
    validation.failed = 0;
    validation.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    fprintf('=== LESION EVIDENCE VALIDATION ===\n');
    fprintf('Date: %s\n\n', validation.timestamp);

    % Test 1: Functions exist
    test1 = runTest('Functions exist', @testFunctionsExist, verbose);
    validation.tests{end+1} = test1;

    % Test 2: Microaneurysm detection
    test2 = runTest('Microaneurysm detection', @testMicroaneurysm, verbose);
    validation.tests{end+1} = test2;

    % Test 3: Hemorrhage detection
    test3 = runTest('Hemorrhage detection', @testHemorrhage, verbose);
    validation.tests{end+1} = test3;

    % Test 4: Exudate detection
    test4 = runTest('Exudate detection', @testExudate, verbose);
    validation.tests{end+1} = test4;

    % Test 5: Neovascularization detection
    test5 = runTest('Neovascularization detection', @testNeovascularization, verbose);
    validation.tests{end+1} = test5;

    % Test 6: Evidence aggregation
    test6 = runTest('Evidence aggregation', @testAggregation, verbose);
    validation.tests{end+1} = test6;

    % Test 7: Empty image handling
    test7 = runTest('Empty image handling', @testEmptyImage, verbose);
    validation.tests{end+1} = test7;

    % Test 8: Deterministic output
    test8 = runTest('Deterministic output', @testDeterministic, verbose);
    validation.tests{end+1} = test8;

    % Test 9: Mask dimensions
    test9 = runTest('Mask dimensions', @testMaskDimensions, verbose);
    validation.tests{end+1} = test9;

    % Test 10: End-to-end pipeline
    test10 = runTest('End-to-end pipeline', @testEndToEnd, verbose);
    validation.tests{end+1} = test10;

    % Summary
    validation.passed = sum(cellfun(@(t) t.passed, validation.tests));
    validation.failed = sum(cellfun(@(t) ~t.passed, validation.tests));

    fprintf('\n=== VALIDATION SUMMARY ===\n');
    fprintf('Passed: %d/%d\n', validation.passed, numel(validation.tests));
    fprintf('Failed: %d/%d\n', validation.failed, numel(validation.tests));

    if validation.failed == 0
        fprintf('ALL TESTS PASSED\n');
    else
        fprintf('SOME TESTS FAILED\n');
        for i = 1:numel(validation.tests)
            if ~validation.tests{i}.passed
                fprintf('  FAILED: %s\n', validation.tests{i}.name);
                fprintf('    Reason: %s\n', validation.tests{i}.error);
            end
        end
    end
end

function result = runTest(name, testFunc, verbose)
    result = struct();
    result.name = name;
    result.passed = false;
    result.error = '';

    if verbose
        fprintf('TEST: %s... ', name);
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

function testFunctionsExist()
    assert(exist('detectMicroaneurysms', 'file') > 0, 'detectMicroaneurysms.m not found');
    assert(exist('detectHemorrhages', 'file') > 0, 'detectHemorrhages.m not found');
    assert(exist('detectExudates', 'file') > 0, 'detectExudates.m not found');
    assert(exist('detectNeovascularization', 'file') > 0, 'detectNeovascularization.m not found');
    assert(exist('extractLesionEvidence', 'file') > 0, 'extractLesionEvidence.m not found');
end

function testMicroaneurysm()
    cfgTL = transferLearningConfig();
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});

    evidence = detectMicroaneurysms(img);
    assert(isfield(evidence, 'count'), 'Missing count field');
    assert(isfield(evidence, 'mask'), 'Missing mask field');
    assert(isfield(evidence, 'locations'), 'Missing locations field');
    assert(isfield(evidence, 'areas'), 'Missing areas field');
    assert(isfield(evidence, 'confidence'), 'Missing confidence field');
    assert(evidence.count >= 0, 'Count should be non-negative');
    assert(evidence.confidence >= 0 && evidence.confidence <= 1, 'Confidence should be in [0,1]');
end

function testHemorrhage()
    cfgTL = transferLearningConfig();
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});

    evidence = detectHemorrhages(img);
    assert(isfield(evidence, 'count'), 'Missing count field');
    assert(isfield(evidence, 'mask'), 'Missing mask field');
    assert(isfield(evidence, 'totalArea'), 'Missing totalArea field');
    assert(evidence.count >= 0, 'Count should be non-negative');
end

function testExudate()
    cfgTL = transferLearningConfig();
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});

    evidence = detectExudates(img);
    assert(isfield(evidence, 'count'), 'Missing count field');
    assert(isfield(evidence, 'mask'), 'Missing mask field');
    assert(isfield(evidence, 'totalArea'), 'Missing totalArea field');
    assert(evidence.count >= 0, 'Count should be non-negative');
end

function testNeovascularization()
    cfgTL = transferLearningConfig();
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});

    evidence = detectNeovascularization(img);
    assert(isfield(evidence, 'detected'), 'Missing detected field');
    assert(isfield(evidence, 'mask'), 'Missing mask field');
    assert(isfield(evidence, 'density'), 'Missing density field');
    assert(isfield(evidence, 'confidence'), 'Missing confidence field');
    assert(islogical(evidence.detected) || isnumeric(evidence.detected), 'detected should be logical or numeric');
end

function testAggregation()
    cfgTL = transferLearningConfig();
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});

    evidence = extractLesionEvidence(img);
    assert(isfield(evidence, 'microaneurysms'), 'Missing microaneurysms field');
    assert(isfield(evidence, 'hemorrhages'), 'Missing hemorrhages field');
    assert(isfield(evidence, 'exudates'), 'Missing exudates field');
    assert(isfield(evidence, 'neovascularization'), 'Missing neovascularization field');
    assert(isfield(evidence, 'totalLesions'), 'Missing totalLesions field');
    assert(isfield(evidence, 'severity'), 'Missing severity field');
    assert(isfield(evidence, 'summary'), 'Missing summary field');
end

function testEmptyImage()
    % Test with a solid black image
    blackImg = zeros(512, 512, 3, 'uint8');
    evidence = extractLesionEvidence(blackImg);
    assert(evidence.totalLesions == 0, 'Black image should have no lesions');
    assert(strcmp(evidence.severity, 'none'), 'Black image should be none severity');
end

function testDeterministic()
    cfgTL = transferLearningConfig();
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});

    evidence1 = extractLesionEvidence(img);
    evidence2 = extractLesionEvidence(img);
    assert(evidence1.totalLesions == evidence2.totalLesions, 'Should be deterministic');
end

function testMaskDimensions()
    cfgTL = transferLearningConfig();
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});

    evidence = extractLesionEvidence(img);
    [rows, cols, ~] = size(img);
    assert(size(evidence.microaneurysms.mask, 1) == rows, 'MA mask height mismatch');
    assert(size(evidence.microaneurysms.mask, 2) == cols, 'MA mask width mismatch');
    assert(size(evidence.hemorrhages.mask, 1) == rows, 'Hem mask height mismatch');
    assert(size(evidence.hemorrhages.mask, 2) == cols, 'Hem mask width mismatch');
end

function testEndToEnd()
    cfgTL = transferLearningConfig();
    T = readtable('data/splits/test.csv');

    % Test with multiple grades
    for g = [0, 2, 4]
        idx = find(T.dr_grade == g, 1);
        if ~isempty(idx)
            img = imread(T.file_path_absolute{idx});
            evidence = extractLesionEvidence(img);
            assert(~isempty(evidence.summary), 'Summary should not be empty');
        end
    end
end
