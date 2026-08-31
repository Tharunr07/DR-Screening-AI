function registry = registerIDRiDAnnotations(cfg, opts)
% registerIDRiDAnnotations  Discover and map IDRiD lesion annotations to images
%
%   registry = registerIDRiDAnnotations()
%   registry = registerIDRiDAnnotations(cfg, opts)
%
%   Scans <cfg.idridRoot> for annotation files:
%     - Microaneurysms (MA), Hemorrhages (HE), Hard Exudates (EX), Soft Exudates (SE)
%     - Optic Disc (OD) and other available retinal lesion/anatomical annotations
%
%   Produces:
%     registry - table with columns:
%       image_id, fundus_path, annotation_type, annotation_path, has_annotation, status
%     Also writes:
%       results/idrid_annotation_registry.csv/.mat/.json
%       results/idrid_annotation_summary.json
%
%   Does NOT build lesion detectors; only establishes discovery/mapping.
%   Verifies that annotation files correspond to fundus images where possible.

    if nargin < 1 || isempty(cfg)
        cfg = datasetConfig();
    end
    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts,'verbose'), opts.verbose = true; end

    registry = emptyRegistry();

    root = cfg.idridRoot;
    if ~exist(root,'dir')
        if opts.verbose, fprintf('[IDRiD] DATASET NOT PRESENT — DOWNLOAD REQUIRED: %s\n', root); end
        writeOutputs(cfg, registry, struct('status','NOT PRESENT','root',root));
        return;
    end

    % Discover fundus images
    fundusFiles = findImageFiles(root, cfg.supportedExtensionsDot);
    % Heuristic: fundus images are NOT inside GT/mask/annotation folders
    % But we already use lesion indicators to exclude; for registry we need ground truth of which files are fundus vs annotation
    lesionKeywords = {'_ma','_he','_ex','_se','_od','_micro','_hem','_haem','_exud','_soft','groundtruth','ground_truth','gt','mask','annotation'};
    isFundus = true(numel(fundusFiles),1);
    for k=1:numel(fundusFiles)
        low = lower(fundusFiles{k});
        % If path contains groundtruth/gt/masks and base suggests lesion, mark as not fundus
        if contains(low, 'groundtruth') || contains(low, 'ground_truth') || (contains(low,'mask') && contains(low, 'idrid'))
            % Could be OD mask etc — exclude from fundus list
            % But keep files that are clearly fundus (e.g., 'original image' folder)
            if contains(low,'original') || contains(low,'image') && ~contains(low,'mask')
                % keep
            else
                % Check base suffix
                [~, b, ~] = fileparts(low);
                if contains(b,'_ma')||contains(b,'_he')||contains(b,'_ex')||contains(b,'_se')||contains(b,'_od')
                    isFundus(k)=false;
                end
            end
        end
    end
    fundusFilesFiltered = fundusFiles(isFundus);

    % Discover all potential annotation files (masks/GT)
    allFiles = collectAllFiles(root);
    annotFiles = {};
    for k=1:numel(allFiles)
        low = lower(allFiles{k});
        % Annotation file if extension is image and name contains lesion keyword or lives in GT folder
        [~,~,ext] = fileparts(low);
        isImg = any(strcmpi(ext, cfg.supportedExtensionsDot));
        if ~isImg, continue; end
        % Consider TIF/PNG/JPG etc containing GT indicators
        hit = false;
        for kw = lesionKeywords
            if contains(low, kw{1}), hit = true; break; end
        end
        % Also include .tif in Groundtruth folders
        if contains(low,'groundtruth') || contains(low,'ground_truth')
            hit = true;
        end
        if hit
            % Exclude fundus images themselves (by path heuristic)
            % If we already flagged as fundus, don't double-count as annotation
            if any(strcmp(allFiles{k}, fundusFilesFiltered)), continue; end
            annotFiles{end+1,1} = allFiles{k}; %#ok<AGROW>
        end
    end

    % Also parse any CSV/XLSX that lists lesions
    metaFiles = findFilesByPattern(root, '*.csv');
    metaFiles = [metaFiles; findFilesByPattern(root, '*.xlsx')];

    if opts.verbose
        fprintf('[IDRiD] Fundus images discovered: %d\n', numel(fundusFilesFiltered));
        fprintf('[IDRiD] Annotation/mask files discovered: %d\n', numel(annotFiles));
        if ~isempty(metaFiles)
            fprintf('[IDRiD] Metadata files: %d\n', numel(metaFiles));
            for k=1:numel(metaFiles), fprintf('   %s\n', metaFiles{k}); end
        end
    end

    % Build ID -> fundus path map
    fundusMap = containers.Map('KeyType','char','ValueType','char');
    for k=1:numel(fundusFilesFiltered)
        [~, base, ~] = fileparts(fundusFilesFiltered{k});
        try fundusMap(base) = fundusFilesFiltered{k}; catch, end
        try fundusMap(lower(base)) = fundusFilesFiltered{k}; catch, end
        % Also stripped
        stripped = regexprep(base, '_(left|right)?$','', 'ignorecase');
        if ~strcmp(stripped, base)
            try fundusMap(stripped) = fundusFilesFiltered{k}; catch, end
        end
    end

    % Build registry rows
    rows = {};
    % Annotation type mapping from filename patterns
    typePatterns = {
        'MA', {'_ma','microaneurysm'}
        'HE', {'_he','hemorrhage','haemorrhage'}
        'EX', {'_ex','hard.?exudate'}
        'SE', {'_se','soft.?exudate','cotton'}
        'OD', {'_od','optic.?disc'}
    };

    % Group annotation files by inferred fundus id
    % Infer fundus id by stripping lesion suffixes
    annotGroups = containers.Map('KeyType','char','ValueType','any');
    for k=1:numel(annotFiles)
        [~, base, ~] = fileparts(annotFiles{k});
        inferId = regexprep(base, '_(MA|HE|EX|SE|OD)(_.*)?$','', 'ignorecase');
        inferId = regexprep(inferId, '_(microaneurysms?|hemorrhages?|haemorrhages?|hard.?exudates?|soft.?exudates?|optic.?disc).*$','', 'ignorecase');
        inferId = strtrim(inferId);
        if isempty(inferId), inferId = base; end
        if isKey(annotGroups, inferId)
            lst = annotGroups(inferId);
            lst{end+1} = annotFiles{k};
            annotGroups(inferId) = lst;
        else
            annotGroups(inferId) = {annotFiles{k}};
        end
        % Also store key lower
        lowKey = lower(inferId);
        if ~strcmp(lowKey, inferId) && ~isKey(annotGroups, lowKey)
            annotGroups(lowKey) = {annotFiles{k}};
        end
    end

    % For each fundus image, create registry rows per annotation type (or one row with all)
    for k=1:numel(fundusFilesFiltered)
        [~, base, ~] = fileparts(fundusFilesFiltered{k});
        imgId = base;
        % Find annotation group
        grp = {};
        if isKey(annotGroups, base), grp = annotGroups(base);
        elseif isKey(annotGroups, lower(base)), grp = annotGroups(lower(base));
        else
            % Try stripping numeric suffix
            stripped = regexprep(base, '\.(jpg|png|tif)$','', 'ignorecase');
            if isKey(annotGroups, stripped), grp = annotGroups(stripped); end
        end

        if isempty(grp)
            % Row with no annotation
            rows{end+1,1} = {imgId, fundusFilesFiltered{k}, 'NONE', '', false, 'no_annotation_file'}; %#ok<AGROW>
        else
            % One row per annotation file, with inferred type
            for a=1:numel(grp)
                ap = grp{a};
                aType = inferType(ap, typePatterns);
                rows{end+1,1} = {imgId, fundusFilesFiltered{k}, aType, ap, true, 'OK'}; %#ok<AGROW>
            end
        end
    end

    % Also handle orphan annotations (annotation without fundus match)
    if ~isempty(annotGroups)
        keysList = keys(annotGroups);
        for k=1:numel(keysList)
            key = keysList{k};
            % Check if this key corresponds to a known fundus base (case-insensitive)
            found = false;
            for f=1:numel(fundusFilesFiltered)
                [~, fb, ~] = fileparts(fundusFilesFiltered{f});
                if strcmpi(fb, key) || strcmpi(fb, regexprep(key,'_.*$',''))
                    found = true; break;
                end
            end
            if ~found
                % Orphan annotation — add rows with missing fundus
                lst = annotGroups(key);
                for a=1:numel(lst)
                    ap = lst{a};
                    % Avoid duplicates already added (check rows)
                    already = false;
                    for r=1:numel(rows)
                        if strcmp(rows{r}{4}, ap), already=true; break; end
                    end
                    if already, continue; end
                    aType = inferType(ap, typePatterns);
                    rows{end+1,1} = {key, '', aType, ap, true, 'orphan_no_fundus_match'}; %#ok<AGROW>
                end
            end
        end
    end

    if isempty(rows)
        registry = emptyRegistry();
    else
        registry = cell2table(vertcat(rows{:}), 'VariableNames', {'image_id','fundus_path','annotation_type','annotation_path','has_annotation','status'});
        registry.image_id = string(registry.image_id);
        registry.annotation_type = string(registry.annotation_type);
        registry.status = string(registry.status);
        registry = sortrows(registry, {'image_id','annotation_type'});
    end

    % Summary struct
    summary = struct();
    summary.timestamp = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    summary.root = root;
    summary.nFundus = numel(fundusFilesFiltered);
    summary.nAnnotFiles = numel(annotFiles);
    summary.nRegistryRows = height(registry);
    summary.nWithAnnotation = sum(registry.has_annotation);
    summary.byType = struct();
    if height(registry)>0
        [uT,~,icT] = unique(registry.annotation_type);
        for t=1:numel(uT)
            summary.byType.(matlab.lang.makeValidName(char(uT(t)))) = sum(icT==t);
        end
    end
    summary.status = 'IMPLEMENTED';
    if summary.nFundus==0, summary.status = 'NOT PRESENT'; end

    if opts.verbose
        fprintf('[IDRiD] Registry rows: %d (with annotation: %d)\n', summary.nRegistryRows, summary.nWithAnnotation);
        if isfield(summary,'byType')
            fns = fieldnames(summary.byType);
            for i=1:numel(fns), fprintf('  %s : %d\n', fns{i}, summary.byType.(fns{i})); end
        end
    end

    writeOutputs(cfg, registry, summary);
