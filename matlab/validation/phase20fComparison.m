function phase20fComparison()
% phase20fComparison  Phase 20F — Final same-image OLD vs NEW comparison
%
%   Runs reference/problematic images through the COMPLETE corrected pipeline
%   and compares against reconstructed OLD pipeline behavior.
%
%   DO NOT tune thresholds based on these images.
%   This is an EVALUATION phase, not a correction phase.

    fprintf('============================================================\n');
    fprintf('  Phase 20F: Final Same-Image System-Level Comparison\n');
    fprintf('============================================================\n\n');

    cfgTL = transferLearningConfig();
    modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
    data = load(modelPath, 'trainedNetTL');
    net = data.trainedNetTL;

    outputDir = fullfile(cfgTL.projectRoot, 'results', 'phase20f_same_image_comparison');
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    refImages = {
        '00836aaacf06', 'Phase 20C system comparison'
        '0097f532ac9f', 'Phase 20C system comparison'
        '009c019a7309', 'Phase 20C system comparison'
        '00e4ddff966a', 'Phase 20C system comparison'
        '01499815e469', 'Phase 20C system comparison (high MA=24)'
        '01d9477b1171', 'Phase 20C system comparison'
        'fda39982a810', 'Phase 20C.1 outlier (G3, Total=11)'
        'fe3b0e50be78', 'Phase 20C.1 outlier (G0, MA=2)'
        'ff0740cb484a', 'Phase 20C.1 outlier (G2, EX=5)'
    };

    valCsv = fullfile(cfgTL.paths.splitDir, 'val.csv');
    Tval = readtable(valCsv, 'TextType', 'string');

    nRef = size(refImages, 1);
    results = {};

    for i = 1:nRef
        imgId = refImages{i, 1};
        reason = refImages{i, 2};
        fprintf('\n--- [%d/%d] %s (%s) ---\n', i, nRef, imgId, reason);

        pathMatch = Tval.image_id == imgId;
        if ~any(pathMatch), fprintf('  SKIP: not found\n'); continue; end
        imgPath = char(Tval.file_path_absolute{pathMatch});
        if ~exist(imgPath, 'file'), fprintf('  SKIP: file missing\n'); continue; end

        img = imread(imgPath);
        if size(img, 3) ~= 3, fprintf('  SKIP: not RGB\n'); continue; end
        [h, w, ~] = size(img);
        fprintf('  Dimensions: %dx%d\n', w, h);

        imgDir = fullfile(outputDir, sprintf('%02d_%s', i, imgId));
        if ~exist(imgDir, 'dir'), mkdir(imgDir); end

        quality = assessQuality(img);
        nNew = preprocessFundus(img, cfgTL.image.size);
        [predNew, scoresNew] = classify(net, nNew);
        gradeNew = double(predNew) - 1;
        scoresNewD = double(scoresNew(:))';
        referableNew = gradeNew >= 2;
        confidenceNew = max(scoresNewD);
        evidenceNew = extractLesionEvidence(img);
        resNew = applyClinicalLogic(gradeNew, scoresNewD, evidenceNew, quality);

        try
            [camNew, ~, ~] = gradcamSimple(net, nNew, 'TargetClass', double(predNew));
            camMaxNew = max(camNew(:)); camInFOV = computeFOVCoverage(camNew, img);
        catch
            camNew = []; camMaxNew = NaN; camInFOV = NaN;
        end

        [maN, heN, exN, nvN, totN] = countLesions(evidenceNew);

        imgR = imresize(img, cfgTL.image.size, 'bilinear');
        mn = [0.485 0.456 0.406]; sd = [0.229 0.224 0.225];
        nOld = double(imgR);
        for c = 1:3, nOld(:,:,c) = (nOld(:,:,c)/255 - mn(c)) / sd(c); end
        [predOld, scoresOld] = classify(net, nOld);
        gradeOld = double(predOld) - 1;
        scoresOldD = double(scoresOld(:))';
        referableOld = gradeOld >= 2;
        confidenceOld = max(scoresOldD);
        evidenceOld = extractLesionEvidence(img);
        resOld = applyClinicalLogic(gradeOld, scoresOldD, evidenceOld, quality);

        try
            [camOld, ~, ~] = gradcamSimple(net, nOld, 'TargetClass', double(predOld));
            camMaxOld = max(camOld(:)); camInFOVold = computeFOVCoverage(camOld, img);
        catch
            camOld = []; camMaxOld = NaN; camInFOVold = NaN;
        end

        [mA, hA, eA, nvA, totA] = countLesions(evidenceOld);

        gradeChanged = gradeOld ~= gradeNew;
        referableChanged = referableOld ~= referableNew;
        camCorr = NaN;
        if ~isempty(camOld) && ~isempty(camNew) && numel(camOld) == numel(camNew)
            camCorr = corr2(camOld(:), camNew(:));
        end

        fprintf('  OLD: G%d Ref=%d Conf=%.3f MA=%d HE=%d EX=%d\n', gradeOld, referableOld, confidenceOld, mA, hA, eA);
        fprintf('  NEW: G%d Ref=%d Conf=%.3f MA=%d HE=%d EX=%d\n', gradeNew, referableNew, confidenceNew, maN, heN, exN);
        if gradeChanged, fprintf('  *** GRADE CHANGED: G%d -> G%d ***\n', gradeOld, gradeNew); end
        if referableChanged, fprintf('  *** REFERABLE CHANGED ***\n'); end
        fprintf('  CAM correlation: %.3f\n', camCorr);

        writePipelineFigure(img, camOld, evidenceOld, gradeOld, scoresOldD, quality, 'OLD', fullfile(imgDir, 'old_pipeline.png'));
        writePipelineFigure(img, camNew, evidenceNew, gradeNew, scoresNewD, quality, 'NEW', fullfile(imgDir, 'new_pipeline.png'));
        writeComparisonFigure(img, camOld, camNew, evidenceOld, evidenceNew, gradeOld, gradeNew, scoresOldD, scoresNewD, referableOld, referableNew, camCorr, fullfile(imgDir, 'comparison.png'));

        R = struct();
        R.image_id = imgId; R.reason = reason; R.width = w; R.height = h;
        R.old_grade = gradeOld; R.new_grade = gradeNew; R.grade_changed = gradeChanged;
        R.old_referable = referableOld; R.new_referable = referableNew; R.referable_changed = referableChanged;
        R.old_scores = scoresOldD; R.new_scores = scoresNewD;
        R.old_confidence = confidenceOld; R.new_confidence = confidenceNew;
        R.old_ma = mA; R.new_ma = maN; R.old_he = hA; R.new_he = heN;
        R.old_ex = eA; R.new_ex = exN; R.old_nv = nvA; R.new_nv = nvN;
        R.old_total = totA; R.new_total = totN;
        R.old_camMax = camMaxOld; R.new_camMax = camMaxNew;
        R.old_camInFOV = camInFOVold; R.new_camInFOV = camInFOV;
        R.cam_correlation = camCorr;
        R.quality_status = quality.status; R.quality_score = quality.score;
        R.old_consistency = resOld.consistency;
        R.new_consistency = resNew.consistency;
        results{end+1} = R;
    end

    writePerImageCSV(results, fullfile(outputDir, 'phase20f_per_image.csv'));
    writeReport(results, outputDir);

    fprintf('\n============================================================\n');
    fprintf('  Phase 20F COMPLETE\n');
    fprintf('  Output: %s\n', outputDir);
    fprintf('============================================================\n');
