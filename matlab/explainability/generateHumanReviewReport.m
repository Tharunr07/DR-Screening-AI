function generateHumanReviewReport(imageId, dataset, split, predResult, phase3Result, contributions, calibration, cfg)
% generateHumanReviewReport  Generate machine-readable JSON review record
%
%   generateHumanReviewReport(imageId, dataset, split, predResult, phase3Result, contributions, calibration, cfg)
%
%   Creates structured JSON for human review workflow.
%   Reviewer fields are initially empty/null.

    if nargin < 8, cfg = explainabilityConfig(); end

    gradeLabels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};

    % Build review JSON
    review = struct();
    review.image_id = imageId;
    review.dataset = dataset;
    review.split = split;
    review.quality_status = safeStr(phase3Result, 'quality_status', 'UNKNOWN');
    review.quality_score = safeNum(phase3Result, 'quality_score', NaN);

    % Classification
    predGrade = safeNum(predResult, 'predicted_grade', -1);
    review.predicted_grade = predGrade;
    if predGrade >= 0 && predGrade <= 4
        review.grade_label = gradeLabels{predGrade + 1};
    else
        review.grade_label = 'Unknown';
    end
    review.referable_prediction = safeNum(predResult, 'referable_pred', 0) == 1;
    review.raw_probability = safeNum(predResult, 'referable_probability', 0);
    review.calibrated_probability = NaN;  % Would be set if Platt scaling applied
    review.confidence = safeNum(predResult, 'confidence_score', 0);

    % Top features
    review.top_features = {};
    if ~isempty(contributions) && isfield(contributions, 'name')
        topN = min(5, numel(contributions.name));
        for k = 1:topN
            feat = struct();
            feat.name = contributions.name{k};
            feat.contribution = contributions.contribution(k);
            feat.direction = contributions.direction{k};
            review.top_features{k} = feat;
        end
    end

    % Lesion evidence
    review.lesion_evidence = struct();
    review.lesion_evidence.ma = struct( ...
        'count', safeNum(phase3Result, 'ma_candidate_count', 0), ...
        'area', safeNum(phase3Result, 'ma_candidate_area', NaN), ...
        'confidence', safeNum(phase3Result, 'ma_confidence', NaN));
    review.lesion_evidence.he = struct( ...
        'count', safeNum(phase3Result, 'he_candidate_count', 0), ...
        'area', safeNum(phase3Result, 'he_candidate_area', NaN), ...
        'confidence', safeNum(phase3Result, 'he_confidence', NaN));
    review.lesion_evidence.ex = struct( ...
        'count', safeNum(phase3Result, 'ex_candidate_count', 0), ...
        'area', safeNum(phase3Result, 'ex_candidate_area', NaN), ...
        'confidence', safeNum(phase3Result, 'ex_confidence', NaN));
    review.lesion_evidence.nv = struct( ...
        'candidate', safeLog(phase3Result, 'nv_candidate', false), ...
        'score', safeNum(phase3Result, 'nv_score', NaN), ...
        'confidence', safeNum(phase3Result, 'nv_confidence', NaN));

    % Structure evidence
    review.structure_evidence = struct();
    review.structure_evidence.optic_disc = struct( ...
        'detected', safeLog(phase3Result, 'optic_disc_detected', false), ...
        'confidence', safeNum(phase3Result, 'optic_disc_confidence', NaN));
    review.structure_evidence.fovea = struct( ...
        'detected', safeLog(phase3Result, 'fovea_detected', false), ...
        'confidence', safeNum(phase3Result, 'fovea_confidence', NaN));
    review.structure_evidence.vessels = struct( ...
        'density', safeNum(phase3Result, 'vessel_density', NaN), ...
        'status', safeStr(phase3Result, 'vessel_segmentation_status', 'UNKNOWN'));

    % Calibration
    if ~isempty(calibration)
        review.calibration = struct( ...
            'brier_score', calibration.brier_score, ...
            'ece', calibration.ece, ...
            'auc', calibration.auc);
    else
        review.calibration = struct();
    end

    % Review workflow
    review.review_required = true;
    review.review_status = 'PENDING';
    review.reviewer_decision = [];
    review.reviewer_notes = '';
    review.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    % Output paths
    review.overlay_path = fullfile(cfg.paths.overlayDir, sprintf('%s_evidence.png', imageId));
    review.heatmap_path = fullfile(cfg.paths.heatmapDir, sprintf('%s_heatmap.png', imageId));
    review.report_path = fullfile(cfg.paths.reportDir, sprintf('%s.md', imageId));

    % Save JSON
    jsonStr = jsonencode(review, 'PrettyPrint', true);
    outPath = fullfile(cfg.paths.reviewDir, sprintf('%s.json', imageId));
    fid = fopen(outPath, 'w');
    fwrite(fid, jsonStr, 'char');
    fclose(fid);
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
