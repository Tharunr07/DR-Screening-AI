function evidence = detectNeovascularization(img, varargin)
% detectNeovascularization  Detect neovascularization candidates in fundus images
%
%   evidence = detectNeovascularization(img)
%
%   Neovascularization (NV) is abnormal new blood vessel growth on the
%   retinal surface or optic disc, a hallmark of proliferative diabetic
%   retinopathy (PDR). NV vessels are typically:
%     - finer than major retinal vessels
%     - more tortuous and irregular
%     - located in the peripheral retina or near the disc
%     - clustered in abnormal density concentrations
%
%   Detection proceeds in two stages:
%     1. VESSEL EXTRACTION: Separate dark vessels from background using
%        black-hat morphology on the green channel (correct polarity).
%     2. NV CRITERIA: Identify regions with abnormally high fine-vessel
%        density, irregularity, and peripheral/peripapillary location.
%        Normal major vessels are excluded.
%
%   Input:
%       img - RGB fundus image (uint8 or double [0,1])
%
%   Name-Value Pairs:
%       'Diagnostic' - If true, include diagnostic masks (default: false)
%
%   Output:
%       evidence - Struct with fields:
%           .detected      - Boolean: NV candidate detected
%           .mask          - Binary mask of candidate regions
%           .density       - Mean fine-vessel density in candidate regions
%           .irregularity  - Pattern irregularity score (0-1)
%           .confidence    - Detection confidence (0-1)
%           .retinalMask   - Retinal FOV mask (Diagnostic only)
%           .discMask      - Optic disc mask (Diagnostic only)
%           .vesselMask    - All-vessels mask (Diagnostic only)
%           .majorMask     - Major vessel mask (Diagnostic only)
%           .fineMask      - Fine vessel mask (Diagnostic only)
%           .densityMap    - Continuous density map (Diagnostic only)
%           .rawNV         - Pre-filter NV candidates (Diagnostic only)
%           .labels        - Connected component labels (Diagnostic only)

    p = inputParser;
    addRequired(p, 'img');
    addParameter(p, 'Diagnostic', false, @islogical);
    parse(p, img, varargin{:});

    [rows, cols, ~] = size(img);

    % Initialize output
    evidence = struct();
    evidence.detected = false;
    evidence.mask = false(rows, cols);
    evidence.density = 0;
    evidence.irregularity = 0;
    evidence.confidence = 0;

    diag = p.Results.Diagnostic;
    if diag
        evidence.retinalMask = false(rows, cols);
        evidence.discMask = false(rows, cols);
        evidence.vesselMask = false(rows, cols);
        evidence.majorMask = false(rows, cols);
        evidence.fineMask = false(rows, cols);
        evidence.densityMap = zeros(rows, cols);
        evidence.rawNV = false(rows, cols);
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

        % --- Step 2: Optic disc detection ---
        discMask = createDiscMask(imgD, retinalMask);
        if diag; evidence.discMask = discMask; end

        % --- Step 3: Vessel extraction ---
        % Correct polarity: vessels are DARK in the green channel.
        % Black-hat (closing - original) produces positive response at
        % dark features below the local background.
        greenCh = imgD(:,:,2);

        % Estimate fundus radius for adaptive SE sizing
        fundusRadius = estimateFundusRadius(retinalMask);

        % Black-hat for vessel enhancement
        seBH = strel('disk', 3);
        vesselResponse = imclose(greenCh, seBH) - greenCh;
        vesselResponse(vesselResponse < 0) = 0;

        % Adaptive threshold: local mean + 1.5*std of vessel response
        winSz = max(15, round(fundusRadius / 3));
        if mod(winSz, 2) == 0; winSz = winSz + 1; end
        localMu = imboxfilt(vesselResponse, [winSz winSz]);
        localVar = imboxfilt(vesselResponse.^2, [winSz winSz]) - localMu.^2;
        localVar = max(localVar, 0);
        localSig = sqrt(localVar);

        vesselThreshold = localMu + 1.5 * localSig;
        vesselThreshold = max(vesselThreshold, 0.005);
        vesselMask = vesselResponse > vesselThreshold;
        vesselMask(~retinalMask) = false;

        % Directional morphological opening: keep elongated structures.
        % 12 orientations (15-degree steps): 6 orientations fragment thin
        % vessels lying between sampling angles; 12 keeps continuity
        % (standard practice) at ~2x cost.
        seLen = max(5, round(fundusRadius * 0.04));
        vesselOriented = false(rows, cols);
        for ang = 0:15:165
            vesselOriented = vesselOriented | imopen(vesselMask, strel('line', seLen, ang));
        end
        vesselMask = vesselMask & vesselOriented;

        % Carve out compact blot-like components (lesion candidates, not
        % vessels): directional opening keeps any feature containing a line
        % segment. Thin vessels (eccentricity ~ 1) are kept.
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

        % Remove tiny fragments (noise)
        vesselMask = bwareaopen(vesselMask, max(5, round(fundusRadius * 0.005)));
        vesselMask(~retinalMask) = false;
        if diag; evidence.vesselMask = vesselMask; end

        % --- Step 4: Separate major vessels from fine vessels ---
        % Major vessels: arcade vessels span hundreds of pixels, so the
        % opening uses long segments (6x the fine scale ~= 30px). NV fronds
        % contain only short runs (10-30px); a short 3x multiple would
        % misclassify frond pieces as major and the overlap gate would
        % then reject genuine proliferation (found by executed validation).
        majorMask = false(rows, cols);
        for ang = 0:15:165
            majorMask = majorMask | imopen(vesselMask, strel('line', seLen * 6, ang));
        end
        majorMask = imdilate(majorMask, strel('disk', 2));
        majorMask(~retinalMask) = false;
        if diag; evidence.majorMask = majorMask; end

        % Fine vessels: all vessels minus major vessels
        % These are candidates for NV (but also include normal capillaries)
        fineMask = vesselMask & ~majorMask;
        if diag; evidence.fineMask = fineMask; end

        % --- Step 5: Exclude disc from analysis ---
        fineExclDisc = fineMask;
        fineExclDisc(discMask) = false;

        % Bridge sub-4px fragmentation gaps for CLUSTERING ONLY. Thin-vessel
        % fragmentation (orientation sampling, junctions) shatters dense
        % meshes into disconnected bits; closing disk-2 reconnects pieces
        % of one proliferation without merging distant structures. Density
        % statistics and the final mask always use ORIGINAL fine pixels.
        fineClosed = imclose(fineExclDisc, strel('disk', 2));

        % --- Step 6: Density-based NV candidate detection ---
        % Compute fine-vessel density using connected components.
        % NV forms clusters of fine vessels; normal capillaries are
        % sparsely distributed.
        ccFine = bwconncomp(fineClosed);
        if ccFine.NumObjects == 0
            return;
        end

        statsFine = regionprops(ccFine, 'Area', 'Centroid', 'Eccentricity', ...
            'Solidity', 'BoundingBox', 'PixelIdxList');

        % Adaptive area threshold: NV clusters are larger than isolated
        % noise but smaller than the entire retina.
        % Min: fine vessels are thin; a cluster needs ~50 pixels
        % Max: NV typically affects a region, not the whole retina
        minClusterArea = max(20, round(fundusRadius * 0.01));
        maxClusterArea = round(pi * (fundusRadius * 0.4)^2);

        % Fixed density window (found by executed validation): local density
        % MUST be measured in equal windows for candidates and background.
        % Component-adaptive windows (bbox+pad) inflate small components'
        % densities via small denominators, making background bits look as
        % "dense" as real proliferations and blinding the comparison.
        winDens = max(31, round(min(rows, cols) * 0.14));
        halfDens = floor(winDens / 2);

        % --- Step 7: Per-cluster NV criteria ---
        % For each candidate cluster, evaluate:
        %   (a) Cluster area (size plausibility)
        %   (b) Fine-vessel density within the cluster's local region
        %   (c) Irregularity (vessels are not parallel/smooth)
        %   (d) Peripheral or peripapillary location
        %   (e) Arcade proximity (not on/hugging major vessels)

        [X, Y] = meshgrid(1:cols, 1:rows);
        centerR = rows / 2;
        centerC = cols / 2;
        maxDist = sqrt(centerR^2 + centerC^2);

        nvCandidates = false(rows, cols);
        clusterStats = struct();
        keptLabels = [];
        nValid = 0;

        for i = 1:numel(statsFine)
            % (a) Area filter
            if statsFine(i).Area < minClusterArea || statsFine(i).Area > maxClusterArea
                continue;
            end

            % (b) Local fine-vessel density in the FIXED window centered on
            % the cluster centroid (comparable across components).
            cc0 = round(statsFine(i).Centroid);
            r1 = max(1, cc0(2) - halfDens);
            r2 = min(rows, cc0(2) + halfDens);
            c1 = max(1, cc0(1) - halfDens);
            c2 = min(cols, cc0(1) + halfDens);

            localRegion = fineExclDisc(r1:r2, c1:c2);
            localFOV = retinalMask(r1:r2, c1:c2);
            fovPixels = sum(localFOV(:));
            if fovPixels < 100
                continue;
            end
            localDensity = sum(localRegion(:)) / fovPixels;

            % (c) Irregularity: boundary roughness of the cluster
            clusterMask = false(rows, cols);
            clusterMask(statsFine(i).PixelIdxList) = true;
            boundaryPixels = getBoundaryPixels(clusterMask);
            if size(boundaryPixels, 1) < 6
                continue;  % Too small for irregularity measurement
            end
            irregularity = computeIrregularity(boundaryPixels);

            % (c2) Proliferative branching: the ORIGINAL fine pattern inside
            % the cluster region must contain vessel junctions. Smooth
            % vessel fragments have zero junctions however dense or
            % peripheral they are (found by executed validation: arc pieces
            % drove flaky high-confidence FPs). Skeleton spurs shorter
            % than 3px are pruned so pixelation cannot fake a junction.
            % Threshold >= 2 (not >= 1): one noise speck touching a vessel
            % makes exactly one junction; real proliferations branch
            % repeatedly (surveyed frond mesh: 28 junctions).
            origInRegion = fineExclDisc;
            origInRegion(~clusterMask) = false;
            sk = bwskel(origInRegion, 'MinBranchLength', 3);
            if sum(sk(:)) < 8
                continue;  % too small to assess branching: reject
            end
            bp = bwmorph(sk, 'branchpoints');
            if sum(bp(:)) < 2
                continue;  % fewer than 2 junctions: not proliferation
            end

            % (d) Location: peripheral or peripapillary
            centroid = statsFine(i).Centroid;
            distFromCenter = sqrt((centroid(1) - centerC)^2 + (centroid(2) - centerR)^2);
            normDist = distFromCenter / maxDist;

            % Peripapillary: within 2 disc radii of disc center
            % Peripapillary: within 2 disc radii of a LOCATED disc. If disc
            % localization failed (empty mask), the peripapillary zone is
            % DISABLED rather than assumed at a guessed point: an assumed
            % disc would hand central vessel fragments a free location
            % pass (found by executed validation: flaky T17). Only the
            % peripheral criterion then applies.
            discFound = any(discMask(:));
            discCenter = getDiscCenter(discMask, rows, cols);
            distFromDisc = sqrt((centroid(1) - discCenter(1))^2 + ...
                                (centroid(2) - discCenter(2))^2);
            isPeripapillary = discFound && (distFromDisc < 2 * fundusRadius * 0.12);
            isPeripheral = normDist > 0.3;
            isLocallyValid = isPeripapillary || isPeripheral;

            % (e) Vessel-proximity gate: the component must not sit on or
            % hug a major arcade. Normal-vessel fragments (broken arcade
            % pieces) lie within a few pixels of major runs; genuine
            % fronds arise AWAY from the arcades. Overlap alone is too lax
            % for fragments that narrowly missed the major opening, so test
            % proximity to the dilated major mask (found by executed
            % validation: flaky T17 high-confidence FP on arc fragments).
            if ~exist('majorNear', 'var')
                majorNear = imdilate(majorMask, strel('disk', 5));
            end
            nearFrac = sum(majorNear(statsFine(i).PixelIdxList)) / statsFine(i).Area;
            if nearFrac > 0.5
                continue;  % arcade-adjacent normal vasculature, not NV
            end

            % Accumulate valid clusters
            nValid = nValid + 1;
            keptLabels(end + 1) = i;
            nvCandidates(statsFine(i).PixelIdxList) = true;
            clusterStats(nValid).area = statsFine(i).Area;
            clusterStats(nValid).density = localDensity;
            clusterStats(nValid).irregularity = irregularity;
            clusterStats(nValid).isLocallyValid = isLocallyValid;
            clusterStats(nValid).normDist = normDist;
        end

        if nValid == 0
            return;
        end

        % --- Step 8: Aggregate cluster statistics ---
        allDensities = [clusterStats.density];
        allIrregularity = [clusterStats.irregularity];
        allLocalValid = [clusterStats.isLocallyValid];
        allAreas = [clusterStats.area];

        % Require at least some clusters in valid locations
        validFraction = sum(allLocalValid) / numel(allLocalValid);
        if validFraction < 0.3
            return;  % Most clusters are in invalid locations
        end

        % Weighted aggregate (larger clusters weighted more)
        weights = allAreas / sum(allAreas);
        meanDensity = sum(allDensities .* weights);
        meanIrregularity = sum(allIrregularity .* weights);
        meanNormDist = sum([clusterStats.normDist] .* weights);

        % --- Step 9: Final NV detection decision ---
        % Multiple criteria must be satisfied:
        %   (1) Fine-vessel density must exceed adaptive threshold
        %   (2) Irregularity must be above baseline
        %   (3) At least some clusters in peripheral/peripapillary locations
        %   (4) Sufficient total area of candidate regions

        % Adaptive density threshold based on BACKGROUND fine-vessel
        % density. Crucially, candidate-sized components (>= minClusterArea,
        % i.e. the potential NV itself plus normal vessels) are EXCLUDED
        % from the baseline: abnormal means outlier relative to the
        % background texture, not relative to a mixture containing the
        % candidate. (Including candidates inflates median/MAD and blinds
        % the test to the very thing it seeks; found by executed
        % validation.) Falls back to all components if no background bits.
        allFineDensities = [];
        for i = 1:numel(statsFine)
            if statsFine(i).Area >= minClusterArea
                continue;
            end
            cc0 = round(statsFine(i).Centroid);
            r1 = max(1, cc0(2) - halfDens);
            r2 = min(rows, cc0(2) + halfDens);
            c1 = max(1, cc0(1) - halfDens);
            c2 = min(cols, cc0(1) + halfDens);
            localRegion = fineExclDisc(r1:r2, c1:c2);
            localFOV = retinalMask(r1:r2, c1:c2);
            fovPx = sum(localFOV(:));
            if fovPx >= 100
                allFineDensities(end+1) = sum(localRegion(:)) / fovPx;
            end
        end

        if isempty(allFineDensities)
            % No background bits: fall back to all components (fixed window).
            for i = 1:numel(statsFine)
                cc0 = round(statsFine(i).Centroid);
                r1 = max(1, cc0(2) - halfDens);
                r2 = min(rows, cc0(2) + halfDens);
                c1 = max(1, cc0(1) - halfDens);
                c2 = min(cols, cc0(1) + halfDens);
                localRegion = fineExclDisc(r1:r2, c1:c2);
                localFOV = retinalMask(r1:r2, c1:c2);
                fovPx = sum(localFOV(:));
                if fovPx >= 100
                    allFineDensities(end+1) = sum(localRegion(:)) / fovPx;
                end
            end
        end

        if isempty(allFineDensities)
            return;
        end

        overallMedianDensity = median(allFineDensities);
        overallMAD = median(abs(allFineDensities - overallMedianDensity));

        % Density threshold: median + 3*MAD (adaptive, robust)
        if overallMAD > 0
            densityThreshold = overallMedianDensity + 3 * overallMAD;
        else
            densityThreshold = overallMedianDensity * 1.5;
        end

        % Apply final criteria
        densityCriterion = meanDensity > densityThreshold && meanDensity > 0.01;
        irregularityCriterion = meanIrregularity > 0.2;
        locationCriterion = validFraction >= 0.3;
        totalAreaCriterion = sum(allAreas) > minClusterArea * 2;

        if densityCriterion && irregularityCriterion && locationCriterion && totalAreaCriterion
            evidence.detected = true;
            evidence.density = meanDensity;
            evidence.irregularity = meanIrregularity;

            % Create output mask from ORIGINAL fine pixels inside kept
            % cluster regions (bridge pixels from closing are excluded).
            labKept = labelmatrix(ccFine);
            evidence.mask = fineExclDisc & ismember(labKept, keptLabels);
            evidence.mask(discMask) = false;  % Ensure disc is excluded
            evidence.mask(~retinalMask) = false;

            % Remove isolated tiny fragments
            evidence.mask = bwareaopen(evidence.mask, minClusterArea);

            % Bridge-supported-only detections evaporate here: reject
            % honestly instead of reporting an empty mask as detected.
            if ~any(evidence.mask(:))
                evidence.detected = false;
                evidence.density = meanDensity;
                evidence.irregularity = meanIrregularity;
                evidence.confidence = 0;
                if diag
                    evidence.rawNV = nvCandidates;
                    evidence.labels = zeros(rows, cols, 'uint16');
                end
                return;
            end

            % Recompute from final mask
            ccFinal = bwconncomp(evidence.mask);
            if ccFinal.NumObjects > 0
                statsFinal = regionprops(ccFinal, 'Area');
                finalAreas = [statsFinal.Area];
                % Remove any remaining oversized components
                tooBig = finalAreas > maxClusterArea;
                if any(tooBig)
                    labFinal = labelmatrix(ccFinal);
                    for j = find(tooBig)
                        evidence.mask(labFinal == j) = false;
                    end
                end
            end

            % Recompute irregularity from final mask
            finalBoundary = getBoundaryPixels(evidence.mask);
            if size(finalBoundary, 1) >= 6
                evidence.irregularity = computeIrregularity(finalBoundary);
            end

            % Confidence based on multiple factors
            densityScore = min(1.0, meanDensity / 0.1);
            locationScore = min(1.0, validFraction / 0.5);
            areaScore = min(1.0, sum(allAreas) / (minClusterArea * 5));
            evidence.confidence = min(1.0, ...
                0.35 * densityScore + ...
                0.25 * evidence.irregularity + ...
                0.20 * locationScore + ...
                0.20 * areaScore);

            if diag
                evidence.rawNV = nvCandidates;
                ccLabels = bwlabel(evidence.mask);
                evidence.labels = uint16(ccLabels);
            end
        else
            evidence.density = meanDensity;
            evidence.irregularity = meanIrregularity;
        end

    catch
        % Return empty evidence on any error
        evidence.detected = false;
        evidence.mask = false(rows, cols);
        evidence.density = 0;
        evidence.irregularity = 0;
        evidence.confidence = 0;
    end
