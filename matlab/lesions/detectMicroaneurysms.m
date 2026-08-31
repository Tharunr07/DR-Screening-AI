function result = detectMicroaneurysms(img, retinalMask, vesselMask, cfg)
% detectMicroaneurysms  Microaneurysm candidate detection (RESEARCH PROTOTYPE)
%
%   result = detectMicroaneurysms(img, retinalMask, vesselMask, cfg)
%
%   Detects small dark/red lesion candidates using green-channel analysis,
%   background normalization, morphological filtering, and connected components.
%   Primary validation: IDRiD MA annotations.

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
    else
        gray = double(img);
        R = gray; G = gray; B = gray;
    end
    if max(G(:)) <= 1, R = R*255; G = G*255; B = B*255; end
    [H, W] = size(G);

    if isempty(retinalMask) || ~isequal(size(retinalMask), [H W])
        retinalMask = true(H, W);
    end
    if isempty(vesselMask) || ~isequal(size(vesselMask), [H W])
        vesselMask = false(H, W);
    end
    retinalMask = logical(retinalMask);
    vesselMask = logical(vesselMask);

    try
        % Step 1: Green channel background normalization
        sigma = cfg.ma.greenBackgroundSigma;
        if exist('imgaussfilt', 'file')
            bg = imgaussfilt(G, sigma);
        else
            h = fspecial('gaussian', round(6*sigma)+1, sigma);
            bg = imfilter(G, h, 'replicate');
        end
        normGreen = G ./ (bg + 1e-6);

        % Step 2: Dark region detection in green channel
        % MA appear as dark spots in green channel
        darkThresh = 1 - cfg.ma.contrastThresh;
        darkMask = (normGreen < darkThresh) & retinalMask;

        % Step 3: Multi-scale blob detection
        candidateMask = false(H, W);
        for scale = cfg.ma.detectionScales
            % Morphological closing to enhance blob-like structures
            se = strel('disk', scale);
            closed = imclose(darkMask, se);
            % Open to remove elongated structures (vessels)
            opened = imopen(closed, strel('disk', max(1, scale-1)));
            candidateMask = candidateMask | opened;
        end

        % Step 4: Remove vessel regions
        if nnz(vesselMask) > 0
            vesselDilated = imdilate(vesselMask, strel('disk', cfg.ma.vesselExclusionDist));
            candidateMask = candidateMask & ~vesselDilated;
        end

        % Step 5: Area filtering
        candidateMask = bwareaopen(candidateMask, cfg.ma.minArea);

        % Remove components larger than max
        CC = bwconncomp(candidateMask);
        for k = 1:CC.NumObjects
            if numel(CC.PixelIdxList{k}) > cfg.ma.maxArea
                candidateMask(CC.PixelIdxList{k}) = false;
            end
        end
        CC = bwconncomp(candidateMask);

        % Step 6: Circularity filter
        stats = regionprops(CC, 'Centroid', 'Area', 'BoundingBox', 'Perimeter');
        validIdx = [];
        candidates = {};
        for k = 1:numel(stats)
            s = stats(k);
            circ = 4 * pi * s.Area / (s.Perimeter^2 + eps);
            if circ >= cfg.ma.circularityMin
                validIdx(end+1) = k; %#ok<AGROW>
                % Confidence based on darkness and circularity
                regionMask = false(H, W);
                regionMask(CC.PixelIdxList{k}) = true;
                meanGreen = mean(G(regionMask)) / 255;
                conf = (1 - meanGreen) * circ;
                candidates{end+1} = struct( ...
                    'centroid_x', s.Centroid(1), ...
                    'centroid_y', s.Centroid(2), ...
                    'area', s.Area, ...
                    'bounding_box', s.BoundingBox, ...
                    'confidence', min(1, conf), ...
                    'type', 'MA_CANDIDATE'); %#ok<AGROW>
            end
        end

        % Filter candidate mask to valid only
        if ~isempty(validIdx)
            validMask = false(H, W);
            for k = validIdx
                validMask(CC.PixelIdxList{k}) = true;
            end
            candidateMask = validMask;
        else
            candidateMask = false(H, W);
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
