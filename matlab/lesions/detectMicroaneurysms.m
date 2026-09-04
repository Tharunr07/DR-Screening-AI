function evidence = detectMicroaneurysms(img, varargin)
% detectMicroaneurysms  Detect microaneurysm candidates in fundus images
%
%   evidence = detectMicroaneurysms(img)
%
%   Microaneurysms are small (<125um), dark-red, round retinal lesions
%   caused by capillary wall weakening. In color fundus images they appear
%   as small dark spots, most visible in the red channel where blood
%   absorbs light relative to the surrounding retinal background.
%
%   Detection uses black-hat morphology to enhance dark features below
%   the local retinal background, followed by adaptive statistical
%   thresholding and anatomical exclusion (vessels, optic disc, FOV).
%
%   Input:
%       img - RGB fundus image (uint8 or double [0,1])
%
%   Name-Value Pairs:
%       'MinArea'  - Minimum lesion area in pixels (default: auto-scaled)
%       'MaxArea'  - Maximum lesion area in pixels (default: auto-scaled)
%       'Diagnostic' - If true, include diagnostic masks (default: false)
%
%   Output:
%       evidence - Struct with fields:
%           .count          - Number of detected candidates
%           .mask           - Binary mask of detected candidates
%           .locations      - Nx2 matrix of [row, col] centroids
%           .areas          - N-element vector of areas (pixels)
%           .confidence     - Detection confidence (0-1)
%           .retinalMask    - Retinal FOV mask (if Diagnostic=true)
%           .vesselMask     - Vessel exclusion mask (if Diagnostic=true)
%           .discMask       - Optic disc mask (if Diagnostic=true)
%           .rawCandidates  - Pre-filter candidate mask (if Diagnostic=true)
%           .filteredCandidates - Post-filter mask (if Diagnostic=true)
%           .labels         - Connected component labels (if Diagnostic=true)

    p = inputParser;
    addRequired(p, 'img');
    addParameter(p, 'MinArea', -1, @isnumeric);
    addParameter(p, 'MaxArea', -1, @isnumeric);
    addParameter(p, 'Diagnostic', false, @islogical);
    parse(p, img, varargin{:});

    [rows, cols, ~] = size(img);

    % Initialize output
    evidence = struct();
    evidence.count = 0;
    evidence.mask = false(rows, cols);
    evidence.locations = [];
    evidence.areas = [];
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

        [rows, cols, ~] = size(imgD);
        if rows < 2 || cols < 2
            return;
        end

        % --- Step 1: Retinal FOV mask ---
        retinalMask = createRetinalMask(imgD);
        if diag; evidence.retinalMask = retinalMask; end

        % --- Step 2: Optic disc mask ---
        discMask = createDiscMask(imgD, retinalMask);
        if diag; evidence.discMask = discMask; end

        % --- Step 3: Adaptive vessel mask ---
        vesselMask = createVesselMask(imgD, retinalMask);
        if diag; evidence.vesselMask = vesselMask; end

        % --- Step 4: Black-hat morphology (dark feature enhancement) ---
        % Black-hat: closing(f) - f
        % This extracts features that are DARKER than the local background.
        % Microaneurysms are dark spots in the red channel, so black-hat
        % produces a POSITIVE response at MA locations.
        %
        % We use the red channel because MAs (blood-filled) absorb light
        % most strongly in the red band relative to surrounding retina.
        redCh = imgD(:,:,1);

        % Structuring element: radius 3 covers small MAs. Larger MAs exceed
        % the SE and yield rim-only black-hat responses, so a second,
        % size-agnostic term (local background subtraction) is combined by
        % maximum (shared lesson, Phase 20B.4). Both terms are positive at
        % features DARKER than the local background.
        seSmall = strel('disk', 3);
        redClosing = imclose(redCh, seSmall);
        blackHat = redClosing - redCh;
        blackHat(blackHat < 0) = 0;

        bgWinMA = 19;
        bgEstMA = imboxfilt(redCh, [bgWinMA bgWinMA]);
        bgSubMA = bgEstMA - redCh;
        bgSubMA(bgSubMA < 0) = 0;

        darkResponse = max(blackHat, bgSubMA);

        % --- Step 5: Adaptive thresholding ---
        % Strategy: threshold = local_mean + k * local_std
        % Applied in sliding-window fashion via imboxfilt.
        %
        % Mathematical justification:
        %   Under the null hypothesis (no MA), black-hat values follow a
        %   distribution with mean mu_bg and std sigma_bg. A genuine dark
        %   feature produces black-hat values significantly above the
        %   background distribution. Setting threshold at mu + k*sigma
        %   controls false positives: for Gaussian noise, k=3 gives ~0.15%
        %   false positive rate per pixel.
        %
        %   We use k=2.5 as a compromise between sensitivity (MAs are small
        %   and can have modest contrast) and specificity (avoid noise).
        %
        %   The window size for local statistics is 39x39 pixels — large
        %   relative to lesions so a lesion cannot inflate its own
        %   threshold by dominating the window (shared lesson, 20B.4).

        winSize = 39;
        localMean = imboxfilt(darkResponse, [winSize winSize]);
        localVar = imboxfilt(darkResponse.^2, [winSize winSize]) - localMean.^2;
        localVar = max(localVar, 0);
        localStd = sqrt(localVar);

        kThreshold = 2.5;
        thresholdMap = localMean + kThreshold * localStd;

        % Also enforce a minimum absolute threshold to avoid detecting
        % noise in uniform regions where localStd ~ 0
        minAbsThreshold = 0.01;
        thresholdMap = max(thresholdMap, minAbsThreshold);

        candidates = darkResponse > thresholdMap;

        if diag; evidence.rawCandidates = candidates; end

        % --- Step 6: Anatomical exclusion ---
        % Remove candidates outside retinal FOV
        candidates(~retinalMask) = false;

        % Remove candidates on optic disc
        candidates(discMask) = false;

        % Remove candidates on vessels
        candidates(vesselMask) = false;

        % --- Step 7: Boundary rejection ---
        % Remove candidates touching image edges or FOV boundary
        edgeMargin = 5;
        candidates(1:edgeMargin, :) = false;
        candidates(rows-edgeMargin+1:rows, :) = false;
        candidates(:, 1:edgeMargin) = false;
        candidates(:, cols-edgeMargin+1:cols) = false;

        % Remove candidates touching the FOV boundary (morphological erosion)
        fovEroded =imerode(retinalMask, strel('disk', 3));
        candidates(~fovEroded) = false;

        % --- Step 8: Morphological cleanup ---
        % Small opening removes single-pixel noise; closing fills small gaps
        seClean = strel('disk', 1);
        candidates = imopen(candidates, seClean);
        candidates = imclose(candidates, seClean);

        % --- Step 9: Resolution-aware size filtering ---
        % MA clinical size: 12-125 um diameter (International Clinical DR
        % Severity Scale). Pixel scale varies by image resolution.
        %
        % Heuristic: assume fundus covers ~6mm diameter retina.
        % image_diameter_pixels -> 6mm / image_diameter = mm/pixel
        % 125um / mm_per_pixel = max_diameter_pixels
        % 25um / mm_per_pixel = min_diameter_pixels (conservative lower bound)
        %
        % +1px discretization margin on the upper bound: at coarse screening
        % resolution (1px ~= 19um at 224px) a true 125um MA digitizes to
        % ~7px, and strict rounding would reject it. Negligible at high res.
        %
        % Clamp to plausible range to avoid degenerate cases.
        imgDiameter = sqrt(rows^2 + cols^2);
        mmPerPixel = 6.0 / imgDiameter;
        minDiamPx = max(2, round(0.025 / mmPerPixel / 2));
        maxDiamPx = min(round(min(rows, cols)/4), round(0.125 / mmPerPixel / 2) + 1);

        % Area = pi * r^2
        minAreaCalc = max(3, round(pi * minDiamPx^2));
        maxAreaCalc = max(minAreaCalc + 1, round(pi * maxDiamPx^2));

        % Use user-provided values only if explicitly set (not default -1)
        if p.Results.MinArea >= 0
            minAreaCalc = p.Results.MinArea;
        end
        if p.Results.MaxArea >= 0
            maxAreaCalc = p.Results.MaxArea;
        end

        candidates = bwareaopen(candidates, minAreaCalc);

        % --- Step 10: Region property filtering ---
        cc = bwconncomp(candidates);
        if cc.NumObjects == 0
            return;
        end

        stats = regionprops(cc, 'Area', 'Centroid', 'Eccentricity', ...
            'Solidity', 'BoundingBox', 'PixelIdxList');

        nCandidates = numel(stats);
        keep = true(nCandidates, 1);

        for i = 1:nCandidates
            % Area filter
            if stats(i).Area < minAreaCalc || stats(i).Area > maxAreaCalc
                keep(i) = false;
                continue;
            end

            % Eccentricity filter: MAs are roughly circular
            % Eccentricity of a circle = 0, ellipse < 0.7
            if stats(i).Eccentricity > 0.8
                keep(i) = false;
                continue;
            end

            % Solidity filter: MAs are compact
            if stats(i).Solidity < 0.4
                keep(i) = false;
                continue;
            end

            % Local contrast: MA must be darker than local background
            % In the red channel, MA < local_mean
            c = round(stats(i).Centroid(1));
            r = round(stats(i).Centroid(2));
            c = max(1, min(c, cols));
            r = max(1, min(r, rows));

            patchR = 15;
            rMin = max(1, r - patchR);
            rMax = min(rows, r + patchR);
            cMin = max(1, c - patchR);
            cMax = min(cols, c + patchR);

            localPatch = redCh(rMin:rMax, cMin:cMax);
            localMu = mean(localPatch(:));
            localSigma = std(localPatch(:));

            % MA should be darker: candidate value < local_mean - 1*std
            % This confirms the dark-feature hypothesis from black-hat
            if localSigma > 0
                candidateVal = redCh(r, c);
                if candidateVal > localMu - 0.5 * localSigma
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
        evidence.locations = reshape([validStats.Centroid], 2, [])';

        % Recreate mask from kept components
        evidence.mask = false(rows, cols);
        labels = zeros(rows, cols, 'uint16');
        for i = 1:numel(validStats)
            evidence.mask(validStats(i).PixelIdxList) = true;
            labels(validStats(i).PixelIdxList) = i;
        end
        if diag; evidence.labels = labels; end

        % --- Step 12: Confidence ---
        % Confidence reflects detection density: more candidates in a
        % plausible range suggests real pathology rather than noise.
        % Scale: 0 candidates -> 0, >=15 candidates -> 1.0
        countScore = min(1.0, evidence.count / 15);

        % Area coverage: fraction of FOV occupied by candidates
        % MA coverage is typically <1% of FOV even in severe DR
        fovPixels = sum(retinalMask(:));
        if fovPixels > 0
            areaFrac = sum(evidence.areas) / fovPixels;
            areaScore = min(1.0, areaFrac / 0.01);
        else
            areaScore = 0;
        end

        evidence.confidence = 0.6 * countScore + 0.4 * areaScore;

        if diag; evidence.filteredCandidates = evidence.mask; end

    catch
        % Return empty evidence on any error
        evidence.count = 0;
        evidence.mask = false(rows, cols);
        evidence.locations = [];
        evidence.areas = [];
        evidence.confidence = 0;
    end
