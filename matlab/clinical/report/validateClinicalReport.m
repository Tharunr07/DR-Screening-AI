function results = validateClinicalReport(varargin)
% validateClinicalReport  Validate Phase 16 clinical report generation
%
%   results = validateClinicalReport()
%   results = validateClinicalReport('Verbose', true)

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    verbose = p.Results.Verbose;
    passed = 0;
    total = 15;
    results = struct();

    if verbose
        fprintf('=== PHASE 16 VALIDATION ===\n');
        fprintf('Date: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    end

    % Load config and model
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');

    % Get test images
    T = readtable('data/splits/test.csv');

    % Helper function to get quality image
    function imgPath = getGoodImage()
        imgPath = '';
        for i = 1:height(T)
            testPath = T.file_path_absolute{i};
            if exist(testPath, 'file')
                img = imread(testPath);
                gray = rgb2gray(img);
                brightness = mean(gray(:));
                contrast = std(double(gray(:)));
                if brightness >= 60 && brightness <= 200 && contrast >= 30
                    imgPath = testPath;
                    break;
                end
            end
        end
    end

    % Helper function to create test report
    function report = createTestReport(gradeNum, qualityStatus, consistency)
        scores = zeros(1, 5);
        scores(gradeNum + 1) = 0.7;
        scores(mod(gradeNum + 1, 5) + 1) = 0.1;
        scores(mod(gradeNum + 2, 5) + 1) = 0.1;
        scores(mod(gradeNum + 3, 5) + 1) = 0.05;
        scores(mod(gradeNum + 4, 5) + 1) = 0.05;

        imageInfo = struct('path', 'test_image.png', 'timestamp', datestr(now));
        quality = struct('status', qualityStatus, 'score', 0.8, 'brightness', 120, 'contrast', 45);
        classification = struct('gradeNum', gradeNum, 'gradeName', getGradeName(gradeNum), ...
            'scores', scores, 'referable', gradeNum >= 2, 'probability', 0.7);

        evidence = struct('microaneurysms', struct('count', 3), ...
            'hemorrhages', struct('count', 1), ...
            'exudates', struct('count', 2), ...
            'neovascularization', struct('detected', false), ...
            'severity', 'mild', 'totalLesions', 6);

        % Deterministic synthetic attention map (test fixture only;
        % never displayed as an explanation). No random data allowed
        % anywhere in the Grad-CAM path (Phase 20B.3).
        gradcam = struct('cam', mat2gray(peaks(224)));

        % Set clinical decision based on quality status and consistency
        if strcmp(qualityStatus, 'POOR')
            clinicalDecision = struct('status', 'UNGRADABLE', ...
                'referableDecision', 'RECAPTURE', ...
                'confidenceLevel', 'NONE', ...
                'consistency', 'N/A', ...
                'consistencyWarning', '', ...
                'recommendation', 'Recapture image');
        else
            % Generate consistency warning based on consistency level
            if strcmp(consistency, 'MAJOR_INCONSISTENCY')
                consistencyWarning = 'Grade 0 but 3 microaneurysms detected';
            elseif strcmp(consistency, 'MINOR_INCONSISTENCY')
                consistencyWarning = 'Minor inconsistency detected';
            else
                consistencyWarning = '';
            end

            clinicalDecision = struct('status', 'GRADED', ...
                'referableDecision', getReferableDecision(gradeNum), ...
                'confidenceLevel', 'HIGH', ...
                'consistency', consistency, ...
                'consistencyWarning', consistencyWarning, ...
                'recommendation', 'Refer to ophthalmologist');
        end

        report = generateClinicalReport(imageInfo, quality, classification, ...
            evidence, gradcam, clinicalDecision);
    end

    function name = getGradeName(num)
        grades = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
        name = grades{num + 1};
    end

    function decision = getReferableDecision(num)
        if num >= 2
            decision = 'REFERABLE';
        else
            decision = 'NON-REFERABLE';
        end
    end

    % TEST 1: G0 report
    try
        report = createTestReport(0, 'GOOD', 'CONSISTENT');
        assert(report.classification.gradeNum == 0);
        assert(strcmp(report.classification.gradeName, 'No DR'));
        assert(~report.classification.referable);
        results.g0Report = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: G0 report... PASS\n'); end
    catch ME
        results.g0Report = 'FAIL';
        if verbose; fprintf('TEST: G0 report... FAIL (%s)\n', ME.message); end
    end

    % TEST 2: G1 report
    try
        report = createTestReport(1, 'GOOD', 'CONSISTENT');
        assert(report.classification.gradeNum == 1);
        assert(strcmp(report.classification.gradeName, 'Mild NPDR'));
        assert(~report.classification.referable);
        results.g1Report = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: G1 report... PASS\n'); end
    catch ME
        results.g1Report = 'FAIL';
        if verbose; fprintf('TEST: G1 report... FAIL (%s)\n', ME.message); end
    end

    % TEST 3: G2 report
    try
        report = createTestReport(2, 'GOOD', 'CONSISTENT');
        assert(report.classification.gradeNum == 2);
        assert(strcmp(report.classification.gradeName, 'Moderate NPDR'));
        assert(report.classification.referable);
        results.g2Report = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: G2 report... PASS\n'); end
    catch ME
        results.g2Report = 'FAIL';
        if verbose; fprintf('TEST: G2 report... FAIL (%s)\n', ME.message); end
    end

    % TEST 4: G3 report
    try
        report = createTestReport(3, 'GOOD', 'CONSISTENT');
        assert(report.classification.gradeNum == 3);
        assert(strcmp(report.classification.gradeName, 'Severe NPDR'));
        assert(report.classification.referable);
        results.g3Report = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: G3 report... PASS\n'); end
    catch ME
        results.g3Report = 'FAIL';
        if verbose; fprintf('TEST: G3 report... FAIL (%s)\n', ME.message); end
    end

    % TEST 5: G4 report
    try
        report = createTestReport(4, 'GOOD', 'CONSISTENT');
        assert(report.classification.gradeNum == 4);
        assert(strcmp(report.classification.gradeName, 'Proliferative DR'));
        assert(report.classification.referable);
        results.g4Report = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: G4 report... PASS\n'); end
    catch ME
        results.g4Report = 'FAIL';
        if verbose; fprintf('TEST: G4 report... FAIL (%s)\n', ME.message); end
    end

    % TEST 6: Poor-quality report
    try
        report = createTestReport(0, 'POOR', 'N/A');
        assert(strcmp(report.quality.status, 'POOR'));
        assert(strcmp(report.clinicalDecision.status, 'UNGRADABLE'));
        assert(contains(report.text, 'RECAPTURE'));
        assert(contains(report.text, 'POOR'));
        results.poorQualityReport = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Poor-quality report... PASS\n'); end
    catch ME
        results.poorQualityReport = 'FAIL';
        if verbose; fprintf('TEST: Poor-quality report... FAIL (%s)\n', ME.message); end
    end

    % TEST 7: Borderline-quality report
    try
        report = createTestReport(2, 'BORDERLINE', 'CONSISTENT');
        assert(strcmp(report.quality.status, 'BORDERLINE'));
        assert(contains(report.text, 'BORDERLINE'));
        results.borderlineQualityReport = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Borderline-quality report... PASS\n'); end
    catch ME
        results.borderlineQualityReport = 'FAIL';
        if verbose; fprintf('TEST: Borderline-quality report... FAIL (%s)\n', ME.message); end
    end

    % TEST 8: Referable case
    try
        report = createTestReport(3, 'GOOD', 'CONSISTENT');
        assert(report.classification.referable);
        assert(strcmp(report.clinicalDecision.referableDecision, 'REFERABLE'));
        assert(contains(report.text, 'REFERABLE'));
        results.referableCase = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Referable case... PASS\n'); end
    catch ME
        results.referableCase = 'FAIL';
        if verbose; fprintf('TEST: Referable case... FAIL (%s)\n', ME.message); end
    end

    % TEST 9: Non-referable case
    try
        report = createTestReport(0, 'GOOD', 'CONSISTENT');
        assert(~report.classification.referable);
        assert(strcmp(report.clinicalDecision.referableDecision, 'NON-REFERABLE'));
        assert(contains(report.text, 'NON-REFERABLE'));
        results.nonReferableCase = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Non-referable case... PASS\n'); end
    catch ME
        results.nonReferableCase = 'FAIL';
        if verbose; fprintf('TEST: Non-referable case... FAIL (%s)\n', ME.message); end
    end

    % TEST 10: Major inconsistency
    try
        report = createTestReport(0, 'GOOD', 'MAJOR_INCONSISTENCY');
        assert(strcmp(report.clinicalDecision.consistency, 'MAJOR_INCONSISTENCY'));
        assert(~isempty(report.clinicalDecision.consistencyWarning));
        assert(contains(report.text, 'INCONSISTENCY'));
        results.majorInconsistency = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Major inconsistency... PASS\n'); end
    catch ME
        results.majorInconsistency = 'FAIL';
        if verbose; fprintf('TEST: Major inconsistency... FAIL (%s)\n', ME.message); end
    end

    % TEST 11: Missing lesion evidence
    try
        imageInfo = struct('path', 'test.png', 'timestamp', datestr(now));
        quality = struct('status', 'GOOD', 'score', 0.8, 'brightness', 120, 'contrast', 45);
        classification = struct('gradeNum', 1, 'gradeName', 'Mild NPDR', ...
            'scores', [0.1 0.7 0.1 0.05 0.05], 'referable', false, 'probability', 0.7);
        evidence = [];
        gradcam = [];
        clinicalDecision = struct('status', 'GRADED', 'referableDecision', 'NON-REFERABLE', ...
            'confidenceLevel', 'HIGH', 'consistency', 'CONSISTENT', ...
            'consistencyWarning', '', 'recommendation', 'Follow-up');

        report = generateClinicalReport(imageInfo, quality, classification, ...
            evidence, gradcam, clinicalDecision);
        assert(report.evidence.microaneurysms == 0);
        assert(report.evidence.hemorrhages == 0);
        results.missingEvidence = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Missing lesion evidence... PASS\n'); end
    catch ME
        results.missingEvidence = 'FAIL';
        if verbose; fprintf('TEST: Missing lesion evidence... FAIL (%s)\n', ME.message); end
    end

    % TEST 12: Missing Grad-CAM
    try
        imageInfo = struct('path', 'test.png', 'timestamp', datestr(now));
        quality = struct('status', 'GOOD', 'score', 0.8, 'brightness', 120, 'contrast', 45);
        classification = struct('gradeNum', 2, 'gradeName', 'Moderate NPDR', ...
            'scores', [0.1 0.1 0.7 0.05 0.05], 'referable', true, 'probability', 0.7);
        evidence = struct('microaneurysms', struct('count', 3), ...
            'hemorrhages', struct('count', 1), ...
            'exudates', struct('count', 2), ...
            'neovascularization', struct('detected', false), ...
            'severity', 'mild', 'totalLesions', 6);
        gradcam = [];  % No Grad-CAM
        clinicalDecision = struct('status', 'GRADED', 'referableDecision', 'REFERABLE', ...
            'confidenceLevel', 'HIGH', 'consistency', 'CONSISTENT', ...
            'consistencyWarning', '', 'recommendation', 'Refer');

        report = generateClinicalReport(imageInfo, quality, classification, ...
            evidence, gradcam, clinicalDecision);
        assert(~report.explainability.gradcamAvailable);
        assert(contains(report.text, 'Not available'));
        results.missingGradcam = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Missing Grad-CAM... PASS\n'); end
    catch ME
        results.missingGradcam = 'FAIL';
        if verbose; fprintf('TEST: Missing Grad-CAM... FAIL (%s)\n', ME.message); end
    end

    % TEST 13: Disclaimer present
    try
        report = createTestReport(2, 'GOOD', 'CONSISTENT');
        assert(~isempty(report.disclaimer));
        assert(contains(report.text, 'DISCLAIMER'));
        assert(contains(report.text, 'research prototype'));
        results.disclaimerPresent = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Disclaimer present... PASS\n'); end
    catch ME
        results.disclaimerPresent = 'FAIL';
        if verbose; fprintf('TEST: Disclaimer present... FAIL (%s)\n', ME.message); end
    end

    % TEST 14: Exportable report
    try
        report = createTestReport(2, 'GOOD', 'CONSISTENT');
        tmpFile = fullfile(tempdir, 'test_report.txt');
        exportClinicalReport(report, tmpFile);
        assert(exist(tmpFile, 'file') > 0);
        fid = fopen(tmpFile, 'r');
        content = fread(fid, '*char')';
        fclose(fid);
        assert(contains(content, 'SCREENING RESULT'));
        assert(contains(content, 'DISCLAIMER'));
        delete(tmpFile);
        results.exportableReport = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Exportable report... PASS\n'); end
    catch ME
        results.exportableReport = 'FAIL';
        if verbose; fprintf('TEST: Exportable report... FAIL (%s)\n', ME.message); end
    end

    % TEST 15: Required fields
    try
        report = createTestReport(2, 'GOOD', 'CONSISTENT');
        assert(isfield(report, 'imageInfo'));
        assert(isfield(report, 'quality'));
        assert(isfield(report, 'classification'));
        assert(isfield(report, 'evidence'));
        assert(isfield(report, 'explainability'));
        assert(isfield(report, 'clinicalDecision'));
        assert(isfield(report, 'text'));
        assert(isfield(report, 'warnings'));
        assert(isfield(report, 'disclaimer'));
        assert(isfield(report, 'display'));
        results.requiredFields = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Required fields... PASS\n'); end
    catch ME
        results.requiredFields = 'FAIL';
        if verbose; fprintf('TEST: Required fields... FAIL (%s)\n', ME.message); end
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
