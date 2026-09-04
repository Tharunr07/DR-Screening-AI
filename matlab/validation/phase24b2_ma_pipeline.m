function phase24b2_ma_pipeline()
% phase24b2_ma_pipeline  Trace exactly where MA candidates are lost

    fprintf('============================================================\n');
    fprintf('  MA Pipeline Step-by-Step Trace\n');
    fprintf('============================================================\n\n');

    fundusDir = 'data/raw/IDRiD/A. Segmentation/1. Original Images/a. Training Set';
    outputDir = 'results/phase24b2_forensic';

    for imgIdx = [1, 10, 25]
        imgId = sprintf('IDRiD_%02d', imgIdx);
        fundusPath = fullfile(fundusDir, [imgId '.jpg']);
        fundus = imread(fundusPath);
        [rows, cols, ~] = size(fundus);

        fprintf('--- %s (%dx%d) ---\n', imgId, cols, rows);

        imgD = double(fundus) / 255;
        redCh = imgD(:,:,1);

        % Steps 1-4: dark response
        seSmall = strel('disk', 3);
        redClosing = imclose(redCh, seSmall);
        blackHat = redClosing - redCh;
        blackHat(blackHat < 0) = 0;
        bgWinMA = 19;
        bgEstMA = imboxfilt(redCh, [bgWinMA bgWinMA]);
        bgSubMA = bgEstMA - redCh;
        bgSubMA(bgSubMA < 0) = 0;
        darkResponse = max(blackHat, bgSubMA);

        % Step 5: threshold
        winSize = 39;
        localMean = imboxfilt(darkResponse, [winSize winSize]);
        localVar = imboxfilt(darkResponse.^2, [winSize winSize]) - localMean.^2;
        localVar = max(localVar, 0);
        localStd = sqrt(localVar);
        kThreshold = 2.5;
        thresholdMap = localMean + kThreshold * localStd;
        minAbsThreshold = 0.01;
        thresholdMap = max(thresholdMap, minAbsThreshold);
        candidates = darkResponse > thresholdMap;

        % Step 6: anatomical exclusion
        retinalMask = createRetinalMask(imgD);
        discMask = createDiscMask(imgD, retinalMask);
        vesselMask = createVesselMask(imgD, retinalMask);
        candidates(~retinalMask) = false;
        candidates(discMask) = false;
        candidates(vesselMask) = false;
        fprintf('  After anatomical exclusion: %d candidates\n', sum(candidates(:)));

        % Step 7: boundary rejection
        edgeMargin = 5;
        candidatesBefore = candidates;
        candidates(1:edgeMargin, :) = false;
        candidates(rows-edgeMargin+1:rows, :) = false;
        candidates(:, 1:edgeMargin) = false;
        candidates(:, cols-edgeMargin+1:cols) = false;
        fprintf('  After edge margin (%d): %d candidates (lost %d)\n', ...
            edgeMargin, sum(candidates(:)), sum(candidatesBefore(:)) - sum(candidates(:)));

        % FOV erosion
        fovEroded = imerode(retinalMask, strel('disk', 3));
        candidatesBefore2 = candidates;
        candidates(~fovEroded) = false;
        fprintf('  After FOV erosion: %d candidates (lost %d)\n', ...
            sum(candidates(:)), sum(candidatesBefore2(:)) - sum(candidates(:)));

        % Step 8: morphological cleanup
        seClean = strel('disk', 1);
        candidatesBefore3 = candidates;
        candidates = imopen(candidates, seClean);
        candidates = imclose(candidates, seClean);
        fprintf('  After morph cleanup: %d candidates (lost %d)\n', ...
            sum(candidates(:)), sum(candidatesBefore3(:)) - sum(candidates(:)));

        % Step 9: size filtering
        imgDiameter = sqrt(rows^2 + cols^2);
        mmPerPixel = 6.0 / imgDiameter;
        minDiamPx = max(2, round(0.025 / mmPerPixel / 2));
        maxDiamPx = min(round(min(rows, cols)/4), round(0.125 / mmPerPixel / 2) + 1);
        minAreaCalc = max(3, round(pi * minDiamPx^2));
        maxAreaCalc = max(minAreaCalc + 1, round(pi * maxDiamPx^2));
        fprintf('  Size filter: minArea=%d maxArea=%d\n', minAreaCalc, maxAreaCalc);
        fprintf('    (minDiam=%.1fpx maxDiam=%.1fpx at %.4f mm/px)\n', ...
            minDiamPx*2, maxDiamPx*2, mmPerPixel);

        candidatesBefore4 = candidates;
        candidates = bwareaopen(candidates, minAreaCalc);
        fprintf('  After bwareaopen(min=%d): %d candidates (lost %d)\n', ...
            minAreaCalc, sum(candidates(:)), sum(candidatesBefore4(:)) - sum(candidates(:)));

        % Step 10: region properties
        cc = bwconncomp(candidates);
        fprintf('  Connected components: %d\n', cc.NumObjects);
        if cc.NumObjects > 0
            stats = regionprops(cc, 'Area', 'Eccentricity', 'Solidity');
            areas = [stats.Area]';
            eccs = [stats.Eccentricity]';
            sols = [stats.Solidity]';
            fprintf('  Area range: [%d, %d]\n', min(areas), max(areas));
            fprintf('  Eccentricity range: [%.3f, %.3f]\n', min(eccs), max(eccs));
            fprintf('  Solidity range: [%.3f, %.3f]\n', min(sols), max(sols));

            keep = true(cc.NumObjects, 1);
            for i = 1:cc.NumObjects
                if stats(i).Area < minAreaCalc || stats(i).Area > maxAreaCalc
                    keep(i) = false;
                elseif stats(i).Eccentricity > 0.8
                    keep(i) = false;
                elseif stats(i).Solidity < 0.4
                    keep(i) = false;
                end
            end
            fprintf('  After area+ecc+solidity filter: %d/%d kept\n', sum(keep), cc.NumObjects);
        end

        fprintf('\n');
    end
