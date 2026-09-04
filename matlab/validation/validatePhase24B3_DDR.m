function validatePhase24B3_DDR()
% validatePhase24B3_DDR  Phase 24B.3 — DDR External Lesion Validation
%
%   Runs frozen detectors on DDR images, compares against expert masks.
%   Same evaluation pipeline as IDRiD (Phase 24B.1).

    fprintf('============================================================\n');
    fprintf('  Phase 24B.3: DDR External Lesion Validation\n');
    fprintf('============================================================\n\n');

    outputDir = 'results/phase24b3_ddr';
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    % DDR paths
    baseDir = 'data/raw/DDR/lesion_segmentation/lesion_segmentation';
    fundusDir = fullfile(baseDir, 'images', 'train');
    maskBase = fullfile(baseDir, 'annotations', 'train');

    lesionTypes = {'MA', 'HE', 'EX'};

    % Find all fundus images
    fundusFiles = dir(fullfile(fundusDir, '*.jpg'));
    nImages = numel(fundusFiles);
    fprintf('  Found %d DDR images\n\n', nImages);

    %% ====================================================================
    %  RUN DETECTORS AND COMPUTE METRICS
    %  ====================================================================
    allMetrics = struct();
    allMetrics.MA = {};
    allMetrics.HE = {};
    allMetrics.EX = {};

    for imgIdx = 1:nImages
        fundusName = fundusFiles(imgIdx).name;
        baseName = fundusName(1:end-4); % remove .jpg
        fundusPath = fullfile(fundusDir, fundusName);

        fundus = imread(fundusPath);
        [h, w, ~] = size(fundus);

        % Run detectors
        maEvidence = detectMicroaneurysms(fundus);
        heEvidence = detectHemorrhages(fundus);
        exEvidence = detectExudates(fundus);

        if imgIdx <= 3
            fprintf('  DIAG %s: %dx%d, MA=%d HE=%d EX=%d\n', ...
                baseName, w, h, maEvidence.count, heEvidence.count, exEvidence.count);
        end

        % Process each lesion type
        for lt = 1:numel(lesionTypes)
            ltName = lesionTypes{lt};
            maskPath = fullfile(maskBase, ltName, [baseName '.tif']);

            if ~exist(maskPath, 'file')
                continue;
            end

            % Load expert mask
            expertRaw = imread(maskPath);

            % Handle multi-channel masks
            if size(expertRaw, 3) > 1
                expertRaw = expertRaw(:,:,1);
            end

            % Convert to logical — handle various formats
            if isa(expertRaw, 'uint8')
                expertMask = logical(expertRaw);
                % If values are 0/255, logical() works directly
                % If values are 0/1, logical() also works
            elseif isa(expertRaw, 'uint16')
                expertMask = logical(expertRaw);
            elseif isa(expertRaw, 'logical')
                expertMask = expertRaw;
            else
                expertMask = expertRaw > 0;
            end

            % Resize expert mask to match fundus if needed
            [eh, ew] = size(expertMask);
            if eh ~= h || ew ~= w
                expertMask = imresize(expertMask, [h, w], 'nearest');
            end

            % Get detector mask
            switch ltName
                case 'MA', detMask = logical(maEvidence.mask);
                case 'HE', detMask = logical(heEvidence.mask);
                case 'EX', detMask = logical(exEvidence.mask);
            end

            % Ensure same size
            [dh, dw] = size(detMask);
            if dh ~= h || dw ~= w
                detMask = imresize(detMask, [h, w], 'nearest');
            end

            % Compute metrics
            metrics = computePixelMetrics(expertMask, detMask);
            metrics.image_id = string(baseName);
            metrics.lesion_type = ltName;
            metrics.image_size = sprintf('%dx%d', w, h);
            metrics.expert_pixels = sum(expertMask(:));
            metrics.detector_pixels = sum(detMask(:));
            metrics.image_level_tp = (metrics.detector_pixels > 0) && (metrics.expert_pixels > 0);
            metrics.image_level_fp = (metrics.detector_pixels > 0) && (metrics.expert_pixels == 0);
            metrics.image_level_fn = (metrics.detector_pixels == 0) && (metrics.expert_pixels > 0);

            % Store
            allMetrics.(ltName){end+1} = metrics;
        end

        if mod(imgIdx, 10) == 0
            fprintf('  Processed %d/%d images\n', imgIdx, nImages);
        end
    end

    fprintf('\n  Processing complete.\n\n');

    %% ====================================================================
    %  SUMMARY METRICS
    %  ====================================================================
    fprintf('--- DDR Summary Metrics ---\n\n');

    summaryTable = table();
    bootstrapTable = table();

    for lt = 1:numel(lesionTypes)
        ltName = lesionTypes{lt};
        metrics = allMetrics.(ltName);

        if isempty(metrics)
            fprintf('  %s: No results\n', ltName);
            continue;
        end

        n = numel(metrics);
        dices = cellfun(@(m) m.dice, metrics);
        ious = cellfun(@(m) m.iou, metrics);
        precisions = cellfun(@(m) m.precision, metrics);
        recalls = cellfun(@(m) m.recall, metrics);
        specificities = cellfun(@(m) m.specificity, metrics);
        expertPx = cellfun(@(m) m.expert_pixels, metrics);
        detPx = cellfun(@(m) m.detector_pixels, metrics);

        meanDice = mean(dices);
        stdDice = std(dices);
        meanIoU = mean(ious);
        meanPrec = mean(precisions);
        meanRec = mean(recalls);
        meanSpec = mean(specificities);

        nHasLesion = sum(expertPx > 0);
        nDetected = sum(cellfun(@(m) m.image_level_tp, metrics));
        imageDetRate = nDetected / max(nHasLesion, 1);

        % Bootstrap 95% CIs
        rng(42);
        nBoot = 10000;
        bootDice = bootstrp(nBoot, @mean, dices);
        bootRec = bootstrp(nBoot, @mean, recalls);
        ciDice = prctile(bootDice, [2.5, 97.5]);
        ciRec = prctile(bootRec, [2.5, 97.5]);

        fprintf('  %s (%d images):\n', ltName, n);
        fprintf('    Dice:      %.3f ± %.3f  [95%% CI: %.3f–%.3f]\n', meanDice, stdDice, ciDice(1), ciDice(2));
        fprintf('    IoU:       %.3f\n', meanIoU);
        fprintf('    Precision: %.3f\n', meanPrec);
        fprintf('    Recall:    %.3f ± %.3f  [95%% CI: %.3f–%.3f]\n', meanRec, std(ciRec), ciRec(1), ciRec(2));
        fprintf('    Specificity: %.3f\n', meanSpec);
        fprintf('    Image-level detection: %d/%d (%.1f%%)\n', nDetected, nHasLesion, imageDetRate*100);
        fprintf('\n');

        row = table();
        row.lesion_type = string(ltName);
        row.n_images = n;
        row.n_has_lesion = nHasLesion;
        row.n_detected = nDetected;
        row.image_detection_rate = imageDetRate;
        row.mean_dice = meanDice;
        row.mean_iou = meanIoU;
        row.mean_precision = meanPrec;
        row.mean_recall = meanRec;
        row.mean_specificity = meanSpec;
        row.mean_dice_ci_low = ciDice(1);
        row.mean_dice_ci_high = ciDice(2);
        row.mean_recall_ci_low = ciRec(1);
        row.mean_recall_ci_high = ciRec(2);
        summaryTable = [summaryTable; row];
    end

    %% ====================================================================
    %  RESOLUTION ANALYSIS
    %  ====================================================================
    fprintf('--- Resolution Distribution ---\n\n');
    allSizes = [];
    for lt = 1:numel(lesionTypes)
        for i = 1:numel(allMetrics.(lesionTypes{lt}))
            m = allMetrics.(lesionTypes{lt}){i};
            parts = strsplit(m.image_size, 'x');
            allSizes.(lesionTypes{lt})(i) = str2double(parts{1}) * str2double(parts{2});
        end
    end

    for lt = 1:numel(lesionTypes)
        ltName = lesionTypes{lt};
        if isfield(allSizes, ltName)
            sz = allSizes.(ltName);
            fprintf('  %s: min=%d max=%d mean=%d pixels\n', ltName, min(sz), max(sz), mean(sz));
        end
    end

    %% ====================================================================
    %  WRITE OUTPUTS
    %  ====================================================================
    fprintf('\n--- Writing outputs ---\n');

    imgResults = table();
    for lt = 1:numel(lesionTypes)
        ltName = lesionTypes{lt};
        for i = 1:numel(allMetrics.(ltName))
            m = allMetrics.(ltName){i};
            row = table();
            row.image_id = m.image_id;
            row.lesion_type = string(m.lesion_type);
            row.image_size = string(m.image_size);
            row.dice = m.dice;
            row.iou = m.iou;
            row.precision = m.precision;
            row.recall = m.recall;
            row.specificity = m.specificity;
            row.image_level_tp = m.image_level_tp;
            row.image_level_fp = m.image_level_fp;
            row.image_level_fn = m.image_level_fn;
            row.expert_pixels = m.expert_pixels;
            row.detector_pixels = m.detector_pixels;
            imgResults = [imgResults; row];
        end
    end
    writetable(imgResults, fullfile(outputDir, 'image_level_results.csv'));
    writetable(summaryTable, fullfile(outputDir, 'summary_metrics.csv'));

    fprintf('  image_level_results.csv\n');
    fprintf('  summary_metrics.csv\n');

    %% ====================================================================
    %  COMPARISON TABLE: IDRiD vs DDR
    %  ====================================================================
    fprintf('\n--- IDRiD vs DDR Comparison ---\n\n');

    % IDRiD results (from Phase 24B.1)
    idrid = struct();
    idrid.MA.dice = 0.000; idrid.MA.recall = 0.000; idrid.MA.image_det = 0.0;
    idrid.HE.dice = 0.033; idrid.HE.recall = 0.020; idrid.HE.image_det = 0.811;
    idrid.EX.dice = 0.011; idrid.EX.recall = 0.006; idrid.EX.image_det = 0.148;

    fprintf('  %-6s | %-20s | %-20s | %-12s\n', 'Lesion', 'IDRiD (4288x2848)', 'DDR (1956-3264)', 'Delta');
    fprintf('  %-6s-+-%-20s-+-%-20s-+-%-12s\n', '------', repmat('-', 1, 20), repmat('-', 1, 20), repmat('-', 1, 12));

    for lt = 1:numel(lesionTypes)
        ltName = lesionTypes{lt};
        ddrDice = 0; ddrRec = 0; ddrDet = 0;
        if ~isempty(allMetrics.(ltName))
            mets = allMetrics.(ltName);
            ddrDice = mean(cellfun(@(m) m.dice, mets));
            ddrRec = mean(cellfun(@(m) m.recall, mets));
            nHas = sum(cellfun(@(m) m.expert_pixels, mets) > 0);
            nDet = sum(cellfun(@(m) m.image_level_tp, mets));
            ddrDet = nDet / max(nHas, 1);
        end

        deltaDice = ddrDice - idrid.(ltName).dice;
        fprintf('  %-6s | Dice=%.3f R=%.3f D=%.1f%% | Dice=%.3f R=%.3f D=%.1f%% | ΔDice=%+.3f\n', ...
            ltName, idrid.(ltName).dice, idrid.(ltName).recall, idrid.(ltName).image_det*100, ...
            ddrDice, ddrRec, ddrDet*100, deltaDice);
    end

    fprintf('\n============================================================\n');
    fprintf('  Phase 24B.3 COMPLETE\n');
    fprintf('============================================================\n');
end


function metrics = computePixelMetrics(expertMask, detMask)
    E = logical(expertMask);
    D = logical(detMask);
    TP = sum(D(:) & E(:));
    FP = sum(D(:) & ~E(:));
    FN = sum(~D(:) & E(:));
    TN = sum(~D(:) & ~E(:));
    metrics.TP = TP; metrics.FP = FP; metrics.FN = FN; metrics.TN = TN;
    metrics.dice = (2 * TP) / (2 * TP + FP + FN);
    metrics.iou = TP / max(TP + FP + FN, 1);
    metrics.precision = TP / max(TP + FP, 1);
    metrics.recall = TP / max(TP + FN, 1);
    metrics.specificity = TN / max(TN + FP, 1);
end
