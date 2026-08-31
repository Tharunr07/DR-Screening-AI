function stats = runPhase3Analysis(varargin)
% runPhase3Analysis  Batch Phase 3 analysis over manifest (RESEARCH PROTOTYPE)
%
%   stats = runPhase3Analysis()
%   stats = runPhase3Analysis('maxImages', 100, 'verbose', true)
%
%   Processes all images through structure + lesion analysis pipeline.
%   Reads manifest.csv and quality_results.csv.
%   Writes structure_results.csv, lesion_results.csv, phase3_metrics.json.

    p = inputParser;
    addParameter(p, 'maxImages', Inf);
    addParameter(p, 'verbose', true);
    addParameter(p, 'datasets', '');  % '' = all, or 'APTOS2019,IDRiD'
    parse(p, varargin{:});
    opts = p.Results;

    cfg = phase3Config();
    cfgData = datasetConfig();

    % Load manifest
    if ~exist(cfg.manifestPath, 'file')
        error('Manifest not found: %s', cfg.manifestPath);
    end
    T = readtable(cfg.manifestPath, 'TextType', 'string');

    % Load quality results
    Tq = [];
    if exist(cfg.qualityResultsPath, 'file')
        Tq = readtable(cfg.qualityResultsPath, 'TextType', 'string');
    end

    % Filter by dataset if specified
    if ~isempty(opts.datasets)
        dsList = strsplit(opts.datasets, ',');
        dsList = strtrim(dsList);
        isMember = false(height(T), 1);
        for k = 1:numel(dsList)
            isMember = isMember | (T.dataset == dsList(k));
        end
        T = T(isMember, :);
    end

    nTotal = height(T);
    if isfinite(opts.maxImages) && opts.maxImages < nTotal
        T = T(1:opts.maxImages, :);
        nTotal = height(T);
    end

    if opts.verbose
        fprintf('[runPhase3Analysis] Processing %d images\n', nTotal);
    end

    % Output variable names (Phase 4-ready contract)
    varNames = {'image_id', 'dataset', 'split', ...
        'quality_status', 'quality_score', 'enhancement_used', ...
        'retinal_area_fraction', 'fov_center_x', 'fov_center_y', 'fov_radius', 'fov_status', ...
        'optic_disc_detected', 'optic_disc_x', 'optic_disc_y', 'optic_disc_radius', 'optic_disc_confidence', ...
        'fovea_detected', 'fovea_x', 'fovea_y', 'fovea_confidence', 'fovea_method', ...
        'vessel_area_fraction', 'vessel_density', 'vessel_segmentation_status', ...
        'ma_candidate_count', 'ma_candidate_area', 'ma_confidence', ...
        'he_candidate_count', 'he_candidate_area', 'he_confidence', ...
        'ex_candidate_count', 'ex_candidate_area', 'ex_candidate_area_fraction', 'ex_confidence', ...
        'nv_candidate', 'nv_score', 'nv_confidence', ...
        'overall_structure_status', 'overall_lesion_status', 'failure_reason'};

    nVars = numel(varNames);
    rows = cell(nTotal, nVars);

    ticTotal = tic;
    nGood = 0; nBorder = 0; nUngrad = 0;
    nStructCompleted = 0; nLesionCompleted = 0;

    for i = 1:nTotal
        imgPath = char(T.file_path_absolute(i));
        if ~exist(imgPath, 'file')
            alt = fullfile(cfgData.projectRoot, char(T.file_path(i)));
            if exist(alt, 'file'), imgPath = alt; end
        end

        image_id = char(T.image_id(i));
        dataset = char(T.dataset(i));
        split = char(T.split(i));

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

        % Run analysis
        try
            result = analyzeImage(imgPath, qr, cfg);
        catch ME
            result = struct();
            result.image_id = string(image_id);
            result.dataset = string(dataset);
            result.split = string(split);
            result.quality_status = 'ANALYSIS_FAILED';
            result.quality_score = NaN;
            result.overall_structure_status = 'FAILED';
            result.overall_lesion_status = 'FAILED';
            result.failure_reason = ME.message;
        end

        % Count quality stats
        if ~isempty(qr)
            if qr.quality_status == "GOOD", nGood = nGood + 1;
            elseif qr.quality_status == "BORDERLINE", nBorder = nBorder + 1;
            else, nUngrad = nUngrad + 1; end
        end

        if isfield(result, 'overall_structure_status') && result.overall_structure_status == "COMPLETED"
            nStructCompleted = nStructCompleted + 1;
        end
        if isfield(result, 'overall_lesion_status') && result.overall_lesion_status == "COMPLETED"
            nLesionCompleted = nLesionCompleted + 1;
        end

        % Fill row
        row = cell(1, nVars);
        row{1} = image_id;
        row{2} = dataset;
        row{3} = split;
        row{4} = safeGet(result, 'quality_status', 'UNKNOWN');
        row{5} = safeGetNum(result, 'quality_score', NaN);
        row{6} = safeGetNum(result, 'enhancement_used', 0);
        row{7} = safeGetNum(result, 'retinal_area_fraction', NaN);
        row{8} = safeGetNum(result, 'fov_center_x', NaN);
        row{9} = safeGetNum(result, 'fov_center_y', NaN);
        row{10} = safeGetNum(result, 'fov_radius', NaN);
        row{11} = safeGet(result, 'fov_status', 'UNKNOWN');
        row{12} = safeGetNum(result, 'optic_disc_detected', 0);
        row{13} = safeGetNum(result, 'optic_disc_x', NaN);
        row{14} = safeGetNum(result, 'optic_disc_y', NaN);
        row{15} = safeGetNum(result, 'optic_disc_radius', NaN);
        row{16} = safeGetNum(result, 'optic_disc_confidence', NaN);
        row{17} = safeGetNum(result, 'fovea_detected', 0);
        row{18} = safeGetNum(result, 'fovea_x', NaN);
        row{19} = safeGetNum(result, 'fovea_y', NaN);
        row{20} = safeGetNum(result, 'fovea_confidence', NaN);
        row{21} = safeGet(result, 'fovea_method', 'UNKNOWN');
        row{22} = safeGetNum(result, 'vessel_area_fraction', NaN);
        row{23} = safeGetNum(result, 'vessel_density', NaN);
        row{24} = safeGet(result, 'vessel_segmentation_status', 'UNKNOWN');
        row{25} = safeGetNum(result, 'ma_candidate_count', 0);
        row{26} = safeGetNum(result, 'ma_candidate_area', NaN);
        row{27} = safeGetNum(result, 'ma_confidence', NaN);
        row{28} = safeGetNum(result, 'he_candidate_count', 0);
        row{29} = safeGetNum(result, 'he_candidate_area', NaN);
        row{30} = safeGetNum(result, 'he_confidence', NaN);
        row{31} = safeGetNum(result, 'ex_candidate_count', 0);
        row{32} = safeGetNum(result, 'ex_candidate_area', NaN);
        row{33} = safeGetNum(result, 'ex_candidate_area_fraction', NaN);
        row{34} = safeGetNum(result, 'ex_confidence', NaN);
        row{35} = safeGetNum(result, 'nv_candidate', 0);
        row{36} = safeGetNum(result, 'nv_score', NaN);
        row{37} = safeGetNum(result, 'nv_confidence', NaN);
        row{38} = safeGet(result, 'overall_structure_status', 'UNKNOWN');
        row{39} = safeGet(result, 'overall_lesion_status', 'UNKNOWN');
        row{40} = safeGet(result, 'failure_reason', '');

        rows(i, :) = row;

        % Progress
        if opts.verbose && mod(i, 500) == 0
            elapsed = toc(ticTotal);
            fprintf('[runPhase3Analysis] %d/%d (%.1f%%) elapsed %.1fs avg %.3fs/img\n', ...
                i, nTotal, 100*i/nTotal, elapsed, elapsed/i);
        end
    end

    totalTime = toc(ticTotal);

    % Create table and save
    Tout = cell2table(rows, 'VariableNames', varNames);
    writetable(Tout, cfg.structureResultsPath);
    save(strrep(cfg.structureResultsPath, '.csv', '.mat'), 'Tout', '-v7');

    % Summary stats
    stats = struct();
    stats.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    stats.version = cfg.version;
    stats.totalImages = nTotal;
    stats.totalTime = totalTime;
    stats.avgTimePerImage = totalTime / max(1, nTotal);
    stats.good = nGood;
    stats.borderline = nBorder;
    stats.ungradable = nUngrad;
    stats.structureCompleted = nStructCompleted;
    stats.lesionCompleted = nLesionCompleted;

    % Per-dataset breakdown
    [uds, ~, ic] = unique(Tout.dataset);
    perDs = struct();
    for k = 1:numel(uds)
        ds = char(uds(k));
        idx = Tout.dataset == string(ds);
        perDs.(matlab.lang.makeValidName(ds)) = struct( ...
            'total', sum(idx), ...
            'structureCompleted', sum(Tout.overall_structure_status(idx) == "COMPLETED"), ...
            'lesionCompleted', sum(Tout.overall_lesion_status(idx) == "COMPLETED"));
    end
    stats.perDataset = perDs;

    % Save metrics JSON
    try
        jsonStr = jsonencode(stats, 'PrettyPrint', true);
        fid = fopen(cfg.metricsPath, 'w');
        fwrite(fid, jsonStr, 'char');
        fclose(fid);
    catch
    end
    save(strrep(cfg.metricsPath, '.json', '.mat'), 'stats', '-v7');

    if opts.verbose
        fprintf('[runPhase3Analysis] DONE %d images in %.1fs (%.3fs/img)\n', nTotal, totalTime, stats.avgTimePerImage);
        fprintf('  Structure completed: %d/%d\n', nStructCompleted, nTotal);
        fprintf('  Lesion completed: %d/%d\n', nLesionCompleted, nTotal);
        fprintf('  Results: %s\n', cfg.structureResultsPath);
    end
end

function val = safeGet(s, field, default)
    if isfield(s, field)
        val = s.(field);
        if isstring(val), val = char(val); end
    else
        val = default;
    end
end

function val = safeGetNum(s, field, default)
    if isfield(s, field)
        val = s.(field);
        if islogical(val), val = double(val); end
    else
        val = default;
    end
end
