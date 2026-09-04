function metrics = assessGlare(img, retinalMask, cfg)
% assessGlare  Detect large saturated/glare artifacts vs normal bright structures
%
%   metrics = assessGlare(img, retinalMask, cfg)

    if nargin < 3 || isempty(cfg), cfg = qualityConfig(); end
    if nargin < 2 || isempty(retinalMask)
        retinalMask = estimateRetinalMask(img);
    end
    if ndims(img)==3 && size(img,3)==3
        % Use max channel for glare (specular highlights are white in all channels)
        % Also use luminance
        gray = 0.2989*double(img(:,:,1)) + 0.5870*double(img(:,:,2)) + 0.1140*double(img(:,:,3));
        maxChan = max(max(double(img(:,:,1)), double(img(:,:,2))), double(img(:,:,3)));
    elseif ndims(img)==3 && size(img,3)==1
        gray = double(squeeze(img));
        maxChan = gray;
    else
        gray = double(img);
        maxChan = gray;
    end
    if max(gray(:)) <= 1, gray = gray*255; maxChan = maxChan*255; end
    retinalMask = logical(retinalMask);
    if nnz(retinalMask) < 100
        retinalMask = true(size(gray));
    end

    thresh = cfg.glare.saturationThreshold; % 250
    % Saturated pixels inside retinal mask
    saturated = (maxChan > thresh) & retinalMask;
    % Also require high luminance to avoid single-channel noise
    % For RGB, also check that all channels >240 for true white glare, but keep inclusive
    % Use morphological to find large regions vs small bright structures (e.g., optic disc is bright but not saturated >250? Actually OD is ~200-220, not 250)
    glareFraction = nnz(saturated) / nnz(retinalMask);

    % Connected components for glare regions
    try
        CC = bwconncomp(saturated);
        regionCount = CC.NumObjects;
        if regionCount > 0
            sizes = cellfun(@numel, CC.PixelIdxList);
            [largest, idx] = max(sizes);
            largestFraction = largest / nnz(retinalMask);
            % Location: centroid of largest
            % Check if concentrated near center vs border? For now just count
        else
            largest = 0; largestFraction = 0; idx = 0;
        end
        % Filter tiny specks (<0.02% of retina) as noise, not glare
        minSize = 0.0002 * nnz(retinalMask); % 0.02%
        largeRegions = sum(sizes > minSize);
        % Largest after filtering
        if largeRegions > 0
            largeSizes = sizes(sizes > minSize);
            largestFiltered = max(largeSizes);
            largestFilteredFraction = largestFiltered / nnz(retinalMask);
        else
            largestFiltered = 0; largestFilteredFraction = 0;
        end
    catch
        regionCount = 0; largest = 0; largestFraction = 0; largeRegions = 0; largestFilteredFraction = 0;
    end

    % Status
    if glareFraction <= cfg.glare.fraction.good && largestFilteredFraction <= cfg.glare.largestRegionFraction.good
        glareStatus = "GOOD";
    elseif glareFraction <= cfg.glare.fraction.borderline && largestFilteredFraction <= cfg.glare.largestRegionFraction.borderline
        glareStatus = "BORDERLINE";
    else
        glareStatus = "UNGRADABLE";
    end
    % Also if many regions but small, still borderline not ungradable
    if regionCount > cfg.glare.regionCount.borderline && glareFraction > cfg.glare.fraction.good
        % keep as is
    end

    metrics = struct( ...
        'fraction', glareFraction, ...
        'regionCount', regionCount, ...
        'largeRegionCount', largeRegions, ...
        'largestRegion', largest, ...
        'largestFraction', largestFraction, ...
        'largestFilteredFraction', largestFilteredFraction, ...
        'glare_status', glareStatus ...
    );
end
