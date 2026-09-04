function report = calibrateQualityThresholds(varargin)
% calibrateQualityThresholds  Analyze quality metric distributions and suggest thresholds
%
%   report = calibrateQualityThresholds()
%   report = calibrateQualityThresholds('resultsPath', p, 'useExternal', false)
%
%   Does NOT claim clinical validation. If manual labels unavailable, marks
%   QUALITY LABELS = NOT AVAILABLE and does not compute ROC/AUC.
%
%   Uses dataset distributions (percentiles) on TRAIN split only to avoid leakage.
%   Messidor2 is observed but not used for tuning unless explicitly allowed.

    p = inputParser;
    addParameter(p,'resultsPath','');
    addParameter(p,'useExternal',false);
    addParameter(p,'verbose',true);
    parse(p,varargin{:});
    opts = p.Results;

    cfgQ = qualityConfig();
    cfgData = datasetConfig();

    resultsPath = opts.resultsPath;
    if isempty(resultsPath), resultsPath = fullfile(cfgQ.resultsQualityRoot,'quality_results.csv'); end

    if ~exist(resultsPath,'file')
        error('quality_results.csv not found: %s. Run runQualityAssessment first.', resultsPath);
    end
    Tq = readtable(resultsPath,'TextType','string');
    % Load splits to identify TRAIN
    try
        trainIds = readtable(fullfile(cfgData.splitsRoot,'train.csv'),'TextType','string');
        trainSet = containers.Map('KeyType','char','ValueType','logical');
        for r=1:height(trainIds)
            key = char(trainIds.image_id(r) + "_" + trainIds.dataset(r));
            trainSet(key)=true;
        end
        isTrain = false(height(Tq),1);
        for r=1:height(Tq)
            key = char(Tq.image_id(r) + "_" + Tq.dataset(r));
            if isKey(trainSet,key), isTrain(r)=true; end
        end
    catch
        % If splits not available, use all non-external as train proxy
        isTrain = Tq.dataset~="Messidor2";
    end

    % Exclude external for calibration (unless useExternal true)
    if ~opts.useExternal
        calibIdx = isTrain & Tq.dataset~="Messidor2";
    else
        calibIdx = isTrain;
    end

    metricsList = {'focus_laplacian','focus_tenengrad','illum_mean','fov_areaFraction','glare_fraction','vignetting_score','contrast_std','contrast_entropy','retinal_visibleFraction','overall_quality_score'};
    % Map to column names in Tq
    colMap = containers.Map( ...
        {'focus_laplacian','focus_tenengrad','illum_mean','fov_areaFraction','glare_fraction','vignetting_score','contrast_std','contrast_entropy','retinal_visibleFraction','overall_quality_score'}, ...
        {'focus_laplacian','focus_tenengrad','illum_mean','fov_areaFraction','glare_fraction','vignetting_score','contrast_std','contrast_entropy','retinal_visibleFraction','overall_quality_score'} ...
    );

    report = struct();
    report.timestamp = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    report.version = cfgQ.version;
    report.status = char(cfgQ.status);
    report.labelsAvailable = cfgQ.labelsAvailable;
    report.nTotal = height(Tq);
    report.nCalib = sum(calibIdx);
    report.nExternal = sum(Tq.dataset=="Messidor2");
    report.note = 'THEORETICAL / INITIAL — NOT clinically validated. QUALITY LABELS = NOT AVAILABLE, so no ROC/AUC.';

    % For each metric, compute percentiles on calib set
    for k=1:numel(metricsList)
        m = metricsList{k};
        col = colMap(m);
        if ~ismember(col, Tq.Properties.VariableNames), continue; end
        vals = Tq.(col)(calibIdx);
        vals = vals(~isnan(vals) & isfinite(vals));
        if isempty(vals), continue; end
        p = prctile(vals, [5 10 25 50 75 90 95]);
        report.(matlab.lang.makeValidName(m)) = struct('p5',p(1),'p10',p(2),'p25',p(3),'p50',p(4),'p75',p(5),'p90',p(6),'p95',p(7),'mean',mean(vals),'std',std(vals),'min',min(vals),'max',max(vals));
    end

    % Suggest thresholds as percentiles (example: focus GOOD > p50, BORDERLINE p25-p50)
    % Do not overwrite config, just report
    report.suggested = struct();
    try
        lap = report.focus_laplacian;
        report.suggested.focus_laplacian_good = lap.p50;
        report.suggested.focus_laplacian_borderline = lap.p25;
    catch
    end
    try
        illum = report.illum_mean;
        report.suggested.illum_low = report.illum_mean.p10;
        report.suggested.illum_high = report.illum_mean.p90;
    catch
    end

    % Save
    try
        jsonStr = jsonencode(report,'PrettyPrint',true);
        fid=fopen(fullfile(cfgQ.resultsQualityRoot,'calibration_report.json'),'w');
        fwrite(fid, jsonStr,'char'); fclose(fid);
        save(fullfile(cfgQ.resultsQualityRoot,'calibration_report.mat'), 'report','-v7');
    catch
    end

    if opts.verbose
        fprintf('[calibrateQualityThresholds] Calib %d / total %d (external %d)\n', report.nCalib, report.nTotal, report.nExternal);
        fprintf(' Note: %s\n', report.note);
    end
end
