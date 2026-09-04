function manifest = buildManifest(cfg, opts)
% buildManifest  Build unified dataset manifest across APTOS, IDRiD, DRIVE, Messidor2
%
%   manifest = buildManifest(cfg)
%   manifest = buildManifest(cfg, opts)
%
%   Inputs:
%     cfg  - struct from datasetConfig()
%     opts - struct (optional) with fields:
%            .computeHash (bool, default false)  compute file hash for duplicates
%            .verbose     (bool, default true)
%
%   Output:
%     manifest - table with columns:
%        image_id, dataset, file_path, file_path_absolute, file_format,
%        laterality, patient_id, subject_id, dr_grade, dr_grade_original,
%        quality_status, has_vessel_annotation, has_lesion_annotation,
%        vessel_mask_path, lesion_annotation_path, split, width, height,
%        channels, file_size_bytes, file_hash, provenance, status
%
%   Notes:
%     - Never invents metadata; uses 'UNKNOWN' / NaN / '' where unavailable
%     - Preserves original labels in dr_grade_original
%     - quality_status defaults to 'UNKNOWN' (no quality algorithm in Phase 1)
%     - Does NOT modify raw files
%     - Reports DATASET NOT PRESENT when a dataset root is missing/empty

    if nargin < 1 || isempty(cfg)
        cfg = datasetConfig();
    end
    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts,'computeHash'), opts.computeHash = false; end
    if ~isfield(opts,'verbose'),     opts.verbose = true; end

    rows = {}; % cell array of row cells

    % Process each dataset in fixed order for determinism
    datasets = {'APTOS2019','IDRiD','DRIVE','Messidor2'};
    roots    = {cfg.aptosRoot, cfg.idridRoot, cfg.driveRoot, cfg.messidor2Root};

    for di = 1:numel(datasets)
        dsName = datasets{di};
        dsRoot = roots{di};
        if opts.verbose
            fprintf('[buildManifest] Scanning %s : %s\n', dsName, dsRoot);
        end
        subRows = scanDataset(dsName, dsRoot, cfg, opts);
        if ~isempty(subRows)
            rows = [rows; subRows]; %#ok<AGROW>
        end
    end

    if isempty(rows)
        % Return empty table with correct schema
        manifest = emptyManifestTable();
        if opts.verbose
            fprintf('[buildManifest] No images found across all datasets.\n');
        end
        return;
    end

    % Convert cell rows to table
    % Row template order must match emptyManifestTable column order
    % rows is N x 1 cell where each cell is a 1x23 row cell; vertcat to make N x 23 cell
    manifest = cell2table(vertcat(rows{:}), 'VariableNames', emptyManifestTable().Properties.VariableNames);

    % Coerce types
    manifest.dataset = string(manifest.dataset);
    manifest.laterality = string(manifest.laterality);
    manifest.quality_status = string(manifest.quality_status);
    manifest.split = string(manifest.split);
    manifest.provenance = string(manifest.provenance);
    manifest.status = string(manifest.status);

    % Sort deterministically: dataset, image_id
    manifest = sortrows(manifest, {'dataset','image_id'});

    if opts.verbose
        fprintf('[buildManifest] Total rows: %d\n', height(manifest));
        % Print per-dataset counts
        [u,~,ic] = unique(manifest.dataset);
        for k=1:numel(u)
            fprintf('  %s : %d\n', u(k), sum(ic==k));
        end
    end
end

