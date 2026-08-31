function results = auditDataset(cfg, manifest, opts)
% auditDataset  Audit manifest + filesystem for Phase 1
%
%   results = auditDataset(cfg)
%   results = auditDataset(cfg, manifest)
%   results = auditDataset(cfg, manifest, opts)
%
%   Inputs:
%     cfg      - datasetConfig() struct
%     manifest - table from buildManifest() ; if empty/missing, will be built
%     opts     - struct with:
%                .checkImageRead (bool, default true)  attempt loadImageSafe per file
%                .computeHash    (bool, default false) hash for duplicate detection
%                .verbose        (bool, default true)
%
%   Output:
%     results - struct with audit findings, suitable for JSON/MAT export:
%       .timestamp, .projectRoot, .totalImages, .byDataset, .byFormat,
%       .byGrade, .bySplit, .dimensions, .channels, .missingFiles,
%       .unreadableFiles, .duplicateFilenames, .duplicateHashes,
%       .annotationAvailability, .patientStats, .lateralityStats,
%       .status ('IMPLEMENTED'/'NOT VALIDATED' etc)
%
%   Side effects: none on raw data. Caller decides to write results.

    if nargin < 1 || isempty(cfg)
        cfg = datasetConfig();
    end
    if nargin < 2 || isempty(manifest)
        if exist(cfg.manifestMatPath,'file')
            try
                S = load(cfg.manifestMatPath, 'manifest');
                manifest = S.manifest;
            catch
                manifest = buildManifest(cfg, struct('computeHash',false,'verbose',false));
            end
        else
            manifest = buildManifest(cfg, struct('computeHash',false,'verbose',false));
        end
    end
    if nargin < 3 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts,'checkImageRead'), opts.checkImageRead = true; end
    if ~isfield(opts,'computeHash'),    opts.computeHash = false; end
    if ~isfield(opts,'verbose'),        opts.verbose = true; end

    results = struct();
    results.timestamp   = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    results.projectRoot = cfg.projectRoot;
    results.status      = 'IMPLEMENTED'; % will flip to NOT VALIDATED if no data
    results.config      = struct('randomSeed', cfg.randomSeed, ...
                                 'splitRatios', cfg.splitRatios, ...
                                 'supportedExtensions', {cfg.supportedExtensions});

    n = height(manifest);
    results.totalImages = n;

    if n == 0
        results.status = 'NOT VALIDATED — DATASET NOT PRESENT';
        results.byDataset = struct('APTOS2019',0,'IDRiD',0,'DRIVE',0,'Messidor2',0);
        results.byFormat  = struct();
        results.byGrade   = struct('Level0',0,'Level1',0,'Level2',0,'Level3',0,'Level4',0,'UNKNOWN',0);
        results.byGradePerDataset = struct( ...
            'APTOS2019', struct('Level0',0,'Level1',0,'Level2',0,'Level3',0,'Level4',0,'UNKNOWN',0,'total',0), ...
            'IDRiD',      struct('Level0',0,'Level1',0,'Level2',0,'Level3',0,'Level4',0,'UNKNOWN',0,'total',0), ...
            'DRIVE',      struct('Level0',0,'Level1',0,'Level2',0,'Level3',0,'Level4',0,'UNKNOWN',0,'total',0), ...
            'Messidor2',  struct('Level0',0,'Level1',0,'Level2',0,'Level3',0,'Level4',0,'UNKNOWN',0,'total',0));
        results.bySplit   = struct();
        dimsEmpty = struct();
        dimsEmpty.minWidth = NaN;
        dimsEmpty.maxWidth = NaN;
        dimsEmpty.minHeight = NaN;
        dimsEmpty.maxHeight = NaN;
        dimsEmpty.meanWidth = NaN;
        dimsEmpty.meanHeight = NaN;
        dimsEmpty.uniqueSizes = {};
        results.dimensions = dimsEmpty;
        results.channels  = struct();
        results.missingFiles = {};
        results.missingCount = 0;
        results.unreadableFiles = {};
        results.unreadableCount = 0;
        results.duplicateFilenames = {};
        results.duplicateFilenameGroupCount = 0;
        results.duplicateHashes = {};
        results.duplicateHashGroupCount = 0;
        results.annotationAvailability = struct('hasVessel',0,'hasLesion',0,'hasVesselPct',0,'hasLesionPct',0);
        results.annotationAvailabilityPerDataset = struct( ...
            'APTOS2019', struct('total',0,'hasVessel',0,'hasLesion',0), ...
            'IDRiD', struct('total',0,'hasVessel',0,'hasLesion',0), ...
            'DRIVE', struct('total',0,'hasVessel',0,'hasLesion',0), ...
            'Messidor2', struct('total',0,'hasVessel',0,'hasLesion',0));
        results.patientStats = struct('totalRows',0,'uniquePatientsKnown',0,'unknownPatientRows',0,'patientIdAvailable',false, 'perDataset', struct( ...
            'APTOS2019', struct('total',0,'uniqueKnown',0,'unknownRows',0), ...
            'IDRiD', struct('total',0,'uniqueKnown',0,'unknownRows',0), ...
            'DRIVE', struct('total',0,'uniqueKnown',0,'unknownRows',0), ...
            'Messidor2', struct('total',0,'uniqueKnown',0,'unknownRows',0)));
        results.lateralityStats = struct('UNKNOWN',0);
        results.summary = 'Total=0, Missing=0, Unreadable=0, DupNameGroups=0, Vessel=0, Lesion=0 — DATASET NOT PRESENT — DOWNLOAD REQUIRED';
        results.notes = 'No images found. Audit reports DATASET NOT PRESENT — DOWNLOAD REQUIRED. See docs/DATASET_DOWNLOAD_GUIDE.md';
        if opts.verbose
            fprintf('[auditDataset] No images — manifest empty.\n');
        end
        return;
    end

    % -- byDataset
    [uDs, ~, icDs] = unique(manifest.dataset);
    byDataset = struct();
    for k=1:numel(uDs)
        key = matlab.lang.makeValidName(char(uDs(k)));
        byDataset.(key) = sum(icDs==k);
    end
    results.byDataset = byDataset;

    % -- byFormat
    [uFmt, ~, icFmt] = unique(manifest.file_format);
    byFormat = struct();
    for k=1:numel(uFmt)
        key = matlab.lang.makeValidName(char(uFmt(k)));
        if isempty(key) || strcmp(key,'UNKNOWN'), key = sprintf('FMT_%s', char(uFmt(k))); end
        byFormat.(key) = sum(icFmt==k);
    end
    results.byFormat = byFormat;

    % -- byGrade (0..4 + UNKNOWN/NaN)
    byGrade = struct('Level0',0,'Level1',0,'Level2',0,'Level3',0,'Level4',0,'UNKNOWN',0);
    grades = manifest.dr_grade;
    for g=0:4
        byGrade.(sprintf('Level%d',g)) = sum(grades==g);
    end
    byGrade.UNKNOWN = sum(isnan(grades));
    results.byGrade = byGrade;
    % per-dataset grade breakdown
    perDsGrade = struct();
    for k=1:numel(uDs)
        ds = char(uDs(k));
        idx = manifest.dataset == string(ds);
        g = manifest.dr_grade(idx);
        s = struct('Level0',sum(g==0),'Level1',sum(g==1),'Level2',sum(g==2),'Level3',sum(g==3),'Level4',sum(g==4),'UNKNOWN',sum(isnan(g)),'total',sum(idx));
        perDsGrade.(matlab.lang.makeValidName(ds)) = s;
    end
    results.byGradePerDataset = perDsGrade;

    % -- bySplit
    [uSp, ~, icSp] = unique(manifest.split);
    bySplit = struct();
    for k=1:numel(uSp)
        key = matlab.lang.makeValidName(char(uSp(k)));
        bySplit.(key) = sum(icSp==k);
    end
    results.bySplit = bySplit;

    % -- dimensions
    widths  = manifest.width;
    heights = manifest.height;
    validDim = ~isnan(widths) & ~isnan(heights);
    if any(validDim)
        dims = struct();
        dims.minWidth = min(widths(validDim));
        dims.maxWidth = max(widths(validDim));
        dims.minHeight = min(heights(validDim));
        dims.maxHeight = max(heights(validDim));
        dims.meanWidth = mean(widths(validDim));
        dims.meanHeight = mean(heights(validDim));
        dims.uniqueSizes = uniqueRows([widths(validDim) heights(validDim)]);
        results.dimensions = dims;
    else
        dims = struct();
        dims.minWidth = NaN;
        dims.maxWidth = NaN;
        dims.minHeight = NaN;
        dims.maxHeight = NaN;
        dims.meanWidth = NaN;
        dims.meanHeight = NaN;
        dims.uniqueSizes = {};
        results.dimensions = dims;
    end

    % -- channels
    chans = manifest.channels;
    [uCh, ~, icCh] = unique(chans);
    chStruct = struct();
    for k=1:numel(uCh)
        if isnan(uCh(k))
            chStruct.UNKNOWN = sum(icCh==k);
        else
            chStruct.(sprintf('C%d', uCh(k))) = sum(icCh==k);
        end
    end
    results.channels = chStruct;

    % -- missing files & unreadable
    missingFiles = {};
    unreadableFiles = {};
    duplicateFilenames = {};
    duplicateHashes = {};

    if opts.checkImageRead
        if opts.verbose
            fprintf('[auditDataset] Checking %d files for readability...\n', n);
        end
        for i=1:n
            ap = char(manifest.file_path_absolute(i));
            if ~exist(ap,'file')
                missingFiles{end+1,1} = ap; %#ok<AGROW>
            else
                [~, info, err] = loadImageSafe(ap);
                if ~info.readable
                    unreadableFiles{end+1,1} = struct('file', ap, 'error', err); %#ok<AGROW>
                end
            end
        end
    else
        % Only check existence
        for i=1:n
            ap = char(manifest.file_path_absolute(i));
            if ~exist(ap,'file')
                missingFiles{end+1,1} = ap; %#ok<AGROW>
            end
        end
    end
    results.missingFiles = missingFiles;
    results.missingCount = numel(missingFiles);
    results.unreadableFiles = unreadableFiles;
    results.unreadableCount = numel(unreadableFiles);

    % -- duplicate filenames (basename collisions across datasets)
    [~, baseNames, ~] = fileparts(manifest.file_path_absolute);
    % lower-case for case-insensitive filesystem
    lowerBases = lower(baseNames);
    [uB, ~, icB] = unique(lowerBases);
    dups = {};
    for k=1:numel(uB)
        idx = find(icB==k);
        if numel(idx) > 1
            % Report group
            grp = manifest.file_path_absolute(idx);
            dups{end+1,1} = struct('image_id', char(uB(k)), 'count', numel(idx), 'files', {grp}); %#ok<AGROW>
        end
    end
    results.duplicateFilenames = dups;
    results.duplicateFilenameGroupCount = numel(dups);

    % -- duplicate hashes (if computed)
    if opts.computeHash && any(~cellfun(@isempty, manifest.file_hash))
        hashes = manifest.file_hash;
        % Only non-empty hashes
        validH = ~cellfun(@isempty, hashes);
        hVals = hashes(validH);
        hPaths = manifest.file_path_absolute(validH);
        [uH, ~, icH] = unique(hVals);
        hDups = {};
        for k=1:numel(uH)
            idx = find(icH==k);
            if numel(idx) > 1
                grp = hPaths(idx);
                hDups{end+1,1} = struct('hash', char(uH(k)), 'count', numel(idx), 'files', {grp}); %#ok<AGROW>
            end
        end
        results.duplicateHashes = hDups;
        results.duplicateHashGroupCount = numel(hDups);
    else
        results.duplicateHashes = {};
        results.duplicateHashGroupCount = 0;
        if opts.computeHash && opts.verbose
            fprintf('[auditDataset] No file hashes available — run buildManifest with computeHash=true\n');
        end
    end

    % -- annotation availability
    results.annotationAvailability = struct( ...
        'hasVessel', sum(manifest.has_vessel_annotation), ...
        'hasLesion', sum(manifest.has_lesion_annotation), ...
        'hasVesselPct', 100*sum(manifest.has_vessel_annotation)/n, ...
        'hasLesionPct', 100*sum(manifest.has_lesion_annotation)/n ...
    );
    % Per dataset
    annPerDs = struct();
    for k=1:numel(uDs)
        ds = char(uDs(k));
        idx = manifest.dataset==string(ds);
        annPerDs.(matlab.lang.makeValidName(ds)) = struct( ...
            'total', sum(idx), ...
            'hasVessel', sum(manifest.has_vessel_annotation(idx)), ...
            'hasLesion', sum(manifest.has_lesion_annotation(idx)) ...
        );
    end
    results.annotationAvailabilityPerDataset = annPerDs;

    % -- patient / subject stats
    pids = manifest.patient_id;
    % Count UNKNOWN vs known
    nUnknownPat = sum(pids=="UNKNOWN" | pids=="" | cellfun(@(x) strcmp(x,'UNKNOWN'), cellstr(pids)));
    % Unique non-unknown patients
    knownMask = ~(pids=="UNKNOWN" | pids=="" );
    uniqPatients = 0;
    if any(knownMask)
        uniqPatients = numel(unique(pids(knownMask)));
    end
    results.patientStats = struct( ...
        'totalRows', n, ...
        'uniquePatientsKnown', uniqPatients, ...
        'unknownPatientRows', nUnknownPat, ...
        'patientIdAvailable', uniqPatients > 0 ...
    );
    perDsPat = struct();
    for k=1:numel(uDs)
        ds = char(uDs(k));
        idx = manifest.dataset==string(ds);
        sub = pids(idx);
        known = ~(sub=="UNKNOWN" | sub=="");
        perDsPat.(matlab.lang.makeValidName(ds)) = struct( ...
            'total', sum(idx), ...
            'uniqueKnown', numel(unique(sub(known))), ...
            'unknownRows', sum(~known) ...
        );
    end
    results.patientStats.perDataset = perDsPat;

    % -- laterality
    lat = manifest.laterality;
    [uLat, ~, icLat] = unique(lat);
    latStruct = struct();
    for k=1:numel(uLat)
        key = matlab.lang.makeValidName(char(uLat(k)));
        latStruct.(key) = sum(icLat==k);
    end
    results.lateralityStats = latStruct;

    % -- file formats summary string
    results.summary = sprintf('Total=%d, Missing=%d, Unreadable=%d, DupNameGroups=%d, Vessel=%d, Lesion=%d', ...
        n, results.missingCount, results.unreadableCount, results.duplicateFilenameGroupCount, ...
        results.annotationAvailability.hasVessel, results.annotationAvailability.hasLesion);

    if opts.verbose
        fprintf('[auditDataset] %s\n', results.summary);
    end
end

function out = uniqueRows(M)
    % Return cell of "WxH" strings for unique sizes
    [u, ~, ~] = unique(M, 'rows');
    out = cell(size(u,1),1);
    for i=1:size(u,1)
        out{i} = sprintf('%dx%d', u(i,1), u(i,2));
    end
end
