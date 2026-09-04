function phase20gForensic(varargin)
% phase20gForensic  Phase 20G — Forensic investigation of flagged cases
%
%   phase20gForensic()           — analyze all 9 Phase 20F images
%   phase20gForensic('ImageID', '01499815e469') — analyze one image

    p = inputParser;
    addParameter(p, 'ImageID', '', @ischar);
    parse(p, varargin{:});

    cfgTL = transferLearningConfig();
    modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
    data = load(modelPath, 'trainedNetTL');
    net = data.trainedNetTL;

    outputBase = fullfile(cfgTL.projectRoot, 'results', 'phase20g_forensic');
    if ~exist(outputBase, 'dir'), mkdir(outputBase); end

    valCsv = fullfile(cfgTL.paths.splitDir, 'val.csv');
    Tval = readtable(valCsv, 'TextType', 'string');

    if ~isempty(p.Results.ImageID)
        refImages = {p.Results.ImageID, 'specified'};
    else
        refImages = {
            '01499815e469', 'Phase 20F primary case (MA=24, G3, CAM 0% FOV)'
            '0097f532ac9f', 'Phase 20F corrected false positive (G2->G0)'
            '00836aaacf06', 'Phase 20F comparison image'
            '009c019a7309', 'Phase 20F comparison image'
            '00e4ddff966a', 'Phase 20F comparison image'
            '01d9477b1171', 'Phase 20F comparison image'
            'fda39982a810', 'Phase 20F outlier (G3, Total=11)'
            'fe3b0e50be78', 'Phase 20F corrected false positive (G2->G0)'
            'ff0740cb484a', 'Phase 20F outlier (G2, EX=5)'
        };
    end

    summaryRows = {};

    for i = 1:size(refImages, 1)
        imgId = refImages{i, 1};
        reason = refImages{i, 2};
        fprintf('\n=== [%d/%d] %s — %s ===\n', i, size(refImages,1), imgId, reason);

        pathMatch = Tval.image_id == imgId;
        if ~any(pathMatch), fprintf('SKIP: not found\n'); continue; end
        imgPath = char(Tval.file_path_absolute{pathMatch});
        if ~exist(imgPath, 'file'), fprintf('SKIP: file missing\n'); continue; end

        trueGrade = Tval.dr_grade(pathMatch);

        img = imread(imgPath);
        if size(img, 3) ~= 3, fprintf('SKIP: not RGB\n'); continue; end
        [h, w, ~] = size(img);

        caseDir = fullfile(outputBase, ['case_' imgId]);
        if ~exist(caseDir, 'dir'), mkdir(caseDir); end

        fprintf('  Image: %dx%d, True grade: G%d\n', w, h, trueGrade);

        quality = assessQualityG(img);

        nNew = preprocessFundus(img, cfgTL.image.size);
        [predNew, scoresNew] = classify(net, nNew);
        gradeNew = double(predNew) - 1;
        scoresNewD = double(scoresNew(:))';
        referableNew = gradeNew >= 2;
        confidenceNew = max(scoresNewD);

        imgR = imresize(img, cfgTL.image.size, 'bilinear');
        mn = [0.485 0.456 0.406]; sd = [0.229 0.224 0.225];
        nOld = double(imgR);
        for c = 1:3, nOld(:,:,c) = (nOld(:,:,c)/255 - mn(c)) / sd(c); end
        [predOld, scoresOld] = classify(net, nOld);
        gradeOld = double(predOld) - 1;
        scoresOldD = double(scoresOld(:))';
        referableOld = gradeOld >= 2;
        confidenceOld = max(scoresOldD);

        fprintf('  OLD: G%d (Conf=%.3f) | NEW: G%d (Conf=%.3f)\n', gradeOld, confidenceOld, gradeNew, confidenceNew);

        fprintf('  Running detectors (Diagnostic=true)...\n');
        tic;
        maResult = detectMicroaneurysms(img, 'Diagnostic', true);
        heResult = detectHemorrhages(img, 'Diagnostic', true);
        exResult = detectExudates(img, 'Diagnostic', true);
        nvResult = detectNeovascularization(img, 'Diagnostic', true);
        dt = toc;
        fprintf('  Detectors: %.1f sec | MA=%d HE=%d EX=%d NV=%d\n', dt, maResult.count, heResult.count, exResult.count, nvResult.detected);

        fprintf('  Running Grad-CAM...\n');
        try
            [camNew, ~, ~] = gradcamSimple(net, nNew, 'TargetClass', double(predNew));
            camMaxNew = max(camNew(:));
        catch ME
            camNew = []; camMaxNew = NaN;
            fprintf('  Grad-CAM error: %s\n', ME.message);
        end

        try
            [camOld, ~, ~] = gradcamSimple(net, nOld, 'TargetClass', double(predOld));
        catch
            camOld = [];
        end

        fprintf('  Saving intermediates...\n');
        saveIntermediates(img, maResult, heResult, exResult, nvResult, camNew, camOld, caseDir);

        fprintf('  Analyzing candidates...\n');
        candidates = analyzeCandidates(img, maResult, heResult, exResult, nvResult, caseDir);

        fprintf('  Analyzing Grad-CAM attention...\n');
        camAnalysis = analyzeGradCAM(img, camNew, camOld, maResult, heResult, exResult, nvResult, caseDir);

        fprintf('  Generating panels...\n');
        generateForensicPanels(img, maResult, heResult, exResult, nvResult, camNew, camOld, ...
            gradeNew, gradeOld, scoresNewD, scoresOldD, quality, camAnalysis, caseDir);

        summaryRows{end+1} = struct( ...
            'image_id', imgId, 'reason', reason, ...
            'true_grade', trueGrade, ...
            'old_grade', gradeOld, 'new_grade', gradeNew, ...
            'old_confidence', confidenceOld, 'new_confidence', confidenceNew, ...
            'old_referable', referableOld, 'new_referable', referableNew, ...
            'ma_count', maResult.count, 'he_count', heResult.count, ...
            'ex_count', exResult.count, 'nv_detected', nvResult.detected, ...
            'cam_fov_pct', camAnalysis.newCamInFOV * 100, ...
            'cam_lesion_pct', camAnalysis.newCamLesionOverlap * 100, ...
            'candidate_count', numel(candidates)); %#ok<AGROW>

        fprintf('  Case complete.\n');
    end

    fprintf('\n\n=== Writing summary ===\n');
    writeCaseSummary(summaryRows, outputBase);
    fprintf('Phase 20G COMPLETE. Output: %s\n', outputBase);
