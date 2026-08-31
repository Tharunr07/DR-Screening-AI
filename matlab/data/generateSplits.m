function splitInfo = generateSplits(cfg, manifest, opts)
% generateSplits  Create reproducible train/val/test splits with leakage prevention
%
%   splitInfo = generateSplits()
%   splitInfo = generateSplits(cfg, manifest, opts)
%
%   This implements the Phase 1 split policy:
%     - Messidor-2 is ALWAYS external validation, never mixed into train/val/test
%     - Where patient_id / subject_id is available (~= 'UNKNOWN'), splits are
%       grouped by patient to avoid leakage (no patient appears in >1 split)
%     - Where no patient IDs exist, falls back to stratified-by-grade
%       image-level split (documented as limitation)
%     - Deterministic via fixed random seed (cfg.randomSeed)
%     - Stratified by dr_grade where possible to preserve class distribution
%
%   Outputs:
%     splitInfo - struct describing what was done (for metadata JSON)
%     Side effects:
%       - Updates manifest.split column and rewrites data/processed/manifest.csv + .mat
%       - Writes data/splits/train.csv, val.csv, test.csv, external.csv
%       - Writes data/splits/split_metadata.json
%       - Prints leakage checks
%
%   No raw images are modified.

    if nargin < 1 || isempty(cfg)
        cfg = datasetConfig();
    end
    if nargin < 2 || isempty(manifest)
        if exist(cfg.manifestMatPath,'file')
            S = load(cfg.manifestMatPath,'manifest');
            manifest = S.manifest;
        else
            manifest = buildManifest(cfg, struct('computeHash',false,'verbose',false));
        end
    end
    if nargin < 3 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts,'seed'),    opts.seed = cfg.randomSeed; end
    if ~isfield(opts,'verbose'), opts.verbose = true; end
    if ~isfield(opts,'ratios'),  opts.ratios = cfg.splitRatios; end

    rng(opts.seed); % deterministic

    splitInfo = struct();
    splitInfo.timestamp = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    splitInfo.seed = opts.seed;
    splitInfo.ratios = opts.ratios;
    splitInfo.policy = 'patient-grouped where patient_id available; stratified-by-grade; Messidor2 isolated as external';
    splitInfo.status = 'IMPLEMENTED';

    nTotal = height(manifest);
    if nTotal==0
        splitInfo.status = 'NOT VALIDATED — EMPTY MANIFEST';
        splitInfo.notes = 'No images to split — DATASET NOT PRESENT';
        if opts.verbose, fprintf('[generateSplits] Empty manifest — nothing to split.\n'); end
        % Still write header-only split CSVs for honest reporting (do not leave stale synthetic files)
        try
            writeOutputs(cfg, manifest, splitInfo, opts);
        catch
            writeSplitMetadata(cfg, splitInfo, manifest);
        end
        return;
    end

    % Ensure split column exists
    if ~ismember('split', manifest.Properties.VariableNames)
        manifest.split = repmat("UNKNOWN", nTotal, 1);
    end

    % --- Isolate external datasets ---
    isExternal = ismember(manifest.dataset, string(cfg.externalDatasets));
    manifest.split(isExternal) = "external";
    nExternal = sum(isExternal);

    % Development pool = non-external
    devIdx = find(~isExternal);
    nDev = numel(devIdx);

    if opts.verbose
        fprintf('[generateSplits] Total: %d, External (isolated): %d, Development pool: %d\n', nTotal, nExternal, nDev);
    end

    if nDev==0
        splitInfo.notes = 'All images are external — no development splits created';
        splitInfo.leakageCheck = struct('patientLeakage', false, 'details', 'no dev pool');
        writeOutputs(cfg, manifest, splitInfo, opts);
        return;
    end

    devManifest = manifest(devIdx, :);

    % --- Determine grouping key ---
    % Use patient_id where known, else subject_id, else singletons with warning
    pids = string(devManifest.patient_id);
    sids = string(devManifest.subject_id);
    % Known patient mask
    knownMask = ~(pids=="UNKNOWN" | pids=="" | ismissing(pids));
    % For DRIVE, patient UNKNOWN — will be image-level split

    % Build patient-level table
    % uniquePatients = unique known pids
    if any(knownMask)
        uniquePats = unique(pids(knownMask));
        nPat = numel(uniquePats);
        if opts.verbose
            fprintf('[generateSplits] Patient-grouped split: %d unique known patients, %d images with UNKNOWN patient\n', nPat, sum(~knownMask));
        end
        % For each patient, collect grade (majority or first) for stratification
        patGrades = zeros(nPat,1);
        patCounts = zeros(nPat,1);
        for pi=1:nPat
            pat = uniquePats(pi);
            rows = find(pids==pat);
            g = devManifest.dr_grade(rows);
            g = g(~isnan(g));
            if isempty(g)
                patGrades(pi) = NaN;
            else
                % Use most frequent grade for stratification
                patGrades(pi) = mode(g);
            end
            patCounts(pi) = numel(rows);
        end
        % Also handle UNKNOWN-patient images as singletons (each image is its own pseudo-patient)
        singletonIdx = find(~knownMask);
        nSingleton = numel(singletonIdx);
        % Combine: patient groups + singleton pseudo-groups
        % We will split patient groups plus singleton groups together proportionally

        % Build list of groups: each group has key, size, grade
        % Patients
        groupKeys = [cellstr(uniquePats); cellstr(string(devManifest.image_id(singletonIdx)))];
        groupGrades = [patGrades; devManifest.dr_grade(singletonIdx)];
        groupSizes  = [patCounts; ones(nSingleton,1)];
        groupIsSingleton = [false(nPat,1); true(nSingleton,1)];
        % Map group index -> row indices in devManifest
        groupRows = cell(numel(groupKeys),1);
        for pi=1:nPat
            groupRows{pi} = find(pids==uniquePats(pi));
        end
        for si=1:nSingleton
            groupRows{nPat+si} = singletonIdx(si);
        end

        % Stratified split of groups by grade
        groupSplits = stratifiedGroupSplit(groupGrades, opts.ratios, opts.seed, opts.verbose);

        % Assign splits to devManifest rows
        newSplits = strings(nDev,1);
        for gi=1:numel(groupKeys)
            rows = groupRows{gi};
            s = groupSplits(gi);
            newSplits(rows) = s;
        end
        manifest.split(devIdx) = newSplits;
        splitInfo.strategy = 'patient-grouped (known patients grouped, UNKNOWN-patient images as singletons), stratified by grade';
        splitInfo.nPatientsGrouped = nPat;
        splitInfo.nSingletonImages = nSingleton;
    else
        % No patient IDs available anywhere — image-level stratified split
        if opts.verbose
            fprintf('[generateSplits] No patient IDs available — using stratified image-level split (documented limitation)\n');
        end
        grades = devManifest.dr_grade;
        imgSplits = stratifiedImageSplit(grades, opts.ratios, opts.seed, opts.verbose);
        manifest.split(devIdx) = imgSplits;
        splitInfo.strategy = 'image-level stratified (no patient IDs available — leakage prevention unverifiable, documented)';
        splitInfo.nPatientsGrouped = 0;
        splitInfo.nSingletonImages = nDev;
    end

    % Leakage check
    leakage = checkLeakage(manifest);
    splitInfo.leakageCheck = leakage;
    if opts.verbose
        if leakage.patientLeakage
            fprintf('[WARN] LEAKAGE DETECTED: %s\n', leakage.details);
        else
            fprintf('[OK] Leakage check passed: %s\n', leakage.details);
        end
    end

    % Write outputs
    writeOutputs(cfg, manifest, splitInfo, opts);
