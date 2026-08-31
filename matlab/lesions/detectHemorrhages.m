function result = detectHemorrhages(img, retinalMask, vesselMask, cfg)
% detectHemorrhages  Hemorrhage candidate detection (RESEARCH PROTOTYPE)
%
%   result = detectHemorrhages(img, retinalMask, vesselMask, cfg)
%
%   Detects dark/red lesion candidates using color, morphology, and vessel filtering.
%   Primary validation: IDRiD HE annotations.

    if nargin < 4 || isempty(cfg), cfg = phase3Config(); end

    result = struct();
    result.candidates = {};
    result.candidate_count = 0;
    result.total_candidate_area = 0;
    result.confidence = 0;
    result.candidate_mask = [];
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
    if isempty(vesselMask) || ~isequal(size(vesselMask), [H W])
        vesselMask = false(H, W);
    end
    retinalMask = logical(retinalMask);
    vesselMask = logical(vesselMask);

    try
        % Step 1: Dark region detection
        % Hemorrhages are dark in all channels, especially green
        darkGray = gray < cfg.he.darkIntensityThresh;
        darkGreen = G < (cfg.he.greenDarkThresh * 255);

        % Combined: both gray and green must be dark
        darkMask = darkGray & darkGreen & retinalMask;

        % Step 2: Morphological operations to enhance blob-like structures
        % Close small gaps
        darkMask = imclose(darkMask, strel('disk', cfg.he.morphCloseRadius));
        % Open to remove noise
        darkMask = imopen(darkMask, strel('disk', cfg.he.morphOpenRadius));

        % Step 3: Multi-scale detection
        candidateMask = false(H, W);
        for scale = 1:3
            se = strel('disk', scale);
            processed = imclose(darkMask, se);
            processed = imopen(processed, strel('disk', max(1, scale-1)));
            candidateMask = candidateMask | processed;
        end

        % Step 4: Remove vessel regions
        if nnz(vesselMask) > 0
            vesselDilated = imdilate(vesselMask, strel('disk', cfg.he.vesselExclusionDist));
            candidateMask = candidateMask & ~vesselDilated;
        end

        % Step 5: Area filtering
        candidateMask = bwareaopen(candidateMask, cfg.he.minArea);

        % Remove too large
        CC = bwconncomp(candidateMask);
        for k = 1:CC.NumObjects
            if numel(CC.PixelIdxList{k}) > cfg.he.maxArea
                candidateMask(CC.PixelIdxList{k}) = false;
            end
        end
        CC = bwconncomp(candidateMask);

        % Step 6: Score candidates
        stats = regionprops(CC, gray, 'Centroid', 'Area', 'BoundingBox', 'MeanIntensity');
        candidates = {};
        for k = 1:numel(stats)
            s = stats(k);
            meanIntensity = s.MeanIntensity / 255;
            conf = (1 - meanIntensity) * 0.8;
            candidates{end+1} = struct( ...
                'centroid_x', s.Centroid(1), ...
                'centroid_y', s.Centroid(2), ...
                'area', s.Area, ...
                'bounding_box', s.BoundingBox, ...
                'confidence', min(1, conf), ...
                'type', 'HE_CANDIDATE'); %#ok<AGROW>
        end

        totalArea = sum(cellfun(@(c) c.area, candidates));
        avgConf = 0;
        if ~isempty(candidates)
            avgConf = mean(cellfun(@(c) c.confidence, candidates));
        end

        result.candidates = candidates;
        result.candidate_count = numel(candidates);
        result.total_candidate_area = totalArea;
        result.confidence = avgConf;
        result.candidate_mask = candidateMask;
        result.status = 'COMPLETED';

    catch ME
        result.status = 'DETECTION_FAILED';
        result.error = ME.message;
    end
end
