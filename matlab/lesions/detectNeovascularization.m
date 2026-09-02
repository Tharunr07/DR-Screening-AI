function evidence = detectNeovascularization(img, varargin)
% detectNeovascularization  Detect neovascularization candidates in fundus images
%
%   evidence = detectNeovascularization(img)
%
%   Neovascularization appears as abnormal new blood vessel growth.
%   Detection analyzes fine vessel patterns while excluding normal
%   optic disc vasculature and major vessels.
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

        [rows, cols, ~] = size(imgDouble);

        % Step 1: Detect and exclude optic disc
        discMask = detectOpticDiscRegion(imgDouble);

        % Step 2: Detect major vessels to exclude them
        majorVesselMask = detectMajorVessels(imgDouble);

        % Step 3: Extract green channel (vessels most visible)
        greenChannel = imgDouble(:,:,2);

        % Step 4: Enhance fine vessels using matched filtering
        % Use smaller filters to detect fine vessels (NV-like)
        fineVesselResponse = zeros(size(greenChannel));
        angles = 0:22.5:157.5;

        for a = 1:numel(angles)
            % Create fine vessel filter (shorter length)
            se = strel('line', 7, angles(a));
            response = imopen(greenChannel, se);
            fineVesselResponse = max(fineVesselResponse, response);
        end

        % Step 5: Threshold to get fine vessel mask
        threshold = graythresh(fineVesselResponse);
        fineVesselMask = fineVesselResponse > threshold * 0.7;

        % Step 6: Exclude optic disc and major vessels
        analysisMask = fineVesselMask;
        analysisMask(discMask) = false;
        analysisMask(majorVesselMask) = false;

        % Step 7: Analyze vessel density in peripheral regions only
        % Divide image into blocks, excluding central disc area
        blockSize = 48;
        numBlocksR = ceil(rows / blockSize);
        numBlocksC = ceil(cols / blockSize);

        densityMap = zeros(numBlocksR, numBlocksC);

        for r = 1:numBlocksR
            for c = 1:numBlocksC
                rStart = (r-1)*blockSize + 1;
                rEnd = min(r*blockSize, rows);
                cStart = (c-1)*blockSize + 1;
                cEnd = min(c*blockSize, cols);

                block = analysisMask(rStart:rEnd, cStart:cEnd);
                densityMap(r, c) = sum(block(:)) / numel(block);
            end
        end

        % Step 8: Identify regions with abnormal fine vessel density
        % Use robust statistics (median instead of mean)
        medianDensity = median(densityMap(:));
        madDensity = median(abs(densityMap(:) - medianDensity));  % MAD

        % Threshold based on MAD (more robust than std)
        if madDensity > 0
            thresholdDensity = medianDensity + 3 * madDensity;
        else
            thresholdDensity = medianDensity + 0.1;
        end

        % Find high-density regions
        highDensityRegions = densityMap > thresholdDensity;

        % Step 9: Analyze irregularity in high-density regions
        if any(highDensityRegions(:))
            % Compute local variance in high-density regions
            irregularityMap = stdfilt(densityMap, ones(3)) / (medianDensity + eps);

            % Only consider irregularity in high-density regions
            highDensityIrregularity = irregularityMap .* highDensityRegions;
            rawIrregularity = mean(highDensityIrregularity(highDensityRegions));

            % Normalize irregularity to 0-1 range
            meanIrregularity = min(1.0, rawIrregularity / 10);

            % Step 10: Check spatial distribution
            % NV typically occurs in peripheral retina, not central
            [blockRows, blockCols] = size(densityMap);
            centerR = round(blockRows / 2);
            centerC = round(blockCols / 2);

            % Create distance from center map
            [X, Y] = meshgrid(1:blockCols, 1:blockRows);
            distFromCenter = sqrt((X - centerC).^2 + (Y - centerR).^2);
            maxDist = sqrt(centerR^2 + centerC^2);
            distNormalized = distFromCenter / maxDist;

            % Weight by distance from center (peripheral regions weighted higher)
            peripheralWeight = distNormalized .* highDensityRegions;
            meanPeripheralWeight = mean(peripheralWeight(peripheralWeight > 0));

            % Step 11: Determine if neovascularization is detected
            % Require: high density, irregularity, AND peripheral location
            if meanIrregularity > 0.3 && meanPeripheralWeight > 0.3
                evidence.detected = true;
                evidence.density = medianDensity;
                evidence.irregularity = meanIrregularity;

                % Create mask for high-density peripheral regions
                evidenceMask = imresize(highDensityRegions, [rows, cols]) > 0.5;
                evidenceMask(discMask) = false;  % Ensure disc is excluded
                evidence.mask = evidenceMask;

                % Confidence based on density, irregularity, and location
                densityScore = min(1.0, medianDensity / 0.2);
                locationScore = min(1.0, meanPeripheralWeight / 0.5);
                evidence.confidence = min(1.0, 0.4 * densityScore + ...
                                     0.3 * meanIrregularity + ...
                                     0.3 * locationScore);
            else
                evidence.density = medianDensity;
                evidence.irregularity = meanIrregularity;
            end
        else
            % No high-density regions found
            medianDensity = median(densityMap(:));
            evidence.density = medianDensity;
            evidence.irregularity = 0;
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

function discMask = detectOpticDiscRegion(imgDouble)
% detectOpticDiscRegion  Detect optic disc region for exclusion

    [rows, cols, ~] = size(imgDouble);
    gray = rgb2gray(imgDouble);

    % The optic disc is the brightest large circular region
    brightThresh = gray > 0.65;

    % Morphological operations
    se = strel('disk', 8);
    brightThresh = imclose(brightThresh, se);
    brightThresh = imfill(brightThresh, 'holes');

    % Find largest bright region
    stats = regionprops(brightThresh, 'Area', 'Centroid', 'EquivDiameter');

    discMask = false(rows, cols);

    if ~isempty(stats)
        areas = [stats.Area];
        [~, maxIdx] = max(areas);

        % Estimate disc radius (with padding)
        discRadius = stats(maxIdx).EquivDiameter / 2;
        center = stats(maxIdx).Centroid;

        % Create disc mask (larger to ensure exclusion)
        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - center(1)).^2 + (Y - center(2)).^2) < (discRadius * 1.5)^2;
    else
        % Fallback: assume center
        centerR = round(rows / 2);
        centerC = round(cols / 2);
        discRadius = round(min(rows, cols) / 6);
        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - centerC).^2 + (Y - centerR).^2) < discRadius^2;
    end
end

function vesselMask = detectMajorVessels(imgDouble)
% detectMajorVessels  Detect major retinal vessels for exclusion

    % Use green channel (vessels are dark)
    greenChannel = imgDouble(:,:,2);

    % Vessels are darker than background
    vesselMask = greenChannel < 0.35;

    % Use morphological filtering to extract major vessel structures
    % Use longer structuring elements for major vessels
    se1 = strel('line', 15, 0);
    se2 = strel('line', 15, 45);
    se3 = strel('line', 15, 90);
    se4 = strel('line', 15, 135);

    vessel1 = imopen(vesselMask, se1);
    vessel2 = imopen(vesselMask, se2);
    vessel3 = imopen(vesselMask, se3);
    vessel4 = imopen(vesselMask, se4);

    % Combine
    majorVesselMask = vessel1 | vessel2 | vessel3 | vessel4;

    % Dilate to cover vessel edges
    se = strel('disk', 2);
    majorVesselMask = imdilate(majorVesselMask, se);
end
