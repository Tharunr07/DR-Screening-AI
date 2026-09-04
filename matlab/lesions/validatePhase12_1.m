function results = validatePhase12_1(varargin)
% validatePhase12_1  Validate Phase 12.1 lesion detection refinement
%
%   results = validatePhase12_1()
%   results = validatePhase12_1('Verbose', true)

    p = inputParser;
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    verbose = p.Results.Verbose;
    passed = 0;
    total = 12;
    results = struct();

    if verbose
        fprintf('=== PHASE 12.1 VALIDATION ===\n');
        fprintf('Date: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    end

    % Load test image
    T = readtable('data/splits/test.csv');
    imgPath = T.file_path_absolute{1};
    img = imread(imgPath);

    % TEST 1: Functions exist
    try
        assert(exist('detectMicroaneurysms', 'file') > 0);
        assert(exist('detectHemorrhages', 'file') > 0);
        assert(exist('detectExudates', 'file') > 0);
        assert(exist('detectNeovascularization', 'file') > 0);
        assert(exist('extractLesionEvidence', 'file') > 0);
        results.functionsExist = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Functions exist... PASS\n'); end
    catch
        results.functionsExist = 'FAIL';
        if verbose; fprintf('TEST: Functions exist... FAIL\n'); end
    end

    % TEST 2: Microaneurysm detection with vessel exclusion
    try
        ma = detectMicroaneurysms(img);
        assert(isfield(ma, 'count'));
        assert(isfield(ma, 'mask'));
        assert(isfield(ma, 'confidence'));
        assert(ma.count >= 0);
        assert(ma.confidence >= 0 && ma.confidence <= 1);
        results.maDetection = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Microaneurysm detection... PASS (count=%d)\n', ma.count); end
    catch ME
        results.maDetection = 'FAIL';
        if verbose; fprintf('TEST: Microaneurysm detection... FAIL (%s)\n', ME.message); end
    end

    % TEST 3: Exudate detection with multi-criteria
    try
        exu = detectExudates(img);
        assert(isfield(exu, 'count'));
        assert(isfield(exu, 'mask'));
        assert(isfield(exu, 'confidence'));
        assert(exu.count >= 0);
        assert(exu.confidence >= 0 && exu.confidence <= 1);
        results.exuDetection = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Exudate detection... PASS (count=%d)\n', exu.count); end
    catch ME
        results.exuDetection = 'FAIL';
        if verbose; fprintf('TEST: Exudate detection... FAIL (%s)\n', ME.message); end
    end

    % TEST 4: Neovascularization with disc exclusion
    try
        nv = detectNeovascularization(img);
        assert(isfield(nv, 'detected'));
        assert(isfield(nv, 'mask'));
        assert(isfield(nv, 'confidence'));
        assert(islogical(nv.detected));
        assert(nv.confidence >= 0 && nv.confidence <= 1);
        results.nvDetection = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Neovascularization detection... PASS (detected=%d)\n', nv.detected); end
    catch ME
        results.nvDetection = 'FAIL';
        if verbose; fprintf('TEST: Neovascularization detection... FAIL (%s)\n', ME.message); end
    end

    % TEST 5: Evidence aggregation with confidence levels
    try
        evidence = extractLesionEvidence(img);
        assert(isfield(evidence, 'microaneurysms'));
        assert(isfield(evidence, 'hemorrhages'));
        assert(isfield(evidence, 'exudates'));
        assert(isfield(evidence, 'neovascularization'));
        assert(isfield(evidence, 'confidenceLevels'));
        assert(isfield(evidence.confidenceLevels, 'microaneurysms'));
        assert(isfield(evidence.confidenceLevels, 'hemorrhages'));
        assert(isfield(evidence.confidenceLevels, 'exudates'));
        assert(isfield(evidence.confidenceLevels, 'neovascularization'));
        results.evidenceAggregation = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Evidence aggregation with confidence... PASS\n'); end
    catch ME
        results.evidenceAggregation = 'FAIL';
        if verbose; fprintf('TEST: Evidence aggregation... FAIL (%s)\n', ME.message); end
    end

    % TEST 6: Confidence levels are valid
    try
        validLevels = {'HIGH', 'MEDIUM', 'LOW'};
        assert(ismember(evidence.confidenceLevels.microaneurysms, validLevels));
        assert(ismember(evidence.confidenceLevels.hemorrhages, validLevels));
        assert(ismember(evidence.confidenceLevels.exudates, validLevels));
        assert(ismember(evidence.confidenceLevels.neovascularization, validLevels));
        results.confidenceLevels = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Confidence levels valid... PASS\n'); end
    catch ME
        results.confidenceLevels = 'FAIL';
        if verbose; fprintf('TEST: Confidence levels valid... FAIL (%s)\n', ME.message); end
    end

    % TEST 7: Severity assessment
    try
        assert(isfield(evidence, 'severity'));
        validSeverity = {'none', 'mild', 'moderate', 'severe'};
        assert(ismember(evidence.severity, validSeverity));
        results.severityAssessment = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Severity assessment... PASS (%s)\n', evidence.severity); end
    catch ME
        results.severityAssessment = 'FAIL';
        if verbose; fprintf('TEST: Severity assessment... FAIL (%s)\n', ME.message); end
    end

    % TEST 8: Summary generation
    try
        assert(isfield(evidence, 'summary'));
        assert(~isempty(evidence.summary));
        assert(contains(evidence.summary, 'confidence'));
        results.summaryGeneration = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Summary generation... PASS\n'); end
    catch ME
        results.summaryGeneration = 'FAIL';
        if verbose; fprintf('TEST: Summary generation... FAIL (%s)\n', ME.message); end
    end

    % TEST 9: Empty image handling
    try
        emptyImg = zeros(224, 224, 3, 'uint8');
        emptyEvidence = extractLesionEvidence(emptyImg);
        assert(emptyEvidence.totalLesions == 0);
        assert(strcmp(emptyEvidence.severity, 'none'));
        results.emptyImage = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Empty image handling... PASS\n'); end
    catch ME
        results.emptyImage = 'FAIL';
        if verbose; fprintf('TEST: Empty image handling... FAIL (%s)\n', ME.message); end
    end

    % TEST 10: Deterministic output
    try
        evidence1 = extractLesionEvidence(img);
        evidence2 = extractLesionEvidence(img);
        assert(evidence1.totalLesions == evidence2.totalLesions);
        assert(strcmp(evidence1.severity, evidence2.severity));
        results.deterministicOutput = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Deterministic output... PASS\n'); end
    catch ME
        results.deterministicOutput = 'FAIL';
        if verbose; fprintf('TEST: Deterministic output... FAIL (%s)\n', ME.message); end
    end

    % TEST 11: Mask dimensions match image
    try
        assert(size(evidence.microaneurysms.mask, 1) == size(img, 1));
        assert(size(evidence.microaneurysms.mask, 2) == size(img, 2));
        assert(size(evidence.exudates.mask, 1) == size(img, 1));
        assert(size(evidence.exudates.mask, 2) == size(img, 2));
        results.maskDimensions = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Mask dimensions match... PASS\n'); end
    catch ME
        results.maskDimensions = 'FAIL';
        if verbose; fprintf('TEST: Mask dimensions match... FAIL (%s)\n', ME.message); end
    end

    % TEST 12: Summary contains confidence keywords
    try
        summary = evidence.summary;
        hasKeywords = contains(summary, 'confidence') || ...
                     contains(summary, 'microaneurysm') || ...
                     contains(summary, 'hemorrhage') || ...
                     contains(summary, 'exudate') || ...
                     contains(summary, 'No lesion');
        assert(hasKeywords);
        results.summaryKeywords = 'PASS';
        passed = passed + 1;
        if verbose; fprintf('TEST: Summary keywords... PASS\n'); end
    catch ME
        results.summaryKeywords = 'FAIL';
        if verbose; fprintf('TEST: Summary keywords... FAIL (%s)\n', ME.message); end
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

        % Print detailed results
        fprintf('\n=== DETAILED RESULTS ===\n');
        fprintf('Microaneurysms: %d [%s confidence]\n', ...
            evidence.microaneurysms.count, evidence.confidenceLevels.microaneurysms);
        fprintf('Hemorrhages: %d [%s confidence]\n', ...
            evidence.hemorrhages.count, evidence.confidenceLevels.hemorrhages);
        fprintf('Exudates: %d [%s confidence]\n', ...
            evidence.exudates.count, evidence.confidenceLevels.exudates);
        fprintf('Neovascularization: %d [%s confidence]\n', ...
            evidence.neovascularization.detected, evidence.confidenceLevels.neovascularization);
        fprintf('Total lesions: %d\n', evidence.totalLesions);
        fprintf('Severity: %s\n', evidence.severity);
        fprintf('Summary: %s\n', evidence.summary);
    end

    results.passed = passed;
    results.total = total;
end