end

%% ------------------------------------------------------------------------
function grpSplits = stratifiedGroupSplit(grades, ratios, seed, verbose)
% Split group-level grades into train/val/test proportionally, stratified.
    rng(seed);
    n = numel(grades);
    grpSplits = strings(n,1);
    grpSplits(:) = "train"; % default

    % Separate labeled vs unlabeled for stratification
    labeledMask = ~isnan(grades);
    unlabeledIdx = find(~labeledMask);
    labeledIdx   = find(labeledMask);

    % For labeled, stratify by grade 0..4
    uniqueGrades = unique(grades(labeledMask));
    for g = uniqueGrades(:)'
        idx = labeledIdx(grades(labeledIdx)==g);
        idx = idx(randperm(numel(idx))); % shuffle deterministically via seeded rng
        nG = numel(idx);
        nTrain = max(1, round(nG * ratios.train));
        nVal   = max(1, round(nG * ratios.val));
        % Adjust to not exceed nG
        if nTrain + nVal >= nG
            nVal = max(0, nG - nTrain - 1);
            nTest = nG - nTrain - nVal;
        else
            nTest = nG - nTrain - nVal;
        end
        % Assign
        if nTrain>0, grpSplits(idx(1:nTrain)) = "train"; end
        if nVal>0,   grpSplits(idx(nTrain+1:nTrain+nVal)) = "val"; end
        if nTest>0,  grpSplits(idx(nTrain+nVal+1:end)) = "test"; end
    end

    % Unlabeled groups: random proportional
    if ~isempty(unlabeledIdx)
        idx = unlabeledIdx(randperm(numel(unlabeledIdx)));
        nU = numel(idx);
        nTrain = round(nU * ratios.train);
        nVal   = round(nU * ratios.val);
        nTest = nU - nTrain - nVal;
        if nTrain>0, grpSplits(idx(1:nTrain)) = "train"; end
        if nVal>0,   grpSplits(idx(nTrain+1:nTrain+nVal)) = "val"; end
        if nTest>0,  grpSplits(idx(nTrain+nVal+1:end)) = "test"; end
    end

    if verbose
        fprintf('  Group split counts: train=%d val=%d test=%d\n', sum(grpSplits=="train"), sum(grpSplits=="val"), sum(grpSplits=="test"));
    end
