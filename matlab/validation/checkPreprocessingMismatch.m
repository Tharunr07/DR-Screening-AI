function checkPreprocessingMismatch()
% checkPreprocessingMismatch  CRITICAL: Compare training vs inference preprocessing
%
%   Hypothesis: The model was trained on RAW pixel values (0-255) via
%   augmentedImageDatastore, but our audit code applies ImageNet normalization.
%   This mismatch would cause the G2 collapse.

    addpath(genpath('matlab'));
    cfg = transferLearningConfig();
    load(fullfile(cfg.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');

    fprintf('=== PREPROCESSING MISMATCH DIAGNOSTIC ===\n\n');

    % ImageNet normalization params
    mn = [0.485 0.456 0.406]; sd = [0.229 0.224 0.225];

    % Load validation images
    T = readtable(fullfile(cfg.paths.splitDir, 'val.csv'), 'TextType', 'string');
    hasGrade = ~isnan(T.dr_grade);
    T = T(hasGrade, :);

    nTest = min(50, height(T));
    agreeCount = 0;
    disagreeCount = 0;
    agreeRawResize = 0;

    fprintf('Testing %d images with 3 preprocessing methods:\n', nTest);
    fprintf('  Method A: augmentedImageDatastore (training match)\n');
    fprintf('  Method B: manual ImageNet normalization (our audit)\n');
    fprintf('  Method C: resize only, single (no normalization)\n\n');

    for i = 1:nTest
        p = char(T.file_path_absolute{i});
        if ~exist(p, 'file'), continue; end
        try
            im = imread(p);

            % Method A: augmentedImageDatastore (matches training evaluation)
            imds_i = imageDatastore({p});
            aug_i = augmentedImageDatastore([224 224], imds_i);
            predA = classify(trainedNetTL, aug_i);
            gradeA = double(predA) - 1;

            % Method B: ImageNet normalization (our audit code)
            imR = imresize(im, [224 224], 'bicubic');
            normPx = double(imR) / 255;
            for c = 1:3, normPx(:,:,c) = (normPx(:,:,c) - mn(c)) / sd(c); end
            normPx = single(normPx);
            predB = classify(trainedNetTL, normPx);
            gradeB = double(predB) - 1;

            % Method C: resize only (single precision, no normalization)
            rawR = single(imresize(im, [224 224], 'bicubic'));
            predC = classify(trainedNetTL, rawR);
            gradeC = double(predC) - 1;

            if gradeA == gradeB, agreeCount = agreeCount + 1; end
            if gradeA ~= gradeB, disagreeCount = disagreeCount + 1; end
            if gradeA == gradeC, agreeRawResize = agreeRawResize + 1; end

            if i <= 15
                matchAB = ''; if gradeA == gradeB, matchAB = 'MATCH'; else, matchAB = 'DIFF'; end
                fprintf('  [%2d] %s True=%d | A=%d B=%d C=%d  %s\n', ...
                    i, T.image_id{i}, T.dr_grade(i), gradeA, gradeB, gradeC, matchAB);
            end
        catch ME
            fprintf('  ERROR %s: %s\n', T.image_id{i}, ME.message);
        end
    end
    fprintf('\n  A vs B (aug vs normalized): agree=%d/%d disagree=%d/%d\n', ...
        agreeCount, nTest, disagreeCount, nTest);
    fprintf('  A vs C (aug vs resizeOnly): agree=%d/%d\n', agreeRawResize, nTest);

    if disagreeCount > nTest * 0.1
        fprintf('\n>>> PREPROCESSING MISMATCH CONFIRMED <<<\n');
        fprintf('>>> Training evaluation uses raw pixels (via augmentedImageDatastore) <<<\n');
        fprintf('>>> Our audit uses ImageNet normalization <<<\n');
        fprintf('>>> This is the ROOT CAUSE of G2 collapse <<<\n');
    else
        fprintf('\nNo significant preprocessing mismatch detected.\n');
    end
end
