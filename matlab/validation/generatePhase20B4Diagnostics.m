function generatePhase20B4Diagnostics(varargin)
% generatePhase20B4Diagnostics  Real-image hemorrhage diagnostics + OLD vs NEW
%
%   generatePhase20B4Diagnostics()
%   generatePhase20B4Diagnostics('NumImages', 5)
%
%   Runs the pre-20B.4 (OLD) and corrected (NEW) hemorrhage detectors on
%   representative VALIDATION images (never test.csv; no tuning here) and
%   saves to results/demo/hemorrhage/:
%     he_<id>_orig.png        - original fundus image
%     he_<id>_old.png         - OLD detector overlay + count
%     he_<id>_new.png         - NEW detector overlay + count
%     he_<id>_panels.png      - A-F: original, raw candidates, vessels,
%                               disc, final mask, annotated centroids
%     he_before_after_<id>.png - OLD vs NEW side-by-side (first image only
%                               is also the 20B.3 reference image 00836aaacf06)
%
%   The OLD detector is loaded from an archived pre-fix copy via temporary
%   path shadowing; the repository file is never overwritten.

    p = inputParser;
    addParameter(p, 'NumImages', 5, @isnumeric);
    addParameter(p, 'OutputDir', fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'demo', 'hemorrhage'), @ischar);
    addParameter(p, 'OldCopy', '', @ischar);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    outputDir = p.Results.OutputDir;
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    verbose = p.Results.Verbose;

    cfgTL = transferLearningConfig();
    paths = collectImagePaths(cfgTL, p.Results.NumImages);
    assert(~isempty(paths), 'No representative images found.');

    % --- Stage the OLD detector copy under its callable name ---
    oldDir = fullfile(tempdir, 'he_old20b4');
    if ~exist(oldDir, 'dir')
        mkdir(oldDir);
    end
    if ~isempty(p.Results.OldCopy) && exist(p.Results.OldCopy, 'file')
        copyfile(p.Results.OldCopy, fullfile(oldDir, 'detectHemorrhages.m'));
    end
    haveOld = exist(fullfile(oldDir, 'detectHemorrhages.m'), 'file') > 0;

    if verbose
        fprintf('=== Phase 20B.4 hemorrhage diagnostics ===\n');
        fprintf('Images: %d | Output: %s | OLD staged: %d\n\n', ...
            numel(paths), outputDir, haveOld);
    end

    for i = 1:numel(paths)
        img = imread(paths{i});
        if size(img, 3) ~= 3
            continue;
        end
        [~, imgId, ~] = fileparts(paths{i});
        safeId = regexprep(imgId, '[^A-Za-z0-9_]', '_');

        % OLD detector (shadowed path)
        oldCount = -1;
        oldMask = [];
        if haveOld
            addpath(oldDir, '-begin');
            try
                eOld = detectHemorrhages(img);
                oldCount = eOld.count;
                oldMask = eOld.mask;
            catch ME
                if verbose
                    fprintf('  OLD failed on %s: %s\n', safeId, ME.message);
                end
            end
            rmpath(oldDir);
        end

        % NEW detector (repository version)
        eNew = detectHemorrhages(img, 'Diagnostic', true);

        if verbose
            fprintf('[%d/%d] %s size=%dx%d OLD count=%d NEW count=%d conf=%.2f\n', ...
                i, numel(paths), safeId, size(img, 2), size(img, 1), ...
                oldCount, eNew.count, eNew.confidence);
        end

        imwrite(img, fullfile(outputDir, sprintf('he_%s_orig.png', safeId)));
        writeOverlay(img, oldMask, oldCount, 'OLD', ...
            fullfile(outputDir, sprintf('he_%s_old.png', safeId)));
        writeOverlay(img, eNew.mask, eNew.count, 'NEW', ...
            fullfile(outputDir, sprintf('he_%s_new.png', safeId)));
        writePanels(img, eNew, ...
            fullfile(outputDir, sprintf('he_%s_panels.png', safeId)));

        if i == 1
            writeBeforeAfter(img, oldMask, oldCount, eNew, safeId, ...
                fullfile(outputDir, sprintf('he_before_after_%s.png', safeId)));
        end
    end

    if verbose
        fprintf('\nDiagnostics complete: %s\n', outputDir);
    end
