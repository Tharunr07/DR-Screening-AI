function result = detectRetinalFOV(img, cfg)
% detectRetinalFOV  Retinal field / FOV segmentation (RESEARCH PROTOTYPE)
%
%   result = detectRetinalFOV(img)
%   result = detectRetinalFOV(img, cfg)
%
%   Detects the circular/elliptical retinal field, estimates center and radius.
%   Returns binary mask, center, radius, area fraction, and status.
%   Deterministic fallback when segmentation fails.

    if nargin < 2 || isempty(cfg), cfg = phase3Config(); end

    result = struct();
    result.mask = [];
    result.center_x = NaN;
    result.center_y = NaN;
    result.radius = NaN;
    result.major_axis = NaN;
    result.minor_axis = NaN;
    result.eccentricity = NaN;
    result.area_fraction = NaN;
    result.status = 'FAILED';
    result.method = 'NONE';

    % Convert to grayscale double
    if ndims(img) == 3 && size(img, 3) == 3
        gray = 0.2989*double(img(:,:,1)) + 0.5870*double(img(:,:,2)) + 0.1140*double(img(:,:,3));
        green = double(img(:,:,2));
    elseif ndims(img) == 3 && size(img, 3) == 1
        gray = double(squeeze(img));
        green = gray;
    else
        gray = double(img);
        green = gray;
    end
    if max(gray(:)) <= 1, gray = gray * 255; green = green * 255; end
    [H, W] = size(gray);

    % Method 1: Otsu threshold with clamped range
    try
        level = graythresh(uint8(gray));
        thresh = level * 255;
        thresh = max(cfg.fov.otsuClampLow, min(cfg.fov.otsuClampHigh, thresh));
    catch
        thresh = cfg.fov.fallbackThreshold;
    end
    bw = gray > thresh;

    % Morphological cleanup
    try
        bw = bwareaopen(bw, round(cfg.fov.minComponentFraction * H * W));
        bw = imfill(bw, 'holes');
        se = strel('disk', cfg.fov.morphDiskRadius);
        bw = imclose(bw, se);
        bw = imopen(bw, strel('disk', 3));

        % Largest connected component
        CC = bwconncomp(bw);
        if CC.NumObjects > 1
            numPixels = cellfun(@numel, CC.PixelIdxList);
            [~, idx] = max(numPixels);
            bw2 = false(size(bw));
            bw2(CC.PixelIdxList{idx}) = true;
            bw = bw2;
        end

        % If too large (>92%), try higher threshold
        areaFrac = nnz(bw) / (H * W);
        if areaFrac > 0.92
            bw2 = gray > 30;
            bw2 = bwareaopen(bw2, round(cfg.fov.minComponentFraction * H * W));
            bw2 = imfill(bw2, 'holes');
            newFrac = nnz(bw2) / (H * W);
            if newFrac < 0.92 && newFrac > cfg.fov.minAreaFraction
                bw = bw2;
                CC = bwconncomp(bw);
                if CC.NumObjects > 1
                    numPixels = cellfun(@numel, CC.PixelIdxList);
                    [~, idx] = max(numPixels);
                    bw2 = false(size(bw));
                    bw2(CC.PixelIdxList{idx}) = true;
                    bw = bw2;
                end
            end
        end

        % Fallback if too small
        if nnz(bw) / (H * W) < cfg.fov.minAreaFraction
            bw = gray > cfg.fov.fallbackThreshold;
            bw = bwareaopen(bw, round(0.002 * H * W));
            bw = imfill(bw, 'holes');
            CC = bwconncomp(bw);
            if CC.NumObjects > 0
                numPixels = cellfun(@numel, CC.PixelIdxList);
                [~, idx] = max(numPixels);
                bw2 = false(size(bw));
                bw2(CC.PixelIdxList{idx}) = true;
                bw = bw2;
            end
        end
    catch
        bw = gray > cfg.fov.fallbackThreshold;
    end

    % Ensure minimum mask
    mask = logical(bw);
    if nnz(mask) < 500
        mask = gray > 10;
        if nnz(mask) < 500
            mask = true(H, W);
        end
    end

    % Compute geometry
    area_fraction = nnz(mask) / (H * W);
    try
        stats = regionprops(mask, 'Centroid', 'MajorAxisLength', 'MinorAxisLength', 'Eccentricity');
        if ~isempty(stats)
            cx = stats(1).Centroid(1);
            cy = stats(1).Centroid(2);
            major = stats(1).MajorAxisLength;
            minor = stats(1).MinorAxisLength;
            ecc = stats(1).Eccentricity;
            radius = (major + minor) / 4; % average radius
        else
            [Y, X] = find(mask);
            cx = mean(X); cy = mean(Y);
            major = sqrt(4 * nnz(mask) / pi);
            minor = major; ecc = 0;
            radius = major / 2;
        end
    catch
        [Y, X] = find(mask);
        cx = mean(X); cy = mean(Y);
        major = sqrt(4 * nnz(mask) / pi);
        minor = major; ecc = 0;
        radius = major / 2;
    end

    % Determine status
    if area_fraction >= 0.18
        status = 'GOOD';
    elseif area_fraction >= 0.10
        status = 'BORDERLINE';
    else
        status = 'POOR';
    end

    result.mask = mask;
    result.center_x = cx;
    result.center_y = cy;
    result.radius = radius;
    result.major_axis = major;
    result.minor_axis = minor;
    result.eccentricity = ecc;
    result.area_fraction = area_fraction;
    result.status = status;
    result.method = 'OTSU_MORPHOLOGY';
    result.H = H;
    result.W = W;
end
