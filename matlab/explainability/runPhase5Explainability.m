function stats = runPhase5Explainability(varargin)
% runPhase5Explainability  Full Phase 5 Explainability pipeline
%
%   stats = runPhase5Explainability()
%   stats = runPhase5Explainability('verbose', true)
%   stats = runPhase5Explainability('skipOverlays', false)

    p = inputParser;
    addParameter(p, 'verbose', true);
    addParameter(p, 'skipOverlays', false);
    parse(p, varargin{:});
    verbose = p.Results.verbose;
    skipOverlays = p.Results.skipOverlays;

    cfg = explainabilityConfig();
    rng(cfg.seed);

    if verbose
        fprintf('=== Phase 5: Explainability + Human Review ===\n');
        fprintf('Version: %s | Seed: %d\n', cfg.version, cfg.seed);
    end

    % ---- Step 1: Load Phase 4 predictions ----
    if verbose, fprintf('\n--- Step 1: Load Phase 4 Predictions ---\n'); end
    T4 = readtable(cfg.paths.phase4CSV, 'TextType', 'string');
    nTest = height(T4);
    if verbose, fprintf('Loaded %d test predictions\n', nTest); end

    % ---- Step 2: Re-run Phase 3 for test images (get spatial data) ----
    if verbose, fprintf('\n--- Step 2: Phase 3 Re-run for Test Images ---\n'); end
    tic;
    phase3Results = rerunPhase3ForTest(T4, cfg, verbose);
    p3Time = toc;
    if verbose, fprintf('Phase 3 re-run: %.1f seconds (%.2f s/image)\n', p3Time, p3Time/nTest); end

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

    % ---- Step 7: Per-Image Outputs ----
    if ~skipOverlays
        if verbose, fprintf('\n--- Step 7: Per-Image Explanations ---\n'); end
        tic;
        nSuccess = 0;
        nFailed = 0;
        for i = 1:nTest
            imgId = T4.image_id{i};
            dataset = T4.dataset{i};

            % Find image file
            imgPath = findImagePath(imgId, cfg);
            if isempty(imgPath)
                if verbose && mod(i, 100) == 0
                    fprintf('  [%d/%d] %s: image not found, skipping overlays\n', i, nTest, imgId);
                end
                nFailed = nFailed + 1;
                continue;
            end

            % Get Phase 3 result
            if i <= numel(phase3Results)
                p3Result = phase3Results{i};
            else
                p3Result = struct();
            end

            % Get contributions for this image
            imgContrib = getContributionsForImage(contributions, imgId);

            % Get prediction result
            predResult = struct();
            predResult.predicted_grade = T4.predicted_grade(i);
            predResult.referable_pred = T4.referable_pred(i);
            predResult.referable_probability = T4.referable_probability(i);
            predResult.confidence_score = T4.confidence_score(i);

            % Get split
            split = 'test';

            % Generate outputs
            try
                generateLesionOverlay(imgPath, p3Result, imgId, cfg);
                generateStructureOverlay(imgPath, p3Result, imgId, cfg);
                generateEvidenceOverlay(imgPath, p3Result, predResult, imgContrib, imgId, cfg);
                generateAttentionMap(imgPath, p3Result, imgContrib, imgId, cfg);
                generateReport(imgId, dataset, split, predResult, p3Result, imgContrib, calibration, cfg);
                generateHumanReviewReport(imgId, dataset, split, predResult, p3Result, imgContrib, calibration, cfg);
                nSuccess = nSuccess + 1;
            catch ME
                fprintf('  [ERROR] %s: %s\n', imgId, ME.message);
                nFailed = nFailed + 1;
            end

            if verbose && mod(i, 100) == 0
                fprintf('  [%d/%d] %s: done\n', i, nTest, imgId);
            end
        end
        perImageTime = toc;
        if verbose
            fprintf('Per-image outputs: %.1f seconds (%.2f s/image)\n', perImageTime, perImageTime/nTest);
            fprintf('  Success: %d, Failed: %d\n', nSuccess, nFailed);
        end
    else
        nSuccess = 0;
        nFailed = 0;
        perImageTime = 0;
        if verbose, fprintf('\n--- Step 7: Skipped (skipOverlays=true) ---\n'); end
    end

    % ---- Step 8: Save summary ----
    if verbose, fprintf('\n--- Step 8: Save Summary ---\n'); end
    stats = struct();
    stats.version = cfg.version;
    stats.date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    stats.n_test_images = nTest;
    stats.n_success = nSuccess;
    stats.n_failed = nFailed;
    stats.phase3_rerun_time = p3Time;
    stats.feature_importance_time = impTime;
    stats.feature_contribution_time = contribTime;
    stats.calibration_time = 0;
    stats.per_image_time = perImageTime;
    stats.total_time = p3Time + impTime + contribTime + perImageTime;
    stats.feature_importance_path = fullfile(cfg.paths.outputDir, cfg.output.featureImportanceCSV);
    stats.feature_contributions_path = fullfile(cfg.paths.outputDir, cfg.output.contributionsCSV);
    stats.calibration_path = fullfile(cfg.paths.outputDir, cfg.output.calibrationJSON);
    stats.calibration_brier = calibration.brier_score;
    stats.calibration_ece = calibration.ece;
    stats.calibration_mce = calibration.mce;
    stats.calibration_auc = calibration.auc;
    stats.disclaimer = 'RESEARCH PROTOTYPE — NOT clinically validated';

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
        fprintf('\n=== PHASE 5 SUMMARY ===\n');
        fprintf('Test images: %d\n', nTest);
        fprintf('Success: %d, Failed: %d\n', nSuccess, nFailed);
        fprintf('Total time: %.1f seconds\n', stats.total_time);
        fprintf('Calibration: Brier=%.4f, ECE=%.4f, AUC=%.4f\n', ...
            calibration.brier_score, calibration.ece, calibration.auc);
        fprintf('Top features: ');
        for k = 1:min(5, numel(sortIdx))
            fprintf('%s(%.4f) ', importance.feature_name{sortIdx(k)}, importance.auc_drop(sortIdx(k)));
        end
        fprintf('\n');
        fprintf('Results saved to: %s\n', cfg.paths.outputDir);
    end
