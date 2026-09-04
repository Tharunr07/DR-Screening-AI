function result = assessImageQuality(imgPath, cfg)
% assessImageQuality  Full quality assessment for one image (RESEARCH PROTOTYPE)
%
%   result = assessImageQuality(imgPath)
%   result = assessImageQuality(imgPath, cfg)
%
%   Input imgPath: absolute path to image file
%   Output result struct with all metrics, overall score, status, reasons
%
%   Handles unreadable -> UNGRADABLE + UNREADABLE_IMAGE
%   Preserves individual metric values (raw + normalized)
%   Labels thresholds THEORETICAL / INITIAL

    if nargin < 2 || isempty(cfg), cfg = qualityConfig(); end

    % Initialize result
    result = struct();
    result.image_path = string(imgPath);
    [~, name, ext] = fileparts(imgPath);
    result.image_id = string(name);
    result.file_format = string(upper(strrep(ext,'.','')));
    result.timestamp = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    result.cfgVersion = string(cfg.version);
    result.cfgStatus  = string(cfg.status);

    % Safe load
    [img, info, err] = loadImageSafe(imgPath);
    result.loadInfo = info;
    result.loadError = string(err);
    if ~info.readable || isempty(img)
        result.quality_status = "UNGRADABLE";
        result.quality_reasons = ["UNREADABLE_IMAGE"];
        result.failed_metrics = ["UNREADABLE_IMAGE"];
        result.borderline_metrics = string([]);
        result.overall_quality_score = 0;
        result.recaputure_code = "RECAPTURE_UNREADABLE";
        result.recapture_human = "Image could not be read. Ensure the file is a valid fundus photograph and recapture.";
        result.focus = struct('laplacian',NaN,'tenengrad',NaN,'brenner',NaN,'edgeDensity',NaN,'focus_status',"UNGRADABLE");
        result.illumination = struct('mean',NaN,'illumination_status',"UNGRADABLE");
        result.fov = struct('areaFraction',0,'fov_status',"UNGRADABLE");
        result.glare = struct('fraction',NaN,'glare_status',"UNGRADABLE");
        result.vignetting = struct('score',NaN,'status',"UNGRADABLE");
        result.contrast = struct('std',NaN,'contrast_status',"UNGRADABLE");
        result.retinal = struct('areaFraction',0,'retinal_status',"UNGRADABLE");
        result.metric_failed = true;
        return;
    end

    % Performance: resize large images to max 256 for metrics (keep original for enhancement)
    try
        [h,w,~] = size(img);
        maxDim = max(h,w);
        if maxDim > 256
            scale = 256 / maxDim;
            % Use imresize if available
            if exist('imresize','file')
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
    % Estimate retinal mask on small (faster)
    try
        retinalMaskSmall = estimateRetinalMask(small);
    catch
        retinalMaskSmall = true(size(small,1), size(small,2));
    end
    % Also estimate on original for FOV completeness? Use small for all metrics for consistency
    retinalMask = retinalMaskSmall;
    imgForMetrics = small;
    result.retinalMaskAreaFraction = nnz(retinalMask) / numel(retinalMask);
    result.processingSize = sprintf('%dx%d', size(small,1), size(small,2));

    % Per-metric assessment (each handles its own errors) — use small image for speed
    try
        focusMetrics = assessFocus(imgForMetrics, retinalMask, cfg);
    catch ME
        focusMetrics = struct('laplacian',NaN,'tenengrad',NaN,'brenner',NaN,'edgeDensity',NaN,'focus_status',"UNGRADABLE",'details',ME.message);
    end
    try
        illumMetrics = assessIllumination(imgForMetrics, retinalMask, cfg);
    catch ME
        illumMetrics = struct('mean',NaN,'illumination_status',"UNGRADABLE",'details',ME.message);
    end
    try
        fovMetrics = assessFOV(imgForMetrics, retinalMask, cfg);
    catch ME
        fovMetrics = struct('areaFraction',0,'fov_status',"UNGRADABLE",'details',ME.message);
    end
    try
        glareMetrics = assessGlare(imgForMetrics, retinalMask, cfg);
    catch ME
        glareMetrics = struct('fraction',NaN,'glare_status',"UNGRADABLE",'details',ME.message);
    end
    try
        vignMetrics = assessVignetting(imgForMetrics, retinalMask, cfg);
    catch ME
        vignMetrics = struct('score',NaN,'status',"UNGRADABLE",'details',ME.message);
    end
    try
        contrastMetrics = assessContrast(imgForMetrics, retinalMask, cfg);
    catch ME
        contrastMetrics = struct('std',NaN,'contrast_status',"UNGRADABLE",'details',ME.message);
    end
    try
        retinalMetrics = assessRetinalArea(imgForMetrics, retinalMask, cfg);
    catch ME
        retinalMetrics = struct('areaFraction',0,'retinal_status',"UNGRADABLE",'details',ME.message);
    end

    result.focus = focusMetrics;
    result.illumination = illumMetrics;
    result.fov = fovMetrics;
    result.glare = glareMetrics;
    result.vignetting = vignMetrics;
    result.contrast = contrastMetrics;
    result.retinal = retinalMetrics;

    % Classification
    try
        decision = classifyQuality(result, cfg);
        result.quality_status = decision.quality_status;
        result.quality_reasons = decision.quality_reasons;
        result.failed_metrics = decision.failed_metrics;
        result.borderline_metrics = decision.borderline_metrics;
        result.overall_quality_score = decision.overall_quality_score;
        result.recaputure_code = decision.recapture_code;
        result.recapture_human = decision.recapture_human;
        result.decisionDetails = decision.details;
    catch ME
        result.quality_status = "UNGRADABLE";
        result.quality_reasons = ["CLASSIFICATION_ERROR"];
        result.failed_metrics = ["CLASSIFICATION_ERROR"];
        result.borderline_metrics = string([]);
        result.overall_quality_score = 0;
        result.recaputure_code = "RECAPTURE_MULTIPLE_QUALITY_FAILURES";
        result.recapture_human = "Image quality assessment failed. Recapture is recommended.";
    end

    % Store also retinal mask for optional reuse (not saved to CSV)
    result.retinalMask = retinalMask;
end
