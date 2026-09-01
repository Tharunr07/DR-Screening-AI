function [status, maskInfo] = generateLesionOverlay(imgPath, phase3Result, imageId, cfg)
% generateLesionOverlay  Overlay REAL Phase 3 lesion masks on fundus image
%
%   [status, maskInfo] = generateLesionOverlay(imgPath, phase3Result, imageId, cfg)
%
%   Uses persisted Phase 3 binary masks for spatial lesion evidence.
%   If no real mask is available, returns status='UNAVAILABLE'.
%   Does NOT generate synthetic/random lesion positions.

    if nargin < 4, cfg = explainabilityConfig(); end
    status = 'FAILED';
    maskInfo = struct('ma', false, 'he', false, 'ex', false, 'source', 'UNKNOWN');

    try, img = imread(imgPath); catch, return; end
    img = ensureRGB(img);
    [H, W, ~] = size(img);
    if max(H, W) > 512
        s = 512 / max(H, W);
        img = imresize(img, s);
        [H, W, ~] = size(img);
    end
    imgD = im2double(img);
    overlay = imgD;
    alpha = cfg.overlay.lesionAlpha;

    % Load real Phase 3 masks from disk
    dataset = '';
    if isfield(phase3Result, 'dataset'), dataset = char(phase3Result.dataset); end
    maskDir = fullfile(cfg.projectRoot, 'results', 'phase3', 'phase3_masks', dataset);
    masks = loadPhase3Masks(maskDir, dataset, imageId);

    if ~masks.available
        status = 'UNAVAILABLE';
        maskInfo.source = 'NO_MASK_FILE';
        imwrite(uint8(overlay*255), fullfile(cfg.paths.overlayDir, sprintf('%s_overlay.png', imageId)));
        return;
    end

    % Resize masks to match display dimensions
    if isfield(masks, 'imgHeight') && masks.imgHeight > 0 && (masks.imgHeight ~= H || masks.imgWidth ~= W)
        masks.maMask = imresize(masks.maMask, [H, W]);
        masks.heMask = imresize(masks.heMask, [H, W]);
        masks.exMask = imresize(masks.exMask, [H, W]);
    end

    % Overlay real masks
    lesionFound = false;

    if any(masks.maMask(:))
        for c = 1:3
            overlay(:,:,c) = overlay(:,:,c) .* (1 - alpha * double(masks.maMask)) + alpha * cfg.overlay.lesionColors.MA(c) * double(masks.maMask);
        end
        lesionFound = true;
        maskInfo.ma = true;
    end

    if any(masks.heMask(:))
        for c = 1:3
            overlay(:,:,c) = overlay(:,:,c) .* (1 - alpha * double(masks.heMask)) + alpha * cfg.overlay.lesionColors.HE(c) * double(masks.heMask);
        end
        lesionFound = true;
        maskInfo.he = true;
    end

    if any(masks.exMask(:))
        for c = 1:3
            overlay(:,:,c) = overlay(:,:,c) .* (1 - alpha * double(masks.exMask)) + alpha * cfg.overlay.lesionColors.EX(c) * double(masks.exMask);
        end
        lesionFound = true;
        maskInfo.ex = true;
    end

    if lesionFound
        maskInfo.source = 'REAL_PHASE3_MASK';
        status = 'SUCCESS';
    else
        maskInfo.source = 'REAL_PHASE3_MASK_EMPTY';
        status = 'SUCCESS_EMPTY';
    end

    imwrite(uint8(overlay*255), fullfile(cfg.paths.overlayDir, sprintf('%s_overlay.png', imageId)));
end

function img = ensureRGB(img)
    if ndims(img) == 2 || size(img, 3) == 1
        img = repmat(img, 1, 1, 3);
    end
end