end

function imgSplits = stratifiedImageSplit(grades, ratios, seed, verbose)
    rng(seed);
    n = numel(grades);
    imgSplits = strings(n,1);
    % Same logic as group but at image granularity
    labeledMask = ~isnan(grades);
    labeledIdx = find(labeledMask);
    unlabeledIdx = find(~labeledMask);
    uniqueGrades = unique(grades(labeledMask));
    for g = uniqueGrades(:)'
        idx = labeledIdx(grades(labeledIdx)==g);
        idx = idx(randperm(numel(idx)));
        nG = numel(idx);
        nTrain = max(1, round(nG * ratios.train));
        nVal   = max(1, round(nG * ratios.val));
        if nTrain + nVal >= nG
            nVal = max(0, nG - nTrain - 1);
            nTest = nG - nTrain - nVal;
        else
            nTest = nG - nTrain - nVal;
        end
        if nTrain>0, imgSplits(idx(1:nTrain)) = "train"; end
        if nVal>0,   imgSplits(idx(nTrain+1:nTrain+nVal)) = "val"; end
        if nTest>0,  imgSplits(idx(nTrain+nVal+1:end)) = "test"; end
    end
    if ~isempty(unlabeledIdx)
        idx = unlabeledIdx(randperm(numel(unlabeledIdx)));
        nU = numel(idx);
        nTrain = round(nU * ratios.train);
        nVal   = round(nU * ratios.val);
        nTest = nU - nTrain - nVal;
        if nTrain>0, imgSplits(idx(1:nTrain)) = "train"; end
        if nVal>0,   imgSplits(idx(nTrain+1:nTrain+nVal)) = "val"; end
        if nTest>0,  imgSplits(idx(nTrain+nVal+1:end)) = "test"; end
    end
    if verbose
        fprintf('  Image split counts: train=%d val=%d test=%d\n', sum(imgSplits=="train"), sum(imgSplits=="val"), sum(imgSplits=="test"));
    end
end

function leakage = checkLeakage(manifest)
    leakage = struct('patientLeakage', false, 'details', '', 'externalLeakage', false);
    % Only check where patient_id known and not external
    isExt = manifest.split=="external";
    dev = manifest(~isExt, :);
    if height(dev)==0
        leakage.details = 'no development pool';
        return;
    end
    pids = string(dev.patient_id);
    splits = string(dev.split);
    knownMask = ~(pids=="UNKNOWN" | pids=="" | ismissing(pids));
    if ~any(knownMask)
        leakage.details = 'no known patient IDs in development pool — leakage unverifiable (image-level split)';
        return;
    end
    uniqPats = unique(pids(knownMask));
    leaked = {};
    for pi=1:numel(uniqPats)
        pat = uniqPats(pi);
        sp = unique(splits(pids==pat));
        if numel(sp) > 1
            leakage.patientLeakage = true;
            leaked{end+1} = sprintf('%s in [%s]', pat, strjoin(cellstr(sp),',')); %#ok<AGROW>
        end
    end
    if leakage.patientLeakage
        leakage.details = sprintf('PATIENT LEAKAGE: %d patients in multiple splits: %s', numel(leaked), strjoin(leaked(1:min(5,end)),'; '));
    else
        leakage.details = sprintf('No patient appears in multiple splits (%d patients checked)', numel(uniqPats));
    end
    % External leakage: ensure no patient overlaps between external and dev (if IDs overlap)
    extPids = string(manifest.patient_id(isExt));
    extKnown = extPids(~(extPids=="UNKNOWN"|extPids==""));
    devKnown = pids(knownMask);
    overlap = intersect(extKnown, devKnown);
    if ~isempty(overlap)
        leakage.externalLeakage = true;
        leakage.details = [leakage.details sprintf('; EXTERNAL LEAKAGE: %d overlapping patients', numel(overlap))];
    end
