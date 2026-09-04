function stats = runQualityAssessment(varargin)
% runQualityAssessment  Batch quality assessment over manifest (7872 images)
%
%   stats = runQualityAssessment()
%   stats = runQualityAssessment('manifestPath', p, 'useExternal', false, 'maxImages', Inf, 'saveExamples', 5)
%
%   Processes data/processed/manifest.csv (or manifest_with_quality.csv if exists)
%   Uses datasetConfig + qualityConfig, supports RGB/gray, handles unreadable.
%   Writes results/quality/quality_results.csv, quality_summary.json, etc.
%   Honors Messidor2 external isolation (not used for threshold tuning).
%
%   Options (name-value):
%     'manifestPath' : path to manifest.csv (default cfg.manifestPath)
%     'outputRoot'   : results/quality (default cfg.resultsQualityRoot)
%     'useExternal'  : true/false (default true for processing, but thresholds not tuned on external)
%     'maxImages'    : limit for testing (default Inf = all)
%     'saveExamples' : number of examples per status to save images (default 5)
%     'enhance'      : true/false whether to enhance BORDERLINE (default true)
%     'verbose'      : true/false

    p = inputParser;
    addParameter(p,'manifestPath','');
    addParameter(p,'outputRoot','');
    addParameter(p,'useExternal',true);
    addParameter(p,'maxImages',Inf);
    addParameter(p,'saveExamples',5);
    addParameter(p,'enhance',true);
    addParameter(p,'verbose',true);
    parse(p,varargin{:});
    opts = p.Results;

    cfgData = datasetConfig();
    cfgQ = qualityConfig();

    manifestPath = opts.manifestPath;
    if isempty(manifestPath), manifestPath = cfgData.manifestPath; end
    outputRoot = opts.outputRoot;
    if isempty(outputRoot), outputRoot = cfgQ.resultsQualityRoot; end
    if ~exist(outputRoot,'dir'), mkdir(outputRoot); end
    examplesRoot = fullfile(outputRoot,'examples');
    if ~exist(examplesRoot,'dir'), mkdir(examplesRoot); end

    % Load manifest
    if ~exist(manifestPath,'file')
        error('Manifest not found: %s', manifestPath);
    end
    T = readtable(manifestPath, 'TextType','string');
    nTotal = height(T);
    if opts.verbose
        fprintf('[runQualityAssessment] Manifest %s : %d rows\n', manifestPath, nTotal);
    end
    % Optionally exclude external for threshold tuning, but we still process for reporting
    % For now process all if useExternal true, else filter out Messidor2
    if ~opts.useExternal
        isExt = T.dataset=="Messidor2";
        T = T(~isExt,:);
        nTotal = height(T);
        if opts.verbose, fprintf(' Excluding external Messidor2, %d rows remain\n', nTotal); end
    end
    if isfinite(opts.maxImages) && opts.maxImages < nTotal
        T = T(1:opts.maxImages,:);
        nTotal = height(T);
        if opts.verbose, fprintf(' Limited to %d images for testing\n', nTotal); end
    end

    % Preallocate results table
    % Define columns for quality_results.csv
    varNames = {'image_id','dataset','file_path','split','quality_status','overall_quality_score','quality_reasons','failed_metrics','borderline_metrics','recapture_code','recapture_human', ...
                'focus_laplacian','focus_tenengrad','focus_edgeDensity','focus_status', ...
                'illum_mean','illum_darkFraction','illum_satFraction','illum_uniformity','illum_status', ...
                'fov_areaFraction','fov_diameter','fov_completeness','fov_truncated','fov_status', ...
                'glare_fraction','glare_regionCount','glare_status', ...
                'vignetting_score','vignetting_status', ...
                'contrast_std','contrast_rms','contrast_entropy','contrast_status', ...
                'retinal_areaFraction','retinal_visibleFraction','retinal_status', ...
                'enhanced','enhancement_applied','enhancement_improved','before_score','after_score'};
    nVars = numel(varNames);
    % Use cell array for building
    rows = cell(nTotal, nVars);
    % For enhancement results
    enhRows = {};

    ticTotal = tic;
    nProcessed = 0; nFailed = 0; nGood=0; nBorder=0; nUngrad=0;
    % For dataset-aware stats
    datasetStats = containers.Map('KeyType','char','ValueType','any');

    for i=1:nTotal
        imgPath = char(T.file_path_absolute(i));
        % Fallback to file_path if absolute missing
        if ~exist(imgPath,'file')
            alt = fullfile(cfgData.projectRoot, char(T.file_path(i)));
            if exist(alt,'file'), imgPath = alt; end
        end
        image_id = char(T.image_id(i));
        dataset = char(T.dataset(i));
        split = char(T.split(i));

        try
            result = assessImageQuality(imgPath, cfgQ);
        catch ME
            % Should not crash, but handle
            result = struct('quality_status',"UNGRADABLE",'quality_reasons',["UNREADABLE_IMAGE"],'overall_quality_score',0,'failed_metrics',["EXCEPTION"],'borderline_metrics',string([]),'recaputure_code',"RECAPTURE_UNREADABLE",'recapture_human',"Exception during assessment",'focus',struct('laplacian',NaN),'illumination',struct('mean',NaN),'fov',struct('areaFraction',0),'glare',struct('fraction',NaN),'vignetting',struct('score',NaN),'contrast',struct('std',NaN),'retinal',struct('areaFraction',0));
            result.quality_status = "UNGRADABLE";
        end

        % Enhance if BORDERLINE
        enhancedFlag = false;
        enhApplied = "";
        enhImproved = false;
        beforeScore = result.overall_quality_score;
        afterScore = beforeScore;
        if opts.enhance && result.quality_status=="BORDERLINE"
            try
                [img, info, err] = loadImageSafe(imgPath);
                if info.readable
                    [enhImg, log] = enhanceBorderlineImage(img, result, cfgQ);
                    enhancedFlag = true;
                    enhApplied = strjoin(cellstr(log.applied), ';');
                    if isfield(log,'after') && isfield(log.after,'overall_quality_score')
                        afterScore = log.after.overall_quality_score;
                    end
                    enhImproved = log.improved;
                    % Optionally save BEFORE/AFTER example (limited)
                    % Save only for first few borderline per dataset
                    % We will handle example saving below
                    % Record enhancement result row
                    enhRows{end+1,1} = {image_id, dataset, char(result.quality_status), beforeScore, afterScore, enhImproved, enhApplied, char(log.recapture_human)}; %#ok<AGROW>
                    % Decide whether to keep enhanced: if log.failed, keep original (do not replace)
                    % For manifest, we still report original status but note enhancement
                else
                    enhApplied = "UNREADABLE";
                end
            catch
                enhApplied = "ENHANCEMENT_EXCEPTION";
            end
        end

        % Fill row
        % Helper to get field safely
        try, lap = result.focus.laplacian; catch, lap=NaN; end
        try, ten = result.focus.tenengrad; catch, ten=NaN; end
        try, edgeD = result.focus.edgeDensity; catch, edgeD=NaN; end
        try, fStatus = char(result.focus.focus_status); catch, fStatus="UNKNOWN"; end
        try, iMean = result.illumination.mean; catch, iMean=NaN; end
        try, iDark = result.illumination.darkFraction; catch, iDark=NaN; end
        try, iSat = result.illumination.saturatedFraction; catch, iSat=NaN; end
        try, iUni = result.illumination.uniformity; catch, iUni=NaN; end
        try, iStatus = char(result.illumination.illumination_status); catch, iStatus="UNKNOWN"; end
        try, fovArea = result.fov.areaFraction; catch, fovArea=NaN; end
        try, fovDiam = result.fov.diameter; catch, fovDiam=NaN; end
        try, fovComp = result.fov.completeness; catch, fovComp=NaN; end
        try, fovTrunc = result.fov.truncated; catch, fovTrunc=false; end
        try, fovStatus = char(result.fov.fov_status); catch, fovStatus="UNKNOWN"; end
        try, gFrac = result.glare.fraction; catch, gFrac=NaN; end
        try, gCount = result.glare.regionCount; catch, gCount=0; end
        try, gStatus = char(result.glare.glare_status); catch, gStatus="UNKNOWN"; end
        try, vScore = result.vignetting.score; catch, vScore=NaN; end
        try, vStatus = char(result.vignetting.vignetting_status); if vStatus=="", vStatus=char(result.vignetting.status); end; catch, vStatus="UNKNOWN"; end
        try, cStd = result.contrast.std; catch, cStd=NaN; end
        try, cRms = result.contrast.rms; catch, cRms=NaN; end
        try, cEnt = result.contrast.entropy; catch, cEnt=NaN; end
        try, cStatus = char(result.contrast.contrast_status); catch, cStatus="UNKNOWN"; end
        try, rArea = result.retinal.areaFraction; catch, rArea=NaN; end
        try, rVis = result.retinal.visibleFraction; catch, rVis=NaN; end
        try, rStatus = char(result.retinal.retinal_status); catch, rStatus="UNKNOWN"; end

        rows{i,1} = image_id;
        rows{i,2} = dataset;
        rows{i,3} = char(T.file_path(i));
        rows{i,4} = split;
        rows{i,5} = char(result.quality_status);
        rows{i,6} = result.overall_quality_score;
        rows{i,7} = strjoin(cellstr(result.quality_reasons), ';');
        rows{i,8} = strjoin(cellstr(result.failed_metrics), ';');
        rows{i,9} = strjoin(cellstr(result.borderline_metrics), ';');
        rows{i,10} = char(result.recaputure_code);
        rows{i,11} = char(result.recapture_human);
        rows{i,12} = lap;
        rows{i,13} = ten;
        rows{i,14} = edgeD;
        rows{i,15} = fStatus;
        rows{i,16} = iMean;
        rows{i,17} = iDark;
        rows{i,18} = iSat;
        rows{i,19} = iUni;
        rows{i,20} = iStatus;
        rows{i,21} = fovArea;
        rows{i,22} = fovDiam;
        rows{i,23} = fovComp;
        rows{i,24} = fovTrunc;
        rows{i,25} = fovStatus;
        rows{i,26} = gFrac;
        rows{i,27} = gCount;
        rows{i,28} = gStatus;
        rows{i,29} = vScore;
        rows{i,30} = vStatus;
        rows{i,31} = cStd;
        rows{i,32} = cRms;
        rows{i,33} = cEnt;
        rows{i,34} = cStatus;
        rows{i,35} = rArea;
        rows{i,36} = rVis;
        rows{i,37} = rStatus;
        rows{i,38} = enhancedFlag;
        rows{i,39} = enhApplied;
        rows{i,40} = enhImproved;
        rows{i,41} = beforeScore;
        rows{i,42} = afterScore;

        nProcessed = nProcessed + 1;
        if result.quality_status=="GOOD", nGood=nGood+1;
        elseif result.quality_status=="BORDERLINE", nBorder=nBorder+1;
        else, nUngrad=nUngrad+1;
        end
        if ~isfield(result,'metric_failed') && result.quality_status=="UNGRADABLE" && any(result.quality_reasons=="UNREADABLE_IMAGE")
            nFailed = nFailed + 1;
        end

        % Progress
        if opts.verbose && mod(i,200)==0
            elapsed = toc(ticTotal);
            fprintf('[runQualityAssessment] %d/%d (%.1f%%) GOOD %d BORDERLINE %d UNGRADABLE %d  elapsed %.1fs  avg %.2fs/img\n', i, nTotal, 100*i/nTotal, nGood, nBorder, nUngrad, elapsed, elapsed/i);
        end

        % Save examples (representative subset)
        if opts.saveExamples > 0
            % Save first few per status per dataset
            key = sprintf('%s_%s', dataset, char(result.quality_status));
            if ~isKey(datasetStats, key)
                datasetStats(key) = 0;
            end
            cnt = datasetStats(key);
            if cnt < opts.saveExamples
                try
                    [img, info, ~] = loadImageSafe(imgPath);
                    if info.readable
                        % Resize for example (256)
                        thumb = imresize(img, [256 NaN]);
                        outName = sprintf('%s_%s_%s.png', dataset, char(result.quality_status), image_id);
                        outName = strrep(outName, '/', '_');
                        outName = strrep(outName, '\', '_');
                        imwrite(thumb, fullfile(examplesRoot, outName));
                        % If borderline and enhanced, also save enhanced
                        if enhancedFlag
                            thumbE = imresize(enhImg, [256 NaN]);
                            outNameE = sprintf('%s_%s_%s_enhanced.png', dataset, char(result.quality_status), image_id);
                            outNameE = strrep(outNameE, '/', '_');
                            imwrite(thumbE, fullfile(examplesRoot, outNameE));
                        end
                        datasetStats(key) = cnt + 1;
                    end
                catch
                end
            end
        end
    end

    totalTime = toc(ticTotal);
    avgTime = totalTime / max(1,nProcessed);

    % Create table and save
    Tq = cell2table(rows, 'VariableNames', varNames);
    % Ensure output dir
    if ~exist(outputRoot,'dir'), mkdir(outputRoot); end
    writetable(Tq, fullfile(outputRoot,'quality_results.csv'));
    % Also save MAT
    save(fullfile(outputRoot,'quality_results.mat'), 'Tq', '-v7');

    % Enhancement results
    if ~isempty(enhRows)
        enhVarNames = {'image_id','dataset','before_status','before_score','after_score','improved','applied','after_human'};
        Te = cell2table(vertcat(enhRows{:}), 'VariableNames', enhVarNames);
        writetable(Te, fullfile(outputRoot,'enhancement_results.csv'));
        save(fullfile(outputRoot,'enhancement_results.mat'), 'Te', '-v7');
    else
        % Write header-only
        enhVarNames = {'image_id','dataset','before_status','before_score','after_score','improved','applied','after_human'};
        Te = cell2table(cell(0,8), 'VariableNames', enhVarNames);
        writetable(Te, fullfile(outputRoot,'enhancement_results.csv'));
    end

    % Quality summary
    summary = struct();
    summary.timestamp = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    summary.version = cfgQ.version;
    summary.totalImages = nTotal;
    summary.processed = nProcessed;
    summary.failed = nFailed;
    summary.good = nGood;
    summary.borderline = nBorder;
    summary.ungradable = nUngrad;
    summary.totalTime = totalTime;
    summary.avgTimePerImage = avgTime;
    summary.cfgStatus = char(cfgQ.status);
    summary.labelsAvailable = cfgQ.labelsAvailable;
    % Per-dataset breakdown
    if height(Tq)>0
        [uds,~,ic]=unique(Tq.dataset);
        perDs = struct();
        for k=1:numel(uds)
            ds = char(uds(k));
            idx = Tq.dataset==string(ds);
            perDs.(matlab.lang.makeValidName(ds)) = struct('total',sum(idx),'good',sum(Tq.quality_status(idx)=="GOOD"),'borderline',sum(Tq.quality_status(idx)=="BORDERLINE"),'ungradable',sum(Tq.quality_status(idx)=="UNGRADABLE"));
        end
        summary.perDataset = perDs;
    end
    % Save JSON
    try
        jsonStr = jsonencode(summary, 'PrettyPrint', true);
        fid=fopen(fullfile(outputRoot,'quality_summary.json'),'w');
        fwrite(fid, jsonStr,'char'); fclose(fid);
    catch
        jsonStr=jsonencode(summary);
        fid=fopen(fullfile(outputRoot,'quality_summary.json'),'w');
        fwrite(fid, jsonStr,'char'); fclose(fid);
    end
    save(fullfile(outputRoot,'quality_summary.mat'), 'summary','-v7');

    % Thresholds file (copy of config)
    try
        thresh = struct('version',cfgQ.version,'date',cfgQ.date,'status',char(cfgQ.status),'focus',cfgQ.focus,'illumination',cfgQ.illumination,'fov',cfgQ.fov,'glare',cfgQ.glare,'vignetting',cfgQ.vignetting,'contrast',cfgQ.contrast,'retinal',cfgQ.retinal,'decision',cfgQ.decision);
        jsonStr=jsonencode(thresh,'PrettyPrint',true);
        fid=fopen(fullfile(outputRoot,'quality_thresholds.json'),'w');
        fwrite(fid, jsonStr,'char'); fclose(fid);
    catch
    end

    % Manifest with quality (derived, not overwriting original)
    try
        % Merge quality_status and score into manifest copy
        Torig = readtable(cfgData.manifestPath,'TextType','string');
        % Map by image_id (assume unique per dataset? Use file_path as key for safety)
        % Simple: join on image_id + dataset
        % Create map from quality results
        qMap = containers.Map('KeyType','char','ValueType','any');
        for r=1:height(Tq)
            key = char(Tq.image_id(r) + "_" + Tq.dataset(r));
            qMap(key) = {char(Tq.quality_status(r)), Tq.overall_quality_score(r), char(Tq.quality_reasons(r))};
        end
        % Add columns to Torig
        nOrig = height(Torig);
        qStatus = strings(nOrig,1); qScore = NaN(nOrig,1); qReasons = strings(nOrig,1);
        for r=1:nOrig
            key = char(Torig.image_id(r) + "_" + Torig.dataset(r));
            if isKey(qMap,key)
                v = qMap(key);
                qStatus(r) = string(v{1});
                qScore(r) = v{2};
                qReasons(r) = string(v{3});
            else
                qStatus(r) = "UNKNOWN";
                qScore(r) = NaN;
                qReasons(r) = "NOT_PROCESSED";
            end
        end
        Torig.quality_status = qStatus;
        Torig.quality_score = qScore;
        Torig.quality_reasons = qReasons;
        writetable(Torig, cfgQ.manifestWithQualityPath);
    catch ME
        warning('Failed to write manifest_with_quality: %s', ME.message);
    end

    stats = summary;
    stats.Tq = Tq;
    if opts.verbose
        fprintf('[runQualityAssessment] DONE %d images GOOD %d BORDERLINE %d UNGRADABLE %d  time %.1fs avg %.3fs/img\n', nTotal, nGood, nBorder, nUngrad, totalTime, avgTime);
        fprintf(' Results: %s\n', fullfile(outputRoot,'quality_results.csv'));
    end
end
