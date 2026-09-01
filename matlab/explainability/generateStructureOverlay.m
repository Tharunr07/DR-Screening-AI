function generateStructureOverlay(imgPath, phase3Result, imageId, cfg)
% generateStructureOverlay  Annotate structures on fundus image (no figures, imwrite only)
    if nargin < 4, cfg = explainabilityConfig(); end
    try, img = imread(imgPath); catch, return; end
    img = ensureRGB(img);
    [H, W, ~] = size(img);
    if max(H, W) > 512, s = 512/max(H,W); img = imresize(img, s); [H,W,~]=size(img); end
    imgD = im2double(img);
    overlay = imgD;
    fovCx=safeNum(phase3Result,'fov_center_x',W/2); fovCy=safeNum(phase3Result,'fov_center_y',H/2);
    fovR=safeNum(phase3Result,'fov_radius',min(H,W)/2);
    if ~isnan(fovCx)&&~isnan(fovCy)&&~isnan(fovR)
        [xx,yy]=meshgrid(1:W,1:H); ring=abs(sqrt((xx-fovCx).^2+(yy-fovCy).^2)-fovR)<2;
        for c=1:3, overlay(:,:,c)=overlay(:,:,c).*~ring+1.0*ring; end
    end
    if safeLog(phase3Result,'optic_disc_detected',false)
        odX=safeNum(phase3Result,'optic_disc_x',NaN); odY=safeNum(phase3Result,'optic_disc_y',NaN); odR=safeNum(phase3Result,'optic_disc_radius',NaN);
        if ~isnan(odX)&&~isnan(odY)&&~isnan(odR)
            [xx,yy]=meshgrid(1:W,1:H); ring=abs(sqrt((xx-odX).^2+(yy-odY).^2)-odR)<2;
            for c=1:3, overlay(:,:,c)=overlay(:,:,c).*~ring+cfg.overlay.structureColors.OD(c)*ring; end
        end
    end
    if safeLog(phase3Result,'fovea_detected',false)
        fX=safeNum(phase3Result,'fovea_x',NaN); fY=safeNum(phase3Result,'fovea_y',NaN);
        if ~isnan(fX)&&~isnan(fY)
            cl=8; xL=max(1,round(fX-cl)); xR=min(W,round(fX+cl)); yT=max(1,round(fY-cl)); yB=min(H,round(fY+cl));
            for ch=1:3
                overlay(round(fY),xL:xR,ch)=cfg.overlay.structureColors.fovea(ch);
                overlay(yT:yB,round(fX),ch)=cfg.overlay.structureColors.fovea(ch);
            end
        end
    end
    imwrite(uint8(overlay*255), fullfile(cfg.paths.overlayDir, sprintf('%s_structure.png', imageId)));
end
function v = safeNum(s,f,d); if isstruct(s)&&isfield(s,f)&&~isempty(s.(f)),v=double(s.(f));else,v=d;end; if isnan(v),v=d;end; end
function v = safeLog(s,f,d); if isstruct(s)&&isfield(s,f)&&~isempty(s.(f)),v=logical(s.(f));else,v=d;end; end
function img = ensureRGB(img); if ndims(img)==2||size(img,3)==1, img=repmat(img,1,1,3); end; end
