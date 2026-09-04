function generateQualityReport(varargin)
% generateQualityReport  Create human-readable markdown + JSON summaries
%
%   generateQualityReport()
%   Must be called after runQualityAssessment

    p = inputParser;
    addParameter(p,'verbose',true);
    parse(p,varargin{:});
    opts = p.Results;

    cfgQ = qualityConfig();
    cfgData = datasetConfig();

    resultsPath = fullfile(cfgQ.resultsQualityRoot,'quality_results.csv');
    summaryPath = fullfile(cfgQ.resultsQualityRoot,'quality_summary.json');
    if ~exist(resultsPath,'file')
        warning('quality_results.csv not found');
        return;
    end
    Tq = readtable(resultsPath,'TextType','string');
    try
        summary = jsondecode(fileread(summaryPath));
    catch
        summary = struct('totalImages', height(Tq));
    end

    outMd = fullfile(cfgQ.resultsQualityRoot,'quality_report.md');
    fid = fopen(outMd,'w');
    if fid==-1, error('Cannot write %s', outMd); end
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '# Phase 2 — Quality Assessment Report\n\n');
    fprintf(fid, '> Generated: %s\n\n', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
    fprintf(fid, '> Version: %s (%s)\n\n', cfgQ.version, cfgQ.status);
    fprintf(fid, '> Total images: %d (GOOD %d BORDERLINE %d UNGRADABLE %d)\n\n', summary.totalImages, summary.good, summary.borderline, summary.ungradable);
    fprintf(fid, '> Avg time: %.3f s/img, total %.1f s\n\n', summary.avgTimePerImage, summary.totalTime);
    fprintf(fid, '> **This is a research prototype and the quality thresholds are not clinically validated.**\n\n');
    fprintf(fid, '---\n\n');

    % Per-dataset breakdown
    fprintf(fid, '## Per-Dataset Quality\n\n');
    fprintf(fid, '| Dataset | Total | GOOD | BORDERLINE | UNGRADABLE | GOOD %% |\n');
    fprintf(fid, '|---------|-------|------|------------|------------|--------|\n');
    [uds,~,ic]=unique(Tq.dataset);
    for k=1:numel(uds)
        ds=char(uds(k));
        idx=Tq.dataset==string(ds);
        tot=sum(idx); g=sum(Tq.quality_status(idx)=="GOOD"); b=sum(Tq.quality_status(idx)=="BORDERLINE"); u=sum(Tq.quality_status(idx)=="UNGRADABLE");
        fprintf(fid, '| %s | %d | %d | %d | %d | %.1f |\n', ds, tot, g, b, u, 100*g/tot);
    end
    fprintf(fid, '\n');

    % Distributions (focus, illumination, etc.)
    fprintf(fid, '## Metric Distributions (median [p25-p75])\n\n');
    fprintf(fid, '| Metric | Overall median | APTOS median | IDRiD median | DRIVE median | Messidor2 median |\n');
    fprintf(fid, '|--------|---------------|--------------|--------------|--------------|------------------|\n');
    metrics = {'focus_laplacian','illum_mean','fov_areaFraction','glare_fraction','vignetting_score','contrast_std','overall_quality_score'};
    for m=1:numel(metrics)
        col = metrics{m};
        if ~ismember(col, Tq.Properties.VariableNames), continue; end
        valsAll = Tq.(col);
        valsAll = valsAll(~isnan(valsAll));
        medAll = median(valsAll);
        % Per dataset
        meds = [];
        for ds=["APTOS2019","IDRiD","DRIVE","Messidor2"]
            vals = Tq.(col)(Tq.dataset==ds);
            vals = vals(~isnan(vals));
            if ~isempty(vals), meds(end+1)=median(vals); else, meds(end+1)=NaN; end %#ok<AGROW>
        end
        fprintf(fid, '| %s | %.2f | %.2f | %.2f | %.2f | %.2f |\n', col, medAll, meds(1), meds(2), meds(3), meds(4));
    end
    fprintf(fid, '\n');

    % Failures
    fprintf(fid, '## Quality Failures (top reasons)\n\n');
    if ismember('quality_reasons', Tq.Properties.VariableNames)
        allReasons = strjoin(Tq.quality_reasons, ';');
        % Count reasons
        reasonsList = strsplit(allReasons, ';');
        reasonsList = strtrim(reasonsList);
        reasonsList = reasonsList(~cellfun('isempty', reasonsList));
        [uR,~,icR]=unique(reasonsList);
        counts = accumarray(icR,1);
        [sortedCounts, idx]=sort(counts,'descend');
        for k=1:min(10, numel(uR))
            fprintf(fid, '- %s : %d\n', uR{idx(k)}, sortedCounts(k));
        end
    end
    fprintf(fid, '\n');

    % Enhancement summary if exists
    enhPath = fullfile(cfgQ.resultsQualityRoot,'enhancement_results.csv');
    if exist(enhPath,'file')
        try
            Te = readtable(enhPath,'TextType','string');
            fprintf(fid, '## Enhancement (BORDERLINE)\n\n');
            fprintf(fid, '- Enhanced images: %d\n', height(Te));
            if height(Te)>0
                fprintf(fid, '- Improved: %d (%.1f%%)\n', sum(Te.improved), 100*mean(Te.improved));
                fprintf(fid, '- Mean before score: %.1f, after: %.1f\n', mean(Te.before_score), mean(Te.after_score));
            end
            fprintf(fid, '\n');
        catch
        end
    end

    % Calibration note
    fprintf(fid, '## Calibration\n\n');
    fprintf(fid, '- Thresholds: THEORETICAL / INITIAL (see `quality_thresholds.json`)\n');
    fprintf(fid, '- QUALITY LABELS = NOT AVAILABLE — no ROC/AUC\n');
    fprintf(fid, '- External Messidor2 observed but not used for tuning\n');
    fprintf(fid, '\n');

    % Limitations
    fprintf(fid, '## Limitations\n\n');
    fprintf(fid, '- Research prototype, not a clinical device\n');
    fprintf(fid, '- Thresholds not clinically validated\n');
    fprintf(fid, '- Retinal mask estimation may fail on severely degraded images (fallback to whole image)\n');
    fprintf(fid, '- Glare vs optic disc distinction heuristic, not perfect\n');
    fprintf(fid, '\n');

    if opts.verbose
        fprintf('[generateQualityReport] Wrote %s\n', outMd);
    end
end