end

function writeOutputs(cfg, manifest, splitInfo, opts)
    % Ensure dirs
    if ~exist(cfg.splitsRoot,'dir'), mkdir(cfg.splitsRoot); end
    if ~exist(cfg.processedRoot,'dir'), mkdir(cfg.processedRoot); end

    % Rewrite manifest (updated split column)
    try
        writetable(manifest, cfg.manifestPath);
        save(cfg.manifestMatPath, 'manifest','-v7');
        if opts.verbose, fprintf('[OK] Updated manifest: %s\n', cfg.manifestPath); end
    catch ME
        warning('Failed to rewrite manifest: %s', ME.message);
    end

    % Write per-split CSVs (include all manifest columns for traceability)
    splitsToWrite = {'train','val','test','external'};
    for k=1:numel(splitsToWrite)
        s = splitsToWrite{k};
        sub = manifest(manifest.split==string(s), :);
        outPath = fullfile(cfg.splitsRoot, [s '.csv']);
        try
            if height(sub) > 0
                writetable(sub, outPath);
                % Also write image_id list convenience file
                listPath = fullfile(cfg.splitsRoot, [s '_ids.txt']);
                fid = fopen(listPath,'w');
                for r=1:height(sub)
                    fprintf(fid,'%s\n', char(sub.image_id(r)));
                end
                fclose(fid);
            else
                % Write header-only
                writetable(sub, outPath);
            end
            if opts.verbose, fprintf('[OK] Wrote %s: %d rows -> %s\n', s, height(sub), outPath); end
            splitInfo.(sprintf('n_%s', s)) = height(sub);
        catch ME
            warning('Failed to write split %s: %s', s, ME.message);
        end
    end

    % Also write all splits combined sanity check
    writeSplitMetadata(cfg, splitInfo, manifest);
end

function writeSplitMetadata(cfg, splitInfo, manifest)
    outPath = fullfile(cfg.splitsRoot, 'split_metadata.json');
    % Build metadata struct
    meta = splitInfo;
    meta.projectRoot = cfg.projectRoot;
    % Add counts
    if ~isempty(manifest) && height(manifest)>0
        % Counts already in splitInfo but duplicate for readability
        for s = ["train","val","test","external","UNKNOWN"]
            meta.(sprintf('count_%s', s)) = sum(manifest.split==s);
        end
        % Ratios actual
        nDev = sum(manifest.split~="external" & manifest.split~="UNKNOWN");
        if nDev>0
            meta.actualRatios = struct( ...
                'train', sum(manifest.split=="train")/nDev, ...
                'val',   sum(manifest.split=="val")/nDev, ...
                'test',  sum(manifest.split=="test")/nDev);
        end
    end
    meta.referableDefinition = struct('nonReferable',[0,1],'referable',[2,3,4],'threshold',2);
    meta.leakagePolicy = 'No patient in multiple splits; external isolated; test not used for tuning (see docs/DATA_LEAKAGE_POLICY.md)';
    if ~exist(cfg.splitsRoot,'dir'), mkdir(cfg.splitsRoot); end
    try
        jsonStr = jsonencode(meta, 'PrettyPrint', true);
        fid = fopen(outPath,'w');
        fwrite(fid, jsonStr, 'char');
        fclose(fid);
    catch ME
        warning('Failed to write split metadata JSON: %s', ME.message);
        try
            jsonStr = jsonencode(meta);
            fid = fopen(outPath,'w');
            fwrite(fid, jsonStr, 'char');
            fclose(fid);
        catch
        end
    end
    % Also .mat
    try
        save(fullfile(cfg.splitsRoot,'split_metadata.mat'), 'meta','-v7');
    catch
    end
end
