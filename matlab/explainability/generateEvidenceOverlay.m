function [status, panelInfo] = generateEvidenceOverlay(imgPath, phase3Result, predResult, contributions, imageId, cfg)
% generateEvidenceOverlay  Combined clinical evidence panel (REAL masks, padding-based)
%
%   [status, panelInfo] = generateEvidenceOverlay(imgPath, phase3Result, predResult, contributions, imageId, cfg)
%
%   Uses real Phase 3 binary masks for lesion overlay.
%   Uses padding to normalize odd panel dimensions (no cropping).
%   If mask unavailable, panel shows original image only.

    if nargin < 6, cfg = explainabilityConfig(); end
    status = 'FAILED';
    panelInfo = struct('lesion_status', 'UNKNOWN', 'dimensions', [0 0]);

    try, img = imread(imgPath); catch, return; end
    img = ensureRGB(img);
    [H, W, ~] = size(img);
    if max(H,W) > 400
        s = 400 / max(H,W);
        img = imresize(img, s);
        [H, W, ~] = size(img);
    end
    imgD = im2double(img);

    % Normalize dimensions with padding (fixes odd-dimension failures)
    % All four panels must be even dimensions for 2x2 layout
    if mod(H, 2) == 1, H = H + 1; end
    if mod(W, 2) == 1, W = W + 1; end

    % Pad original image to normalized size
    imgPad = zeros(H, W, 3);
    imgPad(1:size(imgD,1), 1:size(imgD,2), :) = imgD;

    % Build four panels at normalized dimensions
    panel1 = imgPad;
    panel2 = makeLesionOverlay(imgPad, phase3Result, cfg, imageId, cfg.projectRoot);
    panel3 = makeStructOverlay(imgPad, phase3Result, cfg);
    panel4 = makeContributionChart(contributions, H, W);

    % 2x2 panel with header
    headerH = 30;
    fullPanel = zeros(2*H + headerH, 2*W, 3);
    fullPanel(headerH+1:headerH+H, 1:W, :) = panel1;
    fullPanel(headerH+1:headerH+H, W+1:2*W, :) = panel2;
    fullPanel(headerH+H+1:headerH+2*H, 1:W, :) = panel3;
    fullPanel(headerH+H+1:headerH+2*H, W+1:2*W, :) = panel4;

    % Header bar
    for c = 1:3, fullPanel(1:headerH, :, c) = 0.15; end

    panelInfo.dimensions = [2*H+headerH, 2*W];
    status = 'SUCCESS';

    imwrite(uint8(fullPanel*255), fullfile(cfg.paths.overlayDir, sprintf('%s_evidence.png', imageId)));
end

function overlay = makeLesionOverlay(imgD, p3, cfg, imageId, projectRoot)
    overlay = imgD;
    alpha = cfg.overlay.lesionAlpha;
    [H, W, ~] = size(imgD);

    % Load real Phase 3 masks
    dataset = '';
    if isfield(p3, 'dataset'), dataset = char(p3.dataset); end
    maskDir = fullfile(projectRoot, 'results', 'phase3', 'phase3_masks', dataset);
    masks = loadPhase3Masks(maskDir, dataset, imageId);

    if ~masks.available
        % No masks — show original image only
        return;
    end

    % Resize masks to match display dimensions
    [srcH, srcW] = size(masks.maMask);
    if srcH ~= H || srcW ~= W
        masks.maMask = imresize(masks.maMask, [H, W]);
        masks.heMask = imresize(masks.heMask, [H, W]);
        masks.exMask = imresize(masks.exMask, [H, W]);
    end

    % Overlay real masks
    if any(masks.maMask(:))
        for c = 1:3
            overlay(:,:,c) = overlay(:,:,c) .* (1-alpha*double(masks.maMask)) + alpha*cfg.overlay.lesionColors.MA(c)*double(masks.maMask);
        end
    end
    if any(masks.heMask(:))
        for c = 1:3
            overlay(:,:,c) = overlay(:,:,c) .* (1-alpha*double(masks.heMask)) + alpha*cfg.overlay.lesionColors.HE(c)*double(masks.heMask);
        end
    end
    if any(masks.exMask(:))
        for c = 1:3
            overlay(:,:,c) = overlay(:,:,c) .* (1-alpha*double(masks.exMask)) + alpha*cfg.overlay.lesionColors.EX(c)*double(masks.exMask);
        end
    end
end

function overlay = makeStructOverlay(imgD, p3, cfg)
    overlay = imgD;
    [H, W, ~] = size(imgD);
    fovCx = safeNum(p3,'fov_center_x',W/2); fovCy = safeNum(p3,'fov_center_y',H/2);
    fovR = safeNum(p3,'fov_radius',min(H,W)/2);
    if ~isnan(fovCx) && ~isnan(fovCy) && ~isnan(fovR)
        [xx,yy] = meshgrid(1:W,1:H); ring = abs(sqrt((xx-fovCx).^2+(yy-fovCy).^2)-fovR) < 2;
        for c = 1:3, overlay(:,:,c) = overlay(:,:,c).*~ring + 1.0*ring; end
    end
    if safeLog(p3,'optic_disc_detected',false)
        odX = safeNum(p3,'optic_disc_x',NaN); odY = safeNum(p3,'optic_disc_y',NaN);
        odR = safeNum(p3,'optic_disc_radius',NaN);
        if ~isnan(odX) && ~isnan(odY) && ~isnan(odR)
            [xx,yy] = meshgrid(1:W,1:H); ring = abs(sqrt((xx-odX).^2+(yy-odY).^2)-odR) < 2;
            for c = 1:3, overlay(:,:,c) = overlay(:,:,c).*~ring + cfg.overlay.structureColors.OD(c)*ring; end
        end
    end
    if safeLog(p3,'fovea_detected',false)
        fX = safeNum(p3,'fovea_x',NaN); fY = safeNum(p3,'fovea_y',NaN);
        if ~isnan(fX) && ~isnan(fY)
            cl = 8; xL = max(1,round(fX-cl)); xR = min(W,round(fX+cl));
            yT = max(1,round(fY-cl)); yB = min(H,round(fY+cl));
            for ch = 1:3
                overlay(round(fY), xL:xR, ch) = cfg.overlay.structureColors.fovea(ch);
                overlay(yT:yB, round(fX), ch) = cfg.overlay.structureColors.fovea(ch);
            end
        end
    end
end

function chart = makeContributionChart(contributions, H, W)
    chart = ones(H, W, 3) * 0.1;
    if isempty(contributions) || ~isfield(contributions,'name'), return; end
    topN = min(8, numel(contributions.name));
    barH = max(1, floor(H*0.8/topN));
    for k = 1:topN
        val = contributions.contribution(k);
        barLen = max(1, min(W-20, round(abs(val)*(W-20)/0.2)));
        yStart = max(1, round(H*0.1)+(k-1)*barH);
        yEnd = min(H, yStart+max(1,barH-2));
        xEnd = min(W, 10+barLen);
        if val > 0, color = [0.2,0.7,0.2]; else, color = [0.7,0.2,0.2]; end
        for c = 1:3, chart(yStart:yEnd, 10:xEnd, c) = color(c); end
    end
end

function v = safeNum(s,f,d)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)), v = double(s.(f)); else, v = d; end
    if isnan(v), v = d; end
end
function v = safeLog(s,f,d)
    if isstruct(s) && isfield(s,f) && ~isempty(s.(f)), v = logical(s.(f)); else, v = d; end
end
function img = ensureRGB(img)
    if ndims(img) == 2 || size(img,3) == 1, img = repmat(img,1,1,3); end
end
