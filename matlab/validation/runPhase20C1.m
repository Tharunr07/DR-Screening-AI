function results = runPhase20C1(varargin)
% runPhase20C1  Full 611-image quantitative validation of corrected pipeline
%
%   results = runPhase20C1()
%   results = runPhase20C1('MaxImages', 100)
%
%   Runs the corrected (NEW) pipeline on ALL labeled validation images.
%   Produces:
%     - Per-image CSV with lesion counts, quality metrics, grade, etc.
%     - Distribution statistics (median, mean, P90, P95, P99, max)
%     - Detection prevalence (% images with lesions)
%     - Quality gate analysis (rejection reasons)
%     - Outlier identification (high-count images)
%     - Forensic panels for outlier images
%
%   DO NOT modify frozen classifier, model weights, training data,
%   test set, or detector thresholds. Evaluation only.

    p = inputParser;
    addParameter(p, 'MaxImages', Inf, @isnumeric);
    addParameter(p, 'StartImage', 1, @isnumeric);
    addParameter(p, 'EndImage', Inf, @isnumeric);
    addParameter(p, 'OutputDir', fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20c1'), @ischar);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    outputDir = p.Results.OutputDir;
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end
    verbose = p.Results.Verbose;
    maxImages = p.Results.MaxImages;

    % Load config and model
    cfgTL = transferLearningConfig();
    modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
    data = load(modelPath, 'trainedNetTL');
    net = data.trainedNetTL;

    % Load val.csv — only labeled images
    valCsv = fullfile(cfgTL.paths.splitDir, 'val.csv');
    T = readtable(valCsv);
    hasGrade = ~isnan(T.dr_grade);
    T = T(hasGrade, :);
    idxEnd = min(height(T), p.Results.EndImage);
    idxStart = max(1, p.Results.StartImage);
    nTotal = min(idxEnd - idxStart + 1, maxImages);
    T = T(idxStart:idxEnd, :);

    if verbose
        fprintf('=== Phase 20C.1: Full quantitative validation ===\n');
        fprintf('Images: %d | Output: %s\n\n', nTotal, outputDir);
    end

    % Process images — parallel arrays, no intermediate structs
    csvPath = fullfile(outputDir, 'phase20c1_per_image.csv');
    nCap = min(nTotal, 700);
    c_ids = cell(nCap,1); c_dss = cell(nCap,1); c_qst = cell(nCap,1); c_csq = cell(nCap,1);
    n_dg = zeros(nCap,1,'double'); n_pg = zeros(nCap,1,'double');
    n_gm = zeros(nCap,1,'double'); n_rg = zeros(nCap,1,'double');
    n_rp = zeros(nCap,1,'double'); n_rm = zeros(nCap,1,'double');
    n_w = zeros(nCap,1,'double'); n_h = zeros(nCap,1,'double');
    n_br = zeros(nCap,1,'double'); n_co = zeros(nCap,1,'double');
    n_sh = zeros(nCap,1,'double'); n_qs = zeros(nCap,1,'double');
    n_mac = zeros(nCap,1,'double'); n_hec = zeros(nCap,1,'double');
    n_exc = zeros(nCap,1,'double'); n_nvd = zeros(nCap,1,'double');
    n_tl = zeros(nCap,1,'double'); n_cf = zeros(nCap,1,'double');
    n_maA = zeros(nCap,1,'double'); n_heA = zeros(nCap,1,'double');
    n_exA = zeros(nCap,1,'double');
    n_maD = zeros(nCap,1,'double'); n_heD = zeros(nCap,1,'double');
    n_exD = zeros(nCap,1,'double');
    nProcessed = 0;

    for i = 1:nTotal
        imgPath = char(T.file_path_absolute{i});
        imgId = char(T.image_id{i});
        drGrade = T.dr_grade(i);
        dataset = char(T.dataset{i});
        imgW = T.width(i);
        imgH = T.height(i);

        if ~exist(imgPath, 'file'), continue; end

        try
            img = imread(imgPath);
            if size(img, 3) ~= 3, continue; end

            quality = assessQuality(img);
            n = preprocessFundus(img, cfgTL.image.size);
            [pred, scores] = classify(net, n);
            gradeNum = double(pred) - 1;
            evidence = extractLesionEvidence(img);
            res = applyClinicalLogic(gradeNum, scores, evidence, quality);

            nProcessed = nProcessed + 1;
            j = nProcessed;
            c_ids{j} = imgId;
            c_dss{j} = dataset;
            c_qst{j} = quality.status;
            c_csq{j} = res.consistency;
            n_dg(j) = drGrade;
            n_pg(j) = gradeNum;
            n_gm(j) = double(gradeNum == drGrade);
            n_rg(j) = double(drGrade >= 2);
            n_rp(j) = double(res.referable);
            n_rm(j) = double(double(res.referable) == double(drGrade >= 2));
            n_w(j) = imgW;
            n_h(j) = imgH;
            n_br(j) = quality.brightness;
            n_co(j) = quality.contrast;
            n_sh(j) = quality.sharpness;
            n_qs(j) = (quality.brightness >= 40 && quality.brightness <= 220) + ...
                (quality.contrast >= 20) + (quality.sharpness >= 100);
            n_mac(j) = evidence.microaneurysms.count;
            n_hec(j) = evidence.hemorrhages.count;
            n_exc(j) = evidence.exudates.count;
            n_nvd(j) = double(evidence.neovascularization.detected);
            n_tl(j) = n_mac(j) + n_hec(j) + n_exc(j) + n_nvd(j);
            n_cf(j) = res.probability;
            n_maA(j) = safeArea(evidence.microaneurysms);
            n_heA(j) = safeArea(evidence.hemorrhages);
            n_exA(j) = safeArea(evidence.exudates);
            n_maD(j) = n_mac(j) * 1e6 / (imgW*imgH);
            n_heD(j) = n_hec(j) * 1e6 / (imgW*imgH);
            n_exD(j) = n_exc(j) * 1e6 / (imgW*imgH);

            if mod(nProcessed, 100) == 0
                fprintf('  [%d/%d] %s G%d MA=%d HE=%d EX=%d\n', nProcessed, nTotal, ...
                    imgId, gradeNum, evidence.microaneurysms.count, ...
                    evidence.hemorrhages.count, evidence.exudates.count);
            end

        catch ME
            if verbose, fprintf('  ERROR %s: %s\n', imgId, ME.message); end
        end
    end

    % Trim to actual count
    j = nProcessed;
    c_ids = c_ids(1:j); c_dss = c_dss(1:j); c_qst = c_qst(1:j); c_csq = c_csq(1:j);
    n_dg = n_dg(1:j); n_pg = n_pg(1:j); n_gm = n_gm(1:j); n_rg = n_rg(1:j);
    n_rp = n_rp(1:j); n_rm = n_rm(1:j); n_w = n_w(1:j); n_h = n_h(1:j);
    n_br = n_br(1:j); n_co = n_co(1:j); n_sh = n_sh(1:j); n_qs = n_qs(1:j);
    n_mac = n_mac(1:j); n_hec = n_hec(1:j); n_exc = n_exc(1:j); n_nvd = n_nvd(1:j);
    n_tl = n_tl(1:j); n_cf = n_cf(1:j);
    n_maA = n_maA(1:j); n_heA = n_heA(1:j); n_exA = n_exA(1:j);
    n_maD = n_maD(1:j); n_heD = n_heD(1:j); n_exD = n_exD(1:j);

    % Write CSV
    Tcsv = table(c_ids, c_dss, n_dg, n_pg, n_gm, n_rg, n_rp, n_rm, n_w, n_h, ...
        n_br, n_co, n_sh, c_qst, n_qs, n_mac, n_hec, n_exc, n_nvd, n_tl, ...
        n_maA, n_heA, n_exA, n_cf, c_csq, n_maD, n_heD, n_exD, ...
        'VariableNames', {'image_id','dataset','dr_grade','pred_grade','grade_match', ...
        'referable_gt','referable_pred','referable_match','width','height', ...
        'brightness','contrast','sharpness','quality_status','quality_score', ...
        'ma_count','he_count','ex_count','nv_detected','total_lesions', ...
        'ma_area','he_area','ex_area','confidence','consistency', ...
        'ma_density','he_density','ex_density'});
    writetable(Tcsv, csvPath);

    nValid = j;
    if verbose
        fprintf('\nProcessed: %d/%d images\n\n', nValid, nTotal);
    end

    % Build rows cell for downstream analysis functions
    rows = cell(nValid, 1);
    for k = 1:nValid
        r = struct();
        r.image_id = c_ids{k}; r.dataset = c_dss{k};
        r.dr_grade = n_dg(k); r.pred_grade = n_pg(k);
        r.grade_match = n_gm(k); r.referable_gt = n_rg(k);
        r.referable_pred = n_rp(k); r.referable_match = n_rm(k);
        r.width = n_w(k); r.height = n_h(k);
        r.brightness = n_br(k); r.contrast = n_co(k); r.sharpness = n_sh(k);
        r.quality_status = c_qst{k}; r.quality_score = n_qs(k);
        r.ma_count = n_mac(k); r.he_count = n_hec(k); r.ex_count = n_exc(k);
        r.nv_detected = n_nvd(k); r.total_lesions = n_tl(k);
        r.ma_area = n_maA(k); r.he_area = n_heA(k); r.ex_area = n_exA(k);
        r.confidence = n_cf(k); r.consistency = c_csq{k};
        r.ma_density = n_maD(k); r.he_density = n_heD(k); r.ex_density = n_exD(k);
        rows{k} = r;
    end

    % === Compute distributions ===
    dist = computeDistributions(rows);

    % === Write distribution summary ===
    writeDistributionSummary(outputDir, dist);

    % === Identify outliers ===
    outliers = identifyOutliers(rows, dist);

    % === Write outlier list ===
    writeOutlierList(outputDir, outliers);

    % === Quality gate analysis ===
    qualAnalysis = analyzeQualityGate(rows);

    % === Write quality analysis ===
    writeQualityAnalysis(outputDir, qualAnalysis);

    % === Generate forensic panels for outliers ===
    generateForensicPanels(outputDir, outliers, net, cfgTL);

    % === Generate summary figures ===
    generateSummaryFigures(outputDir, rows, dist, qualAnalysis);

    % === Return results ===
    results = struct();
    results.nImages = nValid;
    results.distribution = dist;
    results.outliers = outliers;
    results.quality = qualAnalysis;
    results.csvPath = fullfile(outputDir, 'phase20c1_per_image.csv');

    if verbose
        fprintf('=== Complete ===\n');
        fprintf('CSV: %s\n', results.csvPath);
    end
end

%% === HELPER FUNCTIONS ===

function quality = assessQuality(img)
    gray = rgb2gray(img);
    brightness = mean(gray(:));
    contrast = std(double(gray(:)));
    lap = fspecial('laplacian');
    convResult = conv2(double(gray), lap, 'same');
    blurVar = var(convResult(:));
    quality = struct('brightness', brightness, 'contrast', contrast, 'sharpness', blurVar);
    score = (brightness >= 40 && brightness <= 220) + (contrast >= 20) + (blurVar >= 100);
    if score == 3
        quality.status = 'GOOD';
    elseif score == 2
        quality.status = 'BORDERLINE';
    else
        quality.status = 'POOR';
    end
    quality.score = score;
end

function a = safeArea(det)
    if isfield(det, 'totalArea')
        a = det.totalArea;
    elseif isfield(det, 'areas') && ~isempty(det.areas)
        a = sum(det.areas);
    else
        a = 0;
    end
end

function writeRowsCSV(csvPath, rows)
    if isempty(rows), return; end
    n = numel(rows);
    ids = cell(n,1); dss = cell(n,1); qSt = cell(n,1); cs = cell(n,1);
    dg = zeros(n,1); pg = zeros(n,1); gm = zeros(n,1);
    rg = zeros(n,1); rp = zeros(n,1); rm = zeros(n,1);
    w = zeros(n,1); h = zeros(n,1);
    br = zeros(n,1); co = zeros(n,1); sh = zeros(n,1); qs = zeros(n,1);
    mac = zeros(n,1); hec = zeros(n,1); exc = zeros(n,1); nvd = zeros(n,1);
    tl = zeros(n,1); maA = zeros(n,1); heA = zeros(n,1); exA = zeros(n,1);
    cf = zeros(n,1); maD = zeros(n,1); heD = zeros(n,1); exD = zeros(n,1);
    for i = 1:n
        r = rows{i};
        ids{i} = r.image_id; dss{i} = r.dataset; qSt{i} = r.quality_status; cs{i} = r.consistency;
        dg(i) = r.dr_grade; pg(i) = r.pred_grade; gm(i) = r.grade_match;
        rg(i) = r.referable_gt; rp(i) = r.referable_pred; rm(i) = r.referable_match;
        w(i) = r.width; h(i) = r.height;
        br(i) = r.brightness; co(i) = r.contrast; sh(i) = r.sharpness; qs(i) = r.quality_score;
        mac(i) = r.ma_count; hec(i) = r.he_count; exc(i) = r.ex_count; nvd(i) = r.nv_detected;
        tl(i) = r.total_lesions; maA(i) = r.ma_area; heA(i) = r.he_area; exA(i) = r.ex_area;
        cf(i) = r.confidence; maD(i) = r.ma_density; heD(i) = r.he_density; exD(i) = r.ex_density;
    end
    T = table(ids, dss, dg, pg, gm, rg, rp, rm, w, h, br, co, sh, qSt, qs, ...
        mac, hec, exc, nvd, tl, maA, heA, exA, cf, cs, maD, heD, exD, ...
        'VariableNames', {'image_id','dataset','dr_grade','pred_grade','grade_match', ...
        'referable_gt','referable_pred','referable_match','width','height', ...
        'brightness','contrast','sharpness','quality_status','quality_score', ...
        'ma_count','he_count','ex_count','nv_detected','total_lesions', ...
        'ma_area','he_area','ex_area','confidence','consistency', ...
        'ma_density','he_density','ex_density'});
    writetable(T, csvPath);
end

function writePerImageCSV(outputDir, rows)
    n = numel(rows);
    ids = cell(n, 1);
    datasets = cell(n, 1);
    drGrades = zeros(n, 1);
    predGrades = zeros(n, 1);
    gradeMatch = zeros(n, 1);
    refGT = zeros(n, 1);
    refPred = zeros(n, 1);
    refMatch = zeros(n, 1);
    widths = zeros(n, 1);
    heights = zeros(n, 1);
    brightness = zeros(n, 1);
    contrast = zeros(n, 1);
    sharpness = zeros(n, 1);
    qStatus = cell(n, 1);
    qScore = zeros(n, 1);
    maCount = zeros(n, 1);
    heCount = zeros(n, 1);
    exCount = zeros(n, 1);
    nvDet = zeros(n, 1);
    totalLesions = zeros(n, 1);
    maArea = zeros(n, 1);
    heArea = zeros(n, 1);
    exArea = zeros(n, 1);
    confidence = zeros(n, 1);
    consistency = cell(n, 1);
    maDensity = zeros(n, 1);
    heDensity = zeros(n, 1);
    exDensity = zeros(n, 1);

    for i = 1:n
        r = rows{i};
        ids{i} = r.image_id;
        datasets{i} = r.dataset;
        drGrades(i) = r.dr_grade;
        predGrades(i) = r.pred_grade;
        gradeMatch(i) = r.grade_match;
        refGT(i) = r.referable_gt;
        refPred(i) = r.referable_pred;
        refMatch(i) = r.referable_match;
        widths(i) = r.width;
        heights(i) = r.height;
        brightness(i) = r.brightness;
        contrast(i) = r.contrast;
        sharpness(i) = r.sharpness;
        qStatus{i} = r.quality_status;
        qScore(i) = r.quality_score;
        maCount(i) = r.ma_count;
        heCount(i) = r.he_count;
        exCount(i) = r.ex_count;
        nvDet(i) = r.nv_detected;
        totalLesions(i) = r.total_lesions;
        maArea(i) = r.ma_area;
        heArea(i) = r.he_area;
        exArea(i) = r.ex_area;
        confidence(i) = r.confidence;
        consistency{i} = r.consistency;
        maDensity(i) = r.ma_density;
        heDensity(i) = r.he_density;
        exDensity(i) = r.ex_density;
    end

    T = table(ids, datasets, drGrades, predGrades, gradeMatch, refGT, refPred, refMatch, ...
        widths, heights, brightness, contrast, sharpness, qStatus, qScore, ...
        maCount, heCount, exCount, nvDet, totalLesions, maArea, heArea, exArea, ...
        confidence, consistency, maDensity, heDensity, exDensity, ...
        'VariableNames', {'image_id', 'dataset', 'dr_grade', 'pred_grade', 'grade_match', ...
        'referable_gt', 'referable_pred', 'referable_match', ...
        'width', 'height', 'brightness', 'contrast', 'sharpness', 'quality_status', 'quality_score', ...
        'ma_count', 'he_count', 'ex_count', 'nv_detected', 'total_lesions', ...
        'ma_area', 'he_area', 'ex_area', 'confidence', 'consistency', ...
        'ma_density', 'he_density', 'ex_density'});

    writetable(T, fullfile(outputDir, 'phase20c1_per_image.csv'));
end

function dist = computeDistributions(rows)
    n = numel(rows);
    maCounts = zeros(n, 1);
    heCounts = zeros(n, 1);
    exCounts = zeros(n, 1);
    nvDets = zeros(n, 1);
    totals = zeros(n, 1);
    densities = zeros(n, 3); % MA, HE, EX

    for i = 1:n
        r = rows{i};
        maCounts(i) = r.ma_count;
        heCounts(i) = r.he_count;
        exCounts(i) = r.ex_count;
        nvDets(i) = r.nv_detected;
        totals(i) = r.total_lesions;
        densities(i, :) = [r.ma_density, r.he_density, r.ex_density];
    end

    dist = struct();
    dist.ma = computeStats(maCounts);
    dist.he = computeStats(heCounts);
    dist.ex = computeStats(exCounts);
    dist.nv = struct();
    dist.nv.prevalence = mean(nvDets) * 100;
    dist.nv.count = sum(nvDets);
    dist.total = computeStats(totals);

    % Prevalence (% images with >0)
    dist.ma.prevalence = mean(maCounts > 0) * 100;
    dist.he.prevalence = mean(heCounts > 0) * 100;
    dist.ex.prevalence = mean(exCounts > 0) * 100;
    dist.ma.withLesions = sum(maCounts > 0);
    dist.he.withLesions = sum(heCounts > 0);
    dist.ex.withLesions = sum(exCounts > 0);

    % Density stats
    dist.ma.density = computeStats(densities(:, 1));
    dist.he.density = computeStats(densities(:, 2));
    dist.ex.density = computeStats(densities(:, 3));

    dist.nTotal = n;
end

function s = computeStats(vals)
    s = struct();
    s.median = median(vals);
    s.mean = mean(vals);
    s.std = std(vals);
    s.p90 = prctile(vals, 90);
    s.p95 = prctile(vals, 95);
    s.p99 = prctile(vals, 99);
    s.max = max(vals);
    s.min = min(vals);
    s.q1 = prctile(vals, 25);
    s.q3 = prctile(vals, 75);
end

function outliers = identifyOutliers(rows, dist)
    % High-count outliers: > P99 for any detector
    outliers = {};
    for i = 1:numel(rows)
        r = rows{i};
        isOutlier = false;
        reasons = {};

        if r.ma_count > dist.ma.p99
            isOutlier = true;
            reasons{end+1} = sprintf('MA=%d > P99(%d)', r.ma_count, round(dist.ma.p99));
        end
        if r.he_count > dist.he.p99
            isOutlier = true;
            reasons{end+1} = sprintf('HE=%d > P99(%d)', r.he_count, round(dist.he.p99));
        end
        if r.ex_count > dist.ex.p99
            isOutlier = true;
            reasons{end+1} = sprintf('EX=%d > P99(%d)', r.ex_count, round(dist.ex.p99));
        end
        if r.total_lesions > dist.total.p99
            isOutlier = true;
            reasons{end+1} = sprintf('Total=%d > P99(%d)', r.total_lesions, round(dist.total.p99));
        end
        if r.ma_density > 50
            isOutlier = true;
            reasons{end+1} = sprintf('MA_density=%.1f > 50', r.ma_density);
        end

        if isOutlier
            outlier = struct();
            outlier.image_id = r.image_id;
            outlier.dataset = r.dataset;
            outlier.dr_grade = r.dr_grade;
            outlier.ma = r.ma_count;
            outlier.he = r.he_count;
            outlier.ex = r.ex_count;
            outlier.nv = r.nv_detected;
            outlier.total = r.total_lesions;
            outlier.width = r.width;
            outlier.height = r.height;
            outlier.quality = r.quality_status;
            outlier.reasons = strjoin(reasons, '; ');
            outliers{end+1} = outlier;
        end
    end
end

function qa = analyzeQualityGate(rows)
    n = numel(rows);
    qa = struct();
    qa.nTotal = n;
    qa.good = 0;
    qa.borderline = 0;
    qa.poor = 0;
    qa.reasons = struct('brightness_low', 0, 'brightness_high', 0, ...
        'contrast_low', 0, 'sharpness_low', 0);

    % Per-grade quality breakdown
    qa.byGrade = struct();
    for g = 0:4
        qa.byGrade.(sprintf('g%d_total', g)) = 0;
        qa.byGrade.(sprintf('g%d_good', g)) = 0;
        qa.byGrade.(sprintf('g%d_borderline', g)) = 0;
        qa.byGrade.(sprintf('g%d_poor', g)) = 0;
    end

    % Size analysis
    qa.sizeBuckets = struct('small_640', 0, 'medium_1024', 0, 'large_2048', 0, 'huge_4096', 0);
    qa.sizeQuality = struct('small_good', 0, 'small_poor', 0, ...
        'medium_good', 0, 'medium_poor', 0, ...
        'large_good', 0, 'large_poor', 0, ...
        'huge_good', 0, 'huge_poor', 0);

    for i = 1:n
        r = rows{i};

        % Quality status
        switch r.quality_status
            case 'GOOD'
                qa.good = qa.good + 1;
            case 'BORDERLINE'
                qa.borderline = qa.borderline + 1;
            otherwise
                qa.poor = qa.poor + 1;
        end

        % Rejection reasons
        if r.brightness < 40, qa.reasons.brightness_low = qa.reasons.brightness_low + 1; end
        if r.brightness > 220, qa.reasons.brightness_high = qa.reasons.brightness_high + 1; end
        if r.contrast < 20, qa.reasons.contrast_low = qa.reasons.contrast_low + 1; end
        if r.sharpness < 100, qa.reasons.sharpness_low = qa.reasons.sharpness_low + 1; end

        % By grade
        gField = sprintf('g%d_total', r.dr_grade);
        qa.byGrade.(gField) = qa.byGrade.(gField) + 1;
        switch r.quality_status
            case 'GOOD'
                qa.byGrade.(sprintf('g%d_good', r.dr_grade)) = qa.byGrade.(sprintf('g%d_good', r.dr_grade)) + 1;
            case 'BORDERLINE'
                qa.byGrade.(sprintf('g%d_borderline', r.dr_grade)) = qa.byGrade.(sprintf('g%d_borderline', r.dr_grade)) + 1;
            otherwise
                qa.byGrade.(sprintf('g%d_poor', r.dr_grade)) = qa.byGrade.(sprintf('g%d_poor', r.dr_grade)) + 1;
        end

        % Size buckets
        if r.width <= 800
            qa.sizeBuckets.small_640 = qa.sizeBuckets.small_640 + 1;
            if strcmp(r.quality_status, 'GOOD')
                qa.sizeQuality.small_good = qa.sizeQuality.small_good + 1;
            else
                qa.sizeQuality.small_poor = qa.sizeQuality.small_poor + 1;
            end
        elseif r.width <= 1500
            qa.sizeBuckets.medium_1024 = qa.sizeBuckets.medium_1024 + 1;
            if strcmp(r.quality_status, 'GOOD')
                qa.sizeQuality.medium_good = qa.sizeQuality.medium_good + 1;
            else
                qa.sizeQuality.medium_poor = qa.sizeQuality.medium_poor + 1;
            end
        elseif r.width <= 3000
            qa.sizeBuckets.large_2048 = qa.sizeBuckets.large_2048 + 1;
            if strcmp(r.quality_status, 'GOOD')
                qa.sizeQuality.large_good = qa.sizeQuality.large_good + 1;
            else
                qa.sizeQuality.large_poor = qa.sizeQuality.large_poor + 1;
            end
        else
            qa.sizeBuckets.huge_4096 = qa.sizeBuckets.huge_4096 + 1;
            if strcmp(r.quality_status, 'GOOD')
                qa.sizeQuality.huge_good = qa.sizeQuality.huge_good + 1;
            else
                qa.sizeQuality.huge_poor = qa.sizeQuality.huge_poor + 1;
            end
        end
    end

    qa.goodPct = qa.good / n * 100;
    qa.borderlinePct = qa.borderline / n * 100;
    qa.poorPct = qa.poor / n * 100;
end

function writeDistributionSummary(outputDir, dist)
    fid = fopen(fullfile(outputDir, 'distributions.txt'), 'w');
    fprintf(fid, '=== Phase 20C.1 Distribution Summary ===\n');
    fprintf(fid, 'Images: %d\n\n', dist.nTotal);

    detectors = {'ma', 'he', 'ex'};
    labels = {'MICROANEURYSM', 'HEMORRHAGE', 'EXUDATE'};

    for d = 1:3
        det = detectors{d};
        s = dist.(det);
        fprintf(fid, '--- %s ---\n', labels{d});
        fprintf(fid, '  Median:     %d\n', round(s.median));
        fprintf(fid, '  Mean:       %.2f\n', s.mean);
        fprintf(fid, '  Std:        %.2f\n', s.std);
        fprintf(fid, '  P90:        %d\n', round(s.p90));
        fprintf(fid, '  P95:        %d\n', round(s.p95));
        fprintf(fid, '  P99:        %d\n', round(s.p99));
        fprintf(fid, '  Max:        %d\n', s.max);
        fprintf(fid, '  Prevalence: %.1f%% (%d/%d images)\n', s.prevalence, s.withLesions, dist.nTotal);
        fprintf(fid, '  Density (per Mpx): median=%.1f mean=%.1f P95=%.1f max=%.1f\n\n', ...
            s.density.median, s.density.mean, s.density.p95, s.density.max);
    end

    fprintf(fid, '--- NV (NeoVascularization) ---\n');
    fprintf(fid, '  Detected: %d/%d (%.1f%%)\n\n', dist.nv.count, dist.nTotal, dist.nv.prevalence);

    fprintf(fid, '--- TOTAL LESIONS ---\n');
    fprintf(fid, '  Median: %d\n', round(dist.total.median));
    fprintf(fid, '  Mean:   %.2f\n', dist.total.mean);
    fprintf(fid, '  P95:    %d\n', round(dist.total.p95));
    fprintf(fid, '  P99:    %d\n', round(dist.total.p99));
    fprintf(fid, '  Max:    %d\n', dist.total.max);

    fclose(fid);

    % Also print to console
    fprintf('=== Distribution Summary ===\n');
    type(fullfile(outputDir, 'distributions.txt'));
end

function writeOutlierList(outputDir, outliers)
    if isempty(outliers)
        fprintf('No outliers found.\n');
        return;
    end

    fid = fopen(fullfile(outputDir, 'outliers.txt'), 'w');
    fprintf(fid, '=== Phase 20C.1 Outlier List ===\n');
    fprintf(fid, 'Count: %d\n\n', numel(outliers));

    for i = 1:numel(outliers)
        o = outliers{i};
        fprintf(fid, '%2d. %s (%s, G%d, %dx%d, %s)\n', i, o.image_id, o.dataset, ...
            o.dr_grade, o.width, o.height, o.quality);
        fprintf(fid, '    MA=%d HE=%d EX=%d NV=%d Total=%d\n', o.ma, o.he, o.ex, o.nv, o.total);
        fprintf(fid, '    Reasons: %s\n\n', o.reasons);
    end

    fclose(fid);

    fprintf('\n=== Outliers (%d) ===\n', numel(outliers));
    type(fullfile(outputDir, 'outliers.txt'));
end

function writeQualityAnalysis(outputDir, qa)
    fid = fopen(fullfile(outputDir, 'quality_analysis.txt'), 'w');
    fprintf(fid, '=== Phase 20C.1 Quality Gate Analysis ===\n');
    fprintf(fid, 'Total images: %d\n\n', qa.nTotal);

    fprintf(fid, '--- Overall Quality ---\n');
    fprintf(fid, '  GOOD:       %d (%.1f%%)\n', qa.good, qa.goodPct);
    fprintf(fid, '  BORDERLINE: %d (%.1f%%)\n', qa.borderline, qa.borderlinePct);
    fprintf(fid, '  POOR:       %d (%.1f%%)\n', qa.poor, qa.poorPct);

    fprintf(fid, '\n--- Rejection Reasons ---\n');
    fprintf(fid, '  Brightness < 40:  %d (%.1f%%)\n', qa.reasons.brightness_low, qa.reasons.brightness_low/qa.nTotal*100);
    fprintf(fid, '  Brightness > 220: %d (%.1f%%)\n', qa.reasons.brightness_high, qa.reasons.brightness_high/qa.nTotal*100);
    fprintf(fid, '  Contrast < 20:    %d (%.1f%%)\n', qa.reasons.contrast_low, qa.reasons.contrast_low/qa.nTotal*100);
    fprintf(fid, '  Sharpness < 100:  %d (%.1f%%)\n', qa.reasons.sharpness_low, qa.reasons.sharpness_low/qa.nTotal*100);

    fprintf(fid, '\n--- By DR Grade ---\n');
    for g = 0:4
        total = qa.byGrade.(sprintf('g%d_total', g));
        good = qa.byGrade.(sprintf('g%d_good', g));
        borderline = qa.byGrade.(sprintf('g%d_borderline', g));
        poor = qa.byGrade.(sprintf('g%d_poor', g));
        if total > 0
            fprintf(fid, '  G%d: %d total | GOOD %d (%.0f%%) | BORDERLINE %d (%.0f%%) | POOR %d (%.0f%%)\n', ...
                g, total, good, good/total*100, borderline, borderline/total*100, poor, poor/total*100);
        end
    end

    fprintf(fid, '\n--- By Image Size ---\n');
    buckets = {'small_640', 'medium_1024', 'large_2048', 'huge_4096'};
    labels = {'<=800px', '801-1500px', '1501-3000px', '>3000px'};
    prefixes = {'small', 'medium', 'large', 'huge'};
    for b = 1:4
        total = qa.sizeBuckets.(buckets{b});
        goodF = sprintf('%s_good', prefixes{b});
        poorF = sprintf('%s_poor', prefixes{b});
        good = qa.sizeQuality.(goodF);
        poor = qa.sizeQuality.(poorF);
        if total > 0
            fprintf(fid, '  %s: %d total | GOOD %d (%.0f%%) | NOT GOOD %d (%.0f%%)\n', ...
                labels{b}, total, good, good/total*100, poor, poor/total*100);
        end
    end

    fclose(fid);

    fprintf('\n=== Quality Analysis ===\n');
    type(fullfile(outputDir, 'quality_analysis.txt'));
end

function generateForensicPanels(outputDir, outliers, net, cfgTL)
    if isempty(outliers), return; end

    panelDir = fullfile(outputDir, 'forensic_panels');
    if ~exist(panelDir, 'dir'), mkdir(panelDir); end

    % Process up to 10 outliers
    nPanels = min(numel(outliers), 10);

    for p = 1:nPanels
        o = outliers{p};
        % Find image path
        valCsv = fullfile(cfgTL.paths.splitDir, 'val.csv');
        T = readtable(valCsv);
        idx = find(strcmp(char(T.image_id), o.image_id));
        if isempty(idx), continue; end
        imgPath = char(T.file_path_absolute{idx(1)});
        if ~exist(imgPath, 'file'), continue; end

        img = imread(imgPath);
        if size(img, 3) ~= 3, continue; end

        % Run pipeline with diagnostics
        quality = assessQuality(img);
        n = preprocessFundus(img, cfgTL.image.size);
        [pred, scores] = classify(net, n);
        gradeNum = double(pred) - 1;
        evidence = extractLesionEvidence(img);
        res = applyClinicalLogic(gradeNum, scores, evidence, quality);

        % Generate 8-panel forensic figure
        fig = figure('Visible', 'off', 'Position', [20 20 1400 900], 'Color', 'white');

        % Panel 1: Original
        subplot(2, 4, 1); imshow(img);
        title(sprintf('Original (%dx%d)', size(img,2), size(img,1)), 'FontSize', 9);

        % Panel 2: FOV mask
        subplot(2, 4, 2);
        gray = rgb2gray(img);
        bgThresh = gray < 0.2;
        bgOpened = imopen(bgThresh, strel('disk', 3));
        bgClosed = imclose(bgOpened, strel('disk', 15));
        retinaCand = ~bgClosed;
        cc = bwconncomp(retinaCand);
        if cc.NumObjects > 0
            areas = cellfun(@numel, cc.PixelIdxList);
            [~, maxIdx] = max(areas);
            fovMask = false(size(gray));
            fovMask(cc.PixelIdxList{maxIdx}) = true;
        else
            fovMask = true(size(gray));
        end
        imshow(fovMask);
        title(sprintf('FOV mask (%.0f%%)', sum(fovMask(:))/numel(fovMask)*100), 'FontSize', 9);

        % Panel 3: MA candidates
        subplot(2, 4, 3); imshow(img); hold on;
        if evidence.microaneurysms.count > 0 && isfield(evidence.microaneurysms, 'locations')
            plot(evidence.microaneurysms.locations(:,1), evidence.microaneurysms.locations(:,2), ...
                'c+', 'MarkerSize', 10, 'LineWidth', 2);
        end
        hold off;
        title(sprintf('MA: %d candidates', evidence.microaneurysms.count), 'FontSize', 9);

        % Panel 4: HE candidates
        subplot(2, 4, 4); imshow(img); hold on;
        if evidence.hemorrhages.count > 0 && isfield(evidence.hemorrhages, 'locations')
            plot(evidence.hemorrhages.locations(:,1), evidence.hemorrhages.locations(:,2), ...
                'm+', 'MarkerSize', 10, 'LineWidth', 2);
        end
        hold off;
        title(sprintf('HE: %d candidates', evidence.hemorrhages.count), 'FontSize', 9);

        % Panel 5: EX candidates
        subplot(2, 4, 5); imshow(img); hold on;
        if evidence.exudates.count > 0 && isfield(evidence.exudates, 'locations')
            plot(evidence.exudates.locations(:,1), evidence.exudates.locations(:,2), ...
                'y+', 'MarkerSize', 10, 'LineWidth', 2);
        end
        hold off;
        title(sprintf('EX: %d candidates', evidence.exudates.count), 'FontSize', 9);

        % Panel 6: NV
        subplot(2, 4, 6); imshow(img); hold on;
        if evidence.neovascularization.detected && isfield(evidence.neovascularization, 'mask')
            h = imagesc(double(evidence.neovascularization.mask));
            set(h, 'AlphaData', double(evidence.neovascularization.mask) * 0.5);
        end
        hold off;
        title(sprintf('NV: %d', double(evidence.neovascularization.detected)), 'FontSize', 9);

        % Panel 7: All lesions overlay
        subplot(2, 4, 7); imshow(img); hold on;
        if evidence.microaneurysms.count > 0 && isfield(evidence.microaneurysms, 'locations')
            plot(evidence.microaneurysms.locations(:,1), evidence.microaneurysms.locations(:,2), ...
                'c+', 'MarkerSize', 8, 'LineWidth', 1.5);
        end
        if evidence.hemorrhages.count > 0 && isfield(evidence.hemorrhages, 'locations')
            plot(evidence.hemorrhages.locations(:,1), evidence.hemorrhages.locations(:,2), ...
                'm+', 'MarkerSize', 8, 'LineWidth', 1.5);
        end
        if evidence.exudates.count > 0 && isfield(evidence.exudates, 'locations')
            plot(evidence.exudates.locations(:,1), evidence.exudates.locations(:,2), ...
                'y+', 'MarkerSize', 8, 'LineWidth', 1.5);
        end
        hold off;
        refStr = 'NON-REF'; if res.referable, refStr = 'REF'; end
        title(sprintf('All: MA%d HE%d EX%d NV%d | G%d %s', ...
            evidence.microaneurysms.count, evidence.hemorrhages.count, ...
            evidence.exudates.count, double(evidence.neovascularization.detected), ...
            gradeNum, refStr), 'FontSize', 9);

        % Panel 8: Quality info
        subplot(2, 4, 8); axis off;
        info = {...
            sprintf('Image: %s', o.image_id), ...
            sprintf('Size: %dx%d', o.width, o.height), ...
            sprintf('Dataset: %s', o.dataset), ...
            sprintf('DR Grade: G%d', o.dr_grade), ...
            sprintf(''), ...
            sprintf('Quality: %s (score %d/3)', quality.status, quality.score), ...
            sprintf('  Brightness: %.1f', quality.brightness), ...
            sprintf('  Contrast: %.1f', quality.contrast), ...
            sprintf('  Sharpness: %.1f', quality.sharpness), ...
            sprintf(''), ...
            sprintf('Classifier: G%d (P=%.2f)', gradeNum, res.probability), ...
            sprintf('Consistency: %s', res.consistency), ...
            sprintf(''), ...
            sprintf('Outlier reasons:'), ...
            strrep(o.reasons, '; ', newline)};
        text(0.05, 0.95, strjoin(info, newline), 'FontSize', 8, ...
            'VerticalAlignment', 'top', 'FontName', 'FixedWidth');
        title('Forensic Info', 'FontSize', 9);

        sgtitle(sprintf('Phase 20C.1 Forensic Panel: %s', o.image_id), 'FontSize', 11);
        saveas(fig, fullfile(panelDir, sprintf('panel_%s.png', o.image_id)));
        close(fig);
    end

    fprintf('Generated %d forensic panels in %s\n', nPanels, panelDir);
end

function generateSummaryFigures(outputDir, rows, dist, qa)
    n = numel(rows);

    % Extract arrays
    maCounts = zeros(n, 1);
    heCounts = zeros(n, 1);
    exCounts = zeros(n, 1);
    nvDets = zeros(n, 1);
    brightnessArr = zeros(n, 1);
    contrastArr = zeros(n, 1);
    sharpnessArr = zeros(n, 1);
    widths = zeros(n, 1);

    for i = 1:n
        r = rows{i};
        maCounts(i) = r.ma_count;
        heCounts(i) = r.he_count;
        exCounts(i) = r.ex_count;
        nvDets(i) = r.nv_detected;
        brightnessArr(i) = r.brightness;
        contrastArr(i) = r.contrast;
        sharpnessArr(i) = r.sharpness;
        widths(i) = r.width;
    end

    % Figure 1: Count distributions (log-scale histograms)
    fig1 = figure('Visible', 'off', 'Position', [20 20 1200 400], 'Color', 'white');
    subplot(1, 3, 1);
    histogram(maCounts(maCounts > 0), 30, 'FaceColor', [0 0.7 0.7]);
    xlabel('MA count'); ylabel('Frequency');
    title(sprintf('MA > 0: %d/%d (%.0f%%)', sum(maCounts>0), n, dist.ma.prevalence));
    subplot(1, 3, 2);
    histogram(heCounts(heCounts > 0), 30, 'FaceColor', [0.8 0 0.8]);
    xlabel('HE count'); ylabel('Frequency');
    title(sprintf('HE > 0: %d/%d (%.0f%%)', sum(heCounts>0), n, dist.he.prevalence));
    subplot(1, 3, 3);
    histogram(exCounts(exCounts > 0), 30, 'FaceColor', [0.9 0.9 0]);
    xlabel('EX count'); ylabel('Frequency');
    title(sprintf('EX > 0: %d/%d (%.0f%%)', sum(exCounts>0), n, dist.ex.prevalence));
    sgtitle('Lesion count distributions (images with detections only)');
    saveas(fig1, fullfile(outputDir, 'fig1_count_distributions.png'));
    close(fig1);

    % Figure 2: Quality gate breakdown
    fig2 = figure('Visible', 'off', 'Position', [20 20 1000 500], 'Color', 'white');
    subplot(1, 2, 1);
    bar([qa.good, qa.borderline, qa.poor]);
    set(gca, 'XTickLabel', {'GOOD', 'BORDERLINE', 'POOR'});
    ylabel('Number of images');
    title(sprintf('Quality: %d GOOD, %d BORDERLINE, %d POOR', qa.good, qa.borderline, qa.poor));
    subplot(1, 2, 2);
    reasons = [qa.reasons.brightness_low, qa.reasons.brightness_high, ...
               qa.reasons.contrast_low, qa.reasons.sharpness_low];
    bar(reasons);
    set(gca, 'XTickLabel', {'Bright<40', 'Bright>220', 'Contrast<20', 'Sharp<100'});
    ylabel('Number of images');
    title('Rejection reasons (images may fail multiple criteria)');
    sgtitle('Quality gate analysis');
    saveas(fig2, fullfile(outputDir, 'fig2_quality_gate.png'));
    close(fig2);

    % Figure 3: Quality by image size
    fig3 = figure('Visible', 'off', 'Position', [20 20 800 400], 'Color', 'white');
    sizeLabels = {'<=800px', '801-1500', '1501-3000', '>3000px'};
    sizeTotals = [qa.sizeBuckets.small_640, qa.sizeBuckets.medium_1024, ...
                  qa.sizeBuckets.large_2048, qa.sizeBuckets.huge_4096];
    sizeGoods = [qa.sizeQuality.small_good, qa.sizeQuality.medium_good, ...
                 qa.sizeQuality.large_good, qa.sizeQuality.huge_good];
    bar_data = [sizeGoods; sizeTotals - sizeGoods]';
    b = bar(bar_data, 'stacked');
    b(1).FaceColor = [0 0.7 0];
    b(2).FaceColor = [0.9 0.2 0.2];
    set(gca, 'XTickLabel', sizeLabels);
    ylabel('Number of images');
    legend({'GOOD', 'NOT GOOD'}, 'Location', 'best');
    title('Quality by image size');
    saveas(fig3, fullfile(outputDir, 'fig3_quality_by_size.png'));
    close(fig3);

    % Figure 4: Lesion counts vs image size
    fig4 = figure('Visible', 'off', 'Position', [20 20 1000 400], 'Color', 'white');
    subplot(1, 3, 1);
    scatter(widths, maCounts, 10, 'filled', 'MarkerFaceAlpha', 0.3);
    xlabel('Image width (px)'); ylabel('MA count');
    title('MA count vs image size');
    subplot(1, 3, 2);
    scatter(widths, heCounts, 10, 'filled', 'MarkerFaceAlpha', 0.3);
    xlabel('Image width (px)'); ylabel('HE count');
    title('HE count vs image size');
    subplot(1, 3, 3);
    scatter(widths, exCounts, 10, 'filled', 'MarkerFaceAlpha', 0.3);
    xlabel('Image width (px)'); ylabel('EX count');
    title('EX count vs image size');
    sgtitle('Lesion counts vs image resolution');
    saveas(fig4, fullfile(outputDir, 'fig4_counts_vs_size.png'));
    close(fig4);

    % Figure 5: Quality metrics scatter
    fig5 = figure('Visible', 'off', 'Position', [20 20 1000 400], 'Color', 'white');
    subplot(1, 3, 1);
    histogram(brightnessArr, 50);
    hold on; xline(40, 'r--', 'LineWidth', 1.5); xline(220, 'r--', 'LineWidth', 1.5);
    hold off;
    xlabel('Brightness'); ylabel('Frequency');
    title('Brightness distribution');
    subplot(1, 3, 2);
    histogram(contrastArr, 50);
    hold on; xline(20, 'r--', 'LineWidth', 1.5); hold off;
    xlabel('Contrast (std)'); ylabel('Frequency');
    title('Contrast distribution');
    subplot(1, 3, 3);
    histogram(sharpnessArr, 50);
    hold on; xline(100, 'r--', 'LineWidth', 1.5); hold off;
    xlabel('Sharpness (Laplacian var)'); ylabel('Frequency');
    title('Sharpness distribution');
    sgtitle('Quality metric distributions (red lines = thresholds)');
    saveas(fig5, fullfile(outputDir, 'fig5_quality_metrics.png'));
    close(fig5);

    fprintf('Generated 5 summary figures in %s\n', outputDir);
end
