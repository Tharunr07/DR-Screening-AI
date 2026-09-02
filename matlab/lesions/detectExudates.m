function evidence = detectExudates(img, varargin)
% detectExudates  Detect exudate candidates in fundus images
%
%   evidence = detectExudates(img)
%
%   Exudates appear as bright, yellow-white lesions.
%   Detection uses adaptive thresholding, color segmentation,
%   and morphological operations.
%
%   Input:
%       img - RGB fundus image (uint8 or double)
%
%   Name-Value Pairs:
%       'MinArea' - Minimum lesion area in pixels (default: 10)
%       'MaxArea' - Maximum lesion area in pixels (default: 3000)
%
%   Output:
%       evidence - Struct with fields:
%           .count    - Number of detected candidates
%           .mask     - Binary mask of detected candidates
%           .locations - Nx2 matrix of [row, col] centroids
%           .areas    - N-element vector of areas
%           .totalArea - Total exudate area in pixels
%           .confidence - Detection confidence (0-1)

    p = inputParser;
    addRequired(p, 'img');
    addParameter(p, 'MinArea', 10, @isnumeric);
    addParameter(p, 'MaxArea', 3000, @isnumeric);
    parse(p, img, varargin{:});

    % Initialize output
    evidence = struct();
    evidence.count = 0;
    evidence.mask = false(size(img, 1), size(img, 2));
    evidence.locations = [];
    evidence.areas = [];
    evidence.totalArea = 0;
    evidence.confidence = 0;

    try
        % Convert to double if needed
        if isa(img, 'uint8')
            imgDouble = double(img) / 255;
        else
            imgDouble = double(img);
        end

        % Convert to HSV for color segmentation
        hsvImg = rgb2hsv(imgDouble);

        hue = hsvImg(:,:,1);
        sat = hsvImg(:,:,2);
        val = hsvImg(:,:,3);

        % Convert to gray for adaptive thresholding
        gray = rgb2gray(imgDouble);

        % === Step 1: Multi-criteria bright lesion detection ===

        % Criterion 1: HSV-based (original approach, relaxed)
        brightHSV = val > 0.6 & sat < 0.5;

        % Criterion 2: Adaptive thresholding on green channel
        % Green channel often shows exudates best
        greenChannel = imgDouble(:,:,2);
        greenAdaptive = adaptthresh(greenChannel, 0.4, 'NeighborhoodSize', 51);
        brightAdaptive = greenChannel > greenAdaptive & greenChannel > 0.5;

        % Criterion 3: Intensity-based with local contrast
        % Exudates are brighter than local background
        meanFilter = fspecial('average', [25 25]);
        localMean = imfilter(gray, meanFilter);
        localContrast = gray - localMean;
        brightLocal = localContrast > 0.1 & gray > 0.45;

        % Combine criteria (any two must agree)
        brightMask = (brightHSV & brightAdaptive) | ...
                     (brightHSV & brightLocal) | ...
                     (brightAdaptive & brightLocal);

        % === Step 2: Optic disc removal ===
        % Use intensity-based optic disc detection
        discMask = detectOpticDisc(imgDouble);
        brightMask(discMask) = false;

        % === Step 3: Vessel masking ===
        % Remove vessel pixels (vessels can be bright)
        vesselMask = detectVesselsSimple(imgDouble);
        brightMask(vesselMask) = false;

        % === Step 4: Morphological cleanup ===
        % Close small gaps
        se = strel('disk', 2);
        brightMask = imclose(brightMask, se);

        % Fill holes in regions
        brightMask = imfill(brightMask, 'holes');

        % Remove small objects
        brightMask = bwareaopen(brightMask, p.Results.MinArea);

        % === Step 5: Region filtering ===
        stats = regionprops(brightMask, 'Area', 'Centroid', 'Perimeter', 'Eccentricity');

        if ~isempty(stats)
            areas = [stats.Area];

            % Filter by area
            areaMask = areas >= p.Results.MinArea & areas <= p.Results.MaxArea;

            % Filter by eccentricity (exudates are roughly circular/oval)
            if isfield(stats, 'Eccentricity')
                ecc = [stats.Eccentricity];
                eccMask = ecc < 0.95;  % Not too elongated
                areaMask = areaMask & eccMask;
            end

            if any(areaMask)
                validStats = stats(areaMask);
                evidence.count = numel(validStats);
                evidence.areas = [validStats.Area];
                evidence.totalArea = sum(evidence.areas);
                evidence.locations = reshape([validStats.Centroid], 2, [])';

                % Create mask
                evidence.mask = false(size(img, 1), size(img, 2));
                labeled = bwlabel(brightMask);
                for i = 1:numel(validStats)
                    idx = find(areaMask, i, 'first');
                    evidence.mask(labeled == idx) = true;
                end

                % Confidence based on count, area, and local contrast
                areaScore = min(1.0, evidence.totalArea / 5000);
                countScore = min(1.0, evidence.count / 10);
                evidence.confidence = 0.5 * areaScore + 0.5 * countScore;
            end
        end

    catch
        % Return empty evidence on error
        evidence.count = 0;
        evidence.mask = false(size(img, 1), size(img, 2));
        evidence.locations = [];
        evidence.areas = [];
        evidence.totalArea = 0;
        evidence.confidence = 0;
    end
