function evidence = detectHemorrhages(img, varargin)
% detectHemorrhages  Detect hemorrhage candidates in fundus images
%
%   evidence = detectHemorrhages(img)
%
%   Hemorrhages are extravasated blood: dark-red, compact patches LARGER
%   than microaneurysms (dot-blot through large blot hemorrhages). In color
%   fundus images they appear as dark regions, most contrasted in the
%   GREEN channel where blood absorbs light relative to retinal background.
%
%   Detection uses black-hat morphology (dark features BELOW the local
%   background) with adaptive statistical thresholding, then anatomical
%   exclusion (retinal FOV, vessels, optic disc, boundaries) and
%   multi-property region filtering (area, shape, local contrast, weak
%   red-color prior).
%
%   Polarity contract (documented, TASK 2): candidates are DARKER than the
%   local retinal background in the green channel. Bright lesions, the
%   optic disc, and dark non-red background are NOT hemorrhages.
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
%           .totalArea - Total hemorrhage area in pixels
%           .confidence - Detection confidence (0-1)
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
            return;  % grayscale or degenerate input: no evidence (honest)
        end

        % --- Step 1: Retinal FOV mask (resolution-aware, adaptive) ---
        retinalMask = createRetinalMask(imgD);
        if diag; evidence.retinalMask = retinalMask; end
        if sum(retinalMask(:)) < 100
            return;  % no usable retina
        end

        % --- Step 2: Adaptive optic-disc mask ---
        discMask = createDiscMask(imgD, retinalMask);
        if diag; evidence.discMask = discMask; end

        % --- Step 3: Adaptive vessel mask (restrained dilation) ---
        % Vessels are the dominant dark-red confounder (old defect B4).
        % Dilation is ONE pixel only: hemorrhages may abut vessels, and
        % heavy dilation would erase genuine perivascular candidates.
        % A second overlap gate (Step 10) removes vessel-dominated
        % components that survive pixel exclusion.
        vesselMask = createVesselMask(imgD, retinalMask);
        vesselExcl = imdilate(vesselMask, strel('disk', 1));
        vesselExcl(~retinalMask) = false;
        if diag; evidence.vesselMask = vesselExcl; end

        % --- Step 4: Multi-scale dark-feature enhancement (GREEN channel) ---
        % Black-hat = closing(f) - f: positive where the image is DARKER
        % than the local background. Blood absorbs green light, so
        % hemorrhages give a positive response. Two complementary scales:
        %   (a) black-hat with disk SE: exact for spots up to the SE
        %       radius; larger uniform blots yield rim-only responses;
        %   (b) local background subtraction (box-mean estimate minus
        %       image): size-agnostic, solid response for blots of any
        %       size below the background window.
        % response = max(a, b): solid coverage across the HE size range.
        % SE and windows scale with image size (resolution-aware).
        greenCh = imgD(:, :, 2);
        minDim = min(rows, cols);
        seR = max(5, round(minDim * 0.02));
        bgWin = 6 * seR + 1;                       % background scale
        statWin = 2 * bgWin + 1;                   % statistics scale
        statWin = min(statWin - mod(statWin + 1, 2), minDim - mod(minDim + 1, 2));
        statWin = max(statWin, 15);

        seBH = strel('disk', seR);
        blackHat = imclose(greenCh, seBH) - greenCh;
        blackHat(blackHat < 0) = 0;

        bgEst = imboxfilt(greenCh, [bgWin bgWin]);
        bgSub = bgEst - greenCh;
        bgSub(bgSub < 0) = 0;

        darkResponse = max(blackHat, bgSub);

        % --- Step 5: Adaptive statistical threshold ---
        % threshold = localMean + k*localStd over a window LARGE relative
        % to lesions (statWin ~ 2x background scale) so that a lesion
        % cannot inflate its own threshold by dominating the window.
        % k = 2.0: permissive per-pixel, strict downstream (size/shape/
        % anatomy gates carry specificity).
        localMean = imboxfilt(darkResponse, [statWin statWin]);
        localVar = imboxfilt(darkResponse.^2, [statWin statWin]) - localMean.^2;
        localVar = max(localVar, 0);
        localStd = sqrt(localVar);

        kThreshold = 2.0;
        thresholdMap = localMean + kThreshold * localStd;
        thresholdMap = max(thresholdMap, 0.008);  % floor for uniform regions

        candidates = darkResponse > thresholdMap;
        if diag; evidence.rawCandidates = candidates; end

        % --- Step 6: Anatomical exclusion ---
        candidates(~retinalMask) = false;   % FOV (old defect B5)
        candidates(discMask) = false;       % optic disc (old defect B4)
        candidates(vesselExcl) = false;     % vessels, 1px margin (B4)

        % --- Step 7: Resolution-aware boundary rejection (B5) ---
        % Margin scales with image size: 5px at 224px reference.
        edgeMargin = max(3, round(min(rows, cols) * 5 / 224));
        candidates(1:edgeMargin, :) = false;
        candidates(rows-edgeMargin+1:rows, :) = false;
        candidates(:, 1:edgeMargin) = false;
        candidates(:, cols-edgeMargin+1:cols) = false;
        fovEroded = imerode(retinalMask, strel('disk', max(2, round(edgeMargin / 2))));
        candidates(~fovEroded) = false;

        % --- Step 8: Morphological consolidation ---
        % Close merges blot fragments; fill solidifies rim responses of
        % large blots; open removes single-pixel specks.
        candidates = imclose(candidates, strel('disk', 2));
        candidates = imfill(candidates, 'holes');
        candidates = imopen(candidates, strel('disk', 1));

        % --- Step 9: Resolution-aware size gating (TASK 7) ---
        % Assumption (documented): fundus spans ~6mm across the image
        % diagonal. Dot-blot hemorrhages start near ~60um; blot
        % hemorrhages extend to ~1.5mm. Clamped to sane pixel bounds.
        imgDiameter = sqrt(rows^2 + cols^2);
        mmPerPixel = 6.0 / imgDiameter;
        minDiamPx = max(3, round(0.06 / mmPerPixel / 2));
        maxDiamPx = min(round(min(rows, cols) / 3), round(1.5 / mmPerPixel / 2));
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
        keep = true(numel(stats), 1);

        for i = 1:numel(stats)
            % (a) area plausibility
            if stats(i).Area < minAreaCalc || stats(i).Area > maxAreaCalc
                keep(i) = false;
                continue;
            end

            % (b) shape: compact-ish; flame hemorrhages elongate, so the
            % gate is lenient (0.95) — vessel segments are removed by the
            % overlap gate below, not by shape alone.
            if stats(i).Eccentricity > 0.95
                keep(i) = false;
                continue;
            end
            if stats(i).Solidity < 0.35
                keep(i) = false;
                continue;
            end

            % (c) vessel overlap: reject vessel-dominated components
            % (flame hemorrhages hugging vessels are a documented miss).
            overlap = sum(vesselMask(stats(i).PixelIdxList)) / stats(i).Area;
            if overlap > 0.40
                keep(i) = false;
                continue;
            end

            c = round(stats(i).Centroid(1));
            r = round(stats(i).Centroid(2));
            c = max(1, min(c, cols));
            r = max(1, min(r, rows));

            % (d) local darkness: candidate darker than local background
            patchR = 20;
            rMin = max(1, r - patchR); rMax = min(rows, r + patchR);
            cMin = max(1, c - patchR); cMax = min(cols, c + patchR);
            localPatch = greenCh(rMin:rMax, cMin:cMax);
            localMu = mean(localPatch(:));
            localSigma = std(localPatch(:));
            if localSigma > 0 && greenCh(r, c) > localMu - 0.5 * localSigma
                keep(i) = false;
                continue;
            end

            % (e) weak red-color prior: blood is redder than background
            % (mean R >= mean G inside the component bbox). Rejects dark
            % non-red artifacts (dust, black specks). Deliberately mild.
            bbox = stats(i).BoundingBox;
            br1 = max(1, round(bbox(2))); br2 = min(rows, round(bbox(2) + bbox(4)));
            bc1 = max(1, round(bbox(1))); bc2 = min(cols, round(bbox(1) + bbox(3)));
            if br2 >= br1 && bc2 >= bc1
                meanR = mean(mean(redCh(br1:br2, bc1:bc2)));
                meanG = mean(mean(greenCh(br1:br2, bc1:bc2)));
                if meanR < meanG
                    keep(i) = false;
                    continue;
                end
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

        % --- Step 12: Confidence (count + FOV-area fraction) ---
        countScore = min(1.0, evidence.count / 8);
        fovPixels = sum(retinalMask(:));
        if fovPixels > 0
            areaScore = min(1.0, (evidence.totalArea / fovPixels) / 0.02);
        else
            areaScore = 0;
        end
        evidence.confidence = 0.6 * countScore + 0.4 * areaScore;

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
% createRetinalMask  Adaptive retinal field-of-view mask.
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
% createDiscMask  Adaptive disc localization; conservative fallback that
% REPORTS via small off-center mask (never silent image-center labeling).
    [rows, cols, ~] = size(imgD);
    gray = rgb2gray(imgD);
    retinalPixels = gray(retinalMask);
    if isempty(retinalPixels)
        discMask = false(rows, cols);
        return;
    end
    brightThresh = prctile(retinalPixels, 95);
    brightRegion = gray > brightThresh & retinalMask;
    % De-speckle WITHOUT closing: closing first would merge distinct bright
    % structures (disc + bright center or exudates) into one oversized
    % blob. Select the winner on unmerged components; solidify only it.
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

        % Plausibility gate: a real disc is ~1/14 of the fundus width
        % (1.5mm disc vs ~10-11mm visible retina in a 45-degree photo).
        % Anything above 1/6 is diffuse brightness, not anatomy — refuse
        % to mask (fail-open) rather than blind the detector over a huge
        % area. An empty discMask is visible in Diagnostic outputs.
        if discRadius > min(rows, cols) / 6
            discMask = false(rows, cols);
            return;
        end

        center = stW(1).Centroid;

        % Boundary-sharpness test: a real disc has a distinct pallor edge;
        % diffuse illumination does not. Sample gradient magnitude on the
        % candidate rim; require it to clearly exceed background gradient.
        % Otherwise fail open (no mask) — visible in Diagnostic outputs.
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
% createVesselMask  Adaptive vessel segmentation (percentile + orientation)
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

    % Carve out compact blot-like components: directional opening keeps ANY
    % feature containing a line segment, including round blots. Blots are
    % lesion candidates, not vessels. Remove components that are large
    % enough, solid, and round (thin vessels have eccentricity ~ 1, kept).
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
