function phase24b2_ma_diagnostic()
% phase24b2_ma_diagnostic  Run MA detector in diagnostic mode on IDRiD images
%   to understand why it returns zero candidates.

    fprintf('============================================================\n');
    fprintf('  MA Detector Diagnostic Mode\n');
    fprintf('============================================================\n\n');

    fundusDir = 'data/raw/IDRiD/A. Segmentation/1. Original Images/a. Training Set';
    maskBase = 'data/raw/IDRiD/A. Segmentation/2. All Segmentation Groundtruths/a. Training Set';
    outputDir = 'results/phase24b2_forensic';
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    diagImages = [1, 5, 10, 25, 40];

    for imgIdx = diagImages
        imgId = sprintf('IDRiD_%02d', imgIdx);
        fundusPath = fullfile(fundusDir, [imgId '.jpg']);
        if ~exist(fundusPath, 'file'), continue; end

        fundus = imread(fundusPath);
        [h, w, ~] = size(fundus);

        fprintf('\n--- %s (fundus %dx%d) ---\n', imgId, w, h);

        % Run detector in diagnostic mode
        ev = detectMicroaneurysms(fundus, 'Diagnostic', true);

        fprintf('  Final: count=%d, mask_px=%d\n', ev.count, sum(ev.mask(:)));
        fprintf('  retinalMask px: %d / %d (%.1f%%)\n', ...
            sum(ev.retinalMask(:)), h*w, sum(ev.retinalMask(:))/h*w*100);
        fprintf('  discMask px: %d\n', sum(ev.discMask(:)));
        fprintf('  vesselMask px: %d / %d (%.1f%%)\n', ...
            sum(ev.vesselMask(:)), h*w, sum(ev.vesselMask(:))/h*w*100);
        fprintf('  rawCandidates px: %d\n', sum(ev.rawCandidates(:)));
        fprintf('  filteredCandidates px: %d\n', sum(ev.filteredCandidates(:)));

        % Manual intermediate analysis
        imgD = double(fundus) / 255;
        redCh = imgD(:,:,1);

        % Black-hat response
        seSmall = strel('disk', 3);
        redClosing = imclose(redCh, seSmall);
        blackHat = redClosing - redCh;
        blackHat(blackHat < 0) = 0;

        bgWinMA = 19;
        bgEstMA = imboxfilt(redCh, [bgWinMA bgWinMA]);
        bgSubMA = bgEstMA - redCh;
        bgSubMA(bgSubMA < 0) = 0;

        darkResponse = max(blackHat, bgSubMA);

        fprintf('  darkResponse: min=%.6f max=%.6f mean=%.6f median=%.6f\n', ...
            min(darkResponse(:)), max(darkResponse(:)), ...
            mean(darkResponse(:)), median(darkResponse(:)));
        fprintf('  darkResponse > 0: %d px (%.4f%%)\n', ...
            sum(darkResponse(:) > 0), sum(darkResponse(:) > 0)/h*w*100);
        fprintf('  darkResponse > 0.01: %d px\n', sum(darkResponse(:) > 0.01));
        fprintf('  darkResponse > 0.05: %d px\n', sum(darkResponse(:) > 0.05));

        % Threshold map
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
        fprintf('  candidates (pre-exclusion): %d px\n', sum(candidates(:)));

        % After retinal exclusion
        candidates(~ev.retinalMask) = false;
        fprintf('  candidates (retinal mask): %d px\n', sum(candidates(:)));

        candidates(ev.discMask) = false;
        fprintf('  candidates (disc excl): %d px\n', sum(candidates(:)));

        candidates(ev.vesselMask) = false;
        fprintf('  candidates (vessel excl): %d px\n', sum(candidates(:)));

        % Save diagnostic figure
        fig = figure('Visible', 'off', 'Position', [100 100 1600 900]);
        subplot(3, 3, 1); imshow(fundus); title('Original');
        subplot(3, 3, 2); imshow(ev.retinalMask); title('Retinal mask');
        subplot(3, 3, 3); imshow(ev.discMask); title('Disc mask');
        subplot(3, 3, 4); imshow(ev.vesselMask); title('Vessel mask');
        subplot(3, 3, 5); imshow(darkResponse, []); title('Dark response');
        colormap(gca, 'hot');
        subplot(3, 3, 6); imshow(thresholdMap, []); title('Threshold map');
        subplot(3, 3, 7); imshow(ev.rawCandidates); title(sprintf('Raw candidates: %d px', sum(ev.rawCandidates(:))));
        subplot(3, 3, 8); imshow(ev.filteredCandidates); title(sprintf('Filtered: %d px', sum(ev.filteredCandidates(:))));
        subplot(3, 3, 9);
        % Expert mask for comparison
        expertMA = logical(imread(fullfile(maskBase, '1. Microaneurysms', [imgId '_MA.tif'])));
        imshow(uint8(expertMA)*255); title(sprintf('Expert MA: %d px', sum(expertMA(:))));
        sgtitle(sprintf('%s MA Diagnostic', imgId), 'FontSize', 12, 'FontWeight', 'bold');
        exportgraphics(fig, fullfile(outputDir, sprintf('ma_diag_%s.png', imgId)), 'Resolution', 72);
        close(fig);
    end

    fprintf('\n============================================================\n');
    fprintf('  MA Diagnostic Complete\n');
    fprintf('============================================================\n');
end