end

function quality = assessQualityG(img)
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

function saveIntermediates(img, maR, heR, exR, nvR, camNew, camOld, caseDir)
    imwrite(img, fullfile(caseDir, '01_original.png'));
    if isfield(maR, 'retinalMask') && any(maR.retinalMask(:))
        imwrite(maR.retinalMask, fullfile(caseDir, '02_fov_mask.png'));
    end
    if isfield(maR, 'discMask') && any(maR.discMask(:))
        imwrite(maR.discMask, fullfile(caseDir, '03_disc_mask.png'));
    end
    if isfield(maR, 'vesselMask') && any(maR.vesselMask(:))
        imwrite(maR.vesselMask, fullfile(caseDir, '04_vessel_mask_ma.png'));
    end
    if isfield(maR, 'rawCandidates') && any(maR.rawCandidates(:))
        imwrite(maR.rawCandidates, fullfile(caseDir, '05_ma_raw_candidates.png'));
    end
    if isfield(maR, 'filteredCandidates')
        imwrite(maR.filteredCandidates, fullfile(caseDir, '06_ma_final_candidates.png'));
    end
    if isfield(heR, 'rawCandidates') && any(heR.rawCandidates(:))
        imwrite(heR.rawCandidates, fullfile(caseDir, '07_he_raw_candidates.png'));
    end
    if isfield(heR, 'filteredCandidates')
        imwrite(heR.filteredCandidates, fullfile(caseDir, '08_he_final_candidates.png'));
    end
    if isfield(exR, 'rawCandidates') && any(exR.rawCandidates(:))
        imwrite(exR.rawCandidates, fullfile(caseDir, '09_ex_raw_candidates.png'));
    end
    if isfield(exR, 'filteredCandidates')
        imwrite(exR.filteredCandidates, fullfile(caseDir, '10_ex_final_candidates.png'));
    end
    if isfield(nvR, 'vesselMask') && any(nvR.vesselMask(:))
        imwrite(nvR.vesselMask, fullfile(caseDir, '11_nv_vessel_mask.png'));
    end
    if isfield(nvR, 'mask') && any(nvR.mask(:))
        imwrite(nvR.mask, fullfile(caseDir, '12_nv_final_mask.png'));
    end
    if ~isempty(camNew)
        camImg = mat2gray(camNew);
        imwrite(camImg, fullfile(caseDir, '13_gradcam_new_raw.png'));
    end
    if ~isempty(camOld)
        camImg = mat2gray(camOld);
        imwrite(camImg, fullfile(caseDir, '14_gradcam_old_raw.png'));
    end
