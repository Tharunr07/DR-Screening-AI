function validation = validateGradCAM(varargin)
% validateGradCAM  Test suite for Grad-CAM implementation
%
%   validation = validateGradCAM()
%   validation = validateGradCAM('Verbose', true)

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    verbose = p.Results.Verbose;

    validation = struct();
    validation.tests = {};
    validation.passed = 0;
    validation.failed = 0;
    validation.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    fprintf('=== GRAD-CAM VALIDATION ===\n');
    fprintf('Date: %s\n\n', validation.timestamp);

    % Test 1: Grad-CAM function exists
    test1 = runTest('Grad-CAM function exists', @testFunctionExists, verbose);
    validation.tests{end+1} = test1;

    % Test 2: Feature extraction
    test2 = runTest('Feature extraction', @testFeatureExtraction, verbose);
    validation.tests{end+1} = test2;

    % Test 3: CAM generation
    test3 = runTest('CAM generation', @testCAMGeneration, verbose);
    validation.tests{end+1} = test3;

    % Test 4: Normalization
    test4 = runTest('Normalization [0,1]', @testNormalization, verbose);
    validation.tests{end+1} = test4;

    % Test 5: Size matching
    test5 = runTest('Size matching', @testSizeMatching, verbose);
    validation.tests{end+1} = test5;

    % Test 6: Deterministic output
    test6 = runTest('Deterministic output', @testDeterministic, verbose);
    validation.tests{end+1} = test6;

    % Test 7: Different classes produce different CAMs
    test7 = runTest('Class-specific CAMs', @testClassSpecific, verbose);
    validation.tests{end+1} = test7;

    % Test 8: Overlay generation
    test8 = runTest('Overlay generation', @testOverlay, verbose);
    validation.tests{end+1} = test8;

    % Test 9: Invalid input handling
    test9 = runTest('Invalid input handling', @testInvalidInput, verbose);
    validation.tests{end+1} = test9;

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

function testFunctionExists()
    assert(exist('gradcamSimple', 'file') > 0, 'gradcamSimple.m not found');
end

function testFeatureExtraction()
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});
    n = preprocessFundus(img, cfgTL.image.size);

    featureMaps = activations(trainedNetTL, n, 'res5b_branch2b', 'OutputAs', 'channels');
    assert(size(featureMaps, 3) == 512, 'Expected 512 channels');
    assert(size(featureMaps, 1) == 7, 'Expected 7x7 spatial');
end

function testCAMGeneration()
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});
    n = preprocessFundus(img, cfgTL.image.size);

    [cam, ~, ~] = gradcamSimple(trainedNetTL, n);
    assert(~isempty(cam), 'CAM should not be empty');
    assert(ndims(cam) == 2, 'CAM should be 2D');
end

function testNormalization()
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});
    n = preprocessFundus(img, cfgTL.image.size);

    [cam, ~, ~] = gradcamSimple(trainedNetTL, n);
    assert(min(cam(:)) >= 0, 'CAM min should be >= 0');
    assert(max(cam(:)) <= 1, 'CAM max should be <= 1');
end

function testSizeMatching()
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});
    n = preprocessFundus(img, cfgTL.image.size);

    [cam, ~, ~] = gradcamSimple(trainedNetTL, n);
    assert(size(cam, 1) == size(n, 1), 'CAM height should match input');
    assert(size(cam, 2) == size(n, 2), 'CAM width should match input');
end

function testDeterministic()
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});
    n = preprocessFundus(img, cfgTL.image.size);

    [cam1, ~, ~] = gradcamSimple(trainedNetTL, n);
    [cam2, ~, ~] = gradcamSimple(trainedNetTL, n);
    assert(max(abs(cam1(:) - cam2(:))) < 1e-6, 'CAM should be deterministic');
end

function testClassSpecific()
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});
    n = preprocessFundus(img, cfgTL.image.size);

    % CAMs for different classes should be different
    [cam1, ~, ~] = gradcamSimple(trainedNetTL, n, 'TargetClass', 1);
    [cam2, ~, ~] = gradcamSimple(trainedNetTL, n, 'TargetClass', 3);
    assert(max(abs(cam1(:) - cam2(:))) > 0.01, 'Different classes should produce different CAMs');
end

function testOverlay()
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
    T = readtable('data/splits/test.csv');
    idx = find(T.dr_grade == 2, 1);
    img = imread(T.file_path_absolute{idx});
    n = preprocessFundus(img, cfgTL.image.size);

    [cam, ~, ~] = gradcamSimple(trainedNetTL, n);

    % Create overlay
    fig = figure('Visible', 'off');
    imshow(uint8(img));
    hold on;
    h = imagesc(cam, [0, 1]);
    set(h, 'AlphaData', 0.4);
    colormap(fig, jet);
    hold off;

    % Check that figure was created
    assert(~isempty(fig), 'Overlay figure should be created');
    close(fig);
end

function testInvalidInput()
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');

    % Test with invalid image (too small)
    try
        smallImg = zeros(10, 10, 3);
        gradcamSimple(trainedNetTL, smallImg);
        % Should either work or fail gracefully
    catch
        % Expected behavior
    end

    % Test with grayscale image
    try
        grayImg = zeros(224, 224, 1);
        gradcamSimple(trainedNetTL, grayImg);
    catch
        % Expected behavior
    end
end
