function metrics = assessIllumination(img, retinalMask, cfg)
% assessIllumination  Illumination quality inside retinal field
%
%   metrics = assessIllumination(img, retinalMask, cfg)
%
%   Measures mean, std, uniformity, dark/saturated fractions
%   Avoids judging black background (uses retinalMask)

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
    if ~isequal(size(retinalMask), size(gray))
        retinalMask = true(size(gray));
    end
    retinalMask = logical(retinalMask);
    vals = gray(retinalMask);
    if isempty(vals)
        vals = gray(:);
        retinalMask = true(size(gray));
    end

    meanVal = mean(vals);
    stdVal  = std(double(vals));
    % Uniformity = std / mean  (higher = less uniform)
    uniformity = stdVal / (meanVal + 1e-6);
    % Dark / saturated fractions
    darkFraction = sum(vals < 30) / numel(vals);
    saturatedFraction = sum(vals > 250) / numel(vals);
    % Percentiles
    p5  = prctile(vals,5);
    p50 = prctile(vals,50);
    p95 = prctile(vals,95);
    % Status
    % Mean check
    if meanVal < cfg.illumination.mean.low
        meanStatus = "DARK";
    elseif meanVal > cfg.illumination.mean.high
        meanStatus = "BRIGHT";
    else
        meanStatus = "GOOD";
    end
    % Dark fraction
    if darkFraction <= cfg.illumination.darkFraction.good
        darkStatus = "GOOD";
    elseif darkFraction <= cfg.illumination.darkFraction.borderline
        darkStatus = "BORDERLINE";
    else
        darkStatus = "UNGRADABLE";
    end
    % Saturated
    if saturatedFraction <= cfg.illumination.saturatedFraction.good
        satStatus = "GOOD";
    elseif saturatedFraction <= cfg.illumination.saturatedFraction.borderline
        satStatus = "BORDERLINE";
    else
        satStatus = "UNGRADABLE";
    end
    % Uniformity
    if uniformity <= cfg.illumination.uniformity.good
        uniStatus = "GOOD";
    elseif uniformity <= cfg.illumination.uniformity.borderline
        uniStatus = "BORDERLINE";
    else
        uniStatus = "UNGRADABLE";
    end

    statuses = [darkStatus, satStatus, uniStatus];
    % Mean dark/bright is not directly UNGRADABLE unless extreme
    if any(statuses=="UNGRADABLE") || meanStatus=="DARK" && darkFraction>0.25 || meanStatus=="BRIGHT" && saturatedFraction>0.03
        illumStatus = "UNGRADABLE";
    elseif any(statuses=="BORDERLINE") || meanStatus~="GOOD"
        illumStatus = "BORDERLINE";
    else
        illumStatus = "GOOD";
    end

    metrics = struct( ...
        'mean', meanVal, ...
        'std', stdVal, ...
        'uniformity', uniformity, ...
        'darkFraction', darkFraction, ...
        'saturatedFraction', saturatedFraction, ...
        'p5', p5, 'p50', p50, 'p95', p95, ...
        'meanStatus', meanStatus, ...
        'darkStatus', darkStatus, ...
        'satStatus', satStatus, ...
        'uniStatus', uniStatus, ...
        'illumination_status', illumStatus ...
    );
end
