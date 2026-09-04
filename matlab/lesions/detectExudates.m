function evidence = detectExudates(img, varargin)
% detectExudates  Detect exudate candidates in fundus images
%
%   evidence = detectExudates(img)
%
%   Exudates are lipid deposits: BRIGHT yellow-white, compact lesions.
%   In color fundus images they are brightest in the GREEN channel
%   relative to the local retinal background (red is confounded by the
%   bright-orange background; blue is noisy).
%
%   Polarity contract (TASK 2): candidates are BRIGHTER than the local
%   retinal background. Enhancement uses white top-hat (f - opening),
%   the correct morphology for bright features, plus a local-contrast
%   term. Dark lesions, vessels, and background are NOT exudates. The
%   optic disc is bright but anatomical: it is localized and excluded,
%   never reported.
%
%   Input:
%       img - RGB fundus image (uint8 or double [0,1])
%
%   Name-Value Pairs:
%       'MinArea'    - Minimum lesion area in pixels (default: auto-scaled)
%       'MaxArea'    - Maximum lesion area in pixels (default: auto-scaled)
%       'Diagnostic' - If true, include diagnostic masks (default: false)
%
%   Output:
%       evidence - Struct with fields:
%           .count     - Number of detected candidates
%           .mask      - Binary mask of detected candidates
%           .locations - Nx2 matrix of [row, col] centroids
%           .areas     - N-element vector of areas (pixels)
%           .totalArea - Total exudate area in pixels
%           .confidence - HEURISTIC confidence (0-1, NOT a calibrated
%                         clinical probability)
%           .retinalMask/.vesselMask/.discMask/.rawCandidates/
%           .filteredCandidates/.labels - Diagnostic only

    p = inputParser;
    addRequired(p, 'img');
    addParameter(p, 'MinArea', -1, @isnumeric);
    addParameter(p, 'MaxArea', -1, @isnumeric);
    addParameter(p, 'Diagnostic', false, @islogical);
    parse(p, img, varargin{:});

    [rows, cols, ~] = size(img);

    % Initialize output (interface-compatible with extractLesionEvidence)
    evidence = struct();
    evidence.count = 0;
    evidence.mask = false(rows, cols);
    evidence.locations = [];
    evidence.areas = [];
    evidence.totalArea = 0;
    evidence.confidence = 0;

    diag = p.Results.Diagnostic;
    if diag
        evidence.retinalMask = false(rows, cols);
        evidence.vesselMask = false(rows, cols);
        evidence.discMask = false(rows, cols);
        evidence.rawCandidates = false(rows, cols);
        evidence.filteredCandidates = false(rows, cols);
        evidence.labels = zeros(rows, cols, 'uint16');
    end

    try
        % --- Image conversion ---
        if isa(img, 'uint8')
            imgD = double(img) / 255;
        elseif isa(img, 'uint16')
            imgD = double(img) / 65535;
        else
            imgD = double(img);
            if max(imgD(:)) > 1
                imgD = imgD / max(imgD(:));
            end
        end

        [rows, cols, nCh] = size(imgD);
        if rows < 2 || cols < 2 || nCh < 3
            return;  % grayscale or degenerate: no evidence (honest)
        end
        if any(~isfinite(imgD(:)))
            return;  % corrupted input: never display garbage
        end

        % --- Step 1: Retinal FOV mask ---
        retinalMask = createRetinalMask(imgD);
        if diag; evidence.retinalMask = retinalMask; end
        if sum(retinalMask(:)) < 100
            return;
        end

        % --- Step 2: Adaptive optic-disc mask (shared design) ---
        % The disc is the dominant bright confounder: localize with
        % brightness percentile + select-first + size/rim validation,
        % fail open. Never a fixed gray>0.7, never a silent center mask.
        discMask = createDiscMask(imgD, retinalMask);
        if diag; evidence.discMask = discMask; end

        % --- Step 3: Vessel mask, UNDILATED (TASK 4) ---
        % Vessels are dark; only bright vessel REFLEX streaks intersect a
        % bright-lesion mask. Dilation would erase genuine exudates
        % adjacent to vessels, so exclusion uses the raw mask plus a
        % restrained overlap gate (Step 10).
        vesselMask = createVesselMask(imgD, retinalMask);
        if diag; evidence.vesselMask = vesselMask; end

        % --- Step 4: Bright-feature enhancement (GREEN channel) ---
        % White top-hat = f - opening(f): positive where the image is
        % BRIGHTER than the local background (correct polarity for bright
        % lesions; verified against the 20B.4 morphology correction).
        % Paired with a size-agnostic local-contrast term
        % (image - boxmean, positive part) so large plaques with weak
        % top-hat rims still respond. response = max of both.
        greenCh = imgD(:, :, 2);
        minDim = min(rows, cols);
        seR = max(4, round(minDim * 0.015));
        bgWin = 6 * seR + 1;
        statWin = 2 * bgWin + 1;
        statWin = min(statWin - mod(statWin + 1, 2), minDim - mod(minDim + 1, 2));
        statWin = max(statWin, 15);

        seBH = strel('disk', seR);
        topHat = greenCh - imopen(greenCh, seBH);
        topHat(topHat < 0) = 0;

        bgEst = imboxfilt(greenCh, [bgWin bgWin]);
        localBright = greenCh - bgEst;
        localBright(localBright < 0) = 0;

        brightResponse = max(topHat, localBright);

        % --- Step 5: Adaptive statistical threshold (TASK 5) ---
        % threshold = localMean + k*localStd over a window large relative
        % to lesions (a lesion must not dominate its own statistics).
        % k = 2.5: bright-field FP control; specificity also carried by
        % size/shape/anatomy gates. Absolute floor for uniform regions.
        localMean = imboxfilt(brightResponse, [statWin statWin]);
        localVar = imboxfilt(brightResponse.^2, [statWin statWin]) - localMean.^2;
        localVar = max(localVar, 0);
        localStd = sqrt(localVar);

        kThreshold = 2.5;
        thresholdMap = localMean + kThreshold * localStd;
        % Absolute floor: typical green-channel sensor/JPEG noise sits
        % below ~0.03 normalized; responses weaker than that are noise
        % even when the local statistics collapse (found by execution:
        % merged speckle clumps otherwise pass the size gate).
        thresholdMap = max(thresholdMap, 0.03);

        candidates = brightResponse > thresholdMap;
        if diag; evidence.rawCandidates = candidates; end

        % --- Step 6: Anatomical exclusion ---
        candidates(~retinalMask) = false;   % FOV / black border
        candidates(discMask) = false;       % optic disc
        candidates(vesselMask) = false;     % vessel reflex streaks

        % --- Step 7: Resolution-aware boundary rejection (TASK 7) ---
        edgeMargin = max(3, round(minDim * 5 / 224));
        candidates(1:edgeMargin, :) = false;
        candidates(rows-edgeMargin+1:rows, :) = false;
        candidates(:, 1:edgeMargin) = false;
        candidates(:, cols-edgeMargin+1:cols) = false;
        fovEroded = imerode(retinalMask, strel('disk', max(2, round(edgeMargin / 2))));
        candidates(~fovEroded) = false;

        % --- Step 8: Morphological consolidation ---
        candidates = imclose(candidates, strel('disk', 2));
        candidates = imfill(candidates, 'holes');
        candidates = imopen(candidates, strel('disk', 1));

        % --- Step 9: Resolution-aware size gating (TASK 8) ---
        % Assumption (documented): fundus spans ~6mm across the image
        % diagonal. Hard exudates start near ~50um; confluent plaques
        % reach several mm (cap 3mm, clamped to image size).
        imgDiameter = sqrt(rows^2 + cols^2);
        mmPerPixel = 6.0 / imgDiameter;
        minDiamPx = max(3, round(0.05 / mmPerPixel / 2));
        maxDiamPx = min(round(minDim / 2), round(3.0 / mmPerPixel / 2));
        minAreaCalc = max(8, round(pi * minDiamPx^2));
        maxAreaCalc = max(minAreaCalc + 1, round(pi * maxDiamPx^2));

        if p.Results.MinArea >= 0
            minAreaCalc = p.Results.MinArea;
        end
        if p.Results.MaxArea >= 0
            maxAreaCalc = p.Results.MaxArea;
        end

        candidates = bwareaopen(candidates, minAreaCalc);

        % --- Step 10: Multi-property region filtering (TASK 6) ---
        cc = bwconncomp(candidates);
        if cc.NumObjects == 0
            return;
        end
        stats = regionprops(cc, 'Area', 'Centroid', 'Eccentricity', ...
            'Solidity', 'BoundingBox', 'PixelIdxList');

        redCh = imgD(:, :, 1);
        blueCh = imgD(:, :, 3);
        [GxG, GyG] = imgradientxy(greenCh);
        GmagGreen = sqrt(GxG.^2 + GyG.^2);
        bgGradGreen = median(GmagGreen(retinalMask));
        keep = true(numel(stats), 1);

        for i = 1:numel(stats)
            % (a) area plausibility
            if stats(i).Area < minAreaCalc || stats(i).Area > maxAreaCalc
                keep(i) = false;
                continue;
            end

            % (b) shape: exudates are compact/oval; confluent plaques
            % irregular, so gates stay lenient — thin streaks rejected.
            if stats(i).Eccentricity > 0.9
                keep(i) = false;
                continue;
            end
            if stats(i).Solidity < 0.4
                keep(i) = false;
                continue;
            end

            % (c) vessel overlap: reject reflex-dominated components
            overlap = sum(vesselMask(stats(i).PixelIdxList)) / stats(i).Area;
            if overlap > 0.40
                keep(i) = false;
                continue;
            end

            c = round(stats(i).Centroid(1));
            r = round(stats(i).Centroid(2));
            c = max(1, min(c, cols));
            r = max(1, min(r, rows));

            % (d) local brightness: candidate brighter than background
            patchR = 20;
            rMin = max(1, r - patchR); rMax = min(rows, r + patchR);
            cMin = max(1, c - patchR); cMax = min(cols, c + patchR);
            localPatch = greenCh(rMin:rMax, cMin:cMax);
            localMu = mean(localPatch(:));
            localSigma = std(localPatch(:));
            if localSigma > 0 && greenCh(r, c) < localMu + 0.5 * localSigma
                keep(i) = false;
                continue;
            end

            % (e) weak yellow-white prior: R >= B inside the bbox
            % (blood/choroid red is dark, not candidate; bright-blue
            % artifacts and white-balance glare fail this directionally).
            % Deliberately mild.
            bbox = stats(i).BoundingBox;
            br1 = max(1, round(bbox(2))); br2 = min(rows, round(bbox(2) + bbox(4)));
            bc1 = max(1, round(bbox(1))); bc2 = min(cols, round(bbox(1) + bbox(3)));
            if br2 >= br1 && bc2 >= bc1
                meanR = mean(mean(redCh(br1:br2, bc1:bc2)));
                meanB = mean(mean(blueCh(br1:br2, bc1:bc2)));
                if meanR < meanB
                    keep(i) = false;
                    continue;
                end
            end
            % (f) edge sharpness: true exudates have a distinct brightness
            % step at their boundary; illumination domes and merged noise
            % have gradual or weak edges. Require boundary gradient above
            % both a relative (3x background) and an absolute (0.02) bar.
            compMask = false(rows, cols);
            compMask(stats(i).PixelIdxList) = true;
            eroded = imerode(compMask, strel('disk', 1));
            rim = compMask & ~eroded;
            if sum(rim(:)) < 4
                keep(i) = false;
                continue;
            end
            rimGrad = mean(GmagGreen(rim));
            if ~(rimGrad > 3 * bgGradGreen && rimGrad > 0.02)
                keep(i) = false;
                continue;
            end
        end

        % --- Step 11: Build output ---
        if ~any(keep)
            return;
        end
        validStats = stats(keep);
        evidence.count = numel(validStats);
        evidence.areas = [validStats.Area]';
        evidence.totalArea = sum(evidence.areas);
        evidence.locations = reshape([validStats.Centroid], 2, [])';

        evidence.mask = false(rows, cols);
        labels = zeros(rows, cols, 'uint16');
        for i = 1:numel(validStats)
            evidence.mask(validStats(i).PixelIdxList) = true;
            labels(validStats(i).PixelIdxList) = i;
        end
        if diag
            evidence.labels = labels;
            evidence.filteredCandidates = evidence.mask;
        end

        % --- Step 12: HEURISTIC confidence (TASK 13) ---
        % Heuristic blend of count and FOV-area fraction. NOT a calibrated
        % clinical probability; labeled as such in the header.
        countScore = min(1.0, evidence.count / 10);
        fovPixels = sum(retinalMask(:));
        if fovPixels > 0
            areaScore = min(1.0, (evidence.totalArea / fovPixels) / 0.02);
        else
            areaScore = 0;
        end
        evidence.confidence = 0.5 * countScore + 0.5 * areaScore;

    catch
        % Return empty evidence on any error (fail-safe, never garbage)
        evidence.count = 0;
        evidence.mask = false(rows, cols);
        evidence.locations = [];
        evidence.areas = [];
        evidence.totalArea = 0;
        evidence.confidence = 0;
    end
