function [status, spatialEvidence] = generateAttentionMap(imgPath, phase3Result, contributions, imageId, cfg)
% generateAttentionMap  Feature-weighted spatial evidence map (REAL masks only)
%
%   [status, spatialEvidence] = generateAttentionMap(imgPath, phase3Result, contributions, imageId, cfg)
%
%   Uses real Phase 3 binary masks for spatial evidence weighting.
%   This is NOT Grad-CAM. It is a "Feature-Weighted Spatial Evidence Map".
%   If no real masks exist, returns status='UNAVAILABLE'.

    if nargin < 5, cfg = explainabilityConfig(); end
    status = 'FAILED';
    spatialEvidence = struct('status', 'UNKNOWN', 'pixels_used', 0);

    try, img = imread(imgPath); catch, return; end
    img = ensureRGB(img);
    [H, W, ~] = size(img);
    if max(H,W) > 512
        s = 512 / max(H,W);
        img = imresize(img, s);
        [H,W,~] = size(img);
    end
    imgD = im2double(img);

    % Load real Phase 3 masks from disk
    dataset = '';
    if isfield(phase3Result, 'dataset'), dataset = char(phase3Result.dataset); end
    maskDir = fullfile(cfg.projectRoot, 'results', 'phase3', 'phase3_masks', dataset);
    masks = loadPhase3Masks(maskDir, dataset, imageId);

    if ~masks.available
        status = 'UNAVAILABLE';
        spatialEvidence.status = 'UNAVAILABLE';
        % Write original image with annotation
        annImg = imgD;
        annImg(1:min(30,H), :, :) = 0.3;
        imwrite(uint8(annImg*255), fullfile(cfg.paths.heatmapDir, sprintf('%s_heatmap.png', imageId)));
        return;
    end

    % Resize masks to match display dimensions
    if isfield(masks, 'imgHeight') && masks.imgHeight > 0 && (masks.imgHeight ~= H || masks.imgWidth ~= W)
        masks.maMask = imresize(masks.maMask, [H, W]);
        masks.heMask = imresize(masks.heMask, [H, W]);
        masks.exMask = imresize(masks.exMask, [H, W]);
        masks.fovMask = imresize(masks.fovMask, [H, W]);
    end

    evidenceMap = zeros(H, W);

    % Weight each lesion type by its contribution magnitude
    maC = abs(getC(contributions,'ma_count') + getC(contributions,'ma_area') + getC(contributions,'ma_confidence'));
    if maC > 0 && any(masks.maMask(:))
        evidenceMap = evidenceMap + maC * double(masks.maMask);
    end

    heC = abs(getC(contributions,'he_count') + getC(contributions,'he_area') + getC(contributions,'he_confidence'));
    if heC > 0 && any(masks.heMask(:))
        evidenceMap = evidenceMap + heC * double(masks.heMask);
    end

    exC = abs(getC(contributions,'ex_count') + getC(contributions,'ex_area') + getC(contributions,'ex_confidence'));
    if exC > 0 && any(masks.exMask(:))
        evidenceMap = evidenceMap + exC * double(masks.exMask);
    end

    % Mask to FOV if available
    if any(masks.fovMask(:))
        evidenceMap = evidenceMap .* double(masks.fovMask);
    end

    % Normalize
    mx = max(evidenceMap(:));
    if mx > 0, evidenceMap = evidenceMap / mx; end

    % Count pixels
    spatialEvidence.pixels_used = nnz(evidenceMap > 0.05);
    spatialEvidence.status = 'REAL_PHASE3_MASK';

    % Hot colormap overlay
    overlay = imgD;
    hotR = min(1, 2*evidenceMap);
    hotG = min(1, 2*max(0, evidenceMap-0.5));
    hotB = zeros(H,W);
    vis = evidenceMap > 0.05;

    for c = 1:3
        hc = cat(3, hotR, hotG, hotB);
        overlay(:,:,c) = overlay(:,:,c) .* (1 - 0.5*double(vis)) + 0.5*hc(:,:,c) .* double(vis);
    end

    status = 'SUCCESS';
    imwrite(uint8(overlay*255), fullfile(cfg.paths.heatmapDir, sprintf('%s_heatmap.png', imageId)));
end

function c = getC(contributions, featureName)
    c = 0;
    if isempty(contributions) || ~isfield(contributions,'name'), return; end
    idx = find(strcmp(contributions.name, featureName), 1);
    if ~isempty(idx), c = contributions.contribution(idx); end
end

function img = ensureRGB(img)
    if ndims(img) == 2 || size(img, 3) == 1
        img = repmat(img, 1, 1, 3);
    end
end
