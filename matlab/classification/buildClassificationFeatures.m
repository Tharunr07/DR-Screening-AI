function [features, featureNames, meta] = buildClassificationFeatures(row, cfg)
% buildClassificationFeatures  Build feature vector from Phase 2+3 outputs
%
%   [features, featureNames, meta] = buildClassificationFeatures(row, cfg)
%
%   Input:
%     row  — scalar struct with image_id, dataset, split, quality fields, structure fields, lesion fields
%     cfg  — classificationConfig output
%
%   Output:
%     features     — 1×N double feature vector (NaN for missing)
%     featureNames — 1×N cell array of feature names
%     meta         — struct with quality_status, quality_score

    % Quality features
    qualityScore = safeNum(row, 'overall_quality_score', NaN);

    % Structure features
    retinalArea     = safeNum(row, 'retinal_area_fraction', NaN);
    fovRadius       = safeNum(row, 'fov_radius', NaN);
    odDetected      = safeLog(row, 'optic_disc_detected', false);
    odRadius        = safeNum(row, 'optic_disc_radius', NaN);
    odConfidence    = safeNum(row, 'optic_disc_confidence', NaN);
    foveaDetected   = safeLog(row, 'fovea_detected', false);
    foveaConfidence = safeNum(row, 'fovea_confidence', NaN);
    vesselFrac      = safeNum(row, 'vessel_area_fraction', NaN);
    vesselDensity   = safeNum(row, 'vessel_density', NaN);

    % Lesion features
    maCount    = safeNum(row, 'ma_candidate_count', 0);
    maArea     = safeNum(row, 'ma_candidate_area', NaN);
    maConf     = safeNum(row, 'ma_confidence', NaN);
    heCount    = safeNum(row, 'he_candidate_count', 0);
    heArea     = safeNum(row, 'he_candidate_area', NaN);
    heConf     = safeNum(row, 'he_confidence', NaN);
    exCount    = safeNum(row, 'ex_candidate_count', 0);
    exArea     = safeNum(row, 'ex_candidate_area', NaN);
    exAreaFrac = safeNum(row, 'ex_candidate_area_fraction', NaN);
    exConf     = safeNum(row, 'ex_confidence', NaN);
    nvPresent  = safeLog(row, 'nv_candidate', false);
    nvScore    = safeNum(row, 'nv_score', NaN);
    nvConf     = safeNum(row, 'nv_confidence', NaN);

    % Combined features
    totalLesions = maCount + heCount + exCount;
    totalLesionArea = nansum([maArea, heArea, exArea]);

    features = [
        qualityScore, ...
        retinalArea, fovRadius, ...
        double(odDetected), odRadius, odConfidence, ...
        double(foveaDetected), foveaConfidence, ...
        vesselFrac, vesselDensity, ...
        maCount, maArea, maConf, ...
        heCount, heArea, heConf, ...
        exCount, exArea, exAreaFrac, exConf, ...
        double(nvPresent), nvScore, nvConf, ...
        totalLesions, totalLesionArea
    ];

    featureNames = {
        'quality_score', ...
        'retinal_area_fraction', 'fov_radius', ...
        'od_detected', 'od_radius', 'od_confidence', ...
        'fovea_detected', 'fovea_confidence', ...
        'vessel_area_fraction', 'vessel_density', ...
        'ma_count', 'ma_area', 'ma_confidence', ...
        'he_count', 'he_area', 'he_confidence', ...
        'ex_count', 'ex_area', 'ex_area_fraction', 'ex_confidence', ...
        'nv_present', 'nv_score', 'nv_confidence', ...
        'total_lesions', 'total_lesion_area'
    };

    meta.quality_status = safeStr(row, 'quality_status', 'UNKNOWN');
    meta.quality_score  = qualityScore;
end

function v = safeNum(s, field, default)
    if isfield(s, field) && ~isempty(s.(field))
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
    if isfield(s, field) && ~isempty(s.(field))
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
    if isfield(s, field) && ~isempty(s.(field))
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
