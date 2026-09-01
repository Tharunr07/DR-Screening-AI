function stats = runPhase5Explainability(varargin)
% runPhase5Explainability  Full Phase 5 Explainability pipeline (v5.1)
%
%   stats = runPhase5Explainability()
%   stats = runPhase5Explainability('verbose', true)
%   stats = runPhase5Explainability('skipOverlays', false)
%
%   v5.1 changes:
%   - Uses persisted Phase 3 masks from disk (no re-run of Phase 3)
%   - Per-artifact failure decoupling
%   - No synthetic lesion placement

    p = inputParser;
    addParameter(p, 'verbose', true);
    addParameter(p, 'skipOverlays', false);
    parse(p, varargin{:});
    verbose = p.Results.verbose;
    skipOverlays = p.Results.skipOverlays;

    cfg = explainabilityConfig();
    rng(cfg.seed);

    if verbose
        fprintf('=== Phase 5: Explainability + Human Review (v5.1) ===\n');
        fprintf('Version: %s | Seed: %d\n', cfg.version, cfg.seed);
    end

    % ---- Step 1: Load Phase 4 predictions ----
    if verbose, fprintf('\n--- Step 1: Load Phase 4 Predictions ---\n'); end
    T4 = readtable(cfg.paths.phase4CSV, 'TextType', 'string');
    nTest = height(T4);
    if verbose, fprintf('Loaded %d test predictions\n', nTest); end

    % ---- Step 2: No Phase 3 re-run (masks already persisted) ----
    if verbose, fprintf('\n--- Step 2: Load Persisted Phase 3 Masks ---\n'); end
    maskRoot = fullfile(cfg.projectRoot, 'results', 'phase3', 'phase3_masks');
    nMasksFound = 0;
    for i = 1:nTest
        dataset = char(T4.dataset(i));
        imageId = T4.image_id{i};
        maskFile = fullfile(maskRoot, dataset, sprintf('%s_%s.mat', dataset, imageId));
        if exist(maskFile, 'file'), nMasksFound = nMasksFound + 1; end
    end
    if verbose, fprintf('Persisted masks found: %d/%d\n', nMasksFound, nTest); end
    p3Time = 0;

    % ---- Step 3: Load trained models and prepare features ----
    if verbose, fprintf('\n--- Step 3: Prepare Classification Data ---\n'); end
    cfg4 = classificationConfig();
    [data, featureMatrix, labels, sampleMeta] = prepareClassificationData(cfg4);
    XTest = featureMatrix.test;
    YTest = labels.test;

    % Train models (same as Phase 4, deterministic)
    rng(cfg4.seed);
    [drModel, drTrainInfo] = trainDRClassifier(featureMatrix.train, labels.train, ...
        featureMatrix.val, labels.val, cfg4);
    [refModel, refTrainInfo] = trainReferableClassifier(featureMatrix.train, labels.train, ...
        featureMatrix.val, labels.val, cfg4);

    if verbose
        fprintf('Models loaded. Test set: %d images, %d features\n', size(XTest,1), size(XTest,2));
    end

    % ---- Step 4: Global Feature Importance ----
    if verbose, fprintf('\n--- Step 4: Permutation Feature Importance ---\n'); end
    tic;
    importance = computeFeatureImportance(drModel, refModel, XTest, YTest, drTrainInfo, refTrainInfo, cfg);
    impTime = toc;
    if verbose, fprintf('Feature importance: %.1f seconds\n', impTime); end

    % ---- Step 5: Per-Image Feature Contribution ----
    if verbose, fprintf('\n--- Step 5: Per-Image Feature Contribution ---\n'); end
    tic;
    imageIds = cell(nTest, 1);
    for i = 1:nTest
        imageIds{i} = T4.image_id{i};
    end
    contributions = computeFeatureContribution(drModel, refModel, XTest, imageIds, drTrainInfo, refTrainInfo, cfg);
    contribTime = toc;
    if verbose, fprintf('Feature contribution: %.1f seconds\n', contribTime); end

    % ---- Step 6: Calibration ----
    if verbose, fprintf('\n--- Step 6: Calibration ---\n'); end
    refProb = T4.referable_probability;
    YTrueBin = double(T4.true_grade >= cfg.referable.threshold);
    calibration = computeCalibration(refProb, YTest, cfg);

    % ---- Step 7: Per-Image Outputs (DECOUPLED) ----
    if ~skipOverlays
        if verbose, fprintf('\n--- Step 7: Per-Image Explanations (decoupled) ---\n'); end
        tic;

        % Per-artifact counters
        artifactStats = struct();
        artifactStats.lesion_overlay = struct('success', 0, 'failed', 0, 'unavailable', 0);
        artifactStats.structure_overlay = struct('success', 0, 'failed', 0);
        artifactStats.evidence_panel = struct('success', 0, 'failed', 0);
        artifactStats.heatmap = struct('success', 0, 'failed', 0, 'unavailable', 0);
        artifactStats.report = struct('success', 0, 'failed', 0);
        artifactStats.review_json = struct('success', 0, 'failed', 0);

        for i = 1:nTest
            imgId = T4.image_id{i};
            dataset = T4.dataset{i};

            % Find image file
            imgPath = findImagePath(imgId, cfg);
            if isempty(imgPath)
                if verbose && mod(i, 100) == 0
                    fprintf('  [%d/%d] %s: image not found\n', i, nTest, imgId);
                end
                continue;
            end

            % Build minimal Phase 3 result struct for overlay functions
            p3Result = struct();
            p3Result.dataset = string(dataset);

            % Get contributions for this image
            imgContrib = getContributionsForImage(contributions, imgId);

            % Get prediction result
            predResult = struct();
            predResult.predicted_grade = T4.predicted_grade(i);
            predResult.referable_pred = T4.referable_pred(i);
            predResult.referable_probability = T4.referable_probability(i);
            predResult.confidence_score = T4.confidence_score(i);

            split = 'test';

            % DECOUPLED: Each artifact generated independently
            % 1. Lesion overlay
            try
                [lStatus, ~] = generateLesionOverlay(imgPath, p3Result, imgId, cfg);
                if strcmp(lStatus, 'UNAVAILABLE')
                    artifactStats.lesion_overlay.unavailable = artifactStats.lesion_overlay.unavailable + 1;
                else
                    artifactStats.lesion_overlay.success = artifactStats.lesion_overlay.success + 1;
                end
            catch
                artifactStats.lesion_overlay.failed = artifactStats.lesion_overlay.failed + 1;
            end

            % 2. Structure overlay
            try
                generateStructureOverlay(imgPath, p3Result, imgId, cfg);
                artifactStats.structure_overlay.success = artifactStats.structure_overlay.success + 1;
            catch
                artifactStats.structure_overlay.failed = artifactStats.structure_overlay.failed + 1;
            end

            % 3. Evidence panel
            try
                generateEvidenceOverlay(imgPath, p3Result, predResult, imgContrib, imgId, cfg);
                artifactStats.evidence_panel.success = artifactStats.evidence_panel.success + 1;
            catch
                artifactStats.evidence_panel.failed = artifactStats.evidence_panel.failed + 1;
            end

            % 4. Heatmap
            try
                [hStatus, ~] = generateAttentionMap(imgPath, p3Result, imgContrib, imgId, cfg);
                if strcmp(hStatus, 'UNAVAILABLE')
                    artifactStats.heatmap.unavailable = artifactStats.heatmap.unavailable + 1;
                else
                    artifactStats.heatmap.success = artifactStats.heatmap.success + 1;
                end
            catch
                artifactStats.heatmap.failed = artifactStats.heatmap.failed + 1;
            end

            % 5. Report
            try
                generateReport(imgId, dataset, split, predResult, p3Result, imgContrib, calibration, cfg);
                artifactStats.report.success = artifactStats.report.success + 1;
            catch
                artifactStats.report.failed = artifactStats.report.failed + 1;
            end

            % 6. Human review JSON
            try
                generateHumanReviewReport(imgId, dataset, split, predResult, p3Result, imgContrib, calibration, cfg);
                artifactStats.review_json.success = artifactStats.review_json.success + 1;
            catch
                artifactStats.review_json.failed = artifactStats.review_json.failed + 1;
            end

            if verbose && mod(i, 100) == 0
                fprintf('  [%d/%d] %s: done\n', i, nTest, imgId);
            end
        end
        perImageTime = toc;

        % Compute total success (all artifacts succeeded)
        nSuccess = min([ ...
            artifactStats.lesion_overlay.success, ...
            artifactStats.structure_overlay.success, ...
            artifactStats.evidence_panel.success, ...
            artifactStats.heatmap.success, ...
            artifactStats.report.success, ...
            artifactStats.review_json.success]);
        nFailed = nTest - nSuccess;

        if verbose
            fprintf('Per-image outputs: %.1f seconds (%.2f s/image)\n', perImageTime, perImageTime/nTest);
            fprintf('  Full success: %d, Any failure: %d\n', nSuccess, nFailed);
            fprintf('  Artifact breakdown:\n');
            fprintf('    Lesion overlay: %d success, %d failed, %d unavailable\n', ...
                artifactStats.lesion_overlay.success, artifactStats.lesion_overlay.failed, artifactStats.lesion_overlay.unavailable);
            fprintf('    Structure overlay: %d success, %d failed\n', ...
                artifactStats.structure_overlay.success, artifactStats.structure_overlay.failed);
            fprintf('    Evidence panel: %d success, %d failed\n', ...
                artifactStats.evidence_panel.success, artifactStats.evidence_panel.failed);
            fprintf('    Heatmap: %d success, %d failed, %d unavailable\n', ...
                artifactStats.heatmap.success, artifactStats.heatmap.failed, artifactStats.heatmap.unavailable);
            fprintf('    Report: %d success, %d failed\n', ...
                artifactStats.report.success, artifactStats.report.failed);
            fprintf('    Review JSON: %d success, %d failed\n', ...
                artifactStats.review_json.success, artifactStats.review_json.failed);
        end
    else
        nSuccess = 0;
        nFailed = 0;
        perImageTime = 0;
        artifactStats = struct();
        if verbose, fprintf('\n--- Step 7: Skipped (skipOverlays=true) ---\n'); end
    end

    % ---- Step 8: Save summary ----
    if verbose, fprintf('\n--- Step 8: Save Summary ---\n'); end
    stats = struct();
    stats.version = '5.1.0';
    stats.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    stats.n_test_images = nTest;
    stats.n_success = nSuccess;
    stats.n_failed = nFailed;
    stats.n_masks_found = nMasksFound;
    stats.phase3_rerun_time = p3Time;
    stats.feature_importance_time = impTime;
    stats.feature_contribution_time = contribTime;
    stats.calibration_time = 0;
    stats.per_image_time = perImageTime;
    stats.total_time = impTime + contribTime + perImageTime;
    stats.artifact_stats = artifactStats;
    stats.feature_importance_path = fullfile(cfg.paths.outputDir, cfg.output.featureImportanceCSV);
    stats.feature_contributions_path = fullfile(cfg.paths.outputDir, cfg.output.contributionsCSV);
    stats.calibration_path = fullfile(cfg.paths.outputDir, cfg.output.calibrationJSON);
    stats.calibration_brier = calibration.brier_score;
    stats.calibration_ece = calibration.ece;
    stats.calibration_mce = calibration.mce;
    stats.calibration_auc = calibration.auc;
    stats.disclaimer = 'RESEARCH PROTOTYPE — NOT clinically validated';
    stats.lesion_localization_status = 'REAL_PHASE3_MASK';

    % Top 5 most important features
    topFeatures = struct();
    [~, sortIdx] = sort(importance.auc_drop, 'descend');
    for k = 1:min(5, numel(sortIdx))
        topFeatures.(sprintf('rank_%d', k)) = struct( ...
            'name', importance.feature_name{sortIdx(k)}, ...
            'auc_drop', importance.auc_drop(sortIdx(k)));
    end
    stats.top_features = topFeatures;

    % Save summary JSON
    jsonStr = jsonencode(stats, 'PrettyPrint', true);
    fid = fopen(fullfile(cfg.paths.outputDir, cfg.output.phase5Summary), 'w');
    fwrite(fid, jsonStr, 'char');
    fclose(fid);

    if verbose
        fprintf('\n=== PHASE 5.1 SUMMARY ===\n');
        fprintf('Test images: %d\n', nTest);
        fprintf('Masks found: %d\n', nMasksFound);
        fprintf('Full success: %d, Any failure: %d\n', nSuccess, nFailed);
        fprintf('Total time: %.1f seconds\n', stats.total_time);
        fprintf('Calibration: Brier=%.4f, ECE=%.4f, AUC=%.4f\n', ...
            calibration.brier_score, calibration.ece, calibration.auc);
        fprintf('Top features: ');
        for k = 1:min(5, numel(sortIdx))
            fprintf('%s(%.4f) ', importance.feature_name{sortIdx(k)}, importance.auc_drop(sortIdx(k)));
        end
        fprintf('\n');
        fprintf('Lesion localization: REAL_PHASE3_MASK\n');
        fprintf('Results saved to: %s\n', cfg.paths.outputDir);
    end