end

%% ============ HELPER FUNCTIONS ============

function quality = assessQuality(img)
    gray = rgb2gray(img);
    brightness = mean(gray(:));
    contrast = std(double(gray(:)));
    lap = [0 1 0; 1 -4 1; 0 1 0];
    convResult = conv2(double(gray), lap, 'same');
    sharpness = var(convResult(:));
    quality.brightness = brightness; quality.contrast = contrast; quality.sharpness = sharpness;
    quality.score = 1;
    if brightness < 40 || brightness > 220, quality.status = 'POOR'; quality.score = 0;
    elseif contrast < 20, quality.status = 'POOR'; quality.score = 0;
    elseif sharpness < 100, quality.status = 'BORDERLINE'; quality.score = 2;
    else, quality.status = 'GOOD'; quality.score = 3; end
end

function [maC, heC, exC, nvD, total] = countLesions(evidence)
    maC = 0; heC = 0; exC = 0; nvD = false;
    if isfield(evidence, 'microaneurysms') && isstruct(evidence.microaneurysms) && isfield(evidence.microaneurysms, 'count'), maC = evidence.microaneurysms.count; end
    if isfield(evidence, 'hemorrhages') && isstruct(evidence.hemorrhages) && isfield(evidence.hemorrhages, 'count'), heC = evidence.hemorrhages.count; end
    if isfield(evidence, 'exudates') && isstruct(evidence.exudates) && isfield(evidence.exudates, 'count'), exC = evidence.exudates.count; end
    if isfield(evidence, 'neovascularization') && isstruct(evidence.neovascularization) && isfield(evidence.neovascularization, 'detected'), nvD = evidence.neovascularization.detected; end
    total = maC + heC + exC + double(nvD);
