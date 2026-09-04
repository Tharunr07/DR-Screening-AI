function results = runPhase20CSystemComparison(varargin)
% runPhase20CSystemComparison  System-level OLD vs NEW pipeline comparison
%
%   results = runPhase20CSystemComparison()
%   results = runPhase20CSystemComparison('NumImages', 6, 'OldDir', PATH)
%
%   Runs the SAME validation images (never test.csv) through:
%     OLD: archived pre-20B detectors + pre-20B.3 gradcamSimple (shadowed
%          path), frozen classifier, shared clinical logic
%     NEW: corrected detectors + corrected gradcamSimple, same classifier
%
%   The classifier, preprocessing, clinical logic, and aggregation are
%   IDENTICAL code in both arms — only the lesion detectors and the
%   Grad-CAM helper differ. Grade/referable MUST therefore match; any
%   mismatch is a harness fault and is flagged, never tuned away.
%
%   Outputs (results/phase20C_system_comparison/):
%     image_XX_<id>/old_pipeline.png, new_pipeline.png, comparison.png
%     system_comparison.csv, before_after_summary.png
%
%   Diagnostic/evaluation use only. NOTHING here tunes thresholds.

    p = inputParser;
    addParameter(p, 'NumImages', 6, @isnumeric);
    addParameter(p, 'OutputDir', fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20C_system_comparison'), @ischar);
    addParameter(p, 'OldDir', '', @ischar);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    outputDir = p.Results.OutputDir;
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    verbose = p.Results.Verbose;
    oldDir = p.Results.OldDir;
    haveOld = ~isempty(oldDir) && exist(fullfile(oldDir, 'detectHemorrhages.m'), 'file');
    assert(haveOld, 'OldDir with archived detectors is required.');

    cfgTL = transferLearningConfig();
    modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
    data = load(modelPath, 'trainedNetTL');
    net = data.trainedNetTL;

    paths = collectImagePaths(cfgTL, p.Results.NumImages);
    assert(~isempty(paths), 'No images found.');

    if verbose
        fprintf('=== Phase 20C system comparison ===\n');
        fprintf('Images: %d | Output: %s\n\n', numel(paths), outputDir);
    end

    rows = {};
    for i = 1:numel(paths)
        img = imread(paths{i});
        if size(img, 3) ~= 3
            continue;
        end
        [~, imgId, ~] = fileparts(paths{i});
        safeId = regexprep(imgId, '[^A-Za-z0-9_]', '_');
        imgDir = fullfile(outputDir, sprintf('image_%02d_%s', i, safeId));
        if ~exist(imgDir, 'dir')
            mkdir(imgDir);
        end

        % Shared front-end: quality + preprocessing + classification
        t0 = tic;
        quality = assessQuality(img);
        n = preprocessFundus(img, cfgTL.image.size);
        [pred, scores] = classify(net, n);
        gradeNum = double(pred) - 1;
        frontTime = toc(t0);

        % OLD arm (shadowed detectors + old Grad-CAM). Dispatch is
        % VERIFIED: a silent shadow failure would compare NEW against
        % itself and invalidate the study (lesson from 20B.4 review).
        tOld = tic;
        addpath(oldDir, '-begin');
        oc = onCleanup(@() rmpath(oldDir));
        shadowSrc = which('detectHemorrhages');
        % Compare on the leaf folder name: which() may return the
        % long-path form while oldDir uses the 8.3 short form.
        assert(~isempty(strfind(lower(shadowSrc), 'phase20c_old')), ...
            'OLD shadow failed: %s does not resolve into the shadow dir', shadowSrc);
        try
            evidenceOld = extractLesionEvidence(img);
            [camOld, ~, ~] = gradcamSimple(net, n, 'TargetClass', double(pred));
        catch ME
            if verbose
                fprintf('  OLD arm failed on %s: %s\n', safeId, ME.message);
            end
            evidenceOld = emptyEvidence(size(img));
            camOld = zeros(224, 224);
        end
        clear oc;  % onCleanup restores path (single removal point)
        oldTime = toc(tOld);

        % NEW arm
        tNew = tic;
        evidenceNew = extractLesionEvidence(img);
        [camNew, ~, ~] = gradcamSimple(net, n, 'TargetClass', double(pred));
        newTime = toc(tNew);

        % Shared clinical logic per arm (evidence differs)
        resOld = applyClinicalLogic(gradeNum, scores, evidenceOld, quality);
        resNew = applyClinicalLogic(gradeNum, scores, evidenceNew, quality);

        % Grade-consistency assertion (same classifier by construction)
        gradeOK = isequal(resOld.gradeNum, resNew.gradeNum) && ...
                  isequal(resOld.referable, resNew.referable);

        % CAM correlation (same size: both 224x224)
        try
            cc = corr2(camOld, camNew);
        catch
            cc = NaN;
        end

        row = {safeId, size(img, 2), size(img, 1), ...
            evidenceOld.microaneurysms.count, evidenceNew.microaneurysms.count, ...
            evidenceOld.hemorrhages.count, evidenceNew.hemorrhages.count, ...
            evidenceOld.exudates.count, evidenceNew.exudates.count, ...
            double(evidenceOld.neovascularization.detected), ...
            double(evidenceNew.neovascularization.detected), ...
            resOld.gradeNum, resNew.gradeNum, ...
            double(resOld.referable), double(resNew.referable), ...
            resOld.probability, resNew.probability, ...
            max(camOld(:)), max(camNew(:)), cc, ...
            frontTime + oldTime, frontTime + newTime, double(gradeOK), ...
            resOld.consistency, resNew.consistency};
        rows{end+1} = row;

        if verbose
            fprintf('[%d/%d] %s G%d ref=%d | MA %d->%d HE %d->%d EX %d->%d NV %d->%d | CAMcorr=%.2f gradeOK=%d\n', ...
                i, numel(paths), safeId, gradeNum, resNew.referable, ...
                row{4}, row{5}, row{6}, row{7}, row{8}, row{9}, row{10}, row{11}, cc, gradeOK);
        end

        writePipelineFig(img, evidenceOld, camOld, resOld, gradeNum, scores, 'OLD', ...
            fullfile(imgDir, 'old_pipeline.png'));
        writePipelineFig(img, evidenceNew, camNew, resNew, gradeNum, scores, 'NEW', ...
            fullfile(imgDir, 'new_pipeline.png'));
        writeComparisonFig(img, evidenceOld, evidenceNew, camOld, camNew, ...
            resOld, resNew, gradeNum, safeId, ...
            fullfile(imgDir, 'comparison.png'));

        % Flush CSV incrementally (survives timeouts)
        writeCSV(outputDir, rows);
    end

    writeSummaryFig(outputDir);
    results = rows;

    if verbose
        fprintf('\nComparison complete: %s\n', outputDir);
    end
end

function quality = assessQuality(img)
    gray = rgb2gray(img);
    brightness = mean(gray(:));
    contrast = std(double(gray(:)));
    lap = fspecial('laplacian');
    blurVar = var(conv2(double(gray), lap, 'same'));
    quality = struct('brightness', brightness, 'contrast', contrast, 'sharpness', blurVar);
    score = (brightness >= 40 && brightness <= 220) + (contrast >= 20) + (blurVar >= 100);
    if score == 3
        quality.status = 'GOOD';
    elseif score == 2
        quality.status = 'BORDERLINE';
    else
        quality.status = 'POOR';
    end
end

function e = emptyEvidence(sz)
    e = struct();
    e.microaneurysms = struct('count', 0, 'mask', false(sz(1), sz(2)));
    e.hemorrhages = struct('count', 0, 'mask', false(sz(1), sz(2)));
    e.exudates = struct('count', 0, 'mask', false(sz(1), sz(2)));
    e.neovascularization = struct('detected', false, 'mask', false(sz(1), sz(2)));
    e.severity = 'none';
end

function writePipelineFig(img, ev, cam, res, gradeNum, scores, tag, outPath)
    fig = figure('Visible', 'off', 'Position', [50, 50, 1250, 640], 'Color', 'white');
    subplot(2, 3, 1); imshow(img); title(sprintf('%s: original (G%d)', tag, gradeNum), 'FontSize', 10);
    drawLesionPanel(img, ev.microaneurysms, 2, 3, 2, 'MA');
    drawLesionPanel(img, ev.hemorrhages, 2, 3, 3, 'HE');
    drawLesionPanel(img, ev.exudates, 2, 3, 4, 'EX');
    subplot(2, 3, 5);
    imshow(img); hold on;
    if isfield(ev.neovascularization, 'mask') && any(ev.neovascularization.mask(:))
        h = imagesc(double(ev.neovascularization.mask));
        set(h, 'AlphaData', double(ev.neovascularization.mask) * 0.5);
    end
    hold off;
    title(sprintf('NV: %d', double(ev.neovascularization.detected)), 'FontSize', 10);
    subplot(2, 3, 6);
    imshow(img); hold on;
    camD = imresize(cam, [size(img, 1), size(img, 2)]);
    h = imagesc(camD, [0, 1]);
    set(h, 'AlphaData', 0.4);
    hold off;
    colormap(gca, jet);
    refStr = 'NON-REF';
    if res.referable
        refStr = 'REFERABLE';
    end
    title(sprintf('CAM (G%d) %s P=%.2f %s', gradeNum, refStr, res.probability, res.consistency), 'FontSize', 9);
    saveas(fig, outPath);
    close(fig);
end

function drawLesionPanel(img, det, r, c, k, name)
    subplot(r, c, k);
    imshow(img);
    hold on;
    count = 0;
    if isfield(det, 'mask') && any(det.mask(:))
        if isfield(det, 'locations') && ~isempty(det.locations)
            plot(det.locations(:, 1), det.locations(:, 2), 'c+', 'MarkerSize', 8, 'LineWidth', 1.5);
            count = size(det.locations, 1);
        else
            h = imagesc(double(det.mask));
            set(h, 'AlphaData', double(det.mask) * 0.5);
            count = det.count;
        end
    elseif isfield(det, 'count')
        count = det.count;
    end
    hold off;
    title(sprintf('%s: %d', name, count), 'FontSize', 10);
end

function writeComparisonFig(img, evO, evN, camO, camN, resO, resN, gradeNum, safeId, outPath)
    fig = figure('Visible', 'off', 'Position', [50, 50, 1150, 560], 'Color', 'white');
    subplot(1, 2, 1);
    imshow(img); hold on;
    overlayAll(evO, 'y');
    hold off;
    title(sprintf('OLD: MA%d HE%d EX%d NV%d | %s', evO.microaneurysms.count, ...
        evO.hemorrhages.count, evO.exudates.count, ...
        double(evO.neovascularization.detected), resO.status), 'FontSize', 10, 'Color', [0.7 0 0]);
    subplot(1, 2, 2);
    imshow(img); hold on;
    overlayAll(evN, 'c');
    hold off;
    title(sprintf('NEW: MA%d HE%d EX%d NV%d | %s', evN.microaneurysms.count, ...
        evN.hemorrhages.count, evN.exudates.count, ...
        double(evN.neovascularization.detected), resN.status), 'FontSize', 10, 'Color', [0 0.45 0]);
    annotation(fig, 'textbox', [0.02, 0.01, 0.96, 0.07], ...
        'String', sprintf('%s — Classifier G%d | Clinical %s, referable=%d (both arms, frozen classifier). CAM corr(OLD,NEW)=%.2f. Lesion counts are CANDIDATES, not clinical truth.', ...
        strrep(safeId, '_', '\_'), gradeNum, resN.status, resN.referable, corr2(camO, camN)), ...
        'FontSize', 9, 'HorizontalAlignment', 'center', 'EdgeColor', 'none');
    saveas(fig, outPath);
    close(fig);
end

function overlayAll(ev, color)
    flds = {'microaneurysms', 'hemorrhages', 'exudates'};
    for k = 1:numel(flds)
        d = ev.(flds{k});
        if isfield(d, 'locations') && ~isempty(d.locations)
            plot(d.locations(:, 1), d.locations(:, 2), [color '+'], 'MarkerSize', 9, 'LineWidth', 1.5);
        end
    end
    if isfield(ev.neovascularization, 'mask') && any(ev.neovascularization.mask(:))
        h = imagesc(double(ev.neovascularization.mask));
        set(h, 'AlphaData', double(ev.neovascularization.mask) * 0.5);
    end
end

function writeCSV(outputDir, rows)
    header = {'Image', 'W', 'H', 'Old_MA', 'New_MA', 'Old_HE', 'New_HE', ...
        'Old_EX', 'New_EX', 'Old_NV', 'New_NV', 'Old_Grade', 'New_Grade', ...
        'Old_Referable', 'New_Referable', 'Old_Confidence', 'New_Confidence', ...
        'Old_CAMmax', 'New_CAMmax', 'CAMcorr', 'Old_Time_s', 'New_Time_s', ...
        'GradeOK', 'Old_Consistency', 'New_Consistency'};
    T = cell2table(vertcat(rows{:}), 'VariableNames', header);
    writetable(T, fullfile(outputDir, 'system_comparison.csv'));
end

function writeSummaryFig(outputDir)
    T = readtable(fullfile(outputDir, 'system_comparison.csv'));
    n = height(T);
    fig = figure('Visible', 'off', 'Position', [50, 50, 1100, 420], 'Color', 'white');
    subplot(1, 2, 1);
    cats = {'MA', 'HE', 'EX', 'NV'};
    oldV = [sum(T.Old_MA), sum(T.Old_HE), sum(T.Old_EX), sum(T.Old_NV)];
    newV = [sum(T.New_MA), sum(T.New_HE), sum(T.New_EX), sum(T.New_NV)];
    bar([oldV; newV]');
    set(gca, 'XTickLabel', cats);
    ylabel('Total candidates (all images)');
    legend({'OLD', 'NEW'}, 'Location', 'best');
    title('Lesion candidate totals: OLD vs NEW', 'FontSize', 11);
    subplot(1, 2, 2);
    axis off;
    lines = {};
    lines{end+1} = sprintf('Images: %d (validation split, never test.csv)', n);
    lines{end+1} = sprintf('Grade agreement: %d/%d', sum(T.GradeOK), n);
    lines{end+1} = sprintf('Mean CAM correlation: %.2f', mean(T.CAMcorr));
    lines{end+1} = sprintf('Mean OLD time: %.1fs | NEW time: %.1fs', ...
        mean(T.Old_Time_s), mean(T.New_Time_s));
    lines{end+1} = '';
    lines{end+1} = 'Counts are CANDIDATES, not clinical truth.';
    lines{end+1} = 'See PHASE20C_SYSTEM_VALIDATION.md for A-D verdicts.';
    text(0.05, 0.9, strjoin(lines, newline), 'FontSize', 11, 'VerticalAlignment', 'top', ...
        'FontName', 'FixedWidth');
    title('Summary', 'FontSize', 11);
    saveas(fig, fullfile(outputDir, 'before_after_summary.png'));
    close(fig);
end

function paths = collectImagePaths(cfgTL, nMax)
    paths = {};
    valCsv = fullfile(cfgTL.paths.splitDir, 'val.csv');
    if exist(valCsv, 'file')
        try
            T = readtable(valCsv);
            col = '';
            for k = 1:numel(T.Properties.VariableNames)
                nm = lower(T.Properties.VariableNames{k});
                if ~isempty(strfind(nm, 'path')) || ~isempty(strfind(nm, 'file'))
                    col = T.Properties.VariableNames{k};
                    break;
                end
            end
            if ~isempty(col)
                order = 1:height(T);
                for i = 1:height(T)
                    if ~isempty(strfind(char(T.(col){i}), '00836aaacf06'))
                        order = [i, setdiff(order, i)];
                        break;
                    end
                end
                for i = order
                    cand = char(T.(col){i});
                    if ~exist(cand, 'file')
                        cand = fullfile(cfgTL.projectRoot, cand);
                    end
                    if exist(cand, 'file')
                        paths{end+1} = cand;
                        if numel(paths) >= nMax
                            return;
                        end
                    end
                end
            end
        catch
        end
    end
end
