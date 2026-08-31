function result = analyzeImage(imgPath, qualityResult, cfg)
% analyzeImage  Per-image Phase 3 orchestrator (RESEARCH PROTOTYPE)
%
%   result = analyzeImage(imgPath, qualityResult, cfg)
%
%   Consumes Phase 2 quality output, runs structure + lesion analysis.
%   Returns structured output per the Phase 4-ready feature contract.
%   UNGRADABLE images are flagged but still processed for completeness.

    if nargin < 3 || isempty(cfg), cfg = phase3Config(); end

    result = struct();
    % Identity
    result.image_path = string(imgPath);
    [~, name, ext] = fileparts(imgPath);
    result.image_id = string(name);
    result.file_format = string(upper(strrep(ext, '.', '')));
    result.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    result.cfgVersion = string(cfg.version);

    % Phase 2 inputs
    if ~isempty(qualityResult)
        result.quality_status = string(qualityResult.quality_status);
        result.quality_score = qualityResult.overall_quality_score;
        result.enhancement_used = false;
        if isfield(qualityResult, 'enhanced')
            result.enhancement_used = logical(qualityResult.enhanced);
        end
    else
        result.quality_status = 'NOT_ASSESSED';
        result.quality_score = NaN;
        result.enhancement_used = false;
    end

    % Load image
    [img, info, err] = loadImageSafe(imgPath);
    result.load_error = string(err);
    if ~info.readable || isempty(img)
        result.overall_structure_status = 'UNREADABLE';
        result.overall_lesion_status = 'UNREADABLE';
        result.failure_reason = 'IMAGE_UNREADABLE';
        % Fill empty fields for contract
        result.retinal_area_fraction = NaN;
        result.fov_center_x = NaN; result.fov_center_y = NaN; result.fov_radius = NaN;
        result.fov_status = 'UNREADABLE';
        result.optic_disc_detected = false; result.optic_disc_x = NaN; result.optic_disc_y = NaN;
        result.optic_disc_radius = NaN; result.optic_disc_confidence = NaN;
        result.fovea_detected = false; result.fovea_x = NaN; result.fovea_y = NaN;
        result.fovea_confidence = NaN; result.fovea_method = 'UNREADABLE';
        result.vessel_area_fraction = NaN; result.vessel_density = NaN;
        result.vessel_segmentation_status = 'UNREADABLE';
        result.ma_candidate_count = 0; result.ma_candidate_area = NaN; result.ma_confidence = NaN;
        result.he_candidate_count = 0; result.he_candidate_area = NaN; result.he_confidence = NaN;
        result.ex_candidate_count = 0; result.ex_candidate_area = NaN;
        result.ex_candidate_area_fraction = NaN; result.ex_confidence = NaN;
        result.nv_candidate = false; result.nv_score = NaN; result.nv_confidence = NaN;
        return;
    end

    % Resize for processing
    try
        [h, w, ~] = size(img);
        maxDim = max(h, w);
        if maxDim > cfg.processing.maxDim
            scale = cfg.processing.maxDim / maxDim;
            if exist('imresize', 'file')
                small = imresize(img, scale);
            else
                small = img;
            end
        else
            small = img;
        end
    catch
        small = img;
    end

    % --- Structure Analysis ---
    try
        fovResult = detectRetinalFOV(small, cfg);
    catch ME
        fovResult = struct('mask', [], 'area_fraction', NaN, 'center_x', NaN, 'center_y', NaN, ...
            'radius', NaN, 'status', 'FAILED', 'error', ME.message);
    end

    try
        odResult = detectOpticDisc(small, fovResult.mask, cfg);
    catch ME
        odResult = struct('detected', false, 'center_x', NaN, 'center_y', NaN, ...
            'radius', NaN, 'confidence', 0, 'status', 'FAILED', 'error', ME.message);
    end

    try
        foveaResult = detectFovea(small, odResult, cfg);
    catch ME
        foveaResult = struct('detected', false, 'center_x', NaN, 'center_y', NaN, ...
            'confidence', 0, 'status', 'FAILED', 'method', 'FAILED', 'error', ME.message);
    end

    try
        vesselResult = segmentVessels(small, fovResult.mask, cfg);
    catch ME
        vesselResult = struct('vessel_mask', [], 'vessel_area_fraction', NaN, ...
            'vessel_density', NaN, 'status', 'FAILED', 'error', ME.message);
    end

    % --- Lesion Analysis ---
    vesselMaskForLesions = [];
    if ~isempty(vesselResult) && isfield(vesselResult, 'vessel_mask') && ~isempty(vesselResult.vessel_mask)
        vesselMaskForLesions = vesselResult.vessel_mask;
    end

    try
        maResult = detectMicroaneurysms(small, fovResult.mask, vesselMaskForLesions, cfg);
    catch ME
        maResult = struct('candidate_count', 0, 'total_candidate_area', 0, ...
            'confidence', 0, 'status', 'FAILED', 'error', ME.message);
    end

    try
        heResult = detectHemorrhages(small, fovResult.mask, vesselMaskForLesions, cfg);
    catch ME
        heResult = struct('candidate_count', 0, 'total_candidate_area', 0, ...
            'confidence', 0, 'status', 'FAILED', 'error', ME.message);
    end

    try
        exResult = detectExudates(small, fovResult.mask, odResult, cfg);
    catch ME
        exResult = struct('candidate_count', 0, 'total_candidate_area', 0, ...
            'area_fraction', 0, 'confidence', 0, 'status', 'FAILED', 'error', ME.message);
    end

    try
        nvResult = detectNeovascularization(small, fovResult.mask, vesselResult, cfg);
    catch ME
        nvResult = struct('nv_candidate', false, 'nv_score', 0, 'nv_confidence', 0, ...
            'status', 'FAILED', 'error', ME.message);
    end

    % --- Fill output contract ---
    % Structure fields
    result.retinal_area_fraction = fovResult.area_fraction;
    result.fov_center_x = fovResult.center_x;
    result.fov_center_y = fovResult.center_y;
    result.fov_radius = fovResult.radius;
    result.fov_status = string(fovResult.status);

    result.optic_disc_detected = odResult.detected;
    result.optic_disc_x = odResult.center_x;
    result.optic_disc_y = odResult.center_y;
    result.optic_disc_radius = odResult.radius;
    result.optic_disc_confidence = odResult.confidence;

    result.fovea_detected = foveaResult.detected;
    result.fovea_x = foveaResult.center_x;
    result.fovea_y = foveaResult.center_y;
    result.fovea_confidence = foveaResult.confidence;
    result.fovea_method = string(foveaResult.method);

    result.vessel_area_fraction = vesselResult.vessel_area_fraction;
    result.vessel_density = vesselResult.vessel_density;
    result.vessel_segmentation_status = string(vesselResult.status);

    % Lesion fields
    result.ma_candidate_count = maResult.candidate_count;
    result.ma_candidate_area = maResult.total_candidate_area;
    result.ma_confidence = maResult.confidence;

    result.he_candidate_count = heResult.candidate_count;
    result.he_candidate_area = heResult.total_candidate_area;
    result.he_confidence = heResult.confidence;

    result.ex_candidate_count = exResult.candidate_count;
    result.ex_candidate_area = exResult.total_candidate_area;
    result.ex_candidate_area_fraction = exResult.area_fraction;
    result.ex_confidence = exResult.confidence;

    result.nv_candidate = nvResult.nv_candidate;
    result.nv_score = nvResult.nv_score;
    result.nv_confidence = nvResult.nv_confidence;

    % Overall status
    structStatuses = [string(fovResult.status), string(odResult.status), ...
                      string(vesselResult.status)];
    lesionStatuses = [string(maResult.status), string(heResult.status), ...
                      string(exResult.status), string(nvResult.status)];

    if all(contains(structStatuses, 'FAILED'))
        result.overall_structure_status = 'ALL_FAILED';
    elseif any(contains(structStatuses, 'FAILED'))
        result.overall_structure_status = 'PARTIAL';
    else
        result.overall_structure_status = 'COMPLETED';
    end

    if all(contains(lesionStatuses, 'FAILED'))
        result.overall_lesion_status = 'ALL_FAILED';
    elseif any(contains(lesionStatuses, 'FAILED'))
        result.overall_lesion_status = 'PARTIAL';
    else
        result.overall_lesion_status = 'COMPLETED';
    end

    % Failure reason
    failureReasons = {};
    if result.quality_status == "UNGRADABLE"
        failureReasons{end+1} = 'QUALITY_UNGRADABLE';
    end
    if fovResult.status == "FAILED"
        failureReasons{end+1} = 'FOV_FAILED';
    end
    if ~odResult.detected
        failureReasons{end+1} = 'OD_NOT_DETECTED';
    end
    if isempty(failureReasons)
        result.failure_reason = '';
    else
        result.failure_reason = strjoin(failureReasons, ';');
    end

    % Store detailed results for validation
    result.detail_fov = fovResult;
    result.detail_od = odResult;
    result.detail_fovea = foveaResult;
    result.detail_vessels = vesselResult;
    result.detail_ma = maResult;
    result.detail_he = heResult;
    result.detail_ex = exResult;
    result.detail_nv = nvResult;
end