end

function n = countMA(e)
    n = 0;
    if isfield(e, 'microaneurysms') && isstruct(e.microaneurysms) && isfield(e.microaneurysms, 'count'), n = e.microaneurysms.count; end
end

function n = countHE(e)
    n = 0;
    if isfield(e, 'hemorrhages') && isstruct(e.hemorrhages) && isfield(e.hemorrhages, 'count'), n = e.hemorrhages.count; end
end

function n = countEX(e)
    n = 0;
    if isfield(e, 'exudates') && isstruct(e.exudates) && isfield(e.exudates, 'count'), n = e.exudates.count; end
end

function fovCov = computeFOVCoverage(cam, img)
    gray = rgb2gray(img);
    fovMask = gray > 10;
    camResized = imresize(cam, size(fovMask));
    camBin = camResized > 0.5 * max(camResized(:));
    if sum(fovMask(:)) == 0, fovCov = 0; return; end
    fovCov = sum(camBin(:) & fovMask(:)) / sum(fovMask(:));
end

function writePipelineFigure(img, cam, evidence, grade, scores, quality, label, outPath)
    fig = figure('Visible', 'off', 'Position', [100 100 1200 600]);
    subplot(2,3,1); imshow(img); title(sprintf('Input (%s)', label));
    subplot(2,3,2); imshow(img); hold on;
    if isfield(evidence, 'microaneurysms') && isstruct(evidence.microaneurysms) && isfield(evidence.microaneurysms, 'centroids') && ~isempty(evidence.microaneurysms.centroids)
        c = evidence.microaneurysms.centroids; plot(c(:,1), c(:,2), 'c+', 'MarkerSize', 12, 'LineWidth', 2);
    end
    hold off; title(sprintf('MA=%d', countMA(evidence)));
    subplot(2,3,3); imshow(img); hold on;
    if isfield(evidence, 'hemorrhages') && isstruct(evidence.hemorrhages) && isfield(evidence.hemorrhages, 'centroids') && ~isempty(evidence.hemorrhages.centroids)
        c = evidence.hemorrhages.centroids; plot(c(:,1), c(:,2), 'm+', 'MarkerSize', 12, 'LineWidth', 2);
    end
    hold off; title(sprintf('HE=%d', countHE(evidence)));
    subplot(2,3,4); imshow(img); hold on;
    if isfield(evidence, 'exudates') && isstruct(evidence.exudates) && isfield(evidence.exudates, 'centroids') && ~isempty(evidence.exudates.centroids)
        c = evidence.exudates.centroids; plot(c(:,1), c(:,2), 'y+', 'MarkerSize', 12, 'LineWidth', 2);
    end
    hold off; title(sprintf('EX=%d', countEX(evidence)));
    subplot(2,3,5); imshow(img); hold on;
    if ~isempty(cam), h = imagesc(cam, [0 1]); set(h, 'AlphaData', 0.4); colormap(fig, jet); end
    hold off; title('Grad-CAM');
    subplot(2,3,6); axis off;
    txt = {sprintf('Grade: G%d', grade), sprintf('P: [%.3f %.3f %.3f %.3f %.3f]', scores(1), scores(2), scores(3), scores(4), scores(5)), ...
        sprintf('Referable: %d', grade >= 2), sprintf('Confidence: %.3f', max(scores)), sprintf('Quality: %s', quality.status)};
    text(0.1, 0.5, txt, 'FontSize', 9, 'VerticalAlignment', 'middle');
    sgtitle(sprintf('%s Pipeline', label), 'FontWeight', 'bold');
    saveas(fig, outPath); close(fig);
