function metrics = assessFocus(img, retinalMask, cfg)
% assessFocus  Focus/sharpness metrics (Variance of Laplacian, Tenengrad, Brenner, edge density)
%
%   metrics = assessFocus(img, retinalMask, cfg)
%
%   Inputs:
%     img - HxWx3 RGB or HxW grayscale, uint8 0-255 or double
%     retinalMask - HxW logical, true=retina (optional, estimated if empty)
%     cfg - qualityConfig struct (optional, THEORETICAL thresholds)
%
%   Output metrics struct:
%     .laplacian, .tenengrad, .brenner, .edgeDensity
%     .focus_status  one of {'GOOD','BORDERLINE','UNGRADABLE'}
%     .details

    if nargin < 3 || isempty(cfg), cfg = qualityConfig(); end
    if nargin < 2 || isempty(retinalMask)
        retinalMask = estimateRetinalMask(img);
    end
    % To grayscale double
    if ndims(img)==3 && size(img,3)==3
        gray = 0.2989*double(img(:,:,1)) + 0.5870*double(img(:,:,2)) + 0.1140*double(img(:,:,3));
    elseif ndims(img)==3 && size(img,3)==1
        gray = double(squeeze(img));
    else
        gray = double(img);
    end
    if max(gray(:)) <= 1, gray = gray*255; end
    % Ensure mask size matches
    if ~isequal(size(retinalMask), size(gray))
        retinalMask = true(size(gray));
    end
    retinalMask = logical(retinalMask);
    if nnz(retinalMask) < 100
        retinalMask = true(size(gray));
    end

    % Variance of Laplacian
    try
        lap = fspecial('laplacian', 0);
        lapImg = imfilter(gray, lap, 'replicate', 'same', 'conv');
        % Use double, var inside mask
        vals = lapImg(retinalMask);
        lapVar = var(vals);
    catch
        lapVar = 0;
    end

    % Tenengrad (mean of Sobel gradient magnitude squared inside mask)
    try
        [Gx, Gy] = imgradientxy(gray, 'sobel');
        Gmag = sqrt(Gx.^2 + Gy.^2);
        vals = Gmag(retinalMask);
        tenengrad = mean(vals.^2);
        % Alternative: mean magnitude
        % tenengrad = mean(vals);
    catch
        tenengrad = 0;
    end

    % Brenner gradient: sum (I(x+2,y)-I(x,y))^2
    try
        diff = gray(:,3:end) - gray(:,1:end-2);
        brennerVals = diff.^2;
        % Need mask for brenner: approximate by eroding retinalMask by 2
        maskB = retinalMask(:,2:end-1);
        % brennerVals size H x (W-2), maskB is H x (W-2) approx
        if size(brennerVals,2)==size(maskB,2)
            brenner = sum(brennerVals(maskB));
        else
            brenner = sum(brennerVals(:));
        end
    catch
        brenner = 0;
    end

    % Edge density via Canny
    try
        % Normalize gray to 0-1 for edge
        grayN = mat2gray(gray);
        % Adaptive thresholds: use 0.1 and 0.25 as low/high
        edges = edge(grayN, 'Canny', [0.08 0.22]);
        % Count edge pixels inside retinal mask
        edgeCount = nnz(edges & retinalMask);
        edgeDensity = edgeCount / nnz(retinalMask);
    catch
        edgeDensity = 0;
    end

    % Status per metric (THEORETICAL)
    % Laplacian
    if lapVar >= cfg.focus.laplacian.good
        lapStatus = "GOOD";
    elseif lapVar >= cfg.focus.laplacian.borderline
        lapStatus = "BORDERLINE";
    else
        lapStatus = "UNGRADABLE";
    end
    % Tenengrad
    if tenengrad >= cfg.focus.tenengrad.good
        tenStatus = "GOOD";
    elseif tenengrad >= cfg.focus.tenengrad.borderline
        tenStatus = "BORDERLINE";
    else
        tenStatus = "UNGRADABLE";
    end
    % Edge density
    if edgeDensity >= cfg.focus.edgeDensity.good
        edgeStatus = "GOOD";
    elseif edgeDensity >= cfg.focus.edgeDensity.borderline
        edgeStatus = "BORDERLINE";
    else
        edgeStatus = "UNGRADABLE";
    end

    % Overall focus_status: worst of the three, but Tenengrad weighted
    % If any UNGRADABLE => UNGRADABLE, else if any BORDERLINE => BORDERLINE else GOOD
    statuses = [lapStatus, tenStatus, edgeStatus];
    if any(statuses=="UNGRADABLE")
        focusStatus = "UNGRADABLE";
    elseif any(statuses=="BORDERLINE")
        focusStatus = "BORDERLINE";
    else
        focusStatus = "GOOD";
    end

    metrics = struct( ...
        'laplacian', lapVar, ...
        'tenengrad', tenengrad, ...
        'brenner', brenner, ...
        'edgeDensity', edgeDensity, ...
        'lapStatus', lapStatus, ...
        'tenStatus', tenStatus, ...
        'edgeStatus', edgeStatus, ...
        'focus_status', focusStatus, ...
        'details', sprintf('Laplacian %.1f Tenengrad %.1f Edge %.3f', lapVar, tenengrad, edgeDensity) ...
    );
end
