% runAudit.m — Phase 1 dataset audit runner
%
%   Usage (MATLAB):
%     >> runAudit
%     >> runAudit(projectRoot)
%     >> runAudit(projectRoot, 'checkImageRead', true, 'computeHash', false)
%
%   Produces:
%     results/audit_results.json   (machine-readable)
%     results/audit_results.mat
%     docs/PHASE1_AUDIT_REPORT.md  (human-readable, regenerated each run)
%
%   Does NOT modify raw data.

function runAudit(projectRoot, varargin)
    if nargin < 1 || isempty(projectRoot)
        cfg = datasetConfig();
    else
        cfg = datasetConfig(projectRoot);
    end

    opts = struct('checkImageRead', true, 'computeHash', false, 'verbose', true);
    for k=1:2:numel(varargin)
        key = lower(string(varargin{k}));
        if k+1 > numel(varargin), break; end
        val = varargin{k+1};
        switch key
            case "checkimageread"
                opts.checkImageRead = logical(val);
            case "computehash"
                opts.computeHash = logical(val);
            case "verbose"
                opts.verbose = logical(val);
            otherwise
                warning('runAudit:UnknownOption','Unknown option %s', key);
        end
    end

    fprintf('=== DR Screening Phase 1 — Dataset Audit ===\n');
    fprintf('Project root     : %s\n', cfg.projectRoot);
    fprintf('checkImageRead   : %d\n', opts.checkImageRead);
    fprintf('computeHash      : %d\n', opts.computeHash);

    % Load or build manifest
    manifest = [];
    if exist(cfg.manifestMatPath,'file')
        try
            S = load(cfg.manifestMatPath, 'manifest');
            manifest = S.manifest;
            fprintf('[runAudit] Loaded manifest: %s (%d rows)\n', cfg.manifestMatPath, height(manifest));
            if opts.computeHash && any(cellfun(@isempty, manifest.file_hash))
                fprintf('[runAudit] Manifest has no hashes but computeHash=true — rebuilding manifest...\n');
                manifest = buildManifest(cfg, struct('computeHash', true, 'verbose', opts.verbose));
                % Persist rebuilt
                try
                    writetable(manifest, cfg.manifestPath);
                    save(cfg.manifestMatPath, 'manifest', '-v7');
                catch, end
            end
        catch ME
            warning('Failed to load manifest MAT: %s — rebuilding', ME.message);
            manifest = buildManifest(cfg, struct('computeHash', opts.computeHash,'verbose', opts.verbose));
        end
    else
        fprintf('[runAudit] No manifest MAT found — building...\n');
        manifest = buildManifest(cfg, struct('computeHash', opts.computeHash,'verbose', opts.verbose));
        % Save
        try
            if ~exist(cfg.processedRoot,'dir'), mkdir(cfg.processedRoot); end
            if height(manifest)>0
                writetable(manifest, cfg.manifestPath);
            else
                writetable(manifest, cfg.manifestPath); % header-only
            end
            save(cfg.manifestMatPath, 'manifest','-v7');
        catch ME
            warning('Failed to save manifest: %s', ME.message);
        end
    end

    % Run audit
    results = auditDataset(cfg, manifest, opts);

    % Ensure output dirs
    if ~exist(cfg.resultsRoot,'dir'), mkdir(cfg.resultsRoot); end
    if ~exist(cfg.docsRoot,'dir'), mkdir(cfg.docsRoot); end

    % Write MAT
    try
        save(cfg.auditMatPath, 'results', '-v7');
        fprintf('[OK] Wrote audit MAT: %s\n', cfg.auditMatPath);
    catch ME
        warning('Failed to write audit MAT: %s', ME.message);
    end

    % Write JSON (machine-readable)
    try
        jsonStr = jsonencode(results, 'PrettyPrint', true);
        fid = fopen(cfg.auditJsonPath, 'w');
        if fid ~= -1
            fwrite(fid, jsonStr, 'char');
            fclose(fid);
            fprintf('[OK] Wrote audit JSON: %s\n', cfg.auditJsonPath);
        else
            warning('Could not open JSON for writing: %s', cfg.auditJsonPath);
        end
    catch ME
        warning('Failed to write JSON: %s', ME.message);
        % Fallback: try without PrettyPrint
        try
            jsonStr = jsonencode(results);
            fid = fopen(cfg.auditJsonPath,'w');
            fwrite(fid, jsonStr, 'char');
            fclose(fid);
        catch, end
    end

    % Generate human-readable markdown report
    try
        writeAuditReport(results, manifest, cfg);
        fprintf('[OK] Wrote audit report: %s\n', cfg.auditReportPath);
    catch ME
        warning('Failed to write markdown report: %s', ME.message);
    end

    fprintf('\n=== Audit Complete ===\n');
    fprintf('%s\n', results.summary);
    if results.totalImages==0
        fprintf('DATASET NOT PRESENT — DOWNLOAD REQUIRED\n');
    end
