function evidence = detectMicroaneurysms(img, varargin)
% detectMicroaneurysms  Detect microaneurysm candidates in fundus images
%
%   evidence = detectMicroaneurysms(img)
%   evidence = detectMicroaneurysms(img, 'MinRadius', 1, 'MaxRadius', 6)
%
%   Microaneurysms appear as small, dark-red, round lesions.
%   Detection uses morphological operations on the red channel.
%
%   Input:
%       img - RGB fundus image (uint8 or double)
%
%   Name-Value Pairs:
%       'MinRadius' - Minimum lesion radius in pixels (default: 1)
%       'MaxRadius' - Maximum lesion radius in pixels (default: 6)
%       'MinArea'   - Minimum lesion area in pixels (default: 3)
%       'MaxArea'   - Maximum lesion area in pixels (default: 150)
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
    addParameter(p, 'MinRadius', 1, @isnumeric);
    addParameter(p, 'MaxRadius', 3, @isnumeric);
    addParameter(p, 'MinArea', 10, @isnumeric);
    addParameter(p, 'MaxArea', 40, @isnumeric);
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

        % Extract red channel (microaneurysms are more visible in red)
        redChannel = imgDouble(:,:,1);

        % Convert to grayscale for processing
        grayImg = rgb2gray(uint8(imgDouble * 255));

        % Step 1: Enhance microaneurysms using morphological top-hat
        % Top-hat extracts small bright features on dark background
        se = strel('disk', p.Results.MaxRadius);
        tophatImg = imtophat(redChannel, se);

        % Step 2: Threshold to find candidates
        % Microaneurysms are brighter than surrounding background in red channel
        threshold = graythresh(tophatImg);
        candidates = tophatImg > threshold * 3.0;

        % Step 3: Remove very small and very large objects
        candidates = bwareaopen(candidates, p.Results.MinArea);

        % Step 4: Filter by area
        stats = regionprops(candidates, 'Area', 'Centroid', 'Perimeter', 'Eccentricity');

        if ~isempty(stats)
            areas = [stats.Area];
            eccentricities = [stats.Eccentricity];

            % Filter by area
            areaMask = areas >= p.Results.MinArea & areas <= p.Results.MaxArea;

            % Filter by eccentricity (microaneurysms are roughly circular)
            % Eccentricity close to 0 means circular
            eccMask = eccentricities < 0.6;

            % Combine filters
            validMask = areaMask & eccMask;

            if any(validMask)
                validStats = stats(validMask);
                evidence.count = numel(validStats);
                evidence.areas = [validStats.Area];
                evidence.locations = reshape([validStats.Centroid], 2, [])';

                % Create mask
                evidence.mask = false(size(img, 1), size(img, 2));
                for i = 1:numel(validStats)
                    % Mark region around centroid
                    r = round(validStats(i).Centroid(2));
                    c = round(validStats(i).Centroid(1));
                    rad = round(sqrt(validStats(i).Area / pi));
                    r = max(1, min(r, size(img, 1)));
                    c = max(1, min(c, size(img, 2)));
                    rad = max(1, min(rad, 10));
                    evidence.mask(max(1,r-rad):min(size(img,1),r+rad), ...
                                  max(1,c-rad):min(size(img,2),c+rad)) = true;
                end

                % Confidence based on count and quality
                evidence.confidence = min(1.0, evidence.count / 10);
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