end

function t = inferType(path, typePatterns)
    low = lower(path);
    t = 'UNKNOWN';
    for i=1:size(typePatterns,1)
        label = typePatterns{i,1};
        pats = typePatterns{i,2};
        for p=1:numel(pats)
            if ~isempty(regexp(low, pats{p}, 'once'))
                t = label;
                return;
            end
        end
    end
end

function T = emptyRegistry()
    T = table(cell(0,1), cell(0,1), cell(0,1), cell(0,1), zeros(0,1,'logical'), cell(0,1), ...
        'VariableNames', {'image_id','fundus_path','annotation_type','annotation_path','has_annotation','status'});
end

function writeOutputs(cfg, registry, summary)
    if ~exist(cfg.resultsRoot,'dir'), mkdir(cfg.resultsRoot); end
    csvPath = fullfile(cfg.resultsRoot, 'idrid_annotation_registry.csv');
    matPath = fullfile(cfg.resultsRoot, 'idrid_annotation_registry.mat');
    jsonPath= fullfile(cfg.resultsRoot, 'idrid_annotation_registry.json');
    summPath= fullfile(cfg.resultsRoot, 'idrid_annotation_summary.json');
    try
        if height(registry)>0
            writetable(registry, csvPath);
        else
            writetable(registry, csvPath);
        end
        save(matPath, 'registry','summary','-v7');
        jsonStr = jsonencode(summary, 'PrettyPrint', true);
        fid=fopen(jsonPath,'w'); fwrite(fid, jsonStr,'char'); fclose(fid);
        fid=fopen(summPath,'w'); fwrite(fid, jsonStr,'char'); fclose(fid);
    catch ME
        warning('Failed to write IDRiD registry outputs: %s', ME.message);
    end
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

function out = findFilesByPattern(root, pat)
    out = {};
    if ~exist(root,'dir'), return; end
    all = collectAllFiles(root);
    % pat like *.csv — check ext
    if startsWith(pat,'*.')
        want = lower(strrep(pat,'*.',''));
        for k=1:numel(all)
            [~,~,e]=fileparts(all{k});
            if strcmpi(strrep(e,'.',''), want)
                out{end+1,1}=all{k}; %#ok<AGROW>
            end
        end
    else
        for k=1:numel(all)
            if contains(lower(all{k}), lower(strrep(pat,'*','')))
                out{end+1,1}=all{k}; %#ok<AGROW>
            end
        end
    end
end
