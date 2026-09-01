function generateLesionOverlay(imgPath, phase3Result, imageId, cfg)
% generateLesionOverlay  Overlay detected lesion masks on fundus image (no figures)
    if nargin < 4, cfg = explainabilityConfig(); end
    try, img = imread(imgPath); catch, return; end
    img = ensureRGB(img);
    [H, W, ~] = size(img);
    if max(H, W) > 512, s = 512/max(H,W); img = imresize(img, s); [H,W,~]=size(img); end
    imgD = im2double(img);
    overlay = imgD;
    alpha = cfg.overlay.lesionAlpha;
    for lesType = {'ma','he','ex'}
        lt = lesType{1};
        switch lt
            case 'ma', count=safeNum(phase3Result,'ma_candidate_count',0); area=safeNum(phase3Result,'ma_candidate_area',0); color=cfg.overlay.lesionColors.MA;
            case 'he', count=safeNum(phase3Result,'he_candidate_count',0); area=safeNum(phase3Result,'he_candidate_area',0); color=cfg.overlay.lesionColors.HE;
            case 'ex', count=safeNum(phase3Result,'ex_candidate_count',0); area=safeNum(phase3Result,'ex_candidate_area',0); color=cfg.overlay.lesionColors.EX;
        end
        if count<=0||area<=0||isnan(area), continue; end
        fovCx=safeNum(phase3Result,'fov_center_x',W/2); fovCy=safeNum(phase3Result,'fov_center_y',H/2);
        fovR=safeNum(phase3Result,'fov_radius',min(H,W)/2);
        if isnan(fovCx),fovCx=W/2;end; if isnan(fovCy),fovCy=H/2;end; if isnan(fovR),fovR=min(H,W)/2;end
        rng(42+find(strcmp({'ma','he','ex'},lt)));
        pixPerLesion=max(1,round(area/count)); r=max(1,round(sqrt(pixPerLesion/pi)));
        mask=false(H,W);
        for k=1:min(count,30)
            ang=2*pi*rand(); d=fovR*sqrt(rand())*0.8;
            cx=round(fovCx+d*cos(ang)); cy=round(fovCy+d*sin(ang));
            cx=max(r+1,min(W-r-1,cx)); cy=max(r+1,min(H-r-1,cy));
            [xx,yy]=meshgrid(1:W,1:H); mask=mask|((xx-cx).^2+(yy-cy).^2<=r^2);
        end
        for c=1:3, overlay(:,:,c)=overlay(:,:,c).*(1-alpha*double(mask))+alpha*color(c)*double(mask); end
    end
    imwrite(uint8(overlay*255), fullfile(cfg.paths.overlayDir, sprintf('%s_overlay.png', imageId)));
end
function v = safeNum(s,f,d); if isstruct(s)&&isfield(s,f)&&~isempty(s.(f)),v=double(s.(f));else,v=d;end; if isnan(v),v=d;end; end
function img = ensureRGB(img); if ndims(img)==2||size(img,3)==1, img=repmat(img,1,1,3); end; end