end

function writeComparisonFigure(img, camOld, camNew, evOld, evNew, gOld, gNew, sOld, sNew, rOld, rNew, camCorr, outPath)
    fig = figure('Visible', 'off', 'Position', [100 100 1400 800]);
    subplot(2,4,1); imshow(img); title('Original');
    subplot(2,4,2); imshow(img); hold on;
    if ~isempty(camOld), h = imagesc(camOld, [0 1]); set(h, 'AlphaData', 0.4); colormap(fig, jet); end
    hold off; title(sprintf('OLD Grad-CAM\nG%d Ref=%d', gOld, rOld));
    subplot(2,4,3); imshow(img); hold on; plotLesions(evOld); hold off;
    title(sprintf('OLD Lesions\nMA=%d HE=%d EX=%d', countMA(evOld), countHE(evOld), countEX(evOld)));
    subplot(2,4,4); axis off;
    oldTxt = {'=== OLD ===', sprintf('Grade: G%d', gOld), sprintf('P: [%.2f %.2f %.2f %.2f %.2f]', sOld(1), sOld(2), sOld(3), sOld(4), sOld(5)), ...
        sprintf('Referable: %d', rOld), sprintf('Confidence: %.3f', max(sOld))};
    text(0.05, 0.5, oldTxt, 'FontSize', 9, 'VerticalAlignment', 'middle');
    subplot(2,4,5); imshow(img); title('Original');
    subplot(2,4,6); imshow(img); hold on;
    if ~isempty(camNew), h = imagesc(camNew, [0 1]); set(h, 'AlphaData', 0.4); colormap(fig, jet); end
    hold off; title(sprintf('NEW Grad-CAM\nG%d Ref=%d', gNew, rNew));
    subplot(2,4,7); imshow(img); hold on; plotLesions(evNew); hold off;
    title(sprintf('NEW Lesions\nMA=%d HE=%d EX=%d', countMA(evNew), countHE(evNew), countEX(evNew)));
    subplot(2,4,8); axis off;
    newTxt = {'=== NEW ===', sprintf('Grade: G%d', gNew), sprintf('P: [%.2f %.2f %.2f %.2f %.2f]', sNew(1), sNew(2), sNew(3), sNew(4), sNew(5)), ...
        sprintf('Referable: %d', rNew), sprintf('Confidence: %.3f', max(sNew)), '', sprintf('CAM corr: %.3f', camCorr)};
    text(0.05, 0.5, newTxt, 'FontSize', 9, 'VerticalAlignment', 'middle');
    sgtitle('OLD vs NEW Comparison', 'FontWeight', 'bold');
    saveas(fig, outPath); close(fig);
end

function plotLesions(evidence)
    if isfield(evidence, 'microaneurysms') && isstruct(evidence.microaneurysms) && isfield(evidence.microaneurysms, 'centroids') && ~isempty(evidence.microaneurysms.centroids)
        c = evidence.microaneurysms.centroids; plot(c(:,1), c(:,2), 'c+', 'MarkerSize', 10, 'LineWidth', 1.5);
    end
    if isfield(evidence, 'hemorrhages') && isstruct(evidence.hemorrhages) && isfield(evidence.hemorrhages, 'centroids') && ~isempty(evidence.hemorrhages.centroids)
        c = evidence.hemorrhages.centroids; plot(c(:,1), c(:,2), 'm+', 'MarkerSize', 10, 'LineWidth', 1.5);
    end
    if isfield(evidence, 'exudates') && isstruct(evidence.exudates) && isfield(evidence.exudates, 'centroids') && ~isempty(evidence.exudates.centroids)
        c = evidence.exudates.centroids; plot(c(:,1), c(:,2), 'y+', 'MarkerSize', 10, 'LineWidth', 1.5);
    end
end