end

function candidates = analyzeCandidates(img, maR, heR, exR, nvR, caseDir)
    candidates = {};
    gray = rgb2gray(img);
    [h, w, ~] = size(img);
    fovMask = false(h, w);
    if isfield(maR, 'retinalMask') && any(maR.retinalMask(:))
        fovMask = maR.retinalMask;
    else
        fovMask = gray > 10;
    end
    [fovR, fovC] = find(fovMask);
    if ~isempty(fovR)
        fovCenterR = mean(fovR); fovCenterC = mean(fovC);
        fovRadius = sqrt(numel(fovR) / pi);
    else
        fovCenterR = h/2; fovCenterC = w/2; fovRadius = min(h,w)/2;
    end
    discCenterR = h/2; discCenterC = w/2; discRadius = 0;
    if isfield(maR, 'discMask') && any(maR.discMask(:))
        dStats = regionprops(maR.discMask, 'Centroid', 'MajorAxisLength');
        if ~isempty(dStats)
            discCenterR = dStats(1).Centroid(2);
            discCenterC = dStats(1).Centroid(1);
            discRadius = dStats(1).MajorAxisLength / 2;
        end
    end
    vesselMask = false(h, w);
    if isfield(maR, 'vesselMask'), vesselMask = maR.vesselMask; end

    detectors = {'MA', 'HE', 'EX'};
    results = {maR, heR, exR};
    colors = {'c', 'm', 'y'};

    for d = 1:3
        det = detectors{d};
        res = results{d};
        if ~isfield(res, 'locations') || isempty(res.locations), continue; end
        locs = res.locations;
        areas = res.areas;
        for j = 1:size(locs, 1)
            c = struct();
            c.detector = det;
            c.id = sprintf('%s-%02d', det, j);
            c.centroid_r = locs(j, 1);
            c.centroid_c = locs(j, 2);
            c.area = areas(j);
            c.dist_to_fov_center = sqrt((c.centroid_r - fovCenterR)^2 + (c.centroid_c - fovCenterC)^2) / fovRadius;
            c.dist_to_disc = sqrt((c.centroid_r - discCenterR)^2 + (c.centroid_c - discCenterC)^2);
            if discRadius > 0, c.dist_to_disc_norm = c.dist_to_disc / discRadius;
            else, c.dist_to_disc_norm = NaN; end
            c.on_vessel = vesselMask(max(1,min(h,round(c.centroid_r))), max(1,min(w,round(c.centroid_c))));
            bb_r1 = max(1, round(c.centroid_r) - 5);
            bb_r2 = min(h, round(c.centroid_r) + 5);
            bb_c1 = max(1, round(c.centroid_c) - 5);
            bb_c2 = min(w, round(c.centroid_c) + 5);
            patch = gray(bb_r1:bb_r2, bb_c1:bb_c2);
            c.local_mean = mean(patch(:));
            c.local_std = std(double(patch(:)));
            c.center_value = double(gray(max(1,min(h,round(c.centroid_r))), max(1,min(w,round(c.centroid_c)))));
            c.on_fov_edge = ~fovMask(max(1,min(h,round(c.centroid_r))), max(1,min(w,round(c.centroid_c))));
            dist_to_border_r = min(c.centroid_r - 1, h - c.centroid_r);
            dist_to_border_c = min(c.centroid_c - 1, w - c.centroid_c);
            c.dist_to_border = min(dist_to_border_r, dist_to_border_c);
            candidates{end+1} = c; %#ok<AGROW>
        end
    end

    fid = fopen(fullfile(caseDir, 'candidate_audit.csv'), 'w');
    fprintf(fid, 'id,detector,centroid_r,centroid_c,area,dist_to_fov_center,dist_to_disc,dist_to_disc_norm,on_vessel,on_fov_edge,dist_to_border,local_mean,local_std,center_value\n');
    for j = 1:numel(candidates)
        c = candidates{j};
        fprintf(fid, '%s,%s,%.1f,%.1f,%.1f,%.3f,%.1f,%.3f,%d,%d,%.1f,%.2f,%.2f,%.1f\n', ...
            c.id, c.detector, c.centroid_r, c.centroid_c, c.area, ...
            c.dist_to_fov_center, c.dist_to_disc, c.dist_to_disc_norm, ...
            c.on_vessel, c.on_fov_edge, c.dist_to_border, ...
            c.local_mean, c.local_std, c.center_value);
    end
    fclose(fid);
    fprintf('  Candidate audit CSV: %s (%d candidates)\n', fullfile(caseDir, 'candidate_audit.csv'), numel(candidates));