end

function writeAuditReport(results, manifest, cfg)
    fid = fopen(cfg.auditReportPath, 'w');
    if fid == -1, error('Cannot open report path for writing'); end
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '# Phase 1 — Dataset Audit Report\n\n');
    fprintf(fid, '> Generated: %s\n\n', results.timestamp);
    fprintf(fid, '> Project root: `%s`\n\n', cfg.projectRoot);
    fprintf(fid, '> Manifest rows: %d\n\n', results.totalImages);
    fprintf(fid, '> Status: **%s**\n\n', results.status);

    fprintf(fid, '---\n\n');

    % Summary table: Dataset | Images | DR labels | Lesion | Vessel | Intended role
    fprintf(fid, '## Summary Table — Dataset Roles\n\n');
    fprintf(fid, '| Dataset | Images | DR labels (known) | Lesion annotations | Vessel annotations | Intended role | Status |\n');
    fprintf(fid, '|---------|--------|-------------------|---------------------|---------------------|----------------|--------|\n');
    roleMap = containers.Map({'APTOS2019','IDRiD','DRIVE','Messidor2'}, ...
                             {'DR grading development','DR grading + lesion analysis','Vessel segmentation','External validation'});
    datasets = {'APTOS2019','IDRiD','DRIVE','Messidor2'};
    for k=1:numel(datasets)
        ds = datasets{k};
        key = matlab.lang.makeValidName(ds);
        n = 0;
        if isfield(results.byDataset, key), n = results.byDataset.(key); end
        nLesion = 0; nVessel = 0; nLabels = 0;
        if isfield(results.annotationAvailabilityPerDataset, key)
            nLesion = results.annotationAvailabilityPerDataset.(key).hasLesion;
            nVessel = results.annotationAvailabilityPerDataset.(key).hasVessel;
        end
        if isfield(results.byGradePerDataset, key)
            s = results.byGradePerDataset.(key);
            nLabels = s.total - s.UNKNOWN;
        end
        status = 'OK';
        if n==0, status = 'NOT PRESENT'; end
        fprintf(fid, '| %s | %d | %d | %d | %d | %s | %s |\n', ds, n, nLabels, nLesion, nVessel, roleMap(ds), status);
    end
    fprintf(fid, '\n');

    % Class distribution
    fprintf(fid, '## Class Distribution (DR Grades)\n\n');
    fprintf(fid, '| Dataset | Level 0 | Level 1 | Level 2 | Level 3 | Level 4 | UNKNOWN | Total |\n');
    fprintf(fid, '|---------|---------|---------|---------|---------|---------|---------|-------|\n');
    for k=1:numel(datasets)
        ds = datasets{k};
        key = matlab.lang.makeValidName(ds);
        if isfield(results.byGradePerDataset, key)
            s = results.byGradePerDataset.(key);
            fprintf(fid, '| %s | %d | %d | %d | %d | %d | %d | %d |\n', ds, s.Level0, s.Level1, s.Level2, s.Level3, s.Level4, s.UNKNOWN, s.total);
        else
            fprintf(fid, '| %s | 0 | 0 | 0 | 0 | 0 | 0 | 0 |\n', ds);
        end
    end
    % Overall row
    fprintf(fid, '| **Overall** | %d | %d | %d | %d | %d | %d | %d |\n', ...
        results.byGrade.Level0, results.byGrade.Level1, results.byGrade.Level2, results.byGrade.Level3, results.byGrade.Level4, results.byGrade.UNKNOWN, results.totalImages);
    fprintf(fid, '\n');

    % Dimensions & channels
    fprintf(fid, '## Image Technical Audit\n\n');
    fprintf(fid, '- Total images in manifest: **%d**\n', results.totalImages);
    if isfield(results.dimensions,'minWidth') && ~isnan(results.dimensions.minWidth)
        fprintf(fid, '- Dimensions: %d x %d (min) .. %d x %d (max), mean %.1f x %.1f\n', ...
            results.dimensions.minWidth, results.dimensions.minHeight, ...
            results.dimensions.maxWidth, results.dimensions.maxHeight, ...
            results.dimensions.meanWidth, results.dimensions.meanHeight);
        if isfield(results.dimensions,'uniqueSizes')
            uniq = results.dimensions.uniqueSizes;
            % Unwrap double-wrapped cell (legacy) if needed
            if iscell(uniq) && numel(uniq)==1 && iscell(uniq{1})
                uniq = uniq{1};
            end
            % Ensure cell array of char vectors
            if iscell(uniq)
                if numel(uniq) <= 20
                    try
                        fprintf(fid, '- Unique sizes (%d): %s\n', numel(uniq), strjoin(uniq, ', '));
                    catch
                        fprintf(fid, '- Unique sizes (%d): (unavailable)\n', numel(uniq));
                    end
                else
                    try
                        fprintf(fid, '- Unique sizes (%d): %s ... (+%d more)\n', numel(uniq), strjoin(uniq(1:10),', '), numel(uniq)-10);
                    catch
                        fprintf(fid, '- Unique sizes (%d): (truncated)\n', numel(uniq));
                    end
                end
            elseif isstring(uniq)
                fprintf(fid, '- Unique sizes (%d): %s\n', numel(uniq), strjoin(uniq, ', '));
            end
        end
    else
        fprintf(fid, '- Dimensions: UNKNOWN (no readable images)\n');
    end
    fprintf(fid, '- Channels: ');
    if isfield(results,'channels')
        fns = fieldnames(results.channels);
        for i=1:numel(fns)
            fprintf(fid, '%s=%d ', fns{i}, results.channels.(fns{i}));
        end
        fprintf(fid, '\n');
    else
        fprintf(fid, 'UNKNOWN\n');
    end
    fprintf(fid, '- By format: ');
    fns = fieldnames(results.byFormat);
    for i=1:numel(fns)
        fprintf(fid, '%s=%d ', fns{i}, results.byFormat.(fns{i}));
    end
    fprintf(fid, '\n');
    fprintf(fid, '- Laterality: ');
    fns = fieldnames(results.lateralityStats);
    for i=1:numel(fns)
        fprintf(fid, '%s=%d ', fns{i}, results.lateralityStats.(fns{i}));
    end
    fprintf(fid, '\n\n');

    % File integrity
    fprintf(fid, '## File Integrity\n\n');
    fprintf(fid, '- Missing files (path in manifest but not on disk): **%d**\n', results.missingCount);
    if results.missingCount>0 && results.missingCount<=20
        for i=1:numel(results.missingFiles)
            fprintf(fid, '  - `%s`\n', results.missingFiles{i});
        end
    elseif results.missingCount>20
        for i=1:10
            fprintf(fid, '  - `%s`\n', results.missingFiles{i});
        end
        fprintf(fid, '  - ... and %d more — see audit_results.json\n', results.missingCount-10);
    end
    fprintf(fid, '- Unreadable/corrupt images: **%d**\n', results.unreadableCount);
    if results.unreadableCount>0 && results.unreadableCount<=10
        for i=1:numel(results.unreadableFiles)
            fprintf(fid, '  - `%s` : %s\n', results.unreadableFiles{i}.file, results.unreadableFiles{i}.error);
        end
    elseif results.unreadableCount>10
        for i=1:5
            fprintf(fid, '  - `%s` : %s\n', results.unreadableFiles{i}.file, results.unreadableFiles{i}.error);
        end
        fprintf(fid, '  - ... and %d more\n', results.unreadableCount-5);
    end
    fprintf(fid, '- Duplicate filename groups (basename collision across datasets): **%d**\n', results.duplicateFilenameGroupCount);
    if results.duplicateFilenameGroupCount>0 && results.duplicateFilenameGroupCount<=10
        for i=1:numel(results.duplicateFilenames)
            fprintf(fid, '  - `%s` x%d\n', results.duplicateFilenames{i}.image_id, results.duplicateFilenames{i}.count);
        end
    end
    fprintf(fid, '- Duplicate hash groups (exact byte duplicates, if hash computed): **%d**\n', results.duplicateHashGroupCount);
    fprintf(fid, '\n');

    % Annotation availability
    fprintf(fid, '## Annotation Availability\n\n');
    fprintf(fid, '- Images with vessel annotation: %d (%.2f%%)\n', results.annotationAvailability.hasVessel, results.annotationAvailability.hasVesselPct);
    fprintf(fid, '- Images with lesion annotation: %d (%.2f%%)\n', results.annotationAvailability.hasLesion, results.annotationAvailability.hasLesionPct);
    fprintf(fid, '\nPer-dataset:\n\n');
    for k=1:numel(datasets)
        ds = datasets{k};
        key = matlab.lang.makeValidName(ds);
        if isfield(results.annotationAvailabilityPerDataset, key)
            a = results.annotationAvailabilityPerDataset.(key);
            fprintf(fid, '- %s: total=%d, vessel=%d, lesion=%d\n', ds, a.total, a.hasVessel, a.hasLesion);
        end
    end
    fprintf(fid, '\n');

    % Patient / leakage readiness
    fprintf(fid, '## Patient / Subject Identifiers\n\n');
    fprintf(fid, '- Unique known patients/subjects: %d\n', results.patientStats.uniquePatientsKnown);
    fprintf(fid, '- Rows with UNKNOWN patient_id: %d / %d\n', results.patientStats.unknownPatientRows, results.patientStats.totalRows);
    fprintf(fid, '- Patient ID available: %s\n', string(results.patientStats.patientIdAvailable));
    if results.patientStats.unknownPatientRows == results.totalImages && results.totalImages>0
        fprintf(fid, '- Note: No dataset provided patient/subject linkage — leakage prevention will use image-level grouping with warnings (see DATA_LEAKAGE_POLICY.md).\n');
    end
    for k=1:numel(datasets)
        ds = datasets{k};
        key = matlab.lang.makeValidName(ds);
        if isfield(results.patientStats.perDataset, key)
            p = results.patientStats.perDataset.(key);
            fprintf(fid, '  - %s: total=%d, uniqueKnown=%d, unknownRows=%d\n', ds, p.total, p.uniqueKnown, p.unknownRows);
        end
    end
    fprintf(fid, '\n');

    % Split
    fprintf(fid, '## Split Assignments (manifest.split)\n\n');
    fns = fieldnames(results.bySplit);
    for i=1:numel(fns)
        fprintf(fid, '- %s : %d\n', fns{i}, results.bySplit.(fns{i}));
    end
    fprintf(fid, '\n');

    % Provenance & caveats
    fprintf(fid, '## Caveats & Next Steps\n\n');
    if results.totalImages==0
        fprintf(fid, '> **DATASET NOT PRESENT — DOWNLOAD REQUIRED**\n\n');
        fprintf(fid, 'No raw images were found. The Phase 1 infrastructure (loader, manifest, audit, splits) is IMPLEMENTED but NOT VALIDATED on real data.\n\n');
        fprintf(fid, 'To validate, download datasets per `docs/DATASET_DOWNLOAD_GUIDE.md` and re-run:\n\n');
        fprintf(fid, '```matlab\n');
        fprintf(fid, 'cfg = datasetConfig();\n');
        fprintf(fid, 'generateManifest();  %% builds data/processed/manifest.csv\n');
        fprintf(fid, 'runAudit();          %% validates and writes results/audit_results.json\n');
        fprintf(fid, 'generateSplits();    %% creates data/splits/*.csv with leakage checks\n');
        fprintf(fid, 'validatePhase1();    %% end-to-end validation\n');
        fprintf(fid, '```\n\n');
    else
        if results.missingCount>0
            fprintf(fid, '- WARN: %d missing files — manifest references files not on disk. Check extraction.\n', results.missingCount);
        end
        if results.unreadableCount>0
            fprintf(fid, '- WARN: %d unreadable/corrupt images — loader reports without crashing.\n', results.unreadableCount);
        end
        if results.duplicateFilenameGroupCount>0
            fprintf(fid, '- NOTE: %d duplicate basename groups — provenance column preserves dataset identity.\n', results.duplicateFilenameGroupCount);
        end
        if ~results.patientStats.patientIdAvailable
            fprintf(fid, '- LIMITATION: No patient IDs available — deterministic image-level splits used; leakage prevention can only be verified where IDs exist (see leakage policy).\n');
        end
    end
    fprintf(fid, '\n---\n\n');
    fprintf(fid, '*This report is generated by `matlab/data/runAudit.m`. Machine-readable details: `results/audit_results.json`*\n');
end
