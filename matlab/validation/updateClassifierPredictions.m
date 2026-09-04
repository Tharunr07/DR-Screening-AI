function updateClassifierPredictions()
% updateClassifierPredictions  Re-run only the classifier on Phase 20C.1 data
%
%   Takes the existing per-image CSV (which has lesion data already computed)
%   and re-runs only the classifier with CORRECT preprocessing.
%   Updates grade predictions, scores, and clinical logic.

    fprintf('=== Updating classifier predictions (correct preprocessing) ===\n\n');

    cfgTL = transferLearningConfig();
    modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
    data = load(modelPath, 'trainedNetTL');
    net = data.trainedNetTL;

    % Read existing CSV
    csvPath = fullfile(cfgTL.paths.splitDir, 'val.csv');
    T = readtable(csvPath, 'TextType', 'string');
    hasGrade = ~isnan(T.dr_grade);
    T = T(hasGrade, :);
    nImages = height(T);
    fprintf('Loaded %d labeled validation images\n', nImages);

    % Initialize output arrays
    predGrades = zeros(nImages, 1);
    allScores = zeros(nImages, 5);
    gradeNums = zeros(nImages, 1);
    referable = false(nImages, 1);
    confidences = zeros(nImages, 1);

    tic;
    for i = 1:nImages
        imgPath = char(T.file_path_absolute{i});
        if ~exist(imgPath, 'file')
            predGrades(i) = -1;
            continue;
        end

        try
            img = imread(imgPath);
            if size(img, 3) ~= 3, continue; end
            n = preprocessFundus(img, cfgTL.image.size);

            [pred, scores] = classify(net, n);
            gradeNums(i) = double(pred) - 1;
            allScores(i, :) = double(scores(:))';
            predGrades(i) = gradeNums(i);
            referable(i) = gradeNums(i) >= 2;
            confidences(i) = max(scores);
        catch ME
            fprintf('  ERROR [%d] %s: %s\n', i, T.image_id{i}, ME.message);
            predGrades(i) = -1;
        end

        if mod(i, 100) == 0
            fprintf('  [%d/%d] %.1f sec elapsed\n', i, nImages, toc);
        end
    end
    elapsed = toc;
    fprintf('Classifier inference: %.1f sec (%.2f sec/image)\n\n', elapsed, elapsed/nImages);

    % Compute accuracy
    validMask = predGrades >= 0;
    acc = sum(gradeNums(validMask) == T.dr_grade(validMask)) / sum(validMask);
    fprintf('Overall accuracy: %.1f%% (%d/%d)\n', acc*100, sum(gradeNums(validMask) == T.dr_grade(validMask)), sum(validMask));

    % Referable metrics
    trueRef = T.dr_grade >= 2;
    predRef = gradeNums >= 2;
    sens = sum(predRef & trueRef) / max(1, sum(trueRef));
    spec = sum(~predRef & ~trueRef) / max(1, sum(~trueRef));
    fprintf('Referable: sens=%.1f%% spec=%.1f%%\n', sens*100, spec*100);

    % Save updated CSV
    outputCsv = fullfile(cfgTL.paths.splitDir, 'val_classifier_corrected.csv');
    Tout = T;
    Tout.predicted_grade = gradeNums;
    Tout.grade_match = gradeNums == T.dr_grade;
    Tout.referable_predicted = referable;
    Tout.referable_true = trueRef;
    Tout.confidence = confidences;
    for c = 1:5
        Tout.(['P_G' num2str(c-1)]) = allScores(:, c);
    end
    writetable(Tout, outputCsv);
    fprintf('Saved corrected predictions: %s\n', outputCsv);

    % Confusion matrix
    fprintf('\n--- 5x5 CONFUSION MATRIX ---\n');
    classes = 0:4;
    C = zeros(5);
    for i = 1:nImages
        if gradeNums(i) >= 0
            trueIdx = T.dr_grade(i) + 1;
            predIdx = gradeNums(i) + 1;
            C(trueIdx, predIdx) = C(trueIdx, predIdx) + 1;
        end
    end
    fprintf('          ');
    for j = 1:5, fprintf('  G%d  ', j-1); end
    fprintf('\n');
    for i = 1:5
        fprintf('    G%d  ', i-1);
        for j = 1:5, fprintf(' %4d ', C(i,j)); end
        fprintf(' (n=%d)\n', sum(C(i,:)));
    end

    % Per-class metrics
    fprintf('\n--- PER-CLASS METRICS ---\n');
    for c = 1:5
        tp = C(c,c);
        fp = sum(C(:,c)) - tp;
        fn = sum(C(c,:)) - tp;
        tn = sum(C(:)) - tp - fp - fn;
        sens_c = tp / max(1, tp+fn);
        spec_c = tn / max(1, tn+fp);
        prec_c = tp / max(1, tp+fp);
        f1_c = 2*prec_c*sens_c / max(0.001, prec_c+sens_c);
        fprintf('  G%d: sens=%.1f%% spec=%.1f%% prec=%.1f%% F1=%.3f support=%d predFreq=%.1f%%\n', ...
            c-1, sens_c*100, spec_c*100, prec_c*100, f1_c, sum(C(c,:)), sum(C(:,c))/nImages*100);
    end

    fprintf('\n=== DONE ===\n');
end