end

function camA = analyzeGradCAM(img, camNew, camOld, maR, heR, exR, nvR, caseDir)
    camA = struct();
    camA.newCamInFOV = 0; camA.oldCamInFOV = 0;
    camA.newCamLesionOverlap = 0; camA.newCamMAOverlap = 0;
    camA.newCamHEOverlap = 0; camA.newCamEXOverlap = 0;
    camA.newCamNVOverlap = 0;
    [h, w, ~] = size(img);
    gray = rgb2gray(img);
    fovMask = gray > 10;
    if isfield(maR, 'retinalMask') && any(maR.retinalMask(:))
        fovMask = maR.retinalMask;
    end
    lesionMask = false(h, w);
    if isfield(maR, 'mask'), lesionMask = lesionMask | maR.mask; end
    if isfield(heR, 'mask'), lesionMask = lesionMask | heR.mask; end
    if isfield(exR, 'mask'), lesionMask = lesionMask | exR.mask; end
    if isfield(nvR, 'mask') && nvR.detected, lesionMask = lesionMask | nvR.mask; end

    if ~isempty(camNew)
        camResized = imresize(camNew, [h, w]);
        camNorm = camResized / max(camResized(:) + eps);
        camBin = camNorm > 0.5;
        camA.newCamInFOV = sum(camBin(:) & fovMask(:)) / max(1, sum(fovMask(:)));
        if any(lesionMask(:))
            camA.newCamLesionOverlap = sum(camBin(:) & lesionMask(:)) / max(1, sum(lesionMask(:)));
            if any(maR.mask(:)), camA.newCamMAOverlap = sum(camBin(:) & maR.mask(:)) / max(1, sum(maR.mask(:))); end
            if any(heR.mask(:)), camA.newCamHEOverlap = sum(camBin(:) & heR.mask(:)) / max(1, sum(heR.mask(:))); end
            if any(exR.mask(:)), camA.newCamEXOverlap = sum(camBin(:) & exR.mask(:)) / max(1, sum(exR.mask(:))); end
        end
        camA.newCamBgOutsideFOV = sum(camBin(:) & ~fovMask(:)) / max(1, sum(camBin(:)));
        camA.newCamMax = max(camNew(:));
        camA.newCamMean = mean(camNew(:));
    end

    if ~isempty(camOld)
        camResized = imresize(camOld, [h, w]);
        camNorm = camResized / max(camResized(:) + eps);
        camBin = camNorm > 0.5;
        camA.oldCamInFOV = sum(camBin(:) & fovMask(:)) / max(1, sum(fovMask(:)));
    end

    fprintf('  NEW Grad-CAM: inFOV=%.1f%% bgOutside=%.1f%% max=%.4f\n', ...
        camA.newCamInFOV*100, camA.newCamBgOutsideFOV*100, camA.newCamMax);
    fprintf('  OLD Grad-CAM: inFOV=%.1f%%\n', camA.oldCamInFOV*100);
    fprintf('  CAM-lesion overlap: %.1f%% (MA=%.1f%% HE=%.1f%% EX=%.1f%%)\n', ...
        camA.newCamLesionOverlap*100, camA.newCamMAOverlap*100, camA.newCamHEOverlap*100, camA.newCamEXOverlap*100);
