function metrics = assessContrast(img, retinalMask, cfg)
% assessContrast  Contrast metrics inside retinal field

    if nargin < 3 || isempty(cfg), cfg = qualityConfig(); end
    if nargin < 2 || isempty(retinalMask)
        retinalMask = estimateRetinalMask(img);
    end
    if ndims(img)==3 && size(img,3)==3
        gray = 0.2989*double(img(:,:,1)) + 0.5870*double(img(:,:,2)) + 0.1140*double(img(:,:,3));
    elseif ndims(img)==3 && size(img,3)==1
        gray = double(squeeze(img));
    else
        gray = double(img);
    end
    if max(gray(:)) <= 1, gray = gray*255; end
    retinalMask = logical(retinalMask);
    vals = double(gray(retinalMask));
    if isempty(vals)
        vals = double(gray(:));
    end

    stdVal = std(vals);
    meanVal = mean(vals);
    rms = stdVal / (meanVal + 1e-6); % RMS contrast
    p5 = prctile(vals,5);
    p95 = prctile(vals,95);
    spread = p95 - p5;
    % Entropy
    try
        % Histogram 256 bins
        counts = histcounts(vals, 0:255);
        p = counts / sum(counts);
        p = p(p>0);
        entropyVal = -sum(p .* log2(p));
    catch
        entropyVal = 0;
    end
    % Local contrast: mean of local std in 16x16 blocks
    try
        % Use blockproc if available, else approximate
        if exist('blockproc','file')
            fun = @(block) std(block.data(:));
            localStd = blockproc(gray, [16 16], fun);
            localContrast = mean(localStd(:));
        else
            % Approximate via imfilter
            localMean = imfilter(gray, fspecial('average',[16 16]), 'replicate');
            localVar = imfilter(gray.^2, fspecial('average',[16 16]), 'replicate') - localMean.^2;
            localStdMap = sqrt(max(0, localVar));
            localContrast = mean(localStdMap(retinalMask));
        end
    catch
        localContrast = stdVal;
    end

    % Status per metric, overall contrast_status
    % Std
    if stdVal >= cfg.contrast.std.good
        stdStatus = "GOOD";
    elseif stdVal >= cfg.contrast.std.borderline
        stdStatus = "BORDERLINE";
    else
        stdStatus = "UNGRADABLE";
    end
    % RMS
    if rms >= cfg.contrast.rms.good
        rmsStatus = "GOOD";
    elseif rms >= cfg.contrast.rms.borderline
        rmsStatus = "BORDERLINE";
    else
        rmsStatus = "UNGRADABLE";
    end
    % Entropy
    if entropyVal >= cfg.contrast.entropy.good
        entStatus = "GOOD";
    elseif entropyVal >= cfg.contrast.entropy.borderline
        entStatus = "BORDERLINE";
    else
        entStatus = "UNGRADABLE";
    end

    statuses = [stdStatus, rmsStatus, entStatus];
    if any(statuses=="UNGRADABLE")
        contrastStatus = "UNGRADABLE";
    elseif any(statuses=="BORDERLINE")
        contrastStatus = "BORDERLINE";
    else
        contrastStatus = "GOOD";
    end

    metrics = struct( ...
        'std', stdVal, ...
        'rms', rms, ...
        'spread', spread, ...
        'p5', p5, 'p95', p95, ...
        'entropy', entropyVal, ...
        'localContrast', localContrast, ...
        'stdStatus', stdStatus, ...
        'rmsStatus', rmsStatus, ...
        'entStatus', entStatus, ...
        'contrast_status', contrastStatus ...
    );
end
