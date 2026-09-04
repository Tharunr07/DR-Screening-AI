function metrics = assessRetinalArea(img, retinalMask, cfg)
% assessRetinalArea  Retinal visibility / usable area
%
%   metrics = assessRetinalArea(img, retinalMask, cfg)
%
%   Distinguishes black background, usable retinal field, dark/obscured, saturated

    if nargin < 3 || isempty(cfg), cfg = qualityConfig(); end
    if nargin < 2 || isempty(retinalMask)
        retinalMask = estimateRetinalMask(img);
    end
    if ndims(img)==3 && size(img,3)==3
        gray = 0.2989*double(img(:,:,1)) + 0.5870*double(img(:,:,2)) + 0.1140*double(img(:,:,3));
        maxChan = max(max(double(img(:,:,1)), double(img(:,:,2))), double(img(:,:,3)));
    elseif ndims(img)==3 && size(img,3)==1
        gray = double(squeeze(img));
        maxChan = gray;
    else
        gray = double(img);
        maxChan = gray;
    end
    if max(gray(:)) <= 1, gray = gray*255; maxChan = maxChan*255; end
    [H,W] = size(gray);
    retinalMask = logical(retinalMask);
    totalPixels = H*W;
    retinalPixels = nnz(retinalMask);
    areaFraction = retinalPixels / totalPixels;

    % Visible retina: retinal pixels that are not severely dark (<30) nor saturated (>250)
    darkThresh = 30; satThresh = 250;
    darkInside = (gray < darkThresh) & retinalMask;
    satInside  = (maxChan > satThresh) & retinalMask;
    obscured = darkInside | satInside;
    visiblePixels = retinalPixels - nnz(obscured);
    if retinalPixels > 0
        visibleFraction = visiblePixels / retinalPixels;
        obscuredFraction = nnz(obscured) / retinalPixels;
        darkFraction = nnz(darkInside) / retinalPixels;
        satFraction = nnz(satInside) / retinalPixels;
    else
        visibleFraction = 0; obscuredFraction = 1; darkFraction = 0; satFraction = 0;
    end

    % Status
    if areaFraction >= cfg.retinal.areaFraction.good
        areaStatus = "GOOD";
    elseif areaFraction >= cfg.retinal.areaFraction.borderline
        areaStatus = "BORDERLINE";
    else
        areaStatus = "UNGRADABLE";
    end
    if visibleFraction >= cfg.retinal.visibleFraction.good
        visStatus = "GOOD";
    elseif visibleFraction >= cfg.retinal.visibleFraction.borderline
        visStatus = "BORDERLINE";
    else
        visStatus = "UNGRADABLE";
    end
    % Overall retinal status
    if areaStatus=="UNGRADABLE" || visStatus=="UNGRADABLE"
        retinalStatus = "UNGRADABLE";
    elseif areaStatus=="BORDERLINE" || visStatus=="BORDERLINE"
        retinalStatus = "BORDERLINE";
    else
        retinalStatus = "GOOD";
    end

    metrics = struct( ...
        'areaFraction', areaFraction, ...
        'retinalPixels', retinalPixels, ...
        'visibleFraction', visibleFraction, ...
        'obscuredFraction', obscuredFraction, ...
        'darkFraction', darkFraction, ...
        'satFraction', satFraction, ...
        'visiblePixels', visiblePixels, ...
        'areaStatus', areaStatus, ...
        'visStatus', visStatus, ...
        'retinal_status', retinalStatus ...
    );
end
