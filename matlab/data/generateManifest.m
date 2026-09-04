% generateManifest.m  — Phase 1 manifest generation script
%
%   Run in MATLAB:
%     >> generateManifest
%   or
%     >> generateManifest(projectRoot, 'computeHash', true)
%
%   Generates:
%     data/processed/manifest.csv
%     data/processed/manifest.mat
%   and prints summary.
%
%   Does NOT modify raw data. All paths configurable.

function generateManifest(projectRoot, varargin)
    if nargin < 1 || isempty(projectRoot)
        cfg = datasetConfig();
    else
        cfg = datasetConfig(projectRoot);
    end

    % Parse optional name-value args
    opts = struct('computeHash', false, 'verbose', true);
    for k=1:2:numel(varargin)
        key = lower(string(varargin{k}));
        if k+1 > numel(varargin), break; end
        val = varargin{k+1};
        switch key
            case "computehash"
                opts.computeHash = logical(val);
            case "verbose"
                opts.verbose = logical(val);
            otherwise
                warning('generateManifest:UnknownOption','Unknown option %s ignored', key);
        end
    end

    fprintf('=== DR Screening Phase 1 — Manifest Generation ===\n');
    fprintf('Project root : %s\n', cfg.projectRoot);
    fprintf('Seed         : %d (manifest generation is deterministic, sort-based)\n', cfg.randomSeed);
    fprintf('Compute hash : %d\n', opts.computeHash);

    tic;
    manifest = buildManifest(cfg, opts);
    elapsed = toc;

    % Ensure processed dir exists
    if ~exist(cfg.processedRoot,'dir'), mkdir(cfg.processedRoot); end

    % Save CSV
    if height(manifest) > 0
        % Convert logical to 0/1 for CSV clarity but keep string columns
        % writetable handles logical correctly
        try
            writetable(manifest, cfg.manifestPath);
            fprintf('[OK] Wrote CSV : %s (%d rows)\n', cfg.manifestPath, height(manifest));
        catch ME
            warning('Failed to write manifest CSV: %s', ME.message);
            % Attempt fallback via manual CSV
        end
        try
            save(cfg.manifestMatPath, 'manifest', '-v7');
            fprintf('[OK] Wrote MAT : %s\n', cfg.manifestMatPath);
        catch ME
            warning('Failed to write manifest MAT: %s', ME.message);
        end
    else
        % Still write empty manifest with header so downstream scripts see schema
        try
            writetable(manifest, cfg.manifestPath);
            fprintf('[WARN] Manifest empty — wrote header-only CSV: %s\n', cfg.manifestPath);
        catch ME
            warning('Failed to write empty manifest: %s', ME.message);
        end
        try
            save(cfg.manifestMatPath, 'manifest', '-v7');
        catch
        end
        fprintf('\n');
        fprintf('DATASET NOT PRESENT — DOWNLOAD REQUIRED\n');
        fprintf('No images discovered. Check that raw datasets are extracted under:\n');
        fprintf('  %s\n', cfg.aptosRoot);
        fprintf('  %s\n', cfg.idridRoot);
        fprintf('  %s\n', cfg.driveRoot);
        fprintf('  %s\n', cfg.messidor2Root);
        fprintf('See docs/DATASET_DOWNLOAD_GUIDE.md for manual download steps.\n');
    end

    % Also print summary table for console / docs
    if height(manifest) > 0
        fprintf('\n--- Manifest Summary (Dataset x DR Grade) ---\n');
        % Dataset counts
        [uds, ~, ic] = unique(manifest.dataset);
        for kk=1:numel(uds)
            cnt = sum(ic==kk);
            fprintf('  %-12s : %4d images\n', uds(kk), cnt);
        end
        fprintf('\n--- Class Distribution (where dr_grade available) ---\n');
        grades = manifest.dr_grade;
        valid = ~isnan(grades);
        if any(valid)
            for g=0:4
                n = sum(grades==g);
                fprintf('  Level %d : %4d (%.1f%% of labeled)\n', g, n, 100*n/sum(valid));
            end
            fprintf('  Labeled total: %d / %d (%.1f%%)\n', sum(valid), height(manifest), 100*sum(valid)/height(manifest));
        else
            fprintf('  No dr_grade labels found (all NaN) — labels UNKNOWN\n');
        end
        fprintf('\n--- Annotation Availability ---\n');
        fprintf('  has_vessel_annotation : %d\n', sum(manifest.has_vessel_annotation));
        fprintf('  has_lesion_annotation : %d\n', sum(manifest.has_lesion_annotation));
        fprintf('\nElapsed: %.2f sec\n', elapsed);
    end
end
