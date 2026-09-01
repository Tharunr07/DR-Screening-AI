function stats = persistPhase3TestMasks(varargin)
% persistPhase3TestMasks  Re-run Phase 3 on test set and persist real masks
%
%   stats = persistPhase3TestMasks()
%   stats = persistPhase3TestMasks('verbose', true)
%
%   Reads data/splits/test.csv.
%   Runs Phase 3 analysis on each image.
%   Persists binary lesion masks to results/phase3_masks/<dataset>/
%   Writes persistence_summary.json.

    p = inputParser;
    addParameter(p, 'verbose', true);
    parse(p, varargin{:});
    verbose = p.Results.verbose;

    cfg = phase3Config();
    cfgData = datasetConfig();
    cfgExpl = explainabilityConfig();

    % Mask output directory
    maskRoot = fullfile(cfg.resultsRoot, 'phase3_masks');

    % Load test split
    testPath = fullfile(cfgData.projectRoot, 'data', 'splits', 'test.csv');
    if ~exist(testPath, 'file')
        error('Test split not found: %s', testPath);
    end
    T = readtable(testPath, 'TextType', 'string');

    % Load quality results
    Tq = [];
    if exist(cfg.qualityResultsPath, 'file')
        Tq = readtable(cfg.qualityResultsPath, 'TextType', 'string');
    end

    nTotal = height(T);
    if verbose
        fprintf('[persistPhase3TestMasks] Processing %d test images\n', nTotal);
    end

    % Counters
    nMA = 0; nHE = 0; nEX = 0; nNV = 0;
    nMasksPersisted = 0;
    nSkipped = 0;
    nFailed = 0;

    ticTotal = tic;

    for i = 1:nTotal
        imgPath = char(T.file_path_absolute(i));
        if ~exist(imgPath, 'file')
            alt = fullfile(cfgData.projectRoot, char(T.file_path(i)));
            if exist(alt, 'file'), imgPath = alt; end
        end

        if ~exist(imgPath, 'file')
            nSkipped = nSkipped + 1;
            if verbose
                fprintf('  SKIP [%d/%d] %s/%s — file not found\n', i, nTotal, char(T.dataset(i)), char(T.image_id(i)));
            end
            continue;
        end

        image_id = char(T.image_id(i));
        dataset = char(T.dataset(i));

        % Get quality result
        qr = [];
        if ~isempty(Tq)
            qIdx = find(Tq.image_id == string(image_id) & Tq.dataset == string(dataset), 1);
            if ~isempty(qIdx)
                qr = struct();
                qr.quality_status = char(Tq.quality_status(qIdx));
                qr.overall_quality_score = Tq.overall_quality_score(qIdx);
                qr.enhanced = Tq.enhanced(qIdx);
            end
        end

        % Run Phase 3 analysis
        try
            result = analyzeImage(imgPath, qr, cfg);
        catch ME
            nFailed = nFailed + 1;
            if verbose
                fprintf('  FAIL [%d/%d] %s/%s — %s\n', i, nTotal, dataset, image_id, ME.message);
            end
            continue;
        end

        % Persist masks
        try
            maskDir = fullfile(maskRoot, dataset);
            persistPhase3Masks(result, maskDir, dataset, image_id);
            nMasksPersisted = nMasksPersisted + 1;

            % Count mask types
            if isfield(result, 'detail_ma') && isfield(result.detail_ma, 'candidate_mask') && any(result.detail_ma.candidate_mask(:))
                nMA = nMA + 1;
            end
            if isfield(result, 'detail_he') && isfield(result.detail_he, 'candidate_mask') && any(result.detail_he.candidate_mask(:))
                nHE = nHE + 1;
            end
            if isfield(result, 'detail_ex') && isfield(result.detail_ex, 'exudate_mask') && any(result.detail_ex.exudate_mask(:))
                nEX = nEX + 1;
            end
            if isfield(result, 'nv_candidate') && result.nv_candidate
                nNV = nNV + 1;
            end
        catch ME
            nFailed = nFailed + 1;
            if verbose
                fprintf('  PERSIST_FAIL [%d/%d] %s/%s — %s\n', i, nTotal, dataset, image_id, ME.message);
            end
        end

        if verbose && mod(i, 50) == 0
            elapsed = toc(ticTotal);
            fprintf('[Phase3 Masks] %d/%d (%.1f%%) elapsed %.1fs avg %.3fs/img\n', ...
                i, nTotal, 100*i/nTotal, elapsed, elapsed/i);
        end
    end

    totalTime = toc(ticTotal);

    % Build summary
    stats = struct();
    stats.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    stats.requested = nTotal;
    stats.processed = nMasksPersisted;
    stats.skipped = nSkipped;
    stats.failed = nFailed;
    stats.totalTime = totalTime;
    stats.avgTimePerImage = totalTime / max(1, nMasksPersisted);
    stats.ma_masks_with_lesions = nMA;
    stats.he_masks_with_lesions = nHE;
    stats.ex_masks_with_lesions = nEX;
    stats.nv_detected = nNV;
    stats.maskRoot = maskRoot;

    % Save summary JSON
    try
        summaryDir = cfg.resultsRoot;
        if ~exist(summaryDir, 'dir'), mkdir(summaryDir); end
        jsonStr = jsonencode(stats, 'PrettyPrint', true);
        fid = fopen(fullfile(summaryDir, 'phase3_mask_persistence_summary.json'), 'w');
        fwrite(fid, jsonStr, 'char');
        fclose(fid);
    catch
    end

    if verbose
        fprintf('\n[Phase3 Mask Persistence] DONE\n');
        fprintf('  Requested: %d\n', nTotal);
        fprintf('  Persisted: %d\n', nMasksPersisted);
        fprintf('  Skipped: %d\n', nSkipped);
        fprintf('  Failed: %d\n', nFailed);
        fprintf('  Time: %.1fs (%.3fs/img)\n', totalTime, stats.avgTimePerImage);
        fprintf('  MA with lesions: %d\n', nMA);
        fprintf('  HE with lesions: %d\n', nHE);
        fprintf('  EX with lesions: %d\n', nEX);
        fprintf('  NV detected: %d\n', nNV);
    end
end