function writePerImageCSV(results, csvPath)
    T = table();
    for i = 1:numel(results)
        R = results{i};
        idx = i;
        T.image_id(idx) = string(R.image_id); T.reason(idx) = string(R.reason);
        T.width(idx) = R.width; T.height(idx) = R.height;
        T.old_grade(idx) = R.old_grade; T.new_grade(idx) = R.new_grade; T.grade_changed(idx) = R.grade_changed;
        T.old_referable(idx) = R.old_referable; T.new_referable(idx) = R.new_referable; T.referable_changed(idx) = R.referable_changed;
        T.old_confidence(idx) = R.old_confidence; T.new_confidence(idx) = R.new_confidence;
        T.old_ma(idx) = R.old_ma; T.new_ma(idx) = R.new_ma;
        T.old_he(idx) = R.old_he; T.new_he(idx) = R.new_he;
        T.old_ex(idx) = R.old_ex; T.new_ex(idx) = R.new_ex;
        T.old_nv(idx) = R.old_nv; T.new_nv(idx) = R.new_nv;
        T.old_total(idx) = R.old_total; T.new_total(idx) = R.new_total;
        T.old_camMax(idx) = R.old_camMax; T.new_camMax(idx) = R.new_camMax;
        T.old_camInFOV(idx) = R.old_camInFOV; T.new_camInFOV(idx) = R.new_camInFOV;
        T.cam_correlation(idx) = R.cam_correlation;
        T.quality_status(idx) = string(R.quality_status);
    end
    writetable(T, csvPath);
end

function writeReport(results, outputDir)
    fid = fopen(fullfile(outputDir, 'PHASE20F_SUMMARY.txt'), 'w');
    fprintf(fid, 'Phase 20F: Final Same-Image System-Level Comparison\n');
    fprintf(fid, '==================================================\n\n');
    n = numel(results); nChanged = 0; nRefChanged = 0; camCorrs = [];
    for i = 1:n
        R = results{i};
        if isempty(fieldnames(R)), continue; end
        if R.grade_changed, nChanged = nChanged + 1; end
        if R.referable_changed, nRefChanged = nRefChanged + 1; end
        if ~isnan(R.cam_correlation), camCorrs(end+1) = R.cam_correlation; end %#ok<AGROW>
    end
    fprintf(fid, 'Images compared: %d\n', n);
    fprintf(fid, 'Grade changed (OLD->NEW): %d/%d\n', nChanged, n);
    fprintf(fid, 'Referable changed: %d/%d\n', nRefChanged, n);
    if ~isempty(camCorrs)
        fprintf(fid, 'CAM correlation: mean=%.3f median=%.3f range=[%.3f, %.3f]\n', mean(camCorrs), median(camCorrs), min(camCorrs), max(camCorrs));
    end
    fprintf(fid, '\n--- Per-Image Details ---\n\n');
    for i = 1:n
        R = results{i};
        if isempty(fieldnames(R)), continue; end
        fprintf(fid, '%d. %s (%s)\n', i, R.image_id, R.reason);
        fprintf(fid, '   Dimensions: %dx%d Quality: %s\n', R.width, R.height, R.quality_status);
        fprintf(fid, '   OLD: G%d Ref=%d Conf=%.3f MA=%d HE=%d EX=%d NV=%d\n', R.old_grade, R.old_referable, R.old_confidence, R.old_ma, R.old_he, R.old_ex, R.old_nv);
        fprintf(fid, '   NEW: G%d Ref=%d Conf=%.3f MA=%d HE=%d EX=%d NV=%d\n', R.new_grade, R.new_referable, R.new_confidence, R.new_ma, R.new_he, R.new_ex, R.new_nv);
        if R.grade_changed, fprintf(fid, '   *** GRADE CHANGED: G%d -> G%d ***\n', R.old_grade, R.new_grade); end
        if R.referable_changed, fprintf(fid, '   *** REFERABLE CHANGED ***\n'); end
        fprintf(fid, '   CAM correlation: %.3f | OLD camInFOV: %.1f%% | NEW camInFOV: %.1f%%\n', R.cam_correlation, R.old_camInFOV*100, R.new_camInFOV*100);
        fprintf(fid, '   OLD P: [%.3f %.3f %.3f %.3f %.3f]\n', R.old_scores(1), R.old_scores(2), R.old_scores(3), R.old_scores(4), R.old_scores(5));
        fprintf(fid, '   NEW P: [%.3f %.3f %.3f %.3f %.3f]\n', R.new_scores(1), R.new_scores(2), R.new_scores(3), R.new_scores(4), R.new_scores(5));
        fprintf(fid, '\n');
    end
    fclose(fid);
    fprintf('Report: %s\n', fullfile(outputDir, 'PHASE20F_SUMMARY.txt'));
end