end

function mask = createRetinalMask(imgD)
% createRetinalMask  Adaptive retinal field-of-view mask (shared design).
%   Dark pixels are background; the retina is the bright region they
%   enclose: mask = largest component of the COMPLEMENT, with background
%   opened first so thin vessels cannot partition the disk. (Two vacuous/
%   partitioning predecessors found by executed validation, Phase 20B.5.)
    [rows, cols, ~] = size(imgD);
    gray = rgb2gray(imgD);
    bgThresh = gray < 0.2;
    bgOpened = imopen(bgThresh, strel('disk', 3));
    bgClosed = imclose(bgOpened, strel('disk', 15));
    retinaCand = ~bgClosed;
    cc = bwconncomp(retinaCand);
    if cc.NumObjects == 0
        mask = true(rows, cols);
        return;
    end
    areas = cellfun(@numel, cc.PixelIdxList);
    [~, maxIdx] = max(areas);
    mask = false(rows, cols);
    mask(cc.PixelIdxList{maxIdx}) = true;
    mask = imclose(mask, strel('disk', 10));
    mask = imfill(mask, 'holes');
end

function discMask = createDiscMask(imgD, retinalMask)
% createDiscMask  Adaptive disc localization (shared 20B.4 design):
% percentile brightness, select-before-close, size plausibility
% (<= minDim/6), rim-sharpness test, fail-open. Never fixed gray>0.7,
% never a silent image-center mask.
    [rows, cols, ~] = size(imgD);
    gray = rgb2gray(imgD);
    retinalPixels = gray(retinalMask);
    if isempty(retinalPixels)
        discMask = false(rows, cols);
        return;
    end
    brightThresh = prctile(retinalPixels, 95);
    brightRegion = gray > brightThresh & retinalMask;
    brightClean = imopen(brightRegion, strel('disk', 2));

    cc0 = bwconncomp(brightClean);
    discMask = false(rows, cols);
    if cc0.NumObjects > 0
        areas0 = cellfun(@numel, cc0.PixelIdxList);
        [~, maxIdx] = max(areas0);
        winner = false(rows, cols);
        winner(cc0.PixelIdxList{maxIdx}) = true;
        winner = imclose(winner, strel('disk', 7));
        winner = imfill(winner, 'holes');
        stW = regionprops(winner, 'EquivDiameter', 'Centroid');
        discRadius = stW(1).EquivDiameter / 2;

        if discRadius > min(rows, cols) / 6
            discMask = false(rows, cols);
            return;
        end

        center = stW(1).Centroid;

        [Gx, Gy] = imgradientxy(gray);
        Gmag = sqrt(Gx.^2 + Gy.^2);
        rimTheta = linspace(0, 2 * pi, 180);
        rimX = round(center(1) + discRadius * cos(rimTheta));
        rimY = round(center(2) + discRadius * sin(rimTheta));
        rimOK = rimX >= 1 & rimX <= cols & rimY >= 1 & rimY <= rows;
        if ~any(rimOK)
            discMask = false(rows, cols);
            return;
        end
        rimGrad = mean(Gmag(sub2ind([rows, cols], rimY(rimOK), rimX(rimOK))));
        bgGrad = median(Gmag(retinalMask));
        if ~(rimGrad > 3 * bgGrad)
            discMask = false(rows, cols);
            return;
        end

        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - center(1)).^2 + (Y - center(2)).^2) < (discRadius * 1.5)^2;
    else
        % Conservative fallback: small, off-center; documented limitation.
        centerR = round(rows * 0.45);
        centerC = round(cols * 0.55);
        discRadius = round(min(rows, cols) / 16);
        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - centerC).^2 + (Y - centerR).^2) < discRadius^2;
    end
