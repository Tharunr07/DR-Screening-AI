function phase24b2_forensic()
% phase24b2_forensic  Phase 24B.2 — Forensic alignment + visual failure analysis
%
%   Verifies: image/mask pairing, coordinate system, resizing, Dice
%   Then: diagnostic panels for 5-10 images showing why scores are poor.

    fprintf('============================================================\n');
    fprintf('  Phase 24B.2: Forensic Alignment + Visual Failure Analysis\n');
    fprintf('============================================================\n\n');

    outputDir = 'results/phase24b2_forensic';
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    segBase = 'data/raw/IDRiD/A. Segmentation';
    fundusDir = fullfile(segBase, '1. Original Images', 'a. Training Set');
    maskBase = fullfile(segBase, '2. All Segmentation Groundtruths', 'a. Training Set');
    maskDirs = struct( ...
        'MA', fullfile(maskBase, '1. Microaneurysms'), ...
        'HE', fullfile(maskBase, '2. Haemorrhages'), ...
        'EX', fullfile(maskBase, '3. Hard Exudates'));

    %% ================================================================
    %  STEP 1: Verify file pairing, sizes, pixel values
    %  ================================================================
    fprintf('--- STEP 1: File Pairing + Metadata Verification ---\n\n');

    pairingReport = table();
    for imgIdx = 1:54
        imgId = sprintf('IDRiD_%02d', imgIdx);
        fundusPath = fullfile(fundusDir, [imgId '.jpg']);
        if ~exist(fundusPath, 'file'), continue; end

        fundus = imread(fundusPath);
        [fh, fw, fc] = size(fundus);

        for lt = {'MA', 'HE', 'EX'}
            ltName = lt{1};
            maskPath = fullfile(maskDirs.(ltName), [imgId '_' ltName '.tif']);
            if ~exist(maskPath, 'file'), continue; end

            maskRaw = imread(maskPath);
            [mh, mw, mc] = size(maskRaw);
            maskUnique = unique(maskRaw(:));

            row = table();
            row.image_id = string(imgId);
            row.lesion_type = string(ltName);
            row.fundus_size = sprintf('%dx%dx%d', fh, fw, fc);
            row.mask_size = sprintf('%dx%dx%d', mh, mw, mc);
            row.mask_dtype = class(maskRaw);
            row.mask_unique_values = mat2str(maskUnique');
            row.size_match = (fh == mh) && (fw == mw);
            vals = maskUnique(:)';
            row.mask_is_binary = isequal(vals, [0]) || isequal(vals, [0 1]) || isequal(vals, [0 255]);
            pairingReport = [pairingReport; row];
        end
    end

    writetable(pairingReport, fullfile(outputDir, 'file_pairing.csv'));
    fprintf('  File pairing report written.\n');

    % Summary
    nTotal = height(pairingReport);
    nSizeMatch = sum(pairingReport.size_match);
    fprintf('  Total image-mask pairs: %d\n', nTotal);
    fprintf('  Size matches: %d/%d (%.1f%%)\n', nSizeMatch, nTotal, nSizeMatch/nTotal*100);

    % Show unique mask values for MA
    maRows = pairingReport(pairingReport.lesion_type == "MA", :);
    fprintf('\n  MA mask unique values (first 10):\n');
    for i = 1:min(10, height(maRows))
        fprintf('    %s: %s (dtype: %s, size match: %d)\n', ...
            maRows.image_id(i), maRows.mask_unique_values(i), ...
            maRows.mask_dtype(i), maRows.size_match(i));
    end

    %% ================================================================
    %  STEP 2: Verify Dice implementation with known answer
    %  ================================================================
    fprintf('\n--- STEP 2: Dice Verification ---\n\n');

    % Test 1: Perfect match
    A = false(100, 100); A(30:70, 30:70) = true;
    B = A;
    m1 = computePixelMetrics(A, B);
    fprintf('  Test 1 (perfect match):     Dice=%.6f  IoU=%.6f  (expect 1.0)\n', m1.dice, m1.iou);

    % Test 2: No overlap
    A2 = false(100, 100); A2(1:50, 1:50) = true;
    B2 = false(100, 100); B2(51:100, 51:100) = true;
    m2 = computePixelMetrics(A2, B2);
    fprintf('  Test 2 (no overlap):        Dice=%.6f  IoU=%.6f  (expect 0.0)\n', m2.dice, m2.iou);

    % Test 3: Partial overlap
    A3 = false(100, 100); A3(1:60, 1:60) = true;
    B3 = false(100, 100); B3(40:100, 40:100) = true;
    expectedDice = 2*sum(A3(:)&B3(:)) / (sum(A3(:)) + sum(B3(:)));
    m3 = computePixelMetrics(A3, B3);
    fprintf('  Test 3 (partial overlap):   Dice=%.6f  IoU=%.6f  (expected Dice=%.6f)\n', m3.dice, m3.iou, expectedDice);

    % Test 4: 50% overlap
    A4 = false(100, 100); A4(1:50, :) = true;
    B4 = false(100, 100); B4(25:75, :) = true;
    m4 = computePixelMetrics(A4, B4);
    expectedDice4 = 2*2500 / (5000 + 5000);
    fprintf('  Test 4 (50%% overlap):       Dice=%.6f  IoU=%.6f  (expected Dice=%.6f)\n', m4.dice, m4.iou, expectedDice4);

    diceOK = (abs(m1.dice - 1.0) < 1e-6) && (abs(m2.dice) < 1e-6) && ...
             (abs(m3.dice - expectedDice) < 1e-6) && (abs(m4.dice - expectedDice4) < 1e-6);
    fprintf('\n  Dice implementation: %s\n', iff(diceOK, 'VERIFIED CORRECT', 'ERROR - INVESTIGATE'));

    %% ================================================================
    %  STEP 3: Coordinate alignment check — do masks line up with fundus?
    %  ================================================================
    fprintf('\n--- STEP 3: Coordinate Alignment Check ---\n\n');

    % Pick 5 images, overlay expert mask on fundus to verify alignment
    checkImages = [1, 10, 25, 40, 54];
    for imgIdx = checkImages
        imgId = sprintf('IDRiD_%02d', imgIdx);
        fundusPath = fullfile(fundusDir, [imgId '.jpg']);
        if ~exist(fundusPath, 'file'), continue; end
        fundus = imread(fundusPath);

        for lt = {'MA', 'HE', 'EX'}
            ltName = lt{1};
            maskPath = fullfile(maskDirs.(ltName), [imgId '_' ltName '.tif']);
            if ~exist(maskPath, 'file'), continue; end

            mask = logical(imread(maskPath));
            [fh, fw, ~] = size(fundus);
            [mh, mw] = size(mask);

            if fh ~= mh || fw ~= mw
                fprintf('  %s %s: SIZE MISMATCH fundus=%dx%d mask=%dx%d\n', ...
                    imgId, ltName, fw, fh, mw, mh);
            else
                fprintf('  %s %s: sizes match (%dx%d)\n', imgId, ltName, fw, fh);
            end

            % Generate alignment panel: fundus | mask overlay | mask only
            fig = figure('Visible', 'off', 'Position', [100 100 1500 400]);
            subplot(1, 3, 1); imshow(fundus); title('Original fundus');
            subplot(1, 3, 2);
            overlay = fundus;
            maskRGB = cat(3, uint8(mask)*255, uint8(mask)*0, uint8(mask)*0);
            overlay = max(overlay, maskRGB);
            imshow(overlay); title(sprintf('%s overlay (red)', ltName));
            subplot(1, 3, 3); imshow(uint8(mask)*255); title(sprintf('%s expert mask', ltName));
            sgtitle(sprintf('%s — Coordinate alignment check', imgId), 'FontSize', 11);
            exportgraphics(fig, fullfile(outputDir, sprintf('align_%s_%s.png', imgId, ltName)), 'Resolution', 72);
            close(fig);
        end
    end
    fprintf('  Alignment panels written.\n');

    %% ================================================================
    %  STEP 4: MA mask deep inspection
    %  ================================================================
    fprintf('\n--- STEP 4: MA Mask Deep Inspection ---\n\n');

    % Inspect MA masks in detail
    for imgIdx = [1, 5, 10, 25]
        imgId = sprintf('IDRiD_%02d', imgIdx);
        maskPath = fullfile(maskDirs.MA, [imgId '_MA.tif']);
        if ~exist(maskPath, 'file'), continue; end

        mask = imread(maskPath);
        fprintf('  %s MA mask:\n', imgId);
        fprintf('    Class: %s\n', class(mask));
        fprintf('    Size: %dx%d\n', size(mask, 1), size(mask, 2));
        fprintf('    Unique values: %s\n', mat2str(unique(mask(:))'));
        fprintf('    Non-zero pixels: %d / %d (%.4f%%)\n', ...
            sum(mask(:) ~= 0), numel(mask), sum(mask(:) ~= 0)/numel(mask)*100);

        % If uint8 and values are 0/255, also check 0/1
        if isa(mask, 'uint8')
            has_255 = any(mask(:) == 255);
            has_1 = any(mask(:) == 1);
            fprintf('    Has value 255: %d, Has value 1: %d\n', has_255, has_1);
        end
    end

    %% ================================================================
    %  STEP 5: Diagnostic panels — why detectors fail
    %  ================================================================
    fprintf('\n--- STEP 5: Diagnostic Visual Panels ---\n\n');

    diagImages = [1, 5, 10, 25, 40];
    for imgIdx = diagImages
        imgId = sprintf('IDRiD_%02d', imgIdx);
        fundusPath = fullfile(fundusDir, [imgId '.jpg']);
        if ~exist(fundusPath, 'file'), continue; end

        fundus = imread(fundusPath);
        [h, w, ~] = size(fundus);

        % Run detectors
        maE = detectMicroaneurysms(fundus);
        heE = detectHemorrhages(fundus);
        exE = detectExudates(fundus);

        % Diagnostic: show what the detector produces internally
        fprintf('  %s:\n', imgId);
        fprintf('    MA: count=%d, mask_px=%d\n', maE.count, sum(maE.mask(:)));
        fprintf('    HE: count=%d, mask_px=%d\n', heE.count, sum(heE.mask(:)));
        fprintf('    EX: count=%d, mask_px=%d\n', exE.count, sum(exE.mask(:)));

        % Load expert masks
        for lt = {'MA', 'HE', 'EX'}
            ltName = lt{1};
            maskPath = fullfile(maskDirs.(ltName), [imgId '_' ltName '.tif']);
            if ~exist(maskPath, 'file'), continue; end

            expertMask = logical(imread(maskPath));
            if size(expertMask, 1) ~= h || size(expertMask, 2) ~= w
                expertMask = imresize(expertMask, [h, w], 'nearest');
            end

            switch ltName
                case 'MA', detMask = logical(maE.mask);
                case 'HE', detMask = logical(heE.mask);
                case 'EX', detMask = logical(exE.mask);
            end

            m = computePixelMetrics(expertMask, detMask);

            % 6-panel diagnostic figure
            fig = figure('Visible', 'off', 'Position', [100 100 1500 800]);

            subplot(2, 3, 1); imshow(fundus); title('Original fundus');
            subplot(2, 3, 2); imshow(uint8(expertMask)*255); title(sprintf('Expert %s', ltName));
            subplot(2, 3, 3); imshow(uint8(detMask)*255); title(sprintf('Detector %s', ltName));

            % Overlay
            subplot(2, 3, 4);
            ov = fundus;
            ov(:,:,1) = max(ov(:,:,1), uint8(detMask)*255);
            ov(:,:,2) = max(ov(:,:,2), uint8(expertMask)*128);
            imshow(ov); title('R=detector G=expert');

            % False positives
            subplot(2, 3, 5);
            fp = detMask & ~expertMask;
            fpVis = fundus;
            fpVis(:,:,1) = max(fpVis(:,:,1), uint8(fp)*255);
            imshow(fpVis); title(sprintf('FP: %d px', sum(fp(:))));

            % False negatives
            subplot(2, 3, 6);
            fn = ~detMask & expertMask;
            fnVis = fundus;
            fnVis(:,:,1) = max(fnVis(:,:,1), uint8(fn)*255);
            imshow(fnVis); title(sprintf('FN: %d px', sum(fn(:))));

            sgtitle(sprintf('%s %s: Dice=%.3f TP=%d FP=%d FN=%d Expert=%dpx Det=%dpx', ...
                imgId, ltName, m.dice, m.TP, m.FP, m.FN, sum(expertMask(:)), sum(detMask(:))), ...
                'FontSize', 11, 'FontWeight', 'bold');

            exportgraphics(fig, fullfile(outputDir, sprintf('diag_%s_%s.png', imgId, ltName)), 'Resolution', 72);
            close(fig);
        end
    end
    fprintf('  Diagnostic panels written.\n');

    %% ================================================================
    %  STEP 6: Investigate MA zero-detection
    %  ================================================================
    fprintf('\n--- STEP 6: MA Zero-Detection Root Cause Analysis ---\n\n');

    % Run MA detector on a few images, examine intermediate values
    for imgIdx = [1, 10, 25]
        imgId = sprintf('IDRiD_%02d', imgIdx);
        fundusPath = fullfile(fundusDir, [imgId '.jpg']);
        fundus = imread(fundusPath);
        [h, w, ~] = size(fundus);

        fprintf('  %s (fundus %dx%d):\n', imgId, w, h);

        % Manual decomposition of what detectMicroaneurysms does
        greenChannel = fundus(:,:,2);

        % Red channel black-hat
        redChannel = fundus(:,:,1);

        % Show basic stats
        fprintf('    Red channel: min=%d max=%d mean=%.1f\n', min(redChannel(:)), max(redChannel(:)), mean(double(redChannel(:))));
        fprintf('    Green channel: min=%d max=%d mean=%.1f\n', min(greenChannel(:)), max(greenChannel(:)), mean(double(greenChannel(:))));

        % Check if the detector can handle the resolution
        maE = detectMicroaneurysms(fundus);
        fprintf('    MA detector output: count=%d, mask_nonzero=%d\n', maE.count, sum(maE.mask(:)));

        % What about after preprocessFundus?
        preprocessed = preprocessFundus(fundus);
        fprintf('    Preprocessed: class=%s, size=%dx%d, range=[%.3f, %.3f]\n', ...
            class(preprocessed), size(preprocessed, 1), size(preprocessed, 2), ...
            min(preprocessed(:)), max(preprocessed(:)));
    end

    fprintf('\n============================================================\n');
    fprintf('  Phase 24B.2 COMPLETE\n');
    fprintf('============================================================\n');
end


function result = iff(condition, trueVal, falseVal)
    if condition, result = trueVal; else, result = falseVal; end
end


function metrics = computePixelMetrics(expertMask, detMask)
    E = logical(expertMask);
    D = logical(detMask);
    TP = sum(D(:) & E(:));
    FP = sum(D(:) & ~E(:));
    FN = sum(~D(:) & E(:));
    TN = sum(~D(:) & ~E(:));
    metrics.TP = TP;
    metrics.FP = FP;
    metrics.FN = FN;
    metrics.TN = TN;
    metrics.dice = (2 * TP) / (2 * TP + FP + FN);
    metrics.iou = TP / (TP + FP + FN);
    metrics.precision = TP / max(TP + FP, 1);
    metrics.recall = TP / max(TP + FN, 1);
    metrics.specificity = TN / max(TN + FP, 1);
end