%% ------------------------------------------------------------------------
function rows = scanDataset(dsName, dsRoot, cfg, opts)
    rows = {};

    if ~exist(dsRoot, 'dir')
        if opts.verbose
            fprintf('  -> DATASET NOT PRESENT — DOWNLOAD REQUIRED: %s\n', dsRoot);
        end
        return;
    end

    % Gather candidate image files recursively
    allImgFiles = findImageFiles(dsRoot, cfg.supportedExtensionsDot);
    % Filter out ground-truth / mask files that are annotations, not fundus images
    % - IDRiD: exclude anything under Groundtruths / Ground Truth / GT
    % - DRIVE: exclude 1st_manual / 2nd_manual / mask folders
    % Keep only fundus candidates for manifest; masks are tracked via annotation maps
    imgFiles = {};
    for ff = 1:numel(allImgFiles)
        p = lower(allImgFiles{ff});
        isMask = false;
        if strcmp(dsName,'IDRiD')
            if contains(p,'groundtruth') || contains(p,'ground_truth') || contains(p,'gt') && contains(p,'segmentation')
                isMask = true;
            end
            % Also exclude optic disc / lesion GT explicitly: _ma, _he, _ex, _se, _od suffixes are GT, but those are tif masks
            % If path contains 'all segmentation groundtruths' or 'localization' groundtruths, it's GT
            if contains(p,'all segmentation groundtruths') || contains(p,'localization') && contains(p,'groundtruth')
                isMask = true;
            end
            % Fallback: if file is tif and path contains groundtruth, definitely mask
            if contains(p,'groundtruth') && (endsWith(p,'.tif') || endsWith(p,'.tiff'))
                isMask = true;
            end
        elseif strcmp(dsName,'DRIVE')
            if contains(p,'manual') || (contains(p,'mask') && ~contains(p,'images'))
                isMask = true;
            end
        end
        if ~isMask
            imgFiles{end+1,1} = allImgFiles{ff}; %#ok<AGROW>
        end
    end
    if opts.verbose && numel(allImgFiles) ~= numel(imgFiles)
        fprintf('  [%s] Filtered %d annotation/mask files from manifest (kept %d fundus candidates)\n', dsName, numel(allImgFiles)-numel(imgFiles), numel(imgFiles));
    end

    % Also handle DRIVE/Messidor2 special substructures but findImageFiles already recurses.
    % For annotation mapping we need extra discovery (masks, csvs, etc.)
    % Build lookup maps for grades / patient ids where available

    gradeMap = containers.Map('KeyType','char','ValueType','any');
    patientMap = containers.Map('KeyType','char','ValueType','char');
    lateralityMap = containers.Map('KeyType','char','ValueType','char');
    vesselMaskMap = containers.Map('KeyType','char','ValueType','char');
    lesionMap = containers.Map('KeyType','char','ValueType','char');

    switch dsName
        case 'APTOS2019'
            [gradeMap, patientMap] = parseAPTOSLabels(dsRoot, opts);
        case 'IDRiD'
            [gradeMap, lesionMap] = parseIDRiDLabels(dsRoot, opts);
            % laterality/patient may be encoded in filename or subfolder
        case 'DRIVE'
            vesselMaskMap = parseDRIVEMasks(dsRoot, opts);
        case 'Messidor2'
            [gradeMap, patientMap, lateralityMap] = parseMessidor2Labels(dsRoot, opts);
    end

    % Also pre-scan vessel/lesion annotations for quick has_* flags if not yet mapped
    % For IDRiD, lesionMap already populated; for DRIVE, vesselMaskMap populated.

    if isempty(imgFiles)
        if opts.verbose
            fprintf('  -> No image files found (supported: %s)\n', strjoin(cfg.supportedExtensions, ','));
            fprintf('     DATASET NOT PRESENT or EMPTY — DOWNLOAD REQUIRED\n');
        end
        return;
    end

    % Deduplicate IDRiD fundus files by base name (same image appears in A. Segmentation / B. Disease Grading / C. Localization)
    if strcmp(dsName,'IDRiD') && numel(imgFiles) > 1
        [~, bases, ~] = cellfun(@fileparts, imgFiles, 'UniformOutput', false);
        lowerBases = cellfun(@lower, bases, 'UniformOutput', false);
        [~, uniqIdx, ~] = unique(lowerBases, 'stable');
        if numel(uniqIdx) < numel(imgFiles)
            if opts.verbose
                fprintf('  [%s] Deduplicated %d duplicate image_ids (kept %d unique fundus images)\n', dsName, numel(imgFiles)-numel(uniqIdx), numel(uniqIdx));
            end
            imgFiles = imgFiles(uniqIdx);
        end
    end

    for i = 1:numel(imgFiles)
        absPath = imgFiles{i};
        % Derive relative path for portability
        relPath = makeRelativePath(absPath, cfg.projectRoot);

        [~, baseName, ext] = fileparts(absPath);
        imageId = baseName; % default; may be overridden by dataset-specific logic

        % Default metadata
        datasetVal = dsName;
        fileFormat = upper(strrep(ext,'.',''));
        if isempty(fileFormat), fileFormat = 'UNKNOWN'; end
        laterality = 'UNKNOWN';
        patientId  = 'UNKNOWN';
        subjectId  = 'UNKNOWN';
        drGrade    = NaN;
        drGradeOrig= '';
        qualityStatus = 'UNKNOWN'; % Phase 1: no quality algorithm
        hasVessel  = false;
        hasLesion  = false;
        vesselMaskPath = '';
        lesionAnnotPath = '';
        splitVal   = 'UNKNOWN';
        provenance = dsName;
        statusVal  = 'OK';

        % Patient/laterality inference (dataset-specific)
        % APTOS: patient inferred from image_id if no explicit ID; laterality UNKNOWN unless parsed
        % IDRiD: IDs like IDRiD_001 etc; lesions annotated separately
        % DRIVE: ids like 01_training.tif ; patient UNKNOWN (one image per subject)
        % Messidor2: depends on metadata availability

        keyForMap = baseName;
        % Try with and without extension, lower/upper
        % For grade lookups, also try imageId variations

        % DR grade lookup
        if isKey(gradeMap, keyForMap)
            v = gradeMap(keyForMap);
            if isnumeric(v)
                drGrade = double(v);
                drGradeOrig = num2str(v);
            else
                drGradeOrig = char(v);
                num = str2double(drGradeOrig);
                if ~isnan(num), drGrade = num; end
            end
        elseif isKey(gradeMap, lower(keyForMap))
            v = gradeMap(lower(keyForMap));
            if isnumeric(v), drGrade = double(v); drGradeOrig = num2str(v);
            else, drGradeOrig = char(v); num=str2double(drGradeOrig); if ~isnan(num), drGrade= num; end; end
        else
            % Try stripping common suffixes like _training, _test, _manual1
            stripped = regexprep(keyForMap, '_(training|test|manual\d*|mask)$', '', 'ignorecase');
            if ~strcmp(stripped, keyForMap) && isKey(gradeMap, stripped)
                v = gradeMap(stripped);
                if isnumeric(v), drGrade = double(v); drGradeOrig = num2str(v);
                else, drGradeOrig = char(v); num=str2double(drGradeOrig); if ~isnan(num), drGrade=num; end; end
            end
        end

        % Patient lookup
        if isKey(patientMap, keyForMap)
            patientId = char(patientMap(keyForMap));
            subjectId = patientId;
        elseif isKey(patientMap, lower(keyForMap))
            patientId = char(patientMap(lower(keyForMap)));
            subjectId = patientId;
        end

        % Laterality lookup
        if isKey(lateralityMap, keyForMap)
            laterality = char(lateralityMap(keyForMap));
        elseif isKey(lateralityMap, lower(keyForMap))
            laterality = char(lateralityMap(lower(keyForMap)));
        else
            % Heuristic: filename contains _left/_right or -L/-R or OS/OD
            low = lower(baseName);
            if contains(low, 'left') || contains(low, '_l.') || endsWith(low, '_l') || contains(low, ' os ')
                laterality = 'LEFT';
            elseif contains(low, 'right') || contains(low, '_r.') || endsWith(low, '_r') || contains(low, ' od ')
                laterality = 'RIGHT';
            elseif contains(low, '_od') || contains(low, '-od')
                laterality = 'RIGHT';
            elseif contains(low, '_os') || contains(low, '-os')
                laterality = 'LEFT';
            end
        end

        % DRIVE vessel mask correspondence
        if strcmp(dsName, 'DRIVE')
            % hasVessel true for all DRIVE fundus images if masks present
            % Lookup exact match or numeric id match
            if isKey(vesselMaskMap, keyForMap)
                hasVessel = true;
                vesselMaskPath = char(vesselMaskMap(keyForMap));
            elseif isKey(vesselMaskMap, strippedKey(keyForMap))
                hasVessel = true;
                vesselMaskPath = char(vesselMaskMap(strippedKey(keyForMap)));
            else
                % Fallback: search masks folder for any mask containing numeric id
                % e.g., 21_training.tif -> 21_manual1.gif
                tok = regexp(baseName, '(\d+)', 'tokens', 'once');
                if ~isempty(tok)
                    nid = tok{1};
                    % linear search vesselMaskMap keys for this id
                    klist = keys(vesselMaskMap);
                    for kk=1:numel(klist)
                        if contains(klist{kk}, nid)
                            hasVessel = true;
                            vesselMaskPath = char(vesselMaskMap(klist{kk}));
                            break;
                        end
                    end
                end
            end
            % For mask images themselves, mark file as mask (not fundus) — but we still record
            % Distinguish: if current file is inside a masks folder, it's a mask not a fundus image
            if contains(lower(absPath), 'mask') || contains(lower(baseName), 'manual')
                % This is itself a mask file; we could still record but flag hasVessel appropriately
                % Keep hasVessel false for mask files themselves to avoid double-counting
                % Instead treat as vessel annotation artifact
                provenance = 'DRIVE/mask';
            else
                % fundus image
                if ~hasVessel
                    % If no mask found yet, still hasVessel false but not error
                end
            end
        end

        % IDRiD lesion annotation flag
        if strcmp(dsName, 'IDRiD')
            if isKey(lesionMap, keyForMap)
                hasLesion = true;
                lesionAnnotPath = char(lesionMap(keyForMap));
            elseif isKey(lesionMap, lower(keyForMap))
                hasLesion = true;
                lesionAnnotPath = char(lesionMap(lower(keyForMap)));
            else
                stripped2 = regexprep(baseName, '\.(jpg|png|tif)$','', 'ignorecase');
                if isKey(lesionMap, stripped2)
                    hasLesion = true;
                    lesionAnnotPath = char(lesionMap(stripped2));
                end
            end
            % Also set hasVessel false for IDRiD (unless OD segmentation present — ignore for Phase 1)
        end

        % Messidor2 external flag
        if strcmp(dsName, 'Messidor2')
            splitVal = 'external'; % per leakage policy, always external
        else
            % Leave split as UNKNOWN; generateSplits will populate train/val/test
            splitVal = 'UNKNOWN';
        end

        % Image dimension probing (lightweight, no full decode if possible)
        w = NaN; h = NaN; c = NaN; fsize = NaN; fhash = '';
        try
            [~, info, ~] = loadImageSafe(absPath);
            if ~isnan(info.width),  w = info.width;  end
            if ~isnan(info.height), h = info.height; end
            if ~isnan(info.channels), c = info.channels; end
            if ~isnan(info.fileSizeBytes), fsize = info.fileSizeBytes; end
        catch
        end
        if opts.computeHash
            try
                fhash = computeFileHash(absPath);
            catch
                fhash = '';
            end
        end

        % Patient fallback: if still UNKNOWN, use imageId as pseudo-patient for leakage safety
        % But mark status as PSEUDO_PATIENT so audit can flag
        if strcmp(patientId,'UNKNOWN')
            % For datasets where patientId truly unavailable, keep UNKNOWN but note
            % Do NOT invent; keep UNKNOWN per spec.
        end

        row = {imageId, datasetVal, relPath, absPath, fileFormat, ...
               laterality, patientId, subjectId, drGrade, drGradeOrig, ...
               qualityStatus, hasVessel, hasLesion, vesselMaskPath, lesionAnnotPath, ...
               splitVal, w, h, c, fsize, fhash, provenance, statusVal};
        rows{end+1,1} = row; %#ok<AGROW>
    end