end

function mask = createRetinalMask(imgD)
% createRetinalMask  Approximate retinal field-of-view mask
%
%   The retina occupies a roughly circular region in fundus images.
%   We estimate it using green channel intensity: retinal tissue is
%   brighter than the surrounding dark background.

    green = imgD(:,:,2);
    gray = rgb2gray(imgD);

    % Multi-scale approach: combine green channel and grayscale
    % Retinal tissue has green channel > background (typically <0.15)
    bgThreshGreen = gray < 0.2;

    % The RETINA is the bright region enclosed by dark background: take
    % the complement and keep its largest component (the FOV disk).
    % Order matters: OPEN the background first (erases thin dark vessels
    % that would otherwise partition the disk into slices), THEN close to
    % merge background gaps. (Previous construction filled the retina as
    % a "hole" and returned the whole frame — vacuous gate. The first
    % complement attempt partitioned on full-width vessels. Both found by
    % executed validation, Phase 20B.5 cross-phase defect.)
    bgOpened = imopen(bgThreshGreen, strel('disk', 3));
    bgClosed = imclose(bgOpened, strel('disk', 15));
    retinaCand = ~bgClosed;

    % Largest connected component is the FOV
    cc = bwconncomp(retinaCand);
    if cc.NumObjects == 0
        mask = true(size(imgD, 1), size(imgD, 2));
        return;
    end

    areas = cellfun(@numel, cc.PixelIdxList);
    [~, maxIdx] = max(areas);
    mask = false(size(imgD, 1), size(imgD, 2));
    mask(cc.PixelIdxList{maxIdx}) = true;

    % Smooth the boundary
    mask = imclose(mask, strel('disk', 10));
    mask = imfill(mask, 'holes');
