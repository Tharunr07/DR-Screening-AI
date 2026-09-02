function evidence = detectMicroaneurysms(img, varargin)
% detectMicroaneurysms  Detect microaneurysm candidates in fundus images
%
%   evidence = detectMicroaneurysms(img)
%
%   Microaneurysms appear as small, dark-red, round lesions.
%   Detection uses morphological operations on the red channel
%   with vessel masking and boundary rejection.
%
%   Input:
%       img - RGB fundus image (uint8 or double)
%
%   Name-Value Pairs:
%       'MinArea' - Minimum lesion area in pixels (default: 5)
%       'MaxArea' - Maximum lesion area in pixels (default: 50)
%
%   Output:
%       evidence - Struct with fields:
%           .count    - Number of detected candidates
%           .mask     - Binary mask of detected candidates
%           .locations - Nx2 matrix of [row, col] centroids
%           .areas    - N-element vector of areas
%           .confidence - Detection confidence (0-1)

    p = inputParser;
    addRequired(p, 'img');
    addParameter(p, 'MinArea', 5, @isnumeric);
    addParameter(p, 'MaxArea', 50, @isnumeric);
    parse(p, img, varargin{:});

    % Initialize output
    evidence = struct();
    evidence.count = 0;
    evidence.mask = false(size(img, 1), size(img, 2));
    evidence.locations = [];
    evidence.areas = [];
    evidence.confidence = 0;

    try
        % Convert to double if needed
        if isa(img, 'uint8')
            imgDouble = double(img) / 255;
        else
            imgDouble = double(img);
        end

        [rows, cols, ~] = size(imgDouble);

        % Step 1: Detect and exclude vessels
        vesselMask = detectVesselsForMA(imgDouble);

        % Step 2: Detect and exclude optic disc
        discMask = detectOpticDiscForMA(imgDouble);

        % Step 3: Extract red channel (microaneurysms are more visible in red)
        redChannel = imgDouble(:,:,1);

        % Step 4: Enhance microaneurysms using morphological top-hat
        se = strel('disk', 3);
        tophatImg = imtophat(redChannel, se);

        % Step 5: Adaptive thresholding
        threshold = graythresh(tophatImg);
        candidates = tophatImg > threshold * 2.0;

        % Step 6: Exclude vessels and optic disc
        candidates(vesselMask) = false;
        candidates(discMask) = false;

        % Step 7: Boundary rejection (remove edge candidates)
        edgeMargin = 5;
        candidates(1:edgeMargin, :) = false;
        candidates(rows-edgeMargin+1:rows, :) = false;
        candidates(:, 1:edgeMargin) = false;
        candidates(:, cols-edgeMargin+1:cols) = false;

        % Step 8: Morphological cleanup
        se = strel('disk', 1);
        candidates = imopen(candidates, se);
        candidates = imclose(candidates, se);

        % Step 9: Remove small objects
        candidates = bwareaopen(candidates, p.Results.MinArea);

        % Step 10: Filter by region properties
        stats = regionprops(candidates, 'Area', 'Centroid', 'Perimeter', ...
            'Eccentricity', 'Solidity');

        if ~isempty(stats)
            areas = [stats.Area];

            % Filter by area
            areaMask = areas >= p.Results.MinArea & areas <= p.Results.MaxArea;

            % Filter by eccentricity (microaneurysms are roughly circular)
            if isfield(stats, 'Eccentricity')
                ecc = [stats.Eccentricity];
                eccMask = ecc < 0.7;  % Not too elongated
                areaMask = areaMask & eccMask;
            end

            % Filter by solidity (compactness)
            if isfield(stats, 'Solidity')
                sol = [stats.Solidity];
                solMask = sol > 0.5;  % Reasonably compact
                areaMask = areaMask & solMask;
            end

            % Filter by local contrast
            localContrastMask = true(size(areaMask));
            for i = 1:numel(stats)
                if areaMask(i)
                    r = round(stats(i).Centroid(2));
                    c = round(stats(i).Centroid(1));
                    r = max(1, min(r, rows));
                    c = max(1, min(c, cols));

                    % Check local contrast around candidate
                    rMin = max(1, r-10);
                    rMax = min(rows, r+10);
                    cMin = max(1, c-10);
                    cMax = min(cols, c+10);

                    localRegion = redChannel(rMin:rMax, cMin:cMax);
                    localMean = mean(localRegion(:));
                    localStd = std(localRegion(:));

                    % Candidate should be darker than local background
                    % (in red channel, MA appears as dark spot)
                    candidateVal = redChannel(r, c);
                    if candidateVal > localMean + localStd
                        localContrastMask(i) = false;
                    end
                end
            end

            % Combine all filters
            validMask = areaMask & localContrastMask;

            if any(validMask)
                validStats = stats(validMask);
                evidence.count = numel(validStats);
                evidence.areas = [validStats.Area];
                evidence.locations = reshape([validStats.Centroid], 2, [])';

                % Create mask
                evidence.mask = false(rows, cols);
                labeled = bwlabel(candidates);
                for i = 1:numel(validStats)
                    idx = find(validMask, i, 'first');
                    evidence.mask(labeled == idx) = true;
                end

                % Confidence based on count and quality metrics
                countScore = min(1.0, evidence.count / 10);
                areaScore = min(1.0, sum(evidence.areas) / 200);
                evidence.confidence = 0.5 * countScore + 0.5 * areaScore;
            end
        end

    catch
        % Return empty evidence on error
        evidence.count = 0;
        evidence.mask = false(size(img, 1), size(img, 2));
        evidence.locations = [];
        evidence.areas = [];
        evidence.confidence = 0;
    end
end

function vesselMask = detectVesselsForMA(imgDouble)
% detectVesselsForMA  Detect vessels for exclusion from MA detection

    greenChannel = imgDouble(:,:,2);

    % Vessels are dark in green channel
    vesselMask = greenChannel < 0.4;

    % Use morphological filtering to extract vessel structures
    se1 = strel('line', 10, 0);
    se2 = strel('line', 10, 60);
    se3 = strel('line', 10, 120);

    vessel1 = imopen(vesselMask, se1);
    vessel2 = imopen(vesselMask, se2);
    vessel3 = imopen(vesselMask, se3);

    vesselMask = vessel1 | vessel2 | vessel3;

    % Dilate to cover vessel edges
    se = strel('disk', 2);
    vesselMask = imdilate(vesselMask, se);
end

function discMask = detectOpticDiscForMA(imgDouble)
% detectOpticDiscForMA  Detect optic disc for exclusion from MA detection

    [rows, cols, ~] = size(imgDouble);
    gray = rgb2gray(imgDouble);

    % Optic disc is brightest large region
    brightThresh = gray > 0.7;

    se = strel('disk', 5);
    brightThresh = imclose(brightThresh, se);
    brightThresh = imfill(brightThresh, 'holes');

    stats = regionprops(brightThresh, 'Area', 'Centroid', 'EquivDiameter');

    discMask = false(rows, cols);

    if ~isempty(stats)
        areas = [stats.Area];
        [~, maxIdx] = max(areas);

        discRadius = stats(maxIdx).EquivDiameter / 2;
        center = stats(maxIdx).Centroid;

        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - center(1)).^2 + (Y - center(2)).^2) < (discRadius * 1.3)^2;
    else
        centerR = round(rows / 2);
        centerC = round(cols / 2);
        discRadius = round(min(rows, cols) / 8);
        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - centerC).^2 + (Y - centerR).^2) < discRadius^2;
    end
end