end

function writeOverlay(img, mask, count, tag, outPath)
    fig = figure('Visible', 'off', 'Position', [50, 50, 520, 480], 'Color', 'white');
    imshow(img);
    hold on;
    if ~isempty(mask) && any(mask(:))
        h = imagesc(double(mask));
        % Alpha must follow the mask: a scalar alpha would tint the whole
        % frame with the colormap floor color (visualization bug caught on
        % review of the first diagnostic batch).
        set(h, 'AlphaData', double(mask) * 0.45);
        colormap(gca, autumn);
    end
    hold off;
    title(sprintf('%s hemorrhage candidates: %d', tag, count), 'FontSize', 11);
    saveas(fig, outPath);
    close(fig);
end

function writePanels(img, e, outPath)
    % A-F diagnostic panels for the NEW detector
    fig = figure('Visible', 'off', 'Position', [50, 50, 1200, 700], 'Color', 'white');
    subplot(2, 3, 1); imshow(img); title('A. Original', 'FontSize', 10);
    subplot(2, 3, 2); imshow(e.rawCandidates); title('B. Raw candidates', 'FontSize', 10);
    subplot(2, 3, 3); imshow(e.vesselMask); title('C. Vessel exclusion', 'FontSize', 10);
    subplot(2, 3, 4); imshow(e.discMask); title('D. Optic-disc exclusion', 'FontSize', 10);
    subplot(2, 3, 5);
    imshow(img); hold on;
    if any(e.mask(:))
        h = imagesc(double(e.mask));
        set(h, 'AlphaData', double(e.mask) * 0.45);
    end
    hold off;
    title(sprintf('E. Final mask (%d)', e.count), 'FontSize', 10);
    subplot(2, 3, 6);
    imshow(img); hold on;
    if ~isempty(e.locations)
        plot(e.locations(:, 1), e.locations(:, 2), 'c+', 'MarkerSize', 10, 'LineWidth', 1.5);
    end
    hold off;
    title(sprintf('F. Centroids (conf %.2f)', e.confidence), 'FontSize', 10);
    saveas(fig, outPath);
    close(fig);
end

function writeBeforeAfter(img, oldMask, oldCount, eNew, safeId, outPath)
    fig = figure('Visible', 'off', 'Position', [50, 50, 1100, 460], 'Color', 'white');
    subplot(1, 3, 1);
    imshow(img);
    title(sprintf('Original (%s)', strrep(safeId, '_', '\_')), 'FontSize', 10);
    subplot(1, 3, 2);
    imshow(img); hold on;
    if ~isempty(oldMask) && any(oldMask(:))
        h = imagesc(double(oldMask));
        set(h, 'AlphaData', double(oldMask) * 0.45);
    end
    hold off;
    title(sprintf('BEFORE (OLD): %d candidates', oldCount), 'FontSize', 11, 'Color', [0.7 0 0]);
    subplot(1, 3, 3);
    imshow(img); hold on;
    if any(eNew.mask(:))
        h = imagesc(double(eNew.mask));
        set(h, 'AlphaData', double(eNew.mask) * 0.45);
    end
    hold off;
    title(sprintf('AFTER (NEW): %d candidates (conf %.2f)', eNew.count, eNew.confidence), ...
        'FontSize', 11, 'Color', [0 0.45 0]);
    saveas(fig, outPath);
    close(fig);
end

function paths = collectImagePaths(cfgTL, nMax)
% collectImagePaths  Validation split, else APTOS train. Never test.csv.
    paths = {};
    % Pin the 20B.3 reference image first for cross-phase comparability.
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
                % Prefer the known 20B.3 reference image if present.
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
    aptosDir = fullfile(cfgTL.projectRoot, 'data', 'raw', 'APTOS2019', 'train_images');
    if exist(aptosDir, 'dir')
        files = dir(fullfile(aptosDir, '*.png'));
        for i = 1:numel(files)
            if numel(paths) >= nMax
                return;
            end
            paths{end+1} = fullfile(files(i).folder, files(i).name);
        end
    end
end
