function result = detectExudates(img, retinalMask, opticDiscResult, cfg)
% detectExudates  Exudate candidate segmentation (RESEARCH PROTOTYPE)
%
%   result = detectExudates(img, retinalMask, opticDiscResult, cfg)
%
%   Detects bright lesion candidates using brightness, local contrast,
%   and optic-disc exclusion. Primary validation: IDRiD EX annotations.

    if nargin < 4 || isempty(cfg), cfg = phase3Config(); end

    result = struct();
    result.candidates = {};
    result.candidate_count = 0;
    result.total_candidate_area = 0;
    result.area_fraction = 0;
    result.confidence = 0;
    result.exudate_mask = [];
    result.status = 'FAILED';

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
        R = R*255; G = G*255; B = B*255; gray = gray*255;
    end
    [H, W] = size(gray);

    if isempty(retinalMask) || ~isequal(size(retinalMask), [H W])
        retinalMask = true(H, W);
    end
    retinalMask = logical(retinalMask);

    try
        % Step 1: Bright region detection
        brightThresh = prctile(gray(retinalMask), cfg.ex.brightPrctile);
        brightMask = (gray >= brightThresh) & retinalMask;

        % Step 2: Local contrast enhancement
        % Use local standard deviation to find high-contrast bright regions
        localMean = imfilter(gray, fspecial('average', [15 15]), 'replicate');
        localVar = imfilter(gray.^2, fspecial('average', [15 15]), 'replicate') - localMean.^2;
        localStd = sqrt(max(0, localVar));
        highContrast = localStd > (cfg.ex.localContrastThresh * 255);
        brightMask = brightMask & highContrast;

        % Step 3: Exclude optic disc region
        if ~isempty(opticDiscResult) && opticDiscResult.detected
            [XX, YY] = meshgrid(1:W, 1:H);
            distFromOD = sqrt((XX - opticDiscResult.center_x).^2 + ...
                              (YY - opticDiscResult.center_y).^2);
            odRadius = opticDiscResult.radius * cfg.ex.odExclusionRadiusFrac;
            odRegion = distFromOD <= odRadius;
            brightMask = brightMask & ~odRegion;
        end

        % Step 4: Morphological cleanup
        brightMask = imopen(brightMask, strel('disk', cfg.ex.morphOpenRadius));
        brightMask = bwareaopen(brightMask, cfg.ex.minArea);

        % Remove too large
        CC = bwconncomp(brightMask);
        for k = 1:CC.NumObjects
            if numel(CC.PixelIdxList{k}) > cfg.ex.maxArea
                brightMask(CC.PixelIdxList{k}) = false;
            end
        end
        CC = bwconncomp(brightMask);

        % Step 5: Score candidates
        stats = regionprops(CC, gray, 'Centroid', 'Area', 'BoundingBox', 'MeanIntensity');
        candidates = {};
        for k = 1:numel(stats)
            s = stats(k);
            meanIntensity = s.MeanIntensity / 255;
            conf = meanIntensity * 0.7;
            candidates{end+1} = struct( ...
                'centroid_x', s.Centroid(1), ...
                'centroid_y', s.Centroid(2), ...
                'area', s.Area, ...
                'bounding_box', s.BoundingBox, ...
                'confidence', min(1, conf), ...
                'type', 'EX_CANDIDATE'); %#ok<AGROW>
        end

        totalArea = sum(cellfun(@(c) c.area, candidates));
        areaFraction = totalArea / max(1, nnz(retinalMask));
        avgConf = 0;
        if ~isempty(candidates)
            avgConf = mean(cellfun(@(c) c.confidence, candidates));
        end

        result.candidates = candidates;
        result.candidate_count = numel(candidates);
        result.total_candidate_area = totalArea;
        result.area_fraction = areaFraction;
        result.confidence = avgConf;
        result.exudate_mask = brightMask;
        result.status = 'COMPLETED';

    catch ME
        result.status = 'DETECTION_FAILED';
        result.error = ME.message;
    end
end
