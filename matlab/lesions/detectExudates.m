function evidence = detectExudates(img, varargin)
% detectExudates  Detect exudate candidates in fundus images
%
%   evidence = detectExudates(img)
%
%   Exudates appear as bright, yellow-white lesions.
%   Detection uses color segmentation and morphological operations.
%
%   Input:
%       img - RGB fundus image (uint8 or double)
%
%   Name-Value Pairs:
%       'MinArea' - Minimum lesion area in pixels (default: 20)
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
    addParameter(p, 'MinArea', 20, @isnumeric);
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

        % Exudates are bright, yellow-white:
        % - High value (bright)
        % - Low saturation (not highly colored)
        % - Hue in yellow-white range

        hue = hsvImg(:,:,1);
        sat = hsvImg(:,:,2);
        val = hsvImg(:,:,3);

        % Bright regions
        brightMask = val > 0.7;

        % Low saturation (white/yellow, not highly colored)
        lowSatMask = sat < 0.4;

        % Combine criteria
        exudateCandidates = brightMask & lowSatMask;

        % Remove optic disc region (large bright area in center)
        % Optic disc is typically in the center
        [rows, cols] = size(imgDouble(:,:,1));
        centerR = round(rows / 2);
        centerC = round(cols / 2);
        discRadius = round(min(rows, cols) / 8);

        % Create optic disc mask
        discMask = false(rows, cols);
        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - centerC).^2 + (Y - centerR).^2) < discRadius^2;

        % Remove optic disc from candidates
        exudateCandidates(discMask) = false;

        % Clean up with morphological operations
        se = strel('disk', 2);
        exudateCandidates = imclose(exudateCandidates, se);

        % Remove small objects
        exudateCandidates = bwareaopen(exudateCandidates, p.Results.MinArea);

        % Filter by area
        stats = regionprops(exudateCandidates, 'Area', 'Centroid', 'Perimeter');

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
                labeled = bwlabel(exudateCandidates);
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
