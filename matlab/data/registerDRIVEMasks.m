function registry = registerDRIVEMasks(cfg, opts)
% registerDRIVEMasks  Inspect DRIVE structure and map images to vessel masks
%
%   registry = registerDRIVEMasks()
%   registry = registerDRIVEMasks(cfg, opts)
%
%   Expected DRIVE layout (per https://drive.grand-challenge.org/):
%     DRIVE/
%       training/
%         images/       *.tif  (e.g., 21_training.tif)
%         1st_manual/   *.gif  (vessel ground truth)
%         2nd_manual/   *.gif  (optional second observer)
%         mask/         *.gif  (FOV masks)
%       test/
%         images/       *.tif
%         1st_manual/   *.gif
%         mask/         *.gif
%     Some distributions are flat or use JPEG.
%
%   Produces:
%     registry - table with columns:
%       image_id, dataset_split (training/test/UNKNOWN), image_path,
%       mask_1st_manual_path, mask_2nd_manual_path, fov_mask_path,
%       has_vessel_annotation, has_fov_mask, status
%
%   Writes:
%     results/drive_vessel_registry.csv/.mat/.json
%     results/drive_vessel_summary.json
%
%   Does NOT build segmentation model; does NOT alter masks.

    if nargin < 1 || isempty(cfg)
        cfg = datasetConfig();
    end
    if nargin < 2 || isempty(opts), opts = struct(); end
    if ~isfield(opts,'verbose'), opts.verbose = true; end

    root = cfg.driveRoot;
    registry = emptyRegistry();

    if ~exist(root,'dir')
        if opts.verbose, fprintf('[DRIVE] DATASET NOT PRESENT — DOWNLOAD REQUIRED: %s\n', root); end
        writeOutputs(cfg, registry, struct('status','NOT PRESENT','root',root));
        return;
    end

    % Discover all image-like files
    allFiles = collectAllFiles(root);
    % Classify
    fundusFiles = {};
    manual1Files = {};
    manual2Files = {};
    fovMaskFiles = {};

    for k=1:numel(allFiles)
        f = allFiles{k};
        low = lower(f);
        [~, base, ext] = fileparts(f);
        isImg = any(strcmpi(ext, cfg.supportedExtensionsDot));
        % Also allow .gif which is common for DRIVE masks (not in our default list? we included but .gif missing)
        % Add .gif handling
        if ~isImg && ~strcmpi(ext,'.gif')
            continue;
        end

        if contains(low, '1st_manual') || contains(low, 'first_manual') || (contains(low,'manual') && ~contains(low,'2nd'))
            % Distinguish: if path contains manual and also mask folder, it's manual; else
            manual1Files{end+1,1}=f; %#ok<AGROW>
        elseif contains(low, '2nd_manual') || contains(low, 'second_manual')
            manual2Files{end+1,1}=f; %#ok<AGROW>
        elseif contains(low, filesep) && contains(low, 'mask') && ~contains(low,'manual')
            % FOV masks live in mask/ folders
            fovMaskFiles{end+1,1}=f; %#ok<AGROW>
        elseif contains(low, 'mask') && ~contains(low,'manual')
            fovMaskFiles{end+1,1}=f; %#ok<AGROW>
        else
            % Potential fundus image: check if under images/ or looks like fundus
            % Heuristic: files under training/images or test/images, or *_training.tif
            if contains(low, 'images') || contains(low,'training') || contains(low,'test') || contains(low,'image')
                % Exclude any manual/mask paths already captured
                if ~contains(low,'manual') && ~contains(low,'mask')
                    fundusFiles{end+1,1}=f; %#ok<AGROW>
                end
            else
                % Fallback: if base matches numeric pattern like 01, 21_training etc, count as fundus candidate
                if ~isempty(regexp(base, '^\d+.*(training|test)?$', 'once'))
                    if ~contains(low,'manual') && ~contains(low,'mask')
                        fundusFiles{end+1,1}=f; %#ok<AGROW>
                    end
                end
            end
        end
    end

    % Deduplicate
    fundusFiles  = unique(fundusFiles);
    manual1Files = unique(manual1Files);
    manual2Files = unique(manual2Files);
    fovMaskFiles = unique(fovMaskFiles);

    % Also handle case where DRIVE is extracted flat with no subfolders: search for all tif and gif
    if isempty(fundusFiles)
        % Try more permissive: any tif/jpg under root is fundus if not manual/mask
        for k=1:numel(allFiles)
            [~,~,ext]=fileparts(allFiles{k});
            low = lower(allFiles{k});
            if any(strcmpi(ext,cfg.supportedExtensionsDot)) || strcmpi(ext,'.gif')
                if ~contains(low,'manual') && ~contains(low,'mask')
                    fundusFiles{end+1,1}=allFiles{k}; %#ok<AGROW>
                end
            end
        end
        fundusFiles = unique(fundusFiles);
    end

    if opts.verbose
        fprintf('[DRIVE] Fundus images discovered: %d\n', numel(fundusFiles));
        fprintf('[DRIVE] 1st manual masks: %d\n', numel(manual1Files));
        fprintf('[DRIVE] 2nd manual masks: %d\n', numel(manual2Files));
        fprintf('[DRIVE] FOV masks: %d\n', numel(fovMaskFiles));
    end

    % Build maps: id -> path for each type keyed by numeric id extracted
    fundusMap = buildIdMap(fundusFiles);
    manual1Map = buildIdMap(manual1Files);
    manual2Map = buildIdMap(manual2Files);
    fovMap    = buildIdMap(fovMaskFiles);

    % Determine image_id and split for each fundus file
    rows = {};
    for k=1:numel(fundusFiles)
        fp = fundusFiles{k};
        [~, base, ~] = fileparts(fp);
        % Numeric id e.g., "21" from "21_training.tif" or "21_test.tif" or "21_manual1.gif" mapping
        nid = extractNumericId(base);
        % Determine training vs test
        low = lower(fp);
        splitVal = 'UNKNOWN';
        if contains(low, 'training') || contains(low, 'train')
            splitVal = 'training';
        elseif contains(low, 'test')
            splitVal = 'test';
        else
            % Infer from manual presence: if we have both train and test manual sets, try to deduce
            % Keep UNKNOWN
        end

        % Lookup masks by nid or by base variations
        m1 = lookupById(manual1Map, nid, base);
        m2 = lookupById(manual2Map, nid, base);
        fov = lookupById(fovMap, nid, base);

        hasVessel = ~isempty(m1) || ~isempty(m2);
        hasFov = ~isempty(fov);
        statusVal = 'OK';
        if ~hasVessel, statusVal = 'missing_vessel_mask'; end

        rows{end+1,1} = {base, splitVal, fp, m1, m2, fov, hasVessel, hasFov, statusVal}; %#ok<AGROW>
    end

    % Also create rows for orphan masks (masks without fundus match) as check
    orphanCount = 0;
    for k=1:numel(manual1Files)
        [~, base, ~] = fileparts(manual1Files{k});
        nid = extractNumericId(base);
        % Check if this mask already mapped to a fundus row
        mapped = false;
        for r=1:numel(rows)
            if strcmp(rows{r}{4}, manual1Files{k}), mapped=true; break; end
        end
        if ~mapped
            % Try to find fundus by nid
            if ~any(cellfun(@(x) contains(x, nid), fundusFiles))
                orphanCount = orphanCount + 1;
                rows{end+1,1} = {base, 'UNKNOWN', '', manual1Files{k}, '', '', true, false, 'orphan_no_fundus_match'}; %#ok<AGROW>
            end
        end
    end

    if isempty(rows)
        registry = emptyRegistry();
    else
        registry = cell2table(vertcat(rows{:}), 'VariableNames', ...
            {'image_id','dataset_split','image_path','mask_1st_manual_path','mask_2nd_manual_path','fov_mask_path','has_vessel_annotation','has_fov_mask','status'});
        registry.image_id = string(registry.image_id);
        registry.dataset_split = string(registry.dataset_split);
        registry.status = string(registry.status);
        registry = sortrows(registry, {'dataset_split','image_id'});
    end

    % Summary
    summary = struct();
    summary.timestamp = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    summary.root = root;
    summary.nFundus = numel(fundusFiles);
    summary.nManual1 = numel(manual1Files);
    summary.nManual2 = numel(manual2Files);
    summary.nFovMasks = numel(fovMaskFiles);
    summary.nRegistryRows = height(registry);
    summary.nWithVessel = sum(registry.has_vessel_annotation);
    summary.nTraining = sum(registry.dataset_split=="training");
    summary.nTest = sum(registry.dataset_split=="test");
    summary.status = 'IMPLEMENTED';
    if summary.nFundus==0, summary.status = 'NOT PRESENT'; end

    if opts.verbose
        fprintf('[DRIVE] Registry rows: %d, with vessel: %d, training: %d, test: %d\n', ...
            summary.nRegistryRows, summary.nWithVessel, summary.nTraining, summary.nTest);
        if orphanCount>0, fprintf('[DRIVE] Orphan masks without fundus: %d\n', orphanCount); end
    end

    writeOutputs(cfg, registry, summary);
end

function T = emptyRegistry()
    T = table(cell(0,1), cell(0,1), cell(0,1), cell(0,1), cell(0,1), cell(0,1), zeros(0,1,'logical'), zeros(0,1,'logical'), cell(0,1), ...
        'VariableNames', {'image_id','dataset_split','image_path','mask_1st_manual_path','mask_2nd_manual_path','fov_mask_path','has_vessel_annotation','has_fov_mask','status'});
end

function out = collectAllFiles(root)
    out = {};
    if ~exist(root,'dir'), return; end
    entries = dir(root);
    for k=1:numel(entries)
        if strcmp(entries(k).name,'.')||strcmp(entries(k).name,'..'), continue; end
        fp = fullfile(entries(k).folder, entries(k).name);
        if entries(k).isdir
            sub = collectAllFiles(fp);
            out = [out; sub]; %#ok<AGROW>
        else
            out{end+1,1}=fp; %#ok<AGROW>
        end
    end
end

function m = buildIdMap(fileList)
    m = containers.Map('KeyType','char','ValueType','char');
    for k=1:numel(fileList)
        [~, base, ~] = fileparts(fileList{k});
        nid = extractNumericId(base);
        % Store base -> path
        try m(base) = fileList{k}; catch, end
        try m(lower(base)) = fileList{k}; catch, end
        if ~isempty(nid)
            try m(nid) = fileList{k}; catch, end
            % Also store nid with training/test suffix stripped
        end
    end
end

function nid = extractNumericId(base)
    tok = regexp(base, '(\d+)', 'tokens', 'once');
    if isempty(tok), nid = ''; else, nid = tok{1}; end
end

function p = lookupById(map, nid, base)
    p = '';
    if ~isempty(nid) && isKey(map, nid)
        p = map(nid);
        return;
    end
    if isKey(map, base)
        p = map(base);
        return;
    end
    if isKey(map, lower(base))
        p = map(lower(base));
        return;
    end
    % Try stripped versions
    s1 = regexprep(base, '_(training|test)$','', 'ignorecase');
    if isKey(map, s1), p=map(s1); return; end
    if isKey(map, lower(s1)), p=map(lower(s1)); return; end
end

function writeOutputs(cfg, registry, summary)
    if ~exist(cfg.resultsRoot,'dir'), mkdir(cfg.resultsRoot); end
    csvPath = fullfile(cfg.resultsRoot, 'drive_vessel_registry.csv');
    matPath = fullfile(cfg.resultsRoot, 'drive_vessel_registry.mat');
    jsonPath= fullfile(cfg.resultsRoot, 'drive_vessel_registry.json');
    summPath= fullfile(cfg.resultsRoot, 'drive_vessel_summary.json');
    try
        writetable(registry, csvPath);
        save(matPath, 'registry','summary','-v7');
        jsonStr = jsonencode(summary, 'PrettyPrint', true);
        fid=fopen(jsonPath,'w'); fwrite(fid, jsonStr,'char'); fclose(fid);
        fid=fopen(summPath,'w'); fwrite(fid, jsonStr,'char'); fclose(fid);
    catch ME
        warning('Failed to write DRIVE registry outputs: %s', ME.message);
    end
end
