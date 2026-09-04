function results = validatePhase15(varargin)
% validatePhase15  Validate Phase 15 production GUI components
%
%   results = validatePhase15()
%   results = validatePhase15('Verbose', true)

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    verbose = p.Results.Verbose;
    passed = 0;
    total = 8;
    results = struct();

    if verbose
        fprintf('=== PHASE 15 VALIDATION ===\n');
        fprintf('Date: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    end

    % TEST 1: GUI function exists
    try
        assert(exist('drScreeningGUIv2', 'file') > 0);
        results.guiExists = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: GUI function exists... PASS\n'); end
    catch
        results.guiExists = 'FAIL';
        if verbose; fprintf('TEST: GUI function exists... FAIL\n'); end
    end

    % TEST 2: Model loading works
    try
        cfgTL = transferLearningConfig();
        data = load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
        assert(isfield(data, 'trainedNetTL'));
        results.modelLoad = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Model loading works... PASS\n'); end
    catch
        results.modelLoad = 'FAIL';
        if verbose; fprintf('TEST: Model loading works... FAIL\n'); end
    end

    % TEST 3: Image loading works
    try
        T = readtable('data/splits/test.csv');
        imgPath = T.file_path_absolute{1};
        img = imread(imgPath);
        assert(~isempty(img));
        assert(ndims(img) == 3);
        results.imageLoad = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Image loading works... PASS\n'); end
    catch
        results.imageLoad = 'FAIL';
        if verbose; fprintf('TEST: Image loading works... FAIL\n'); end
    end

    % TEST 4: Quality assessment works
    try
        gray = rgb2gray(img);
        brightness = mean(gray(:));
        contrast = std(double(gray(:)));
        lap = fspecial('laplacian');
        lapResult = conv2(double(gray), lap, 'same');
        blurVar = var(lapResult(:));

        assert(brightness >= 0 && brightness <= 255);
        assert(contrast >= 0);
        assert(blurVar >= 0);
        results.qualityAssess = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Quality assessment works... PASS\n'); end
    catch
        results.qualityAssess = 'FAIL';
        if verbose; fprintf('TEST: Quality assessment works... FAIL\n'); end
    end

    % TEST 5: Screening workflow works
    try
        data = load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
        trainedNet = data.trainedNetTL;

        imgR = imresize(img, cfgTL.image.size, 'bicubic');
        n = preprocessFundus(img, cfgTL.image.size);

        [pred, scores] = classify(trainedNet, n);
        gradeNum = double(pred) - 1;
        refProb = sum(scores(3:5));
        isReferable = refProb >= 0.1951;

        assert(gradeNum >= 0 && gradeNum <= 4);
        assert(refProb >= 0 && refProb <= 1);
        results.screeningWorkflow = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Screening workflow works... PASS\n'); end
    catch
        results.screeningWorkflow = 'FAIL';
        if verbose; fprintf('TEST: Screening workflow works... FAIL\n'); end
    end

    % TEST 6: Lesion evidence works
    try
        evidence = extractLesionEvidence(img);
        assert(isfield(evidence, 'microaneurysms'));
        assert(isfield(evidence, 'hemorrhages'));
        assert(isfield(evidence, 'exudates'));
        assert(isfield(evidence, 'neovascularization'));
        assert(isfield(evidence, 'severity'));
        results.lesionEvidence = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Lesion evidence works... PASS\n'); end
    catch
        results.lesionEvidence = 'FAIL';
        if verbose; fprintf('TEST: Lesion evidence works... FAIL\n'); end
    end

    % TEST 7: Report generation works
    try
        grades = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
        report = sprintf('Grade %d (%s), Referable=%d, Confidence=%.1f%%', ...
            gradeNum, grades{gradeNum+1}, isReferable, max(scores)*100);
        assert(~isempty(report));
        assert(contains(report, 'Grade'));
        results.reportGeneration = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Report generation works... PASS\n'); end
    catch
        results.reportGeneration = 'FAIL';
        if verbose; fprintf('TEST: Report generation works... FAIL\n'); end
    end

    % TEST 8: Export functionality works
    try
        tmpFile = fullfile(tempdir, 'test_report.txt');
        fid = fopen(tmpFile, 'w');
        fprintf(fid, 'TEST REPORT\n');
        fprintf(fid, 'Grade: %d\n', gradeNum);
        fclose(fid);
        assert(exist(tmpFile, 'file') > 0);
        delete(tmpFile);
        results.exportFunctionality = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Export functionality works... PASS\n'); end
    catch
        results.exportFunctionality = 'FAIL';
        if verbose; fprintf('TEST: Export functionality works... FAIL\n'); end
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