end

function vesselMask = createVesselMask(imgD, retinalMask)
% createVesselMask  Adaptive vessel segmentation (shared 20B.4 design):
% green 10th-percentile + directional opening + blot carve-out.
% Returned UNDILATED: bright-lesion exclusion must not erase exudates
% adjacent to vessels (TASK 4).
    [rows, cols, ~] = size(imgD);
    green = imgD(:, :, 2);
    retinalGreen = green(retinalMask);
    if isempty(retinalGreen)
        vesselMask = false(rows, cols);
        return;
    end
    vesselThresh = prctile(retinalGreen, 10);
    vesselRaw = green < vesselThresh;

    seLen = max(5, round(min(rows, cols) * 0.02));
    vesselOriented = false(rows, cols);
    for ang = [0, 30, 60, 90, 120, 150]
        vesselOriented = vesselOriented | imopen(vesselRaw, strel('line', seLen, ang));
    end
    vesselMask = vesselRaw & vesselOriented;

    % Blot carve-out (shared fix): round dark blobs are not vessels.
    ccV = bwconncomp(vesselMask);
    if ccV.NumObjects > 0
        stV = regionprops(ccV, 'Area', 'Eccentricity', 'Solidity');
        labV = labelmatrix(ccV);
        for kV = 1:numel(stV)
            if stV(kV).Area >= 25 && stV(kV).Solidity > 0.8 ...
                    && stV(kV).Eccentricity < 0.6
                vesselMask(labV == kV) = false;
            end
        end
    end

    vesselMask(~retinalMask) = false;
    vesselMask = bwareaopen(vesselMask, max(5, round(min(rows, cols) * 0.005)));
    vesselMask(~retinalMask) = false;
end