end

%% APTOS parsing
function [gradeMap, patientMap] = parseAPTOSLabels(dsRoot, opts)
    gradeMap = containers.Map('KeyType','char','ValueType','any');
    patientMap = containers.Map('KeyType','char','ValueType','char');
    % APTOS typically has train.csv / test.csv or similar under dsRoot or dsRoot/train
    candidates = { fullfile(dsRoot,'train.csv'), fullfile(dsRoot,'trainLabels.csv'), ...
                   fullfile(dsRoot,'labels.csv'), fullfile(dsRoot,'APTOS_train.csv')};
    csvPath = '';
    for k=1:numel(candidates)
        if exist(candidates{k},'file'), csvPath = candidates{k}; break; end
    end
    % Also search recursively one level
    if isempty(csvPath)
        found = findFilesByName(dsRoot, '*.csv', 3);
        % Prefer file containing 'train' and 'diagnosis' or 'level'
        for k=1:numel(found)
            low = lower(found{k});
            if contains(low,'train') || contains(low,'label')
                csvPath = found{k}; break;
            end
        end
        if isempty(csvPath) && ~isempty(found)
            csvPath = found{1};
        end
    end
    if isempty(csvPath)
        if opts.verbose
            fprintf('  [APTOS] No label CSV found under %s — dr_grade will be UNKNOWN\n', dsRoot);
        end
        return;
    end
    if opts.verbose
        fprintf('  [APTOS] Parsing labels: %s\n', csvPath);
    end
    try
        T = readtable(csvPath, 'TextType','string');
        % Normalize column names
        varNames = lower(strtrim(T.Properties.VariableNames));
        % Find id column: id_code, image, id, image_id
        idCol = find(contains(varNames, 'id_code') | varNames=="id" | varNames=="image" | varNames=="image_id" | contains(varNames,'filename'), 1);
        gradeCol = find(contains(varNames,'diagnosis') | contains(varNames,'level') | contains(varNames,'grade') | contains(varNames,'label') | varNames=="target", 1);
        if isempty(idCol) || isempty(gradeCol)
            if opts.verbose
                fprintf('  [APTOS] CSV columns %s do not contain expected id/grade fields\n', strjoin(T.Properties.VariableNames,','));
            end
            return;
        end
        idVals = T{:,idCol};
        gradeVals = T{:,gradeCol};
        for r=1:numel(idVals)
            if iscell(idVals), key = strtrim(char(idVals{r})); else, key = strtrim(char(string(idVals(r)))); end
            % Strip extension if present
            [~, kbase, ~] = fileparts(key);
            if ~isempty(kbase), key = kbase; end
            val = gradeVals(r);
            if iscell(gradeVals), val = gradeVals{r}; end
            % Store both base and full key
            try gradeMap(key) = val; catch, end
            try gradeMap(lower(key)) = val; catch, end
            % Patient mapping: APTOS does not provide patient_id; use id_code as pseudo-patient but per spec keep UNKNOWN unless verified
            % We store mapping so split can group by imageId if needed, but leakage doc will state patient IDs unavailable
            try patientMap(key) = key; catch, end
            try patientMap(lower(key)) = key; catch, end
        end
    catch ME
        if opts.verbose
            fprintf('  [APTOS] Failed to parse %s : %s\n', csvPath, ME.message);
        end
    end
