function [enhanced, log] = enhanceBorderlineImage(img, qualityResult, cfg)
% enhanceBorderlineImage  Adaptive conservative enhancement for BORDERLINE
%
%   [enhanced, log] = enhanceBorderlineImage(img, qualityResult, cfg)
%
%   Only call for BORDERLINE images. Applies operations adaptively:
%     LOW_CONTRAST -> CLAHE
%     NONUNIFORM_ILLUMINATION / SEVERE_DARK -> illumination normalization
%     MILD_NOISE (inferred from low focus but moderate contrast) -> median denoising
%
%   Does NOT enhance GOOD images unnecessarily.
%   Returns enhanced image (same size/type) and log struct with before/after metrics

    if nargin < 3 || isempty(cfg), cfg = qualityConfig(); end
    log = struct('applied', string([]), 'skipped', string([]), 'before', [], 'after', [], 'improved', false, 'failed', false);
    enhanced = img;

    if isempty(img)
        log.failed = true;
        return;
    end

    % Only BORDERLINE should be enhanced; if GOOD or UNGRADABLE, skip
    if ~isfield(qualityResult,'quality_status') || qualityResult.quality_status ~= "BORDERLINE"
        log.skipped = "NOT_BORDERLINE";
        return;
    end

    reasons = string(qualityResult.quality_reasons);
    % Determine which operations to apply
    needCLAHE = any(contains(reasons, ["LOW_CONTRAST","BORDERLINE_CONTRAST","LOW_FOCUS"])) || qualityResult.contrast.contrast_status~="GOOD";
    needIllumNorm = any(contains(reasons, ["ILLUMINATION","UNDEREXPOSURE","VIGNETTING"])) || qualityResult.illumination.illumination_status~="GOOD" || qualityResult.vignetting.status~="GOOD";
    needDenoise = false; % conservative: only if focus borderline but contrast good (suggests noise)
    if qualityResult.focus.focus_status=="BORDERLINE" && qualityResult.contrast.contrast_status=="GOOD"
        needDenoise = true;
    end

    % Convert to double for processing
    isRGB = ndims(img)==3 && size(img,3)==3;
    if isRGB
        imgDouble = im2double(img);
    else
        imgDouble = im2double(squeeze(img));
        if ndims(imgDouble)==2
            % keep as 2D
        end
    end

    % Store before metrics for comparison (we will recompute after)
    beforeMetrics = qualityResult;

    % 1. Illumination normalization (large Gaussian background subtraction)
    if needIllumNorm && cfg.enhancement.illuminationNormalization
        try
            if isRGB
                % Work on value channel in HSV or on each channel
                hsv = rgb2hsv(imgDouble);
                V = hsv(:,:,3);
                % Estimate background via large Gaussian
                sigma = cfg.enhancement.illuminationSigma;
                % Approximate Gaussian via imgaussfilt if available, else fspecial
                if exist('imgaussfilt','file')
                    bg = imgaussfilt(V, sigma);
                else
                    h = fspecial('gaussian', round(6*sigma)+1, sigma);
                    bg = imfilter(V, h, 'replicate');
                end
                % Normalize: V_norm = V ./ (bg + eps) * mean(bg)
                bgMean = mean(bg(:));
                Vnorm = V ./ (bg + 0.1) * bgMean;
                Vnorm = min(1, max(0, Vnorm));
                hsv(:,:,3) = Vnorm;
                imgDouble = hsv2rgb(hsv);
                log.applied(end+1) = "ILLUMINATION_NORMALIZATION";
            else
                % Grayscale
                sigma = cfg.enhancement.illuminationSigma;
                if exist('imgaussfilt','file')
                    bg = imgaussfilt(imgDouble, sigma);
                else
                    h = fspecial('gaussian', round(6*sigma)+1, sigma);
                    bg = imfilter(imgDouble, h, 'replicate');
                end
                bgMean = mean(bg(:));
                imgDouble = imgDouble ./ (bg + 0.1) * bgMean;
                imgDouble = min(1, max(0, imgDouble));
                log.applied(end+1) = "ILLUMINATION_NORMALIZATION";
            end
        catch ME
            log.skipped(end+1) = "ILLUMINATION_FAILED: " + string(ME.message);
        end
    end

    % 2. CLAHE (Contrast Limited Adaptive Histogram Equalization)
    if needCLAHE && cfg.enhancement.applyCLAHE
        try
            if isRGB
                % Apply CLAHE on L channel in Lab
                if exist('rgb2lab','file') && exist('lab2rgb','file')
                    lab = rgb2lab(imgDouble);
                    L = lab(:,:,1); % 0-100
                    Lnorm = L / 100; % 0-1
                    % Use adapthisteq if available
                    if exist('adapthisteq','file')
                        Lclahe = adapthisteq(Lnorm, 'ClipLimit', cfg.enhancement.claheClipLimit, 'NumTiles', cfg.enhancement.claheTileSize, 'Distribution','rayleigh');
                    else
                        Lclahe = histeq(Lnorm);
                    end
                    lab(:,:,1) = Lclahe * 100;
                    imgDouble = lab2rgb(lab);
                    imgDouble = min(1, max(0, imgDouble));
                else
                    % Fallback: apply on each channel
                    for c=1:3
                        ch = imgDouble(:,:,c);
                        if exist('adapthisteq','file')
                            imgDouble(:,:,c) = adapthisteq(ch, 'ClipLimit', cfg.enhancement.claheClipLimit, 'NumTiles', cfg.enhancement.claheTileSize);
                        else
                            imgDouble(:,:,c) = histeq(ch);
                        end
                    end
                end
                log.applied(end+1) = "CLAHE";
            else
                % Grayscale
                if exist('adapthisteq','file')
                    imgDouble = adapthisteq(imgDouble, 'ClipLimit', cfg.enhancement.claheClipLimit, 'NumTiles', cfg.enhancement.claheTileSize);
                else
                    imgDouble = histeq(imgDouble);
                end
                log.applied(end+1) = "CLAHE";
            end
        catch ME
            log.skipped(end+1) = "CLAHE_FAILED: " + string(ME.message);
        end
    end

    % 3. Mild denoising (median filter)
    if needDenoise && cfg.enhancement.denoising
        try
            if isRGB
                for c=1:3
                    imgDouble(:,:,c) = medfilt2(imgDouble(:,:,c), [cfg.enhancement.medianFilterSize cfg.enhancement.medianFilterSize]);
                end
            else
                imgDouble = medfilt2(imgDouble, [cfg.enhancement.medianFilterSize cfg.enhancement.medianFilterSize]);
            end
            log.applied(end+1) = "DENOISING";
        catch ME
            log.skipped(end+1) = "DENOISING_FAILED: " + string(ME.message);
        end
    end

    % Convert back to uint8
    if isRGB
        enhanced = im2uint8(imgDouble);
    else
        enhanced = im2uint8(imgDouble);
        % Ensure 3D if input was 3D grayscale? Keep 2D
    end

    % Before/after validation: recompute quality on enhanced
    try
        % Need retinal mask for enhanced? estimate again
        afterResult = assessImageQualityFromImage(enhanced, cfg);
        log.before = beforeMetrics;
        log.after = afterResult;
        % Improved if score increased and status not worsened
        % GOOD > BORDERLINE > UNGRADABLE
        scoreBefore = beforeMetrics.overall_quality_score;
        scoreAfter  = afterResult.overall_quality_score;
        statusOrder = containers.Map(["UNGRADABLE","BORDERLINE","GOOD"], [0,1,2]);
        sBefore = statusOrder(char(beforeMetrics.quality_status));
        sAfter  = statusOrder(char(afterResult.quality_status));
        if sAfter > sBefore || (sAfter==sBefore && scoreAfter > scoreBefore + 2)
            log.improved = true;
            log.failed = false;
        else
            log.improved = false;
            % If worse, flag failed and keep original (caller will decide)
            if sAfter < sBefore || scoreAfter < scoreBefore - 5
                log.failed = true;
            else
                log.failed = false;
            end
        end
    catch
        log.improved = false;
        log.failed = true;
    end
end

function result = assessImageQualityFromImage(img, cfg)
% Helper to assess already loaded image (no file path)
    % Estimate mask
    try
        retinalMask = estimateRetinalMask(img);
    catch
        retinalMask = true(size(img,1), size(img,2));
    end
    % Build fake result via direct metric calls
    focus = assessFocus(img, retinalMask, cfg);
    illum = assessIllumination(img, retinalMask, cfg);
    fov   = assessFOV(img, retinalMask, cfg);
    glare = assessGlare(img, retinalMask, cfg);
    vig   = assessVignetting(img, retinalMask, cfg);
    contrast = assessContrast(img, retinalMask, cfg);
    retinal = assessRetinalArea(img, retinalMask, cfg);
    tmp = struct('focus',focus,'illumination',illum,'fov',fov,'glare',glare,'vignetting',vig,'contrast',contrast,'retinal',retinal);
    decision = classifyQuality(tmp, cfg);
    result = tmp;
    result.quality_status = decision.quality_status;
    result.quality_reasons = decision.quality_reasons;
    result.overall_quality_score = decision.overall_quality_score;
end