end

function mask = createRetinalMask(imgD)
% createRetinalMask  Approximate retinal field-of-view mask.
%   Dark pixels are background (outside FOV); the retina is the bright
%   region they enclose, so the mask is the largest component of the
%   COMPLEMENT. Open the background first (thin dark vessels would
%   otherwise partition the disk), then close gaps. (Two successive
%   constructions — fill-based vacuous mask, then partitioning complement
%   — both found by executed validation, Phase 20B.5.)
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
% createDiscMask  Detect optic disc (adaptive threshold, no center fallback)
    [rows, cols, ~] = size(imgD);
    gray = rgb2gray(imgD);

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

        % Plausibility gate (shared fix, Phase 20B.4): fail open on
        % detections above 1/6 of the image width (diffuse brightness,
        % not a disc; real discs are ~1/14).
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
        % Conservative fallback: small disc at estimated location
        centerR = round(rows * 0.45);
        centerC = round(cols * 0.55);
        discRadius = round(min(rows, cols) / 16);
        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - centerC).^2 + (Y - centerR).^2) < discRadius^2;
    end
end

function radius = estimateFundusRadius(retinalMask)
% estimateFundusRadius  Estimate the radius of the retinal fundus in pixels
    [rows, cols] = size(retinalMask);
    centerR = rows / 2;
    centerC = cols / 2;
    maxR = round(min(rows, cols) / 2);

    % Sample the logical mask directly (rgb2gray requires RGB input and
    % would throw on a 2-D mask — that bug silently disabled this whole
    % detector via try/catch; found by executed validation in Phase 20B.4).
    for r = maxR:-10:10
        theta = linspace(0, 2*pi, 360);
        x = round(centerC + r * cos(theta));
        y = round(centerR + r * sin(theta));
        x = max(1, min(cols, x));
        y = max(1, min(rows, y));
        vals = retinalMask(sub2ind([rows, cols], y, x));
        if mean(vals) > 0.5
            radius = r;
            return;
        end
    end
    radius = round(min(rows, cols) / 2);