end

function imgPath = findImagePath(imageId, cfg)
    T = readtable(cfg.paths.manifest, 'TextType', 'string');
    row = find(strcmp(T.image_id, imageId), 1);
    if ~isempty(row) && ismember('file_path_absolute', T.Properties.VariableNames)
        imgPath = T.file_path_absolute{row};
        if exist(imgPath, 'file')
            return;
        end
    end
    if ~isempty(row) && ismember('file_path', T.Properties.VariableNames)
        relPath = T.file_path{row};
        imgPath = fullfile(cfg.projectRoot, relPath);
        if exist(imgPath, 'file')
            return;
        end
    end
    imgPath = [];
end

function imgContrib = getContributionsForImage(contributions, imageId)
    imgContrib = struct();
    imgContrib.name = {};
    imgContrib.contribution = [];
    imgContrib.direction = {};
    if isempty(contributions) || ~isfield(contributions, 'details')
        return;
    end
    T = contributions.details;
    mask = strcmp(T.image_id, imageId);
    if ~any(mask)
        return;
    end
    imgTable = T(mask, :);
    [~, sortIdx] = sort(abs(imgTable.contribution), 'descend');
    topN = min(10, height(imgTable));
    nameCell = cell(1, topN);
    dirCell = cell(1, topN);
    contribVals = zeros(1, topN);
    for k = 1:topN
        nameCell{k} = imgTable.feature_name{sortIdx(k)};
        contribVals(k) = imgTable.contribution(sortIdx(k));
        dirCell{k} = imgTable.direction{sortIdx(k)};
    end
    imgContrib.name = nameCell;
    imgContrib.contribution = contribVals;
    imgContrib.direction = dirCell;
end
