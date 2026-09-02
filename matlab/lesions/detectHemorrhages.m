function evidence = detectHemorrhages(img, varargin)
% detectHemorrhages  Detect hemorrhage candidates in fundus images
%
%   evidence = detectHemorrhages(img)
%
%   Hemorrhages appear as dark/red patches larger than microaneurysms.
%   Detection uses color segmentation and morphological operations.
%
%   Input:
%       img - RGB fundus image (uint8 or double)
%
%   Name-Value Pairs:
%       'MinArea' - Minimum lesion area in pixels (default: 50)
%       'MaxArea' - Maximum lesion area in pixels (default: 2000)
%
%   Output:
%       evidence - Struct with fields:
%           .count    - Number of detected candidates
%           .mask     - Binary mask of detected candidates
%           .locations - Nx2 matrix of [row, col] centroids
%           .areas    - N-element vector of areas
%           .totalArea - Total hemorrhage area in pixels
%           .confidence - Detection confidence (0-1)

    p = inputParser;
    addRequired(p, 'img');
    addParameter(p, 'MinArea', 50, @isnumeric);
    addParameter(p, 'MaxArea', 2000, @isnumeric);
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

        % Hemorrhages are dark red:
        % - Low value (dark)
        % - Hue in red range (0-0.1 or 0.9-1.0)
        % - Moderate saturation

        hue = hsvImg(:,:,1);
        sat = hsvImg(:,:,2);
        val = hsvImg(:,:,3);

        % Red hue mask (wraps around 0/1)
        redMask = (hue < 0.1) | (hue > 0.9);

        % Dark regions
        darkMask = val < 0.4;

        % Moderate saturation
        satMask = sat > 0.2;

        % Combine criteria
        hemorrhageCandidates = redMask & darkMask & satMask;

        % Clean up with morphological operations
        se = strel('disk', 3);
        hemorrhageCandidates = imclose(hemorrhageCandidates, se);
        hemorrhageCandidates = imopen(hemorrhageCandidates, se);

        % Remove small objects
        hemorrhageCandidates = bwareaopen(hemorrhageCandidates, p.Results.MinArea);

        % Filter by area
        stats = regionprops(hemorrhageCandidates, 'Area', 'Centroid', 'Perimeter');

        if ~isempty(stats)
            areas = [stats.Area];
            areaMask = areas <= p.Results.MaxArea;

            if any(areaMask)
                validStats = stats(areaMask);
                evidence.count = numel(validStats);
                evidence.areas = [validStats.Area];
                evidence.totalArea = sum(evidence.areas);
                evidence.locations = reshape([validStats.Centroid], 2, [])';

                % Create mask
                evidence.mask = false(size(img, 1), size(img, 2));
                labeled = bwlabel(hemorrhageCandidates);
                for i = 1:numel(validStats)
                    evidence.mask(labeled == find(areaMask, i, 'first')) = true;
                end

                % Confidence based on count and total area
                evidence.confidence = min(1.0, (evidence.count / 5) + (evidence.totalArea / 10000));
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