end

function phase3Results = rerunPhase3ForTest(T4, cfg, verbose)
    nTest = height(T4);
    phase3Results = cell(nTest, 1);
    cfgP3 = phase3Config();
    cfgQ = qualityConfig();

    % Load quality results
    Tq = readtable(cfg.paths.qualityCSV, 'TextType', 'string');

    nProcessed = 0;
    for i = 1:nTest
        imgId = T4.image_id{i};
        imgPath = findImagePath(imgId, cfg);

        if isempty(imgPath)
            phase3Results{i} = struct('quality_status', 'IMAGE_NOT_FOUND', ...
                'ma_candidate_count', 0, 'he_candidate_count', 0, ...
                'ex_candidate_count', 0, 'nv_candidate', false);
            continue;
        end

        % Get quality result
        qRow = find(strcmp(Tq.image_id, imgId), 1);
        if ~isempty(qRow)
            qualityResult = struct();
            qualityResult.quality_status = Tq.quality_status(qRow);
            qualityResult.overall_quality_score = Tq.overall_quality_score(qRow);
        else
            qualityResult = struct('quality_status', 'NOT_ASSED', 'overall_quality_score', NaN);
        end

        % Run Phase 3 analysis
        try
            p3Result = analyzeImage(imgPath, qualityResult, cfgP3);
            phase3Results{i} = p3Result;
            nProcessed = nProcessed + 1;
        catch ME
            phase3Results{i} = struct('quality_status', 'ANALYSIS_FAILED', ...
                'ma_candidate_count', 0, 'he_candidate_count', 0, ...
                'ex_candidate_count', 0, 'nv_candidate', false, ...
                'error', ME.message);
        end

        if verbose && mod(i, 100) == 0
            fprintf('  Phase 3 re-run: %d/%d processed\n', i, nTest);
        end
    end
    if verbose, fprintf('Phase 3 re-run complete: %d/%d successful\n', nProcessed, nTest); end
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