end

function generateForensicPanels(img, maR, heR, exR, nvR, camNew, camOld, ...
        gradeNew, gradeOld, scoresNewD, scoresOldD, quality, camA, caseDir)
    [h, w, ~] = size(img);

    fig = figure('Visible', 'off', 'Position', [50 50 1600 1200]);

    subplot(3,4,1); imshow(img); title('Original');
    subplot(3,4,2); imshow(img); hold on;
    if isfield(maR, 'retinalMask') && any(maR.retinalMask(:))
        visboundaries(maR.retinalMask, 'Color', 'g', 'LineWidth', 1);
    end
    title('FOV mask');

    subplot(3,4,3); imshow(img); hold on;
    if isfield(maR, 'discMask') && any(maR.discMask(:))
        visboundaries(maR.discMask, 'Color', 'y', 'LineWidth', 1);
    end
    title('Disc mask');

    subplot(3,4,4); imshow(img); hold on;
    if isfield(maR, 'vesselMask') && any(maR.vesselMask(:))
        visboundaries(maR.vesselMask, 'Color', 'w', 'LineWidth', 1);
    end
    title('Vessel mask (MA)');

    subplot(3,4,5); imshow(img); hold on;
    if isfield(maR, 'locations') && ~isempty(maR.locations)
        plot(maR.locations(:,2), maR.locations(:,1), 'c+', 'MarkerSize', 12, 'LineWidth', 2);
        for k = 1:size(maR.locations,1)
            text(maR.locations(k,2)+5, maR.locations(k,1)-5, sprintf('MA-%02d', k), 'Color', 'c', 'FontSize', 7);
        end
    end
    title(sprintf('MA=%d', maR.count));

    subplot(3,4,6); imshow(img); hold on;
    if isfield(heR, 'locations') && ~isempty(heR.locations)
        plot(heR.locations(:,2), heR.locations(:,1), 'm+', 'MarkerSize', 12, 'LineWidth', 2);
        for k = 1:size(heR.locations,1)
            text(heR.locations(k,2)+5, heR.locations(k,1)-5, sprintf('HE-%02d', k), 'Color', 'm', 'FontSize', 7);
        end
    end
    title(sprintf('HE=%d', heR.count));

    subplot(3,4,7); imshow(img); hold on;
    if isfield(exR, 'locations') && ~isempty(exR.locations)
        plot(exR.locations(:,2), exR.locations(:,1), 'y+', 'MarkerSize', 12, 'LineWidth', 2);
        for k = 1:size(exR.locations,1)
            text(exR.locations(k,2)+5, exR.locations(k,1)-5, sprintf('EX-%02d', k), 'Color', 'y', 'FontSize', 7);
        end
    end
    title(sprintf('EX=%d', exR.count));

    subplot(3,4,8); imshow(img); hold on;
    nvDetected = nvR.detected;
    if nvDetected && isfield(nvR, 'mask') && any(nvR.mask(:))
        nvRGB = cat(3, double(nvR.mask)*255, zeros(h,w), zeros(h,w));
        hNv = imshow(uint8(nvRGB));
        set(hNv, 'AlphaData', 0.4 * double(nvR.mask));
    end
    title(sprintf('NV=%d', nvDetected));

    subplot(3,4,9); imshow(img); hold on;
    if ~isempty(camNew)
        camResized = imresize(camNew, [h, w]);
        hCam = imagesc(camResized, [0, max(camResized(:)+eps)]);
        set(hCam, 'AlphaData', 0.4); colormap(fig, jet);
    end
    hold off;
    title(sprintf('NEW Grad-CAM (inFOV=%.0f%%)', camA.newCamInFOV*100));

    subplot(3,4,10); imshow(img); hold on;
    if ~isempty(camOld)
        camResized = imresize(camOld, [h, w]);
        hCam = imagesc(camResized, [0, max(camResized(:)+eps)]);
        set(hCam, 'AlphaData', 0.4); colormap(fig, jet);
    end
    hold off;
    title(sprintf('OLD Grad-CAM (inFOV=%.0f%%)', camA.oldCamInFOV*100));

    subplot(3,4,11); axis off;
    txt = {
        sprintf('True: G%d | OLD: G%d (Conf=%.3f)', gradeOld, gradeOld, scoresOldD(gradeOld+1))
        sprintf('NEW: G%d (Conf=%.3f)', gradeNew, max(scoresNewD))
        sprintf('Referable: OLD=%d NEW=%d', gradeOld>=2, gradeNew>=2)
        sprintf('Quality: %s', quality.status)
        sprintf('CAM-lesion overlap: %.1f%%', camA.newCamLesionOverlap*100)
    };
    text(0.05, 0.5, txt, 'FontSize', 9, 'VerticalAlignment', 'middle');
    title('Summary');

    subplot(3,4,12); axis off;
    allScoresOld = sprintf('OLD P: [%.3f %.3f %.3f %.3f %.3f]', scoresOldD(1), scoresOldD(2), scoresOldD(3), scoresOldD(4), scoresOldD(5));
    allScoresNew = sprintf('NEW P: [%.3f %.3f %.3f %.3f %.3f]', scoresNewD(1), scoresNewD(2), scoresNewD(3), scoresNewD(4), scoresNewD(5));
    txt2 = {allScoresOld, '', allScoresNew};
    text(0.05, 0.5, txt2, 'FontSize', 8, 'VerticalAlignment', 'middle');
    title('Class probabilities');

    sgtitle('Phase 20G Forensic Analysis', 'FontWeight', 'bold');
    saveas(fig, fullfile(caseDir, 'forensic_panel.png'));
    close(fig);
