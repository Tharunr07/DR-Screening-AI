function validatePhase24B1()
% validatePhase24B1  Phase 24B.1 — IDRiD Expert-Ground-Truth Lesion Validation
%
%   EVALUATION ONLY. No detector modifications. No threshold changes.
%   Runs existing MA/HE/EX detectors on IDRiD images and compares against
%   expert pixel-level masks.

    fprintf('============================================================\n');
    fprintf('  Phase 24B.1: IDRiD Expert-Ground-Truth Lesion Validation\n');
    fprintf('============================================================\n');
    fprintf('  EVALUATION ONLY — no detector modifications\n\n');

    outputDir = 'results/phase24b1_idrid';
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    % IDRiD paths
    segBase = 'data/raw/IDRiD/A. Segmentation';
    fundusDir = fullfile(segBase, '1. Original Images', 'a. Training Set');
    maskBase = fullfile(segBase, '2. All Segmentation Groundtruths', 'a. Training Set');
    maskDirs = struct( ...
        'MA', fullfile(maskBase, '1. Microaneurysms'), ...
        'HE', fullfile(maskBase, '2. Haemorrhages'), ...
        'EX', fullfile(maskBase, '3. Hard Exudates'));

    lesionTypes = {'MA', 'HE', 'EX'};
    nImages = 54;  % IDRiD training set: IDRiD_01 through IDRiD_54

    %% ====================================================================
    %  LOAD DATA AND RUN DETECTORS
    %  ====================================================================
    fprintf('--- Loading IDRiD images and running detectors ---\n\n');

    results = struct();
    allMetrics = struct();
    allMetrics.MA = {};
    allMetrics.HE = {};
    allMetrics.EX = {};

    for imgIdx = 1:nImages
        imgId = sprintf('IDRiD_%02d', imgIdx);
        fundusPath = fullfile(fundusDir, [imgId '.jpg']);

        if ~exist(fundusPath, 'file')
            fprintf('  SKIP: %s (fundus not found)\n', imgId);
            continue;
        end

        % Load fundus
        fundus = imread(fundusPath);
        [h, w, ~] = size(fundus);

        % Run detectors (current, unmodified)
        maEvidence = detectMicroaneurysms(fundus);
        heEvidence = detectHemorrhages(fundus);
        exEvidence = detectExudates(fundus);

        % Diagnostic: check what detectors return
        if imgIdx <= 3
            fprintf('  DIAG %s: MA count=%d, mask px=%d, size=%dx%d\n', ...
                imgId, maEvidence.count, sum(maEvidence.mask(:)), size(maEvidence.mask, 1), size(maEvidence.mask, 2));
            fprintf('  DIAG %s: HE count=%d, mask px=%d\n', imgId, heEvidence.count, sum(heEvidence.mask(:)));
            fprintf('  DIAG %s: EX count=%d, mask px=%d\n', imgId, exEvidence.count, sum(exEvidence.mask(:)));
            fprintf('  DIAG %s: Fundus size: %dx%dx%d\n', imgId, h, w, size(fundus, 3));
        end

        % Detector masks (logical, same resolution as fundus)
        detMA = logical(maEvidence.mask);
        detHE = logical(heEvidence.mask);
        detEX = logical(exEvidence.mask);

        % Process each lesion type
        for lt = 1:numel(lesionTypes)
            ltName = lesionTypes{lt};
            maskPath = fullfile(maskDirs.(ltName), [imgId '_' ltName '.tif']);

            if ~exist(maskPath, 'file')
                fprintf('  SKIP: %s %s (mask not found)\n', imgId, ltName);
                continue;
            end

            % Load expert mask (binary 0/1)
            expertRaw = imread(maskPath);

            % Ensure binary logical
            if size(expertRaw, 3) > 1
                expertRaw = expertRaw(:,:,1);
            end
            expertMask = logical(expertRaw);

            % Resize expert mask to match fundus if needed
            [eh, ew] = size(expertMask);
            if eh ~= h || ew ~= w
                expertMask = imresize(expertMask, [h, w], 'nearest');
            end

            % Get detector mask for this lesion type
            switch ltName
                case 'MA', detMask = detMA;
                case 'HE', detMask = detHE;
                case 'EX', detMask = detEX;
            end

            % Ensure same size
            [dh, dw] = size(detMask);
            if dh ~= h || dw ~= w
                detMask = imresize(detMask, [h, w], 'nearest');
            end

            % Compute pixel-level metrics
            metrics = computePixelMetrics(expertMask, detMask);
            metrics.image_id = imgId;
            metrics.lesion_type = ltName;
            metrics.fundus_path = fundusPath;
            metrics.mask_path = maskPath;
            metrics.fundus_size = [h, w];
            metrics.expert_pixels = sum(expertMask(:));
            metrics.detector_pixels = sum(detMask(:));

            % Image-level: does detector find anything in this image?
            metrics.image_level_tp = (metrics.detector_pixels > 0) && (metrics.expert_pixels > 0);
            metrics.image_level_fp = (metrics.detector_pixels > 0) && (metrics.expert_pixels == 0);
            metrics.image_level_fn = (metrics.detector_pixels == 0) && (metrics.expert_pixels > 0);
            metrics.image_level_tn = (metrics.detector_pixels == 0) && (metrics.expert_pixels == 0);

            % Store as cell array of structs
            allMetrics.(ltName){end+1} = metrics;

            % Skip visual panel generation for speed (can be run separately)
            % generateVisualPanel(fundus, expertMask, detMask, imgId, ltName, outputDir);
        end

        if mod(imgIdx, 10) == 0
            fprintf('  Processed %d/%d images\n', imgIdx, nImages);
        end
    end

    fprintf('\n  Processing complete.\n\n');

    %% ====================================================================
    %  COMPUTE SUMMARY METRICS
    %  ====================================================================
    fprintf('--- Summary Metrics ---\n\n');

    summaryTable = table();
    bootstrapTable = table();
    worstCases = table();

    for lt = 1:numel(lesionTypes)
        ltName = lesionTypes{lt};
        metrics = allMetrics.(ltName);

        if isempty(metrics)
            fprintf('  %s: No results\n', ltName);
            continue;
        end

        n = numel(metrics);

        % Extract arrays from cell array
        dices = cellfun(@(m) m.dice, metrics);
        ious = cellfun(@(m) m.iou, metrics);
        precisions = cellfun(@(m) m.precision, metrics);
        recalls = cellfun(@(m) m.recall, metrics);
        specificities = cellfun(@(m) m.specificity, metrics);
        expertPx = cellfun(@(m) m.expert_pixels, metrics);
        detPx = cellfun(@(m) m.detector_pixels, metrics);
        tpImg = cellfun(@(m) m.image_level_tp, metrics);

        % Mean, median, std
        meanDice = mean(dices);
        medianDice = median(dices);
        stdDice = std(dices);

        meanIoU = mean(ious);
        medianIoU = median(ious);
        stdIoU = std(ious);

        meanPrec = mean(precisions);
        medianPrec = median(precisions);
        stdPrec = std(precisions);

        meanRec = mean(recalls);
        medianRec = median(recalls);
        stdRec = std(recalls);

        meanSpec = mean(specificities);
        medianSpec = median(specificities);
        stdSpec = std(specificities);

        % Image-level detection rate
        nHasLesion = sum(expertPx > 0);
        nDetected = sum(tpImg);
        imageDetRate = nDetected / max(nHasLesion, 1);

        % Bootstrap 95% CIs
        rng(42);
        nBoot = 10000;
        bootDice = bootstrp(nBoot, @mean, dices);
        bootIoU = bootstrp(nBoot, @mean, ious);
        bootPrec = bootstrp(nBoot, @mean, precisions);
        bootRec = bootstrp(nBoot, @mean, recalls);

        ciDice = prctile(bootDice, [2.5, 97.5]);
        ciIoU = prctile(bootIoU, [2.5, 97.5]);
        ciPrec = prctile(bootPrec, [2.5, 97.5]);
        ciRec = prctile(bootRec, [2.5, 97.5]);

        % Print
        fprintf('  %s (%d images with masks):\n', ltName, n);
        fprintf('    Dice:      %.3f ± %.3f  [95%% CI: %.3f–%.3f]\n', meanDice, stdDice, ciDice(1), ciDice(2));
        fprintf('    IoU:       %.3f ± %.3f  [95%% CI: %.3f–%.3f]\n', meanIoU, stdIoU, ciIoU(1), ciIoU(2));
        fprintf('    Precision: %.3f ± %.3f  [95%% CI: %.3f–%.3f]\n', meanPrec, stdPrec, ciPrec(1), ciPrec(2));
        fprintf('    Recall:    %.3f ± %.3f  [95%% CI: %.3f–%.3f]\n', meanRec, stdRec, ciRec(1), ciRec(2));
        fprintf('    Specificity: %.3f ± %.3f\n', meanSpec, stdSpec);
        fprintf('    Image-level detection rate: %d/%d (%.1f%%)\n', nDetected, nHasLesion, imageDetRate*100);
        fprintf('\n');

        % Summary table row
        row = table();
        row.lesion_type = string(ltName);
        row.n_images = n;
        row.n_has_lesion = nHasLesion;
        row.n_detected = nDetected;
        row.image_detection_rate = imageDetRate;
        row.mean_dice = meanDice;
        row.median_dice = medianDice;
        row.std_dice = stdDice;
        row.mean_iou = meanIoU;
        row.mean_precision = meanPrec;
        row.mean_recall = meanRec;
        row.mean_specificity = meanSpec;
        summaryTable = [summaryTable; row];

        % Bootstrap CI table
        ciRow = table();
        ciRow.lesion_type = repmat(string(ltName), 4, 1);
        ciRow.metric = ["Dice"; "IoU"; "Precision"; "Recall"];
        ciRow.mean = [meanDice; meanIoU; meanPrec; meanRec];
        ciRow.ci_lower = [ciDice(1); ciIoU(1); ciPrec(1); ciRec(1)];
        ciRow.ci_upper = [ciDice(2); ciIoU(2); ciPrec(2); ciRec(2)];
        bootstrapTable = [bootstrapTable; ciRow];

        % Worst cases (bottom 5 by Dice)
        [~, sortIdx] = sort(dices, 'ascend');
        nWorst = min(5, numel(sortIdx));
        for w = 1:nWorst
            wIdx = sortIdx(w);
            m = metrics{wIdx};
            wRow = table();
            wRow.lesion_type = string(ltName);
            wRow.image_id = string(m.image_id);
            wRow.dice = dices(wIdx);
            wRow.iou = ious(wIdx);
            wRow.precision = precisions(wIdx);
            wRow.recall = recalls(wIdx);
            wRow.expert_pixels = m.expert_pixels;
            wRow.detector_pixels = m.detector_pixels;
            worstCases = [worstCases; wRow];
        end
    end

    %% ====================================================================
    %  WRITE OUTPUTS
    %  ====================================================================
    fprintf('--- Writing outputs ---\n');

    % Image-level results
    imgResults = table();
    for lt = 1:numel(lesionTypes)
        ltName = lesionTypes{lt};
        for i = 1:numel(allMetrics.(ltName))
            m = allMetrics.(ltName){i};
            row = table();
            row.image_id = string(m.image_id);
            row.lesion_type = string(m.lesion_type);
            row.dice = m.dice;
            row.iou = m.iou;
            row.precision = m.precision;
            row.recall = m.recall;
            row.specificity = m.specificity;
            row.image_level_tp = m.image_level_tp;
            row.image_level_fp = m.image_level_fp;
            row.image_level_fn = m.image_level_fn;
            row.image_level_tn = m.image_level_tn;
            row.expert_pixels = m.expert_pixels;
            row.detector_pixels = m.detector_pixels;
            imgResults = [imgResults; row];
        end
    end
    writetable(imgResults, fullfile(outputDir, 'image_level_results.csv'));
    fprintf('  image_level_results.csv\n');

    % Summary metrics
    writetable(summaryTable, fullfile(outputDir, 'summary_metrics.csv'));
    fprintf('  summary_metrics.csv\n');

    % Bootstrap CIs
    writetable(bootstrapTable, fullfile(outputDir, 'bootstrap_ci.csv'));
    fprintf('  bootstrap_ci.csv\n');

    % Worst cases
    writetable(worstCases, fullfile(outputDir, 'worst_cases.csv'));
    fprintf('  worst_cases.csv\n');

    fprintf('\n============================================================\n');
    fprintf('  Phase 24B.1 COMPLETE\n');
    fprintf('============================================================\n');
