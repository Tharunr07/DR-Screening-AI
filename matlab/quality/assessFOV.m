function metrics = assessFOV(img, retinalMask, cfg)
% assessFOV  Field of view / retinal area estimation
%
%   metrics = assessFOV(img, retinalMask, cfg)
%
%   Measures retinal area fraction, estimated diameter, completeness, truncation

    if nargin < 3 || isempty(cfg), cfg = qualityConfig(); end
    if nargin < 2 || isempty(retinalMask)
        retinalMask = estimateRetinalMask(img);
    end
    if ndims(img)==3 && size(img,3)==3
        H = size(img,1); W = size(img,2);
    else
        H = size(img,1); W = size(img,2);
    end
    if ~isequal(size(retinalMask), [H W])
        % Resize or fallback
        retinalMask = estimateRetinalMask(img);
    end
    retinalMask = logical(retinalMask);
    totalPixels = H*W;
    retinalPixels = nnz(retinalMask);
    areaFraction = retinalPixels / totalPixels;

    % Estimated diameter: sqrt(4*area/pi)  (equivalent circle diameter)
    diameter = sqrt(4 * retinalPixels / pi);
    % For elliptical, also compute major/minor via regionprops if available
    try
        stats = regionprops(retinalMask, 'MajorAxisLength','MinorAxisLength','Centroid','Eccentricity');
        if ~isempty(stats)
            major = stats(1).MajorAxisLength;
            minor = stats(1).MinorAxisLength;
            eccentricity = stats(1).Eccentricity;
            % Use mean diameter
            diameter = (major + minor)/2;
        else
            major = diameter; minor = diameter; eccentricity = 0;
        end
    catch
        major = diameter; minor = diameter; eccentricity = 0;
    end

    % Border completeness: compare perimeter of retinal mask to ideal ellipse/circle perimeter
    try
        perim = bwperim(retinalMask);
        perimCount = nnz(perim);
        % Ideal perimeter of ellipse: Ramanujan
        if major>0 && minor>0
            a = major/2; b = minor/2;
            idealPerim = pi * (3*(a+b) - sqrt((3*a+b)*(a+3*b)));
        else
            idealPerim = pi * diameter;
        end
        completeness = min(1, perimCount / (idealPerim + eps));
        % Alternative: if mask touches border heavily, completeness low
    catch
        completeness = 0.8;
        idealPerim = pi*diameter;
    end

    % Truncation: retinal mask touches image border?
    try
        borderMask = false(H,W);
        borderMask(1,:) = true; borderMask(end,:) = true;
        borderMask(:,1) = true; borderMask(:,end) = true;
        % Dilate border by 2 pixels
        borderMask = imdilate(borderMask, strel('disk',2));
        touch = retinalMask & borderMask;
        touchFraction = nnz(touch) / (nnz(bwperim(retinalMask))+eps);
        % Also fraction of retinal mask on border
        truncated = touchFraction > cfg.fov.truncation.borderTouchFraction;
    catch
        touchFraction = 0;
        truncated = false;
    end

    % Status
    if areaFraction >= cfg.fov.areaFraction.good
        areaStatus = "GOOD";
    elseif areaFraction >= cfg.fov.areaFraction.borderline
        areaStatus = "BORDERLINE";
    else
        areaStatus = "UNGRADABLE";
    end
    if completeness >= cfg.fov.completeness.good
        compStatus = "GOOD";
    elseif completeness >= cfg.fov.completeness.borderline
        compStatus = "BORDERLINE";
    else
        compStatus = "UNGRADABLE";
    end
    % Overall FOV status
    if areaStatus=="UNGRADABLE" || compStatus=="UNGRADABLE" || truncated && areaFraction < cfg.fov.areaFraction.good
        fovStatus = "UNGRADABLE";
    elseif areaStatus=="BORDERLINE" || compStatus=="BORDERLINE" || truncated
        fovStatus = "BORDERLINE";
    else
        fovStatus = "GOOD";
    end

    metrics = struct( ...
        'areaFraction', areaFraction, ...
        'diameter', diameter, ...
        'majorAxis', major, ...
        'minorAxis', minor, ...
        'eccentricity', eccentricity, ...
        'completeness', completeness, ...
        'idealPerim', idealPerim, ...
        'touchFraction', touchFraction, ...
        'truncated', truncated, ...
        'areaStatus', areaStatus, ...
        'compStatus', compStatus, ...
        'fov_status', fovStatus ...
    );
end
