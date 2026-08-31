function result = detectOpticDisc(img, retinalMask, cfg)
% detectOpticDisc  Optic disc localization (RESEARCH PROTOTYPE)
%
%   result = detectOpticDisc(img, retinalMask, cfg)
%
%   Localizes optic disc using top-hat transform (local brightness peaks),
%   geometric constraints, and vessel convergence.
%   Does NOT treat every bright region as the optic disc.

    if nargin < 3 || isempty(cfg), cfg = phase3Config(); end

    result = struct();
    result.detected = false;
    result.center_x = NaN;
    result.center_y = NaN;
    result.radius = NaN;
    result.confidence = 0;
    result.method = 'NONE';
    result.status = 'NOT_DETECTED';

    % Convert to double
    if ndims(img) == 3 && size(img, 3) == 3
        R = double(img(:,:,1));
        G = double(img(:,:,2));
        B = double(img(:,:,3));
        gray = 0.2989*R + 0.5870*G + 0.1140*B;
    else
        gray = double(img);
        R = gray; G = gray; B = gray;
    end
    if max(gray(:)) <= 1
        gray = gray * 255; R = R * 255; G = G * 255; B = B * 255;
    end
    [H, W] = size(gray);

    if isempty(retinalMask) || ~isequal(size(retinalMask), [H W])
        retinalMask = true(H, W);
    end
    retinalMask = logical(retinalMask);
    if nnz(retinalMask) < 100
        retinalMask = true(H, W);
    end

    try
        % Step 1: Top-hat transform to find LOCAL brightness peaks
        % Use smaller kernel to detect OD-sized bright spots (not the whole retina)
        odExpectedSize = round(min(H, W) * 0.06);
        se = strel('disk', max(3, odExpectedSize));
        tophat = imtophat(gray, se);
        tophatNorm = tophat ./ (max(tophat(:)) + eps);

        % Step 2: Threshold top-hat to find bright spots
        tophatThresh = 0.3;
        brightMask = (tophatNorm >= tophatThresh) & retinalMask;

        % Morphological cleanup
        brightMask = bwareaopen(brightMask, round(0.0005 * H * W));
        brightMask = imclose(brightMask, strel('disk', 3));

        % Step 3: Find connected components
        CC = bwconncomp(brightMask);
        if CC.NumObjects == 0
            % Fallback: try lower threshold
            tophatThresh = 0.15;
            brightMask = (tophatNorm >= tophatThresh) & retinalMask;
            brightMask = bwareaopen(brightMask, round(0.0005 * H * W));
            CC = bwconncomp(brightMask);
        end

        if CC.NumObjects == 0
            result.status = 'NO_BRIGHT_REGIONS';
            result.method = 'TOPHAT';
            return;
        end

        stats = regionprops(CC, tophat, 'Centroid', 'Area', 'BoundingBox', ...
            'MajorAxisLength', 'MinorAxisLength', 'Eccentricity', 'MeanIntensity');

        % Step 4: Score each candidate
        bestScore = -Inf;
        bestIdx = 0;
        minDiam = cfg.opticDisc.minRadiusFrac * min(H, W);
        maxDiam = cfg.opticDisc.maxRadiusFrac * min(H, W);

        for k = 1:numel(stats)
            s = stats(k);
            diam = (s.MajorAxisLength + s.MinorAxisLength) / 2;

            % Size filter
            if diam < minDiam || diam > maxDiam
                continue;
            end

            % Circularity
            area = s.Area;
            perim = pi * diam;
            circularity = 4 * pi * area / (perim^2 + eps);

            % Brightness (top-hat intensity)
            brightness = s.MeanIntensity / (max(tophat(:)) + eps);

            % Position: prefer being inside the retinal mask center region
            positionScore = 1 - sqrt((s.Centroid(1) - W/2)^2 + (s.Centroid(2) - H/2)^2) / sqrt((W/2)^2 + (H/2)^2);

            % Size ratio to retinal area: OD should be small relative to retina
            sizeRatio = area / nnz(retinalMask);
            sizeScore = 1 - abs(sizeRatio - 0.01) / 0.01; % prefer ~1% of retina
            sizeScore = max(0, sizeScore);

            % Combined score
            score = brightness * 0.35 + circularity * 0.25 + positionScore * 0.2 + sizeScore * 0.2;

            if score > bestScore
                bestScore = score;
                bestIdx = k;
            end
        end

        if bestIdx == 0
            result.status = 'NO_VALID_CANDIDATES';
            result.method = 'TOPHAT';
            return;
        end

        % Extract best candidate
        s = stats(bestIdx);
        cx = s.Centroid(1);
        cy = s.Centroid(2);
        radius = (s.MajorAxisLength + s.MinorAxisLength) / 4;
        confidence = min(1, bestScore);

        % Step 5: Refine with vessel convergence check
        try
            [Gx, Gy] = imgradientxy(gray, 'sobel');
            Gmag = sqrt(Gx.^2 + Gy.^2);
            r1 = radius * 0.8;
            r2 = radius * 2.5;
            [XX, YY] = meshgrid(1:W, 1:H);
            distFromOD = sqrt((XX - cx).^2 + (YY - cy).^2);
            ring = (distFromOD >= r1) & (distFromOD <= r2) & retinalMask;
            if nnz(ring) > 0
                vesselLike = Gmag > prctile(Gmag(retinalMask), 80);
                convergence = nnz(vesselLike & ring) / nnz(ring);
                if convergence > cfg.opticDisc.vesselConvergenceThresh
                    confidence = min(1, confidence + 0.15);
                end
            end
        catch
        end

        result.detected = true;
        result.center_x = cx;
        result.center_y = cy;
        result.radius = radius;
        result.confidence = confidence;
        result.method = 'TOPHAT_GEOMETRY';
        result.status = 'DETECTED';

    catch ME
        result.status = 'DETECTION_FAILED';
        result.method = 'TOPHAT';
        result.error = ME.message;
    end
end