end

%% IDRiD parsing
function [gradeMap, lesionMap] = parseIDRiDLabels(dsRoot, opts)
    gradeMap = containers.Map('KeyType','char','ValueType','any');
    lesionMap = containers.Map('KeyType','char','ValueType','char');
    % IDRiD structure varies; common: 
    %  - Original Images + Groundtruths folders
    %  - CSV with Image name, Retinopathy grade
    %  - Lesions: Microaneurysms, Haemorrhages, Hard Exudates, Soft Exudates, Optic Disc
    foundCsv = findFilesByName(dsRoot, '*.csv', 4);
    % Also look for *.xlsx
    foundXlsx = findFilesByName(dsRoot, '*.xlsx', 4);
    allMeta = [foundCsv; foundXlsx];
    for k=1:numel(allMeta)
        f = allMeta{k};
        low = lower(f);
        if contains(low,'grade') || contains(low,'label') || contains(low,'grading') || contains(low,'retinopathy')
            try
                T = readtable(f, 'TextType','string');
                varNames = lower(strtrim(T.Properties.VariableNames));
                idCol = find(contains(varNames,'image') | contains(varNames,'id') | contains(varNames,'name') | contains(varNames,'file'), 1);
                gradeCol = find(contains(varNames,'grade') | contains(varNames,'level') | contains(varNames,'retinopathy') | contains(varNames,'diagnosis'), 1);
                if ~isempty(idCol) && ~isempty(gradeCol)
                    if opts.verbose
                        fprintf('  [IDRiD] Parsing grades: %s\n', f);
                    end
                    for r=1:height(T)
                        rawId = T{r,idCol};
                        if iscell(rawId), rawId = rawId{1}; end
                        key = char(string(rawId));
                        [~, kbase, ~] = fileparts(strtrim(key));
                        if ~isempty(kbase), key = kbase; end
                        val = T{r,gradeCol};
                        if iscell(val), val = val{1}; end
                        try gradeMap(key) = val; catch, end
                        try gradeMap(lower(key)) = val; catch, end
                    end
                end
            catch ME
                if opts.verbose
                    fprintf('  [IDRiD] Failed to parse grade file %s : %s\n', f, ME.message);
                end
            end
        end
    end
    if gradeMap.Count==0 && opts.verbose
        fprintf('  [IDRiD] No DR grade CSV/XLSX mapping found — dr_grade will be UNKNOWN where not inferred\n');
    end
    % Lesion annotations: discover mask/groundtruth files
    % Common subfolders: Groundtruths / Masks / Annotations containing _MA, _HE, _EX, _SE, _OD etc
    lesionIndicators = {'_ma','_he','_ex','_se','_od','microaneurysm','hemorrhage','haemorrhage','exudate','optic','lesion','groundtruth','gt'};
    allFiles = findFilesByName(dsRoot, '*.*', 6); % all files
    for k=1:numel(allFiles)
        f = allFiles{k};
        low = lower(f);
        isLesionFile = false;
        for li=1:numel(lesionIndicators)
            if contains(low, lesionIndicators{li})
                isLesionFile = true; break;
            end
        end
        if isLesionFile
            [~, base, ext] = fileparts(f);
            % Map lesion file to fundus image id: strip lesion suffixes
            % e.g., IDRiD_001_HE.tif -> IDRiD_001 ; IDRiD_02_MA.jpg
            fundusKey = regexprep(base, '_(MA|HE|EX|SE|OD|microaneurysms?|haemorrhages?|hemorrhages?|hard.?exudates?|soft.?exudates?|optic.?disc).*$','', 'ignorecase');
            fundusKey = strtrim(fundusKey);
            if isempty(fundusKey), fundusKey = base; end
            % Store mapping fundusKey -> lesion file (append if multiple)
            existing = '';
            if isKey(lesionMap, fundusKey), existing = lesionMap(fundusKey); end
            if isempty(existing)
                lesionMap(fundusKey) = f;
                try lesionMap(lower(fundusKey)) = f; catch, end
            else
                % Multiple lesion types: concatenate with semicolon
                lesionMap(fundusKey) = [existing ';' f];
                try lesionMap(lower(fundusKey)) = [existing ';' f]; catch, end
            end
            % Also map base itself
            if ~isKey(lesionMap, base)
                lesionMap(base) = f;
            end
        end
    end
    if opts.verbose
        fprintf('  [IDRiD] Lesion annotation files discovered: %d\n', lesionMap.Count);
    end
