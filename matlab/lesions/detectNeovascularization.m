function evidence = detectNeovascularization(img, varargin)
% detectNeovascularization  Detect neovascularization candidates in fundus images
%
%   evidence = detectNeovascularization(img)
%
%   Neovascularization appears as abnormal new blood vessel growth.
%   Detection analyzes vessel density and pattern irregularity.
%
%   Input:
%       img - RGB fundus image (uint8 or double)
%
%   Output:
%       evidence - Struct with fields:
%           .detected  - Boolean: candidate detected
%           .mask      - Binary mask of candidate regions
%           .density   - Vessel density in candidate regions
%           .irregularity - Pattern irregularity score (0-1)
%           .confidence - Detection confidence (0-1)

    % Initialize output
    evidence = struct();
    evidence.detected = false;
    evidence.mask = false(size(img, 1), size(img, 2));
    evidence.density = 0;
    evidence.irregularity = 0;
    evidence.confidence = 0;

    try
        % Convert to double if needed
        if isa(img, 'uint8')
            imgDouble = double(img) / 255;
        else
            imgDouble = double(img);
        end

        % Extract green channel (vessels most visible)
        greenChannel = imgDouble(:,:,2);

        % Step 1: Enhance vessels using matched filtering
        % Create vessel-like filters at multiple orientations
        vesselFilters = {};
        angles = 0:30:150;
        for a = 1:numel(angles)
            % Create a line-shaped structuring element
            se = strel('line', 15, angles(a));
            vesselFilters{a} = imopen(greenChannel, se);
        end

        % Combine responses
        vesselResponse = zeros(size(greenChannel));
        for a = 1:numel(vesselFilters)
            vesselResponse = max(vesselResponse, vesselFilters{a});
        end

        % Step 2: Threshold to get vessel mask
        threshold = graythresh(vesselResponse);
        vesselMask = vesselResponse > threshold * 0.8;

        % Step 3: Analyze vessel density in regions
        % Divide image into blocks and compute density
        blockSize = 64;
        [rows, cols] = size(greenChannel);
        numBlocksR = ceil(rows / blockSize);
        numBlocksC = ceil(cols / blockSize);

        densityMap = zeros(numBlocksR, numBlocksC);

        for r = 1:numBlocksR
            for c = 1:numBlocksC
                rStart = (r-1)*blockSize + 1;
                rEnd = min(r*blockSize, rows);
                cStart = (c-1)*blockSize + 1;
                cEnd = min(c*blockSize, cols);

                block = vesselMask(rStart:rEnd, cStart:cEnd);
                densityMap(r, c) = sum(block(:)) / numel(block);
            end
        end

        % Step 4: Identify regions with abnormally high vessel density
        % Neovascularization typically has higher density
        meanDensity = mean(densityMap(:));
        stdDensity = std(densityMap(:));
        thresholdDensity = meanDensity + 2 * stdDensity;

        % Find high-density regions
        highDensityRegions = densityMap > thresholdDensity;

        % Step 5: Check for irregularity (non-smooth patterns)
        % Irregularity measured by local variance
        irregularityMap = stdfilt(densityMap, ones(3)) / (meanDensity + eps);
        meanIrregularity = mean(irregularityMap(:));

        % Step 6: Determine if neovascularization is detected
        if any(highDensityRegions(:)) && meanIrregularity > 0.3
            evidence.detected = true;
            evidence.density = meanDensity;
            evidence.irregularity = meanIrregularity;

            % Create mask for high-density regions
            evidence.mask = imresize(highDensityRegions, [rows, cols]) > 0.5;

            % Confidence based on density and irregularity
            evidence.confidence = min(1.0, (meanDensity / 0.3) * (meanIrregularity / 0.5));
        else
            evidence.density = meanDensity;
            evidence.irregularity = meanIrregularity;
        end

    catch
        % Return empty evidence on error
        evidence.detected = false;
        evidence.mask = false(size(img, 1), size(img, 2));
        evidence.density = 0;
        evidence.irregularity = 0;
        evidence.confidence = 0;
    end
end