end


%% ====================================================================
%  HELPER FUNCTIONS
%  ====================================================================

function metrics = computePixelMetrics(expertMask, detMask)
    % Ensure logical
    E = logical(expertMask);
    D = logical(detMask);

    % Pixel counts
    TP = sum(D(:) & E(:));
    FP = sum(D(:) & ~E(:));
    FN = sum(~D(:) & E(:));
    TN = sum(~D(:) & ~E(:));

    % Dice
    dice = (2 * TP) / (2 * TP + FP + FN);

    % IoU
    iou = TP / (TP + FP + FN);

    % Precision
    precision = TP / max(TP + FP, 1);

    % Recall (sensitivity)
    recall = TP / max(TP + FN, 1);

    % Specificity
    specificity = TN / max(TN + FP, 1);

    metrics.TP = TP;
    metrics.FP = FP;
    metrics.FN = FN;
    metrics.TN = TN;
    metrics.dice = dice;
    metrics.iou = iou;
    metrics.precision = precision;
    metrics.recall = recall;
    metrics.specificity = specificity;
end


function generateVisualPanel(fundus, expertMask, detMask, imgId, ltName, outputDir)
    % Generate a 6-panel diagnostic figure
    fig = figure('Visible', 'off', 'Position', [100 100 1200 400]);

    % Panel 1: Original fundus
    subplot(2, 3, 1);
    imshow(fundus);
    title(sprintf('Original: %s', imgId), 'FontSize', 10);

    % Panel 2: Expert mask
    subplot(2, 3, 2);
    imshow(repmat(uint8(expertMask) * 255, [1 1 3]));
    title(sprintf('Expert %s mask', ltName), 'FontSize', 10);

    % Panel 3: Detector mask
    subplot(2, 3, 3);
    imshow(repmat(uint8(detMask) * 255, [1 1 3]));
    title(sprintf('Detector %s mask', ltName), 'FontSize', 10);

    % Panel 4: Overlay (expert=green, detector=red, overlap=yellow)
    subplot(2, 3, 4);
    overlay = zeros(size(fundus, 1), size(fundus, 2), 3, 'uint8');
    overlay(:,:,1) = uint8(detMask) * 255;  % Red channel = detector
    overlay(:,:,2) = uint8(expertMask) * 128;  % Green = expert (dimmer)
    overlay(:,:,3) = uint8(expertMask & detMask) * 255;  % Blue = overlap
    imshow(overlay);
    title('Overlay (R=det, G=expert, B=overlap)', 'FontSize', 10);

    % Panel 5: False positives (detector says yes, expert says no)
    subplot(2, 3, 5);
    fpMask = detMask & ~expertMask;
    imshow(repmat(uint8(fpMask) * 255, [1 1 3]));
    title(sprintf('False Positives: %d px', sum(fpMask(:))), 'FontSize', 10);

    % Panel 6: False negatives (expert says yes, detector says no)
    subplot(2, 3, 6);
    fnMask = ~detMask & expertMask;
    imshow(repmat(uint8(fnMask) * 255, [1 1 3]));
    title(sprintf('False Negatives: %d px', sum(fnMask(:))), 'FontSize', 10);

    % Compute metrics for title
    TP = sum(detMask(:) & expertMask(:));
    FP = sum(detMask(:) & ~expertMask(:));
    FN = sum(~detMask(:) & expertMask(:));
    dice = (2*TP) / (2*TP + FP + FN);

    sgtitle(sprintf('%s — %s  |  Dice=%.3f  TP=%d  FP=%d  FN=%d', ...
        imgId, ltName, dice, TP, FP, FN), 'FontSize', 12, 'FontWeight', 'bold');

    % Save
    figPath = fullfile(outputDir, sprintf('panel_%s_%s.png', imgId, ltName));
    exportgraphics(fig, figPath, 'Resolution', 72);
    close(fig);
end