end

function writeCaseSummary(summaryRows, outputBase)
    fid = fopen(fullfile(outputBase, 'phase20g_summary.txt'), 'w');
    fprintf(fid, 'Phase 20G: Forensic Investigation of Flagged Cases\n');
    fprintf(fid, '=================================================\n\n');
    fprintf(fid, 'Images analyzed: %d\n\n', numel(summaryRows));

    csvFid = fopen(fullfile(outputBase, 'case_summary.csv'), 'w');
    fprintf(csvFid, 'image_id,reason,true_grade,old_grade,new_grade,old_conf,new_conf,old_ref,new_ref,ma,he,ex,nv,cam_fov_pct,cam_lesion_pct,candidates\n');

    for i = 1:numel(summaryRows)
        R = summaryRows{i};
        fprintf(fid, '%d. %s (%s)\n', i, R.image_id, R.reason);
        fprintf(fid, '   True=G%d OLD=G%d(Conf=%.3f) NEW=G%d(Conf=%.3f)\n', R.true_grade, R.old_grade, R.old_confidence, R.new_grade, R.new_confidence);
        fprintf(fid, '   Referable: OLD=%d NEW=%d\n', R.old_referable, R.new_referable);
        fprintf(fid, '   Lesions: MA=%d HE=%d EX=%d NV=%d\n', R.ma_count, R.he_count, R.ex_count, R.nv_detected);
        fprintf(fid, '   Grad-CAM: FOV=%.1f%% Lesion=%.1f%%\n', R.cam_fov_pct, R.cam_lesion_pct);
        fprintf(fid, '   Candidates: %d\n\n', R.candidate_count);

        fprintf(csvFid, '%s,%s,%d,%d,%d,%.3f,%.3f,%d,%d,%d,%d,%d,%d,%.1f,%.1f,%d\n', ...
            R.image_id, R.reason, R.true_grade, R.old_grade, R.new_grade, ...
            R.old_confidence, R.new_confidence, R.old_referable, R.new_referable, ...
            R.ma_count, R.he_count, R.ex_count, R.nv_detected, ...
            R.cam_fov_pct, R.cam_lesion_pct, R.candidate_count);
    end
    fclose(csvFid);
    fclose(fid);
    fprintf('Summary: %s\n', fullfile(outputBase, 'phase20g_summary.txt'));
    fprintf('Case CSV: %s\n', fullfile(outputBase, 'case_summary.csv'));
end
