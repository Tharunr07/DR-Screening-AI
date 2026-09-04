function result = detectFovea(img, opticDiscResult, cfg)
% detectFovea  Fovea localization / estimation (RESEARCH PROTOTYPE)
%
%   result = detectFovea(img, opticDiscResult, cfg)
%
%   Uses anatomical relationship to optic disc (temporal, ~2.5 disc diameters)
%   combined with image evidence (dark pit region).
%   Clearly distinguishes DETECTED vs ESTIMATED vs NOT_FOUND.

    if nargin < 3 || isempty(cfg), cfg = phase3Config(); end

    result = struct();
    result.detected = false;
    result.center_x = NaN;
    result.center_y = NaN;
    result.confidence = 0;
    result.method = 'NOT_FOUND';
    result.status = 'NOT_FOUND';

    % Convert to grayscale
    if ndims(img) == 3 && size(img, 3) == 3
        gray = 0.2989*double(img(:,:,1)) + 0.5870*double(img(:,:,2)) + 0.1140*double(img(:,:,3));
    else
        gray = double(img);
    end
    if max(gray(:)) <= 1, gray = gray * 255; end
    [H, W] = size(gray);

    % If no optic disc detected, cannot estimate fovea
    if isempty(opticDiscResult) || ~opticDiscResult.detected
        result.status = 'NO_OPTIC_DISC';
        result.method = 'NOT_FOUND';
        return;
    end

    od_x = opticDiscResult.center_x;
    od_y = opticDiscResult.center_y;
    od_r = opticDiscResult.radius;

    % Anatomical estimate: fovea is temporal to OD, ~2.5 disc diameters away
    % Temporal = toward image center (assume OD is nasal)
    % Typical angle: ~15 degrees below horizontal
    distPix = cfg.fovea.typicalDistanceDiscDiameters * od_r * 2;
    angleRad = deg2rad(cfg.fovea.typicalAngleDeg);

    % Estimate temporal direction (toward image center)
    dirX = (W/2) - od_x;
    dirY = (H/2) - od_y;
    dirNorm = sqrt(dirX^2 + dirY^2);
    if dirNorm > 0
        dirX = dirX / dirNorm;
        dirY = dirY / dirNorm;
    else
        dirX = 1; dirY = 0;
    end

    % Apply angle offset
    est_x = od_x + distPix * (dirX * cos(angleRad) + dirY * sin(angleRad));
    est_y = od_y + distPix * (-dirX * sin(angleRad) + dirY * cos(angleRad));

    % Clamp to image
    est_x = max(1, min(W, est_x));
    est_y = max(1, min(H, est_y));

    % Search for dark pit region near anatomical estimate
    searchR = cfg.fovea.searchRadiusFrac * min(H, W);
    [XX, YY] = meshgrid(1:W, 1:H);
    distFromEst = sqrt((XX - est_x).^2 + (YY - est_y).^2);
    searchMask = distFromEst <= searchR;

    % Fovea is typically the darkest region in the macula area
    try
        grayNorm = mat2gray(gray);
        % Weight by distance (closer = higher weight)
        weightMap = exp(-distFromEst.^2 / (2 * (searchR/3)^2));
        scoreMap = (1 - grayNorm) .* weightMap .* double(searchMask);

        [maxVal, maxIdx] = max(scoreMap(:));
        if maxVal > 0
            [fy, fx] = ind2sub([H, W], maxIdx);
            % Confidence based on how much darker the pit is
            localMean = mean(gray(searchMask));
            pitDarkness = (localMean - gray(fy, fx)) / (localMean + 1e-6);
            confidence = min(1, pitDarkness * 2) * opticDiscResult.confidence;

            if confidence > 0.3
                result.detected = true;
                result.center_x = fx;
                result.center_y = fy;
                result.confidence = confidence;
                result.method = 'DARK_PIT_SEARCH';
                result.status = 'DETECTED';
            else
                % Fall back to anatomical estimate
                result.detected = true;
                result.center_x = round(est_x);
                result.center_y = round(est_y);
                result.confidence = 0.3;
                result.method = 'ANATOMICAL_ESTIMATE';
                result.status = 'ESTIMATED';
            end
        else
            result.detected = true;
            result.center_x = round(est_x);
            result.center_y = round(est_y);
            result.confidence = 0.2;
            result.method = 'ANATOMICAL_ESTIMATE';
            result.status = 'ESTIMATED';
        end
    catch
        result.detected = true;
        result.center_x = round(est_x);
        result.center_y = round(est_y);
        result.confidence = 0.2;
        result.method = 'ANATOMICAL_ESTIMATE';
        result.status = 'ESTIMATED';
    end
end