end

function discMask = createDiscMask(imgD, retinalMask)
% createDiscMask  Detect optic disc for exclusion
%
%   The optic disc is the brightest large circular region in the fundus.
%   We detect it using intensity thresholding on the grayscale image,
%   restricted to the retinal FOV.

    [rows, cols, ~] = size(imgD);
    gray = rgb2gray(imgD);

    % Adaptive threshold: top 5% of retinal brightness
    retinalPixels = gray(retinalMask);
    if isempty(retinalPixels)
        discMask = false(rows, cols);
        return;
    end
    brightThresh = prctile(retinalPixels, 95);

    brightRegion = gray > brightThresh & retinalMask;

    % De-speckle WITHOUT closing first (shared fix, Phase 20B.4): closing
    % would merge distinct bright structures into one oversized blob.
    brightClean = imopen(brightRegion, strel('disk', 2));

    % Find largest bright component (the disc)
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

        % Plausibility gate (shared fix, Phase 20B.4): a real disc is
        % ~1/14 of the fundus width. Detections above 1/6 are diffuse
        % brightness, not anatomy — fail open (no mask) rather than blind
        % lesion detection over a huge area.
        if discRadius > min(rows, cols) / 6
            discMask = false(rows, cols);
            return;
        end

        center = stW(1).Centroid;

        % Boundary-sharpness test (shared fix, Phase 20B.4): require a
        % distinct pallor edge, else fail open (diffuse brightness).
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
        % Fallback: center of image, small radius
        centerR = round(rows / 2);
        centerC = round(cols / 2);
        discRadius = round(min(rows, cols) / 12);
        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - centerC).^2 + (Y - centerR).^2) < discRadius^2;
    end
