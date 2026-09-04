function metrics = assessVignetting(img, retinalMask, cfg)
% assessVignetting  Radial illumination falloff toward boundary
%
%   metrics = assessVignetting(img, retinalMask, cfg)
%
%   Uses retinal mask, computes center vs periphery mean intensity.
%   Does not assume perfect circle; uses distance transform from mask centroid.

    if nargin < 3 || isempty(cfg), cfg = qualityConfig(); end
    if nargin < 2 || isempty(retinalMask)
        retinalMask = estimateRetinalMask(img);
    end
    if ndims(img)==3 && size(img,3)==3
        gray = 0.2989*double(img(:,:,1)) + 0.5870*double(img(:,:,2)) + 0.1140*double(img(:,:,3));
    elseif ndims(img)==3 && size(img,3)==1
        gray = double(squeeze(img));
    else
        gray = double(img);
    end
    if max(gray(:)) <= 1, gray = gray*255; end
    retinalMask = logical(retinalMask);
    if nnz(retinalMask) < 100
        metrics = struct('score',0,'profile',zeros(1,cfg.vignetting.rings),'status',"GOOD");
        metrics.vignetting_status = "GOOD";
        return;
    end

    % Find centroid of retinal mask
    try
        stats = regionprops(retinalMask, 'Centroid');
        cx = stats(1).Centroid(1);
        cy = stats(1).Centroid(2);
    catch
        [Y,X] = find(retinalMask);
        cx = mean(X); cy = mean(Y);
    end
    [H,W] = size(gray);
    [XX,YY] = meshgrid(1:W, 1:H);
    dist = sqrt((XX - cx).^2 + (YY - cy).^2);
    % Max distance inside mask
    maxDist = max(dist(retinalMask));
    if maxDist < 1, maxDist = 1; end
    % Rings
    nRings = cfg.vignetting.rings;
    profile = zeros(1,nRings);
    for r=1:nRings
        rLow = (r-1)/nRings * maxDist;
        rHigh = r/nRings * maxDist;
        ringMask = retinalMask & (dist >= rLow) & (dist < rHigh);
        if nnz(ringMask) > 0
            profile(r) = mean(gray(ringMask));
        else
            profile(r) = NaN;
        end
    end
    % Vignetting score: (center - periphery)/center
    centerMean = profile(1);
    peripheryMean = profile(end);
    if isnan(centerMean) || centerMean < 1
        score = 0;
    elseif isnan(peripheryMean)
        score = 0;
    else
        score = (centerMean - peripheryMean) / (centerMean + 1e-6);
        % Clamp to [0,1] (negative means periphery brighter, not vignetting)
        score = max(0, min(1, score));
    end

    % Status
    if score <= cfg.vignetting.score.good
        status = "GOOD";
    elseif score <= cfg.vignetting.score.borderline
        status = "BORDERLINE";
    else
        status = "UNGRADABLE";
    end

    metrics = struct('score', score, 'profile', profile, 'centerMean', centerMean, 'peripheryMean', peripheryMean, 'status', status, 'vignetting_status', status);
end