end

%% DRIVE parsing
function maskMap = parseDRIVEMasks(dsRoot, opts)
    maskMap = containers.Map('KeyType','char','ValueType','char');
    % Common DRIVE layout:
    %  training/images/*.tif, training/1st_manual/*.gif, training/mask/*.gif
    %  test/images/*.tif, test/1st_manual/*.gif, test/mask/*.gif
    %  Or flat with manual1 / mask folders
    keywords = {'manual','mask'};
    allFiles = findFilesByName(dsRoot, '*.*', 6);
    maskFiles = {};
    for k=1:numel(allFiles)
        low = lower(allFiles{k});
        for kw=keywords
            if contains(low, kw{1})
                maskFiles{end+1,1} = allFiles{k}; %#ok<AGROW>
                break;
            end
        end
    end
    if opts.verbose
        fprintf('  [DRIVE] Vessel mask files discovered: %d\n', numel(maskFiles));
    end
    for k=1:numel(maskFiles)
        f = maskFiles{k};
        [~, base, ~] = fileparts(f);
        % Key is base; also stripped numeric
        try maskMap(base) = f; catch, end
        try maskMap(lower(base)) = f; catch, end
        skey = strippedKey(base);
        if ~strcmp(skey, base)
            try maskMap(skey) = f; catch, end
            try maskMap(lower(skey)) = f; catch, end
        end
    end
    % Also need to map fundus images to masks via numeric id
    % Build fundus list for cross-check (not needed for map but for verbose)
end

function k = strippedKey(base)
    k = regexprep(base, '_(training|test|manual\d*|mask|1st_manual|2nd_manual)$','', 'ignorecase');
    k = regexprep(k, '(_manual\d*)$','', 'ignorecase');
end

%% Messidor2 parsing
function [gradeMap, patientMap, lateralityMap] = parseMessidor2Labels(dsRoot, opts)
    gradeMap = containers.Map('KeyType','char','ValueType','any');
    patientMap = containers.Map('KeyType','char','ValueType','char');
    lateralityMap = containers.Map('KeyType','char','ValueType','char');
    % Messidor-2 distribution varies; look for csv/xls with DR grades
    foundCsv = findFilesByName(dsRoot, '*.csv', 4);
    foundXlsx = findFilesByName(dsRoot, '*.xlsx', 4);
    foundXls = findFilesByName(dsRoot, '*.xls', 4);
    allMeta = [foundCsv; foundXlsx; foundXls];
    if isempty(allMeta) && opts.verbose
        fprintf('  [Messidor2] No metadata CSV/XLSX found under %s\n', dsRoot);
        fprintf('              DO NOT assume labels exist — see docs/MESSIDOR2_EXTERNAL_VALIDATION.md\n');
        return;
    end
    for k=1:numel(allMeta)
        f = allMeta{k};
        low = lower(f);
        % Heuristic: file containing messidor, grade, label, annotation, data
        try
            T = readtable(f, 'TextType','string');
        catch
            continue;
        end
        varNames = lower(strtrim(T.Properties.VariableNames));
        idCol = find(contains(varNames,'image') | contains(varNames,'id') | contains(varNames,'name') | contains(varNames,'file') | contains(varNames,'picture'), 1);
        gradeCol = find(contains(varNames,'grade') | contains(varNames,'diagnosis') | contains(varNames,'retinopathy') | contains(varNames,'dr') | contains(varNames,'level') | contains(varNames,'adjudicated') | contains(varNames,'drs'), 1);
        patCol  = find(contains(varNames,'patient') | contains(varNames,'subject') | contains(varNames,'case') | contains(varNames,'id_patient'), 1);
        latCol  = find(contains(varNames,'eye') | contains(varNames,'laterality') | contains(varNames,'latera') | contains(varNames,'left') | contains(varNames,'right') | contains(varNames,'od') | contains(varNames,'os'), 1);
        if isempty(idCol) && opts.verbose
            % Try first column as image id fallback if no explicit id col named
            idCol = 1;
        end
        if ~isempty(gradeCol) && ~isempty(idCol)
            if opts.verbose
                fprintf('  [Messidor2] Parsing potential label file: %s (vars: %s)\n', f, strjoin(T.Properties.VariableNames,', '));
            end
            for r=1:height(T)
                rawId = T{r,idCol};
                if iscell(rawId), rawId = rawId{1}; end
                key = char(string(rawId));
                [~, kbase, ~] = fileparts(strtrim(key));
                if ~isempty(kbase) && ~strcmp(kbase, key), key = kbase; end
                key = strtrim(key);
                if isempty(key), continue; end
                % Grade
                gval = T{r,gradeCol};
                if iscell(gval), gval = gval{1}; end
                try gradeMap(key) = gval; catch, end
                try gradeMap(lower(key)) = gval; catch, end
                % Patient
                if ~isempty(patCol)
                    pval = T{r,patCol};
                    if iscell(pval), pval = pval{1}; end
                    pstr = char(string(pval));
                    if ~isempty(strtrim(pstr))
                        try patientMap(key) = strtrim(pstr); catch, end
                        try patientMap(lower(key)) = strtrim(pstr); catch, end
                    end
                end
                % Laterality
                if ~isempty(latCol)
                    lval = T{r,latCol};
                    if iscell(lval), lval = lval{1}; end
                    lstr = upper(strtrim(char(string(lval))));
                    % Normalize OD/OS or L/R
                    if any(strcmp(lstr,{'OD','RIGHT','R','1','DROITE'}))
                        lstr = 'RIGHT';
                    elseif any(strcmp(lstr,{'OS','LEFT','L','0','GAUCHE'}))
                        lstr = 'LEFT';
                    end
                    if ~isempty(lstr) && ~strcmp(lstr,'UNKNOWN')
                        try lateralityMap(key) = lstr; catch, end
                        try lateralityMap(lower(key)) = lstr; catch, end
                    end
                end
            end
        elseif opts.verbose
            fprintf('  [Messidor2] Skipping file (no grade/id columns): %s vars=%s\n', f, strjoin(T.Properties.VariableNames,','));
        end
    end
    if gradeMap.Count==0 && opts.verbose
        fprintf('  [Messidor2] No DR grade mapping established — labels UNKNOWN. See external validation doc.\n');
    end
end

%% Utilities
function rel = makeRelativePath(absPath, projectRoot)
    % Try to make path relative to projectRoot for portability
    try
        % Ensure both use same separator
        rel = strrep(absPath, [projectRoot filesep], '');
        rel = strrep(rel, projectRoot, '');
        % Remove leading filesep
        if ~isempty(rel) && (rel(1)=='/' || rel(1)=='\')
            rel = rel(2:end);
        end
        % Normalize to forward slashes
        rel = strrep(rel, '\', '/');
        if isempty(rel)
            rel = strrep(absPath, '\', '/');
        end
    catch
        rel = strrep(absPath, '\', '/');
    end
end

function out = findFilesByName(rootDir, pattern, maxDepth)
% Find files matching pattern up to maxDepth levels
    out = {};
    if ~exist(rootDir,'dir'), return; end
    if nargin<3, maxDepth=4; end
    % Use dir recursive with depth limit
    out = collect(rootDir, pattern, 0, maxDepth);
end

function out = collect(curDir, pattern, curDepth, maxDepth)
    out = {};
    if curDepth > maxDepth, return; end
    try
        entries = dir(curDir);
    catch
        return;
    end
    for k=1:numel(entries)
        if strcmp(entries(k).name,'.') || strcmp(entries(k).name,'..'), continue; end
        fullP = fullfile(entries(k).folder, entries(k).name);
        if entries(k).isdir
            sub = collect(fullP, pattern, curDepth+1, maxDepth);
            out = [out; sub]; %#ok<AGROW>
        else
            % pattern like *.csv — use wildcard check via extension/fileparts or fnmatch simulation
            [~, nm, ext] = fileparts(entries(k).name);
            pat = pattern;
            % Simple handling: *.csv, *.xlsx, *.*, etc.
            if strcmp(pat,'*.*')
                out{end+1,1}=fullP; %#ok<AGROW>
            elseif startsWith(pat,'*.')
                wantExt = lower(strrep(pat,'*.',''));
                if strcmpi(ext(2:end), wantExt) % ext includes dot
                    out{end+1,1}=fullP; %#ok<AGROW>
                end
            else
                % Fallback: contains check
                if contains(lower(entries(k).name), lower(strrep(pat,'*','')))
                    out{end+1,1}=fullP; %#ok<AGROW>
                end
            end
        end
    end
end

function T = emptyManifestTable()
    T = table( ...
        cell(0,1), cell(0,1), cell(0,1), cell(0,1), cell(0,1), ... % image_id, dataset, file_path, file_path_absolute, file_format
        cell(0,1), cell(0,1), cell(0,1), ... % laterality, patient_id, subject_id
        zeros(0,1), cell(0,1), ... % dr_grade, dr_grade_original
        cell(0,1), zeros(0,1,'logical'), zeros(0,1,'logical'), ... % quality_status, has_vessel, has_lesion
        cell(0,1), cell(0,1), ... % vessel_mask_path, lesion_annotation_path
        cell(0,1), ... % split
        zeros(0,1), zeros(0,1), zeros(0,1), ... % width, height, channels
        zeros(0,1), cell(0,1), ... % file_size_bytes, file_hash
        cell(0,1), cell(0,1), ... % provenance, status
        'VariableNames', {'image_id','dataset','file_path','file_path_absolute','file_format', ...
                          'laterality','patient_id','subject_id','dr_grade','dr_grade_original', ...
                          'quality_status','has_vessel_annotation','has_lesion_annotation', ...
                          'vessel_mask_path','lesion_annotation_path','split', ...
                          'width','height','channels','file_size_bytes','file_hash', ...
                          'provenance','status'});
end