end

function discMask = detectOpticDisc(imgDouble)
% detectOpticDisc  Detect optic disc using intensity and circularity

    [rows, cols, ~] = size(imgDouble);
    gray = rgb2gray(imgDouble);

    % The optic disc is typically the brightest large circular region
    % Use adaptive threshold to find bright regions
    brightThresh = gray > 0.7;

    % Morphological operations to clean up
    se = strel('disk', 5);
    brightThresh = imclose(brightThresh, se);
    brightThresh = imfill(brightThresh, 'holes');

    % Find largest bright region (likely optic disc)
    stats = regionprops(brightThresh, 'Area', 'Centroid', 'EquivDiameter');

    discMask = false(rows, cols);

    if ~isempty(stats)
        % Get largest region
        areas = [stats.Area];
        [~, maxIdx] = max(areas);

        % Estimate disc radius
        discRadius = stats(maxIdx).EquivDiameter / 2;
        center = stats(maxIdx).Centroid;

        % Create disc mask (slightly larger to ensure removal)
        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - center(1)).^2 + (Y - center(2)).^2) < (discRadius * 1.2)^2;
    else
        % Fallback: assume center of image
        centerR = round(rows / 2);
        centerC = round(cols / 2);
        discRadius = round(min(rows, cols) / 8);
        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - centerC).^2 + (Y - centerR).^2) < discRadius^2;
    end
end

function vesselMask = detectVesselsSimple(imgDouble)
% detectVesselsSimple  Simple vessel detection using morphological filtering

    % Use green channel (vessels are dark in green)
    greenChannel = imgDouble(:,:,2);

    % Vessels are darker than background
    vesselMask = greenChannel < 0.4;

    % Morphological filtering to extract vessel-like structures
    % Use line structuring elements at multiple angles
    se1 = strel('line', 5, 0);
    se2 = strel('line', 5, 45);
    se3 = strel('line', 5, 90);
    se4 = strel('line', 5, 135);

    % Open with line elements to keep vessel-like structures
    vessel1 = imopen(vesselMask, se1);
    vessel2 = imopen(vesselMask, se2);
    vessel3 = imopen(vesselMask, se3);
    vessel4 = imopen(vesselMask, se4);

    % Combine
    vesselMask = vessel1 | vessel2 | vessel3 | vessel4;

    % Dilate slightly to cover vessel edges
    se = strel('disk', 1);
    vesselMask = imdilate(vesselMask, se);
end
