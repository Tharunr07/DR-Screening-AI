function generateReport(imageId, dataset, split, predResult, phase3Result, contributions, calibration, cfg)
% generateReport  Generate ophthalmologist-oriented research report
%
%   generateReport(imageId, dataset, split, predResult, phase3Result, contributions, calibration, cfg)
%
%   IMPORTANT: This is a decision-support research prototype.
%   The report must NOT state "diagnosed with DR".
%   Use wording: "Model prediction", "Research screening result", "Requires human review".

    if nargin < 8, cfg = explainabilityConfig(); end

    gradeLabels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};

    % Extract prediction info
    predGrade = safeNum(predResult, 'predicted_grade', -1);
    refPred = safeNum(predResult, 'referable_pred', 0);
    refProb = safeNum(predResult, 'referable_probability', 0);
    conf = safeNum(predResult, 'confidence_score', 0);

    if predGrade >= 0 && predGrade <= 4
        gradeStr = gradeLabels{predGrade + 1};
    else
        gradeStr = 'Unknown';
    end

    % Quality
    qualStatus = safeStr(phase3Result, 'quality_status', 'UNKNOWN');
    qualScore = safeNum(phase3Result, 'quality_score', NaN);

    % Structures
    odDetected = safeLog(phase3Result, 'optic_disc_detected', false);
    odConf = safeNum(phase3Result, 'optic_disc_confidence', NaN);
    foveaDetected = safeLog(phase3Result, 'fovea_detected', false);
    foveaConf = safeNum(phase3Result, 'fovea_confidence', NaN);
    vesselDensity = safeNum(phase3Result, 'vessel_density', NaN);
    vesselStatus = safeStr(phase3Result, 'vessel_segmentation_status', 'UNKNOWN');

    % Lesions
    maCount = safeNum(phase3Result, 'ma_candidate_count', 0);
    maArea = safeNum(phase3Result, 'ma_candidate_area', NaN);
    maConf = safeNum(phase3Result, 'ma_confidence', NaN);
    heCount = safeNum(phase3Result, 'he_candidate_count', 0);
    heArea = safeNum(phase3Result, 'he_candidate_area', NaN);
    heConf = safeNum(phase3Result, 'he_confidence', NaN);
    exCount = safeNum(phase3Result, 'ex_candidate_count', 0);
    exArea = safeNum(phase3Result, 'ex_candidate_area', NaN);
    exConf = safeNum(phase3Result, 'ex_confidence', NaN);
    nvPresent = safeLog(phase3Result, 'nv_candidate', false);
    nvScore = safeNum(phase3Result, 'nv_score', NaN);

    % Build report
    report = {};
    report{end+1} = '=== DR Screening Research Report ===';
    report{end+1} = '';
    report{end+1} = 'STATUS: RESEARCH PROTOTYPE — NOT clinically validated';
    report{end+1} = 'All thresholds PROVISIONAL/THEORETICAL.';
    report{end+1} = '';
    report{end+1} = '--- IMAGE ---';
    report{end+1} = sprintf('Image ID: %s', imageId);
    report{end+1} = sprintf('Dataset: %s', dataset);
    report{end+1} = sprintf('Split: %s', split);
    report{end+1} = sprintf('Quality Status: %s', qualStatus);
    if ~isnan(qualScore)
        report{end+1} = sprintf('Quality Score: %.1f', qualScore);
    end
    report{end+1} = '';
    report{end+1} = '--- MODEL PREDICTION ---';
    report{end+1} = sprintf('Predicted DR Level: %d (%s)', predGrade, gradeStr);
    report{end+1} = sprintf('Referable: %s', iif(refPred == 1, 'Yes', 'No'));
    report{end+1} = sprintf('Referable Probability: %.4f', refProb);
    report{end+1} = sprintf('Confidence: %.1f%%', conf * 100);
    report{end+1} = '';
    report{end+1} = '--- STRUCTURAL EVIDENCE ---';
    report{end+1} = sprintf('Optic Disc: %s (confidence: %.2f)', iif(odDetected, 'Detected', 'Not detected'), odConf);
    report{end+1} = sprintf('Fovea: %s (confidence: %.2f)', iif(foveaDetected, 'Detected', 'Not detected'), foveaConf);
    report{end+1} = sprintf('Vessel Density: %.4f (status: %s)', vesselDensity, vesselStatus);
    report{end+1} = '';
    report{end+1} = '--- LESION EVIDENCE ---';
    report{end+1} = sprintf('Microaneurysms: %d candidates (area: %s px, confidence: %s)', ...
        maCount, formatVal(maArea), formatVal(maConf));
    report{end+1} = sprintf('Hemorrhages: %d candidates (area: %s px, confidence: %s)', ...
        heCount, formatVal(heArea), formatVal(heConf));
    report{end+1} = sprintf('Exudates: %d candidates (area: %s px, confidence: %s)', ...
        exCount, formatVal(exArea), formatVal(exConf));
    report{end+1} = sprintf('Neovascularization: %s (score: %s)', ...
        iif(nvPresent, 'Candidate', 'Not detected'), formatVal(nvScore));
    report{end+1} = '';
    report{end+1} = '--- FEATURE CONTRIBUTIONS (Top 5) ---';
    if ~isempty(contributions) && isfield(contributions, 'name')
        topN = min(5, numel(contributions.name));
        for k = 1:topN
            report{end+1} = sprintf('%d. %s: %+.4f (%s)', ...
                k, contributions.name{k}, contributions.contribution(k), contributions.direction{k});
        end
    else
        report{end+1} = 'No feature contributions available.';
    end
    report{end+1} = '';
    report{end+1} = '--- CALIBRATION ---';
    if ~isempty(calibration)
        report{end+1} = sprintf('Brier Score: %.4f', calibration.brier_score);
        report{end+1} = sprintf('ECE: %.4f', calibration.ece);
        report{end+1} = sprintf('Discrimination AUC: %.4f', calibration.auc);
        report{end+1} = 'Note: Discrimination (AUC) and calibration (Brier/ECE) are different properties.';
    end
    report{end+1} = '';
    report{end+1} = '--- REVIEW ---';
    report{end+1} = 'Requires human review: YES';
    report{end+1} = 'Review status: PENDING';
    report{end+1} = 'Reviewer decision: (empty — awaiting clinician)';
    report{end+1} = 'Reviewer notes: (empty — awaiting clinician)';
    report{end+1} = '';
    report{end+1} = '--- DISCLAIMER ---';
    report{end+1} = 'This is a research screening result from a prototype system.';
    report{end+1} = 'It is NOT a clinical diagnosis.';
    report{end+1} = 'All decisions must be made by a qualified ophthalmologist.';
    report{end+1} = sprintf('Report generated: %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));

    % Save report
    outPath = fullfile(cfg.paths.reportDir, sprintf('%s.md', imageId));
    fid = fopen(outPath, 'w');
    for k = 1:numel(report)
        fprintf(fid, '%s\n', report{k});
    end
    fclose(fid);
end

function s = iif(cond, trueStr, falseStr)
    if cond, s = trueStr; else, s = falseStr; end
end

function s = formatVal(v)
    if isnan(v)
        s = 'N/A';
    else
        s = sprintf('%.2f', v);
    end
end

function v = safeNum(s, field, default)
    if isstruct(s) && isfield(s, field) && ~isempty(s.(field))
        val = s.(field);
        if ismissing(val) || (isnumeric(val) && isnan(val))
            v = default;
        else
            v = double(val);
        end
    else
        v = default;
    end
end

function v = safeLog(s, field, default)
    if isstruct(s) && isfield(s, field) && ~isempty(s.(field))
        val = s.(field);
        if ismissing(val)
            v = default;
        else
            v = logical(val);
        end
    else
        v = default;
    end
end

function v = safeStr(s, field, default)
    if isstruct(s) && isfield(s, field) && ~isempty(s.(field))
        val = s.(field);
        if ismissing(val)
            v = string(default);
        else
            v = string(val);
        end
    else
        v = string(default);
    end
end
