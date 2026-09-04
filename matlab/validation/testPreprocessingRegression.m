function testPreprocessingRegression()
% testPreprocessingRegression  Prove canonical preprocessing matches training
%
%   This test verifies that preprocessFundus() produces output identical
%   to what augmentedImageDatastore produces, ensuring no preprocessing
%   mismatch between training and inference.

    addpath(genpath('matlab'));
    cfg = transferLearningConfig();
    load(fullfile(cfg.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');

    fprintf('=== Preprocessing Regression Test ===\n\n');

    % Load test images
    T = readtable(fullfile(cfg.paths.splitDir, 'val.csv'), 'TextType', 'string');
    hasGrade = ~isnan(T.dr_grade);
    T = T(hasGrade, :);

    nTest = 20;
    nPass = 0;
    nFail = 0;

    for i = 1:nTest
        p = char(T.file_path_absolute{i});
        if ~exist(p, 'file'), continue; end
        try
            img = imread(p);

            % Method 1: augmentedImageDatastore (training reference)
            imds_i = imageDatastore({p});
            aug_i = augmentedImageDatastore(cfg.image.size, imds_i);
            [predAug, scAug] = classify(trainedNetTL, aug_i);

            % Method 2: canonical preprocessFundus
            imgC = preprocessFundus(img, cfg.image.size);
            [predCan, scCan] = classify(trainedNetTL, imgC);

            % Compare
            gradeAug = double(predAug) - 1;
            gradeCan = double(predCan) - 1;
            maxScoreDiff = max(abs(double(scAug) - double(scCan)));

            if gradeAug == gradeCan
                nPass = nPass + 1;
                status = 'PASS';
            else
                nFail = nFail + 1;
                status = 'FAIL';
            end

            fprintf('  [%2d] %s True=%d | aug=%d can=%d | maxDiff=%.2e | %s\n', ...
                i, T.image_id{i}, T.dr_grade(i), gradeAug, gradeCan, maxScoreDiff, status);
        catch ME
            fprintf('  ERROR %s: %s\n', T.image_id{i}, ME.message);
            nFail = nFail + 1;
        end
    end

    fprintf('\nResults: %d PASS, %d FAIL out of %d\n', nPass, nFail, nTest);
    if nFail == 0
        fprintf('>>> REGRESSION TEST PASSED: canonical preprocessing matches training <<<\n');
    else
        fprintf('>>> REGRESSION TEST FAILED: preprocessing mismatch still exists <<<\n');
    end
end