end


function mask = createRetinalMask(imgD)
    green = imgD(:,:,2);
    gray = rgb2gray(imgD);
    bgThreshGreen = gray < 0.2;
    bgOpened = imopen(bgThreshGreen, strel('disk', 3));
    bgClosed = imclose(bgOpened, strel('disk', 15));
    retinaCand = ~bgClosed;
    cc = bwconncomp(retinaCand);
    if cc.NumObjects == 0
        mask = true(size(imgD, 1), size(imgD, 2));
        return;
    end
    areas = cellfun(@numel, cc.PixelIdxList);
    [~, maxIdx] = max(areas);
    mask = false(size(imgD, 1), size(imgD, 2));
    mask(cc.PixelIdxList{maxIdx}) = true;
    mask = imclose(mask, strel('disk', 10));
    mask = imfill(mask, 'holes');
end

function discMask = createDiscMask(imgD, retinalMask)
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
        centerR = round(rows / 2);
        centerC = round(cols / 2);
        discRadius = round(min(rows, cols) / 12);
        [X, Y] = meshgrid(1:cols, 1:rows);
        discMask = ((X - centerC).^2 + (Y - centerR).^2) < discRadius^2;
    end
end

function vesselMask = createVesselMask(imgD, retinalMask)
    green = imgD(:,:,2);
    retinalGreen = green(retinalMask);
    if isempty(retinalGreen)
        vesselMask = false(size(imgD, 1), size(imgD, 2));
        return;
    end
    vesselThresh = prctile(retinalGreen, 10);
    vesselRaw = green < vesselThresh;
    seLen = max(5, round(min(size(imgD,1), size(imgD,2)) * 0.02));
    vessel1 = imopen(vesselRaw, strel('line', seLen, 0));
    vessel2 = imopen(vesselRaw, strel('line', seLen, 60));
    vessel3 = imopen(vesselRaw, strel('line', seLen, 120));
    vesselMask = vessel1 | vessel2 | vessel3;
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
    vesselMask = imdilate(vesselMask, strel('disk', 2));
end
