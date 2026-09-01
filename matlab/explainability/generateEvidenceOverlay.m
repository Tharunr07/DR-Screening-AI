function generateEvidenceOverlay(imgPath, phase3Result, predResult, contributions, imageId, cfg)
% generateEvidenceOverlay  Combined clinical evidence panel (no figures, imwrite only)
    if nargin < 6, cfg = explainabilityConfig(); end
    try, img = imread(imgPath); catch, return; end
    img = ensureRGB(img);
    [H, W, ~] = size(img);
    if max(H,W)>400, s=400/max(H,W); img=imresize(img,s); [H,W,~]=size(img); end
    imgD = im2double(img);
    panel = zeros(2*H, 2*W, 3);
    panel(1:H, 1:W, :) = imgD;
    panel(1:H, W+1:2*W, :) = makeLesionOverlay(imgD, phase3Result, cfg);
    panel(H+1:2*H, 1:W, :) = makeStructOverlay(imgD, phase3Result, cfg);
    panel(H+1:2*H, W+1:2*W, :) = makeContributionChart(contributions, H, W);
    headerH = 30;
    fullPanel = zeros(2*H+headerH, 2*W, 3);
    fullPanel(headerH+1:end, :, :) = panel;
    for c=1:3, fullPanel(1:headerH,:,c)=0.15; end
    imwrite(uint8(fullPanel*255), fullfile(cfg.paths.overlayDir, sprintf('%s_evidence.png', imageId)));
end

function overlay = makeLesionOverlay(imgD, p3, cfg)
    overlay = imgD; alpha = cfg.overlay.lesionAlpha; [H,W,~]=size(imgD);
    for lesType = {'ma','he','ex'}
        lt = lesType{1};
        switch lt
            case 'ma', count=safeNum(p3,'ma_candidate_count',0); area=safeNum(p3,'ma_candidate_area',0); color=cfg.overlay.lesionColors.MA;
            case 'he', count=safeNum(p3,'he_candidate_count',0); area=safeNum(p3,'he_candidate_area',0); color=cfg.overlay.lesionColors.HE;
            case 'ex', count=safeNum(p3,'ex_candidate_count',0); area=safeNum(p3,'ex_candidate_area',0); color=cfg.overlay.lesionColors.EX;
        end
        if count<=0||area<=0||isnan(area), continue; end
        fovCx=safeNum(p3,'fov_center_x',W/2); fovCy=safeNum(p3,'fov_center_y',H/2); fovR=safeNum(p3,'fov_radius',min(H,W)/2);
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
end

function overlay = makeStructOverlay(imgD, p3, cfg)
    overlay = imgD; [H,W,~]=size(imgD);
    fovCx=safeNum(p3,'fov_center_x',W/2); fovCy=safeNum(p3,'fov_center_y',H/2); fovR=safeNum(p3,'fov_radius',min(H,W)/2);
    if ~isnan(fovCx)&&~isnan(fovCy)&&~isnan(fovR)
        [xx,yy]=meshgrid(1:W,1:H); ring=abs(sqrt((xx-fovCx).^2+(yy-fovCy).^2)-fovR)<2;
        for c=1:3, overlay(:,:,c)=overlay(:,:,c).*~ring+1.0*ring; end
    end
    if safeLog(p3,'optic_disc_detected',false)
        odX=safeNum(p3,'optic_disc_x',NaN); odY=safeNum(p3,'optic_disc_y',NaN); odR=safeNum(p3,'optic_disc_radius',NaN);
        if ~isnan(odX)&&~isnan(odY)&&~isnan(odR)
            [xx,yy]=meshgrid(1:W,1:H); ring=abs(sqrt((xx-odX).^2+(yy-odY).^2)-odR)<2;
            for c=1:3, overlay(:,:,c)=overlay(:,:,c).*~ring+cfg.overlay.structureColors.OD(c)*ring; end
        end
    end
    if safeLog(p3,'fovea_detected',false)
        fX=safeNum(p3,'fovea_x',NaN); fY=safeNum(p3,'fovea_y',NaN);
        if ~isnan(fX)&&~isnan(fY)
            cl=8; xL=max(1,round(fX-cl)); xR=min(W,round(fX+cl)); yT=max(1,round(fY-cl)); yB=min(H,round(fY+cl));
            for ch=1:3
                overlay(round(fY),xL:xR,ch)=cfg.overlay.structureColors.fovea(ch);
                overlay(yT:yB,round(fX),ch)=cfg.overlay.structureColors.fovea(ch);
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
        if val>0, color=[0.2,0.7,0.2]; else, color=[0.7,0.2,0.2]; end
        for c=1:3, chart(yStart:yEnd, 10:xEnd, c)=color(c); end
    end
end

function v = safeNum(s,f,d); if isstruct(s)&&isfield(s,f)&&~isempty(s.(f)),v=double(s.(f));else,v=d;end; if isnan(v),v=d;end; end
function v = safeLog(s,f,d); if isstruct(s)&&isfield(s,f)&&~isempty(s.(f)),v=logical(s.(f));else,v=d;end; end
function img = ensureRGB(img); if ndims(img)==2||size(img,3)==1, img=repmat(img,1,1,3); end; end
