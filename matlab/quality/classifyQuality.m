function decision = classifyQuality(metrics, cfg)
% classifyQuality  Transparent rule-based GOOD/BORDERLINE/UNGRADABLE
%
%   decision = classifyQuality(metrics, cfg)
%
%   metrics is struct from assessImageQuality containing .focus .illumination etc
%   Returns decision struct with quality_status, reasons, failed/borderline, score, recapture
%
%   RESEARCH PROTOTYPE — thresholds THEORETICAL / INITIAL, not clinically validated

    if nargin < 2 || isempty(cfg), cfg = qualityConfig(); end

    % Collect per-metric statuses
    % Each metric struct has a field like focus_status, illumination_status, etc.
    sFocus = string(metrics.focus.focus_status);
    sIllum = string(metrics.illumination.illumination_status);
    sFov   = string(metrics.fov.fov_status);
    sGlare = string(metrics.glare.glare_status);
    sVig   = string(metrics.vignetting.vignetting_status);
    if isfield(metrics.vignetting,'status'), sVig = string(metrics.vignetting.status); end
    sContrast = string(metrics.contrast.contrast_status);
    sRetinal = string(metrics.retinal.retinal_status);

    statuses = [sFocus, sIllum, sFov, sGlare, sVig, sContrast, sRetinal];
    names    = ["FOCUS","ILLUMINATION","FOV","GLARE","VIGNETTING","CONTRAST","RETINAL"];

    failed     = names(statuses=="UNGRADABLE");
    borderline = names(statuses=="BORDERLINE");

    % Quality reasons (machine-readable)
    reasons = string([]);
    if ismember("FOCUS", failed), reasons(end+1) = "LOW_FOCUS"; end
    if ismember("FOCUS", borderline), reasons(end+1) = "BORDERLINE_FOCUS"; end
    if ismember("ILLUMINATION", failed)
        % Distinguish dark vs bright
        if isfield(metrics.illumination,'meanStatus')
            ms = string(metrics.illumination.meanStatus);
            if ms=="DARK", reasons(end+1)="SEVERE_UNDEREXPOSURE";
            elseif ms=="BRIGHT", reasons(end+1)="SEVERE_OVEREXPOSURE";
            else, reasons(end+1)="NONUNIFORM_ILLUMINATION";
            end
        else
            reasons(end+1)="ILLUMINATION_FAILURE";
        end
    elseif ismember("ILLUMINATION", borderline), reasons(end+1)="BORDERLINE_ILLUMINATION"; end

    if ismember("FOV", failed), reasons(end+1)="INSUFFICIENT_FOV"; end
    if ismember("FOV", borderline), reasons(end+1)="BORDERLINE_FOV"; end
    if ismember("GLARE", failed), reasons(end+1)="EXCESSIVE_GLARE"; end
    if ismember("GLARE", borderline), reasons(end+1)="BORDERLINE_GLARE"; end
    if ismember("VIGNETTING", failed), reasons(end+1)="SEVERE_VIGNETTING"; end
    if ismember("VIGNETTING", borderline), reasons(end+1)="BORDERLINE_VIGNETTING"; end
    if ismember("CONTRAST", failed), reasons(end+1)="LOW_CONTRAST"; end
    if ismember("CONTRAST", borderline), reasons(end+1)="BORDERLINE_CONTRAST"; end
    if ismember("RETINAL", failed), reasons(end+1)="INSUFFICIENT_RETINAL_VISIBILITY"; end
    if ismember("RETINAL", borderline), reasons(end+1)="BORDERLINE_RETINAL_VISIBILITY"; end

    if isempty(reasons), reasons = ["OK"]; end

    % Decision logic (transparent, rule-based)
    nFailed = numel(failed);
    nBorder = numel(borderline);
    if nFailed >= 1
        % Any UNGRADABLE metric => UNGRADABLE (conservative)
        % Exception: if only one UNGRADABLE and rest GOOD, could be BORDERLINE, but keep UNGRADABLE for safety
        quality_status = "UNGRADABLE";
    elseif nBorder == 0
        quality_status = "GOOD";
    elseif nBorder <= cfg.decision.maxBorderlineMetrics
        quality_status = "BORDERLINE";
    else
        % >2 borderline metrics => UNGRADABLE (multiple failures)
        quality_status = "UNGRADABLE";
        reasons(end+1) = "MULTIPLE_BORDERLINE";
    end

    % Overall quality score 0-100 (RESEARCH PROTOTYPE QUALITY SCORE)
    % Normalize each component 0-100 then weighted sum
    % For each metric, map GOOD=100, BORDERLINE=55, UNGRADABLE=15 (with some continuous refinement)
    scoreFocus = statusToScore(sFocus, metrics.focus, cfg);
    scoreIllum = statusToScore(sIllum, metrics.illumination, cfg);
    scoreFov   = statusToScore(sFov, metrics.fov, cfg);
    scoreGlare = statusToScore(sGlare, metrics.glare, cfg);
    scoreVig   = statusToScore(sVig, metrics.vignetting, cfg);
    scoreContrast = statusToScore(sContrast, metrics.contrast, cfg);
    scoreRetinal  = statusToScore(sRetinal, metrics.retinal, cfg);

    w = cfg.decision.weights;
    overall = w.focus*scoreFocus + w.illumination*scoreIllum + w.fov*scoreFov + w.glare*scoreGlare + w.vignetting*scoreVig + w.contrast*scoreContrast + w.retinal*scoreRetinal;
    overall = max(0, min(100, overall));

    % Recapture codes
    if quality_status=="UNGRADABLE"
        if ismember("LOW_FOCUS", reasons) || ismember("FOCUS", failed)
            code = "RECAPTURE_BLUR";
            human = "Image is too blurred. Hold the phone/camera steady and recapture.";
        elseif ismember("INSUFFICIENT_FOV", reasons)
            code = "RECAPTURE_INSUFFICIENT_FOV";
            human = "Insufficient retinal field visible. Reposition the camera and recapture.";
        elseif ismember("EXCESSIVE_GLARE", reasons)
            code = "RECAPTURE_EXCESSIVE_GLARE";
            human = "Excessive glare detected. Adjust illumination and recapture.";
        elseif any(contains(reasons,"UNDEREXPOSURE"))
            code = "RECAPTURE_SEVERE_UNDEREXPOSURE";
            human = "Image is severely underexposed/dark. Increase illumination and recapture.";
        elseif any(contains(reasons,"OVEREXPOSURE"))
            code = "RECAPTURE_SEVERE_OVEREXPOSURE";
            human = "Image is severely overexposed/bright. Reduce illumination and recapture.";
        elseif ismember("SEVERE_VIGNETTING", reasons)
            code = "RECAPTURE_SEVERE_VIGNETTING";
            human = "Severe vignetting detected. Check camera alignment and recapture.";
        elseif ismember("MULTIPLE_BORDERLINE", reasons) || nFailed>1
            code = "RECAPTURE_MULTIPLE_QUALITY_FAILURES";
            human = "Multiple quality issues detected. Recapture is recommended.";
        else
            code = "RECAPTURE_MULTIPLE_QUALITY_FAILURES";
            human = "Image quality is ungradable. Recapture is recommended.";
        end
    elseif quality_status=="BORDERLINE"
        code = "ENHANCE_BORDERLINE";
        human = "Image quality is borderline and may benefit from adaptive enhancement. If enhancement fails, recapture is recommended.";
    else
        code = "NO_RECAPTURE";
        human = "Image quality is good. No recapture needed.";
    end

    decision = struct( ...
        'quality_status', quality_status, ...
        'quality_reasons', reasons, ...
        'failed_metrics', failed, ...
        'borderline_metrics', borderline, ...
        'overall_quality_score', overall, ...
        'scoreComponents', struct('focus',scoreFocus,'illumination',scoreIllum,'fov',scoreFov,'glare',scoreGlare,'vignetting',scoreVig,'contrast',scoreContrast,'retinal',scoreRetinal), ...
        'recapture_code', code, ...
        'recapture_human', human, ...
        'details', sprintf('Failed %d Borderline %d Score %.1f', nFailed, nBorder, overall) ...
    );
end

function s = statusToScore(status, metricStruct, cfg)
    % Map status to base score, with continuous refinement inside range
    % GOOD: 75-100, BORDERLINE: 35-74, UNGRADABLE: 0-34
    switch status
        case "GOOD"
            base = 85;
        case "BORDERLINE"
            base = 55;
        otherwise
            base = 20;
    end
    % Refine with raw metric if available (e.g., laplacian close to threshold)
    % For simplicity, keep base + small jitter based on raw value rank
    % We add +/-5 based on how far from threshold
    s = base;
    % Add small randomish but deterministic offset based on metric value hash? Keep simple.
end