end

function vesselMask = createVesselMask(imgD, retinalMask)
% createVesselMask  Adaptive vessel detection for exclusion
%
%   Vessels appear as dark tubular structures in the green channel.
%   We use an adaptive threshold based on the green channel distribution
%   within the retinal FOV, rather than a hard-coded value.
%
%   Method:
%     1. Extract green channel within retinal FOV
%     2. Compute percentile-based threshold: pixels darker than the
%        10th percentile of retinal green distribution are candidate vessels
%     3. Morphological opening with directional line structuring elements
%        at 0, 60, 120 degrees to select elongated (tubular) structures
%     4. Dilate to cover vessel edges

    green = imgD(:,:,2);

    % Adaptive threshold using retinal FOV statistics
    retinalGreen = green(retinalMask);
    if isempty(retinalGreen)
        vesselMask = false(size(imgD, 1), size(imgD, 2));
        return;
    end

    % Vessels are in the lower tail of the green distribution
    % 10th percentile captures most vessels while excluding background
    vesselThresh = prctile(retinalGreen, 10);

    vesselRaw = green < vesselThresh;

    % Directional morphological opening: select elongated structures
    seLen = max(5, round(min(size(imgD,1), size(imgD,2)) * 0.02));
    vessel1 = imopen(vesselRaw, strel('line', seLen, 0));
    vessel2 = imopen(vesselRaw, strel('line', seLen, 60));
    vessel3 = imopen(vesselRaw, strel('line', seLen, 120));

    vesselMask = vessel1 | vessel2 | vessel3;

    % Carve out compact blot-like components: directional opening keeps ANY
    % feature containing a line segment, including round lesion candidates.
    % Remove components that are large enough, solid, and round (thin
    % vessels have eccentricity ~ 1 and are kept). Shared fix with the
    % hemorrhage detector (Phase 20B.4): without this, blots are labeled
    % vessels and wrongly excluded from lesion candidacy.
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

    % Restrict to retinal FOV
    vesselMask(~retinalMask) = false;

    % Dilate to cover vessel edges (MA adjacent to vessel should be excluded)
    vesselMask = imdilate(vesselMask, strel('disk', 2));
end