end

function center = getDiscCenter(discMask, rows, cols)
% getDiscCenter  Get disc center coordinates, with fallback
    if any(discMask(:))
        stats = regionprops(discMask, 'Centroid');
        center = stats(1).Centroid;
    else
        center = [cols * 0.55, rows * 0.45];
    end
end

function boundaryPixels = getBoundaryPixels(mask)
% getBoundaryPixels  Get boundary pixel coordinates of a binary mask
    eroded = imerode(mask, strel('disk', 1));
    boundaryMask = mask & ~eroded;
    [r, c] = find(boundaryMask);
    boundaryPixels = [r, c];
end

function irr = computeIrregularity(boundaryPixels)
% computeIrregularity  Measure boundary irregularity of a region
%
%   Irregularity = path length / convex hull perimeter.
%   A perfect circle has irregularity ~1.0.
%   NV vessels have irregular, tortuous boundaries → higher values.

    if size(boundaryPixels, 1) < 6
        irr = 0;
        return;
    end

    % Sort boundary pixels by angle from centroid
    centroid = mean(boundaryPixels, 1);
    angles = atan2(boundaryPixels(:,2) - centroid(2), ...
                   boundaryPixels(:,1) - centroid(1));
    [~, sortIdx] = sort(angles);
    sortedPixels = boundaryPixels(sortIdx, :);

    % Compute path length along boundary
    diffs = diff(sortedPixels, 1, 1);
    pathLength = sum(sqrt(sum(diffs.^2, 2)));

    % Convex hull perimeter
    try
        hull = convhull(sortedPixels(:,1), sortedPixels(:,2));
        hullPts = sortedPixels(hull, :);
        hullDiffs = diff(hullPts, 1, 1);
        hullPerimeter = sum(sqrt(sum(hullDiffs.^2, 2)));
    catch
        hullPerimeter = pathLength;
    end

    if hullPerimeter > 0
        irr = min(1.0, pathLength / hullPerimeter);
    else
        irr = 0;
    end
end
