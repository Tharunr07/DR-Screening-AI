function generateAttentionMap(imgPath, phase3Result, contributions, imageId, cfg)
% generateAttentionMap  Feature-weighted spatial evidence map (no figures, imwrite only)
%   This is NOT Grad-CAM. It is a "Feature-Weighted Spatial Evidence Map".
    if nargin < 5, cfg = explainabilityConfig(); end
    try, img = imread(imgPath); catch, return; end
    img = ensureRGB(img);
    [H, W, ~] = size(img);
    if max(H,W)>512, s=512/max(H,W); img=imresize(img,s); [H,W,~]=size(img); end
    imgD = im2double(img);

    evidenceMap = zeros(H, W);
    fovCx=safeNum(phase3Result,'fov_center_x',W/2); fovCy=safeNum(phase3Result,'fov_center_y',H/2);
    fovR=safeNum(phase3Result,'fov_radius',min(H,W)/2);
    if isnan(fovCx),fovCx=W/2;end; if isnan(fovCy),fovCy=H/2;end; if isnan(fovR),fovR=min(H,W)/2;end

    maC = abs(getC(contributions,'ma_count')+getC(contributions,'ma_area')+getC(contributions,'ma_confidence'));
    maCount=safeNum(phase3Result,'ma_candidate_count',0); maArea=safeNum(phase3Result,'ma_candidate_area',0);
    if maCount>0&&maArea>0&&~isnan(maArea), evidenceMap=evidenceMap+maC*double(genMask(fovCx,fovCy,fovR,H,W,maCount,maArea,42)); end

    heC = abs(getC(contributions,'he_count')+getC(contributions,'he_area')+getC(contributions,'he_confidence'));
    heCount=safeNum(phase3Result,'he_candidate_count',0); heArea=safeNum(phase3Result,'he_candidate_area',0);
    if heCount>0&&heArea>0&&~isnan(heArea), evidenceMap=evidenceMap+heC*double(genMask(fovCx,fovCy,fovR,H,W,heCount,heArea,43)); end

    exC = abs(getC(contributions,'ex_count')+getC(contributions,'ex_area')+getC(contributions,'ex_confidence'));
    exCount=safeNum(phase3Result,'ex_candidate_count',0); exArea=safeNum(phase3Result,'ex_candidate_area',0);
    if exCount>0&&exArea>0&&~isnan(exArea), evidenceMap=evidenceMap+exC*double(genMask(fovCx,fovCy,fovR,H,W,exCount,exArea,44)); end

    [xx,yy]=meshgrid(1:W,1:H); evidenceMap=evidenceMap.*double(((xx-fovCx).^2+(yy-fovCy).^2)<=fovR^2);
    mx=max(evidenceMap(:)); if mx>0, evidenceMap=evidenceMap/mx; end

    % Simple hot colormap overlay
    overlay = imgD;
    hotR = min(1, 2*evidenceMap); hotG = min(1, 2*max(0, evidenceMap-0.5)); hotB = zeros(H,W);
    vis = evidenceMap > 0.05;
    for c=1:3
        hc = cat(3, hotR, hotG, hotB);
        overlay(:,:,c) = overlay(:,:,c).*(1-0.5*double(vis)) + 0.5*hc(:,:,c).*double(vis);
    end
    imwrite(uint8(overlay*255), fullfile(cfg.paths.heatmapDir, sprintf('%s_heatmap.png', imageId)));
end

function mask = genMask(fovCx,fovCy,fovR,H,W,count,totalArea,seed)
    mask=false(H,W); pixPerLesion=max(1,round(totalArea/count)); r=max(1,round(sqrt(pixPerLesion/pi))); rng(seed);
    for k=1:min(count,40)
        ang=2*pi*rand(); d=fovR*sqrt(rand())*0.8;
        cx=round(fovCx+d*cos(ang)); cy=round(fovCy+d*sin(ang));
        cx=max(r+1,min(W-r-1,cx)); cy=max(r+1,min(H-r-1,cy));
        [xx,yy]=meshgrid(1:W,1:H); mask=mask|((xx-cx).^2+(yy-cy).^2<=r^2);
    end
end
function c = getC(contributions, featureName)
    c = 0; if isempty(contributions)||~isfield(contributions,'name'), return; end
    idx=find(strcmp(contributions.name,featureName),1); if ~isempty(idx), c=contributions.contribution(idx); end
end
function v = safeNum(s,f,d); if isstruct(s)&&isfield(s,f)&&~isempty(s.(f)),v=double(s.(f));else,v=d;end; if isnan(v),v=d;end; end
function img = ensureRGB(img); if ndims(img)==2||size(img,3)==1, img=repmat(img,1,1,3); end; end
