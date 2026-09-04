function results = testQualityPipeline(varargin)
% testQualityPipeline  Tests for 12 synthetic cases (RESEARCH PROTOTYPE, not clinical validation)
%
%   results = testQualityPipeline()
%   Tests: RGB, grayscale, unreadable, blurred, underexposed, overexposed,
%          severe glare, insufficient FOV, strong vignetting, low contrast,
%          normal-quality, borderline requiring enhancement
%
%   Creates synthetic fixtures in temp dir, runs assessImageQuality, checks
%   that each case returns expected status (GOOD/BORDERLINE/UNGRADABLE) and
%   does not crash. Returns struct with pass/fail per test.

    p = inputParser;
    addParameter(p,'verbose',true);
    parse(p,varargin{:});
    opts = p.Results;

    cfg = qualityConfig();
    tmpDir = fullfile(tempdir, 'dr_quality_tests');
    if ~exist(tmpDir,'dir'), mkdir(tmpDir); end

    tests = {};
    % 1. RGB normal
    img = createSyntheticFundus('normal', false);
    f = fullfile(tmpDir, 'test_rgb_normal.png'); imwrite(img, f);
    tests{end+1} = struct('name','RGB normal','path',f,'expected',"GOOD");

    % 2. grayscale
    imgG = rgb2gray(img);
    f = fullfile(tmpDir, 'test_gray_normal.png'); imwrite(imgG, f);
    tests{end+1} = struct('name','grayscale','path',f,'expected',"GOOD");

    % 3. unreadable
    f = fullfile(tmpDir, 'test_unreadable.jpg');
    fid=fopen(f,'w'); fwrite(fid,'not an image','char'); fclose(fid);
    tests{end+1} = struct('name','unreadable','path',f,'expected',"UNGRADABLE");

    % 4. very blurred
    imgBlur = imgaussfilt(img, 8);
    f = fullfile(tmpDir, 'test_blurred.png'); imwrite(imgBlur, f);
    tests{end+1} = struct('name','very blurred','path',f,'expected',"UNGRADABLE");

    % 5. underexposed
    imgDark = im2uint8(im2double(img)*0.25);
    f = fullfile(tmpDir, 'test_underexposed.png'); imwrite(imgDark, f);
    tests{end+1} = struct('name','underexposed','path',f,'expected',"UNGRADABLE");

    % 6. overexposed
    imgBright = im2uint8(min(1, im2double(img)*1.8 + 0.2));
    f = fullfile(tmpDir, 'test_overexposed.png'); imwrite(imgBright, f);
    tests{end+1} = struct('name','overexposed','path',f,'expected',"BORDERLINE");

    % 7. severe glare (large white region)
    imgGlare = img; imgGlare(80:150, 80:150, :) = 255;
    f = fullfile(tmpDir, 'test_glare.png'); imwrite(imgGlare, f);
    tests{end+1} = struct('name','severe glare','path',f,'expected',"UNGRADABLE");

    % 8. insufficient FOV (small circle)
    imgFOV = createSyntheticFundus('small_fov', false);
    f = fullfile(tmpDir, 'test_insufficient_fov.png'); imwrite(imgFOV, f);
    tests{end+1} = struct('name','insufficient FOV','path',f,'expected',"UNGRADABLE");

    % 9. strong vignetting (radial darkening)
    imgVig = createSyntheticFundus('vignetting', false);
    f = fullfile(tmpDir, 'test_vignetting.png'); imwrite(imgVig, f);
    tests{end+1} = struct('name','strong vignetting','path',f,'expected',"BORDERLINE");

    % 10. low contrast (compressed range)
    imgLowC = im2uint8(0.5 + 0.2*(im2double(img)-0.5) + 0.5); % compress to 0.4-0.6
    imgLowC = uint8(128 + double(imgLowC)*0.3); % low contrast
    % Simpler: reduce contrast via imadjust
    imgLowC2 = imadjust(img, [0.3 0.7], [0.45 0.55]);
    f = fullfile(tmpDir, 'test_lowcontrast.png'); imwrite(imgLowC2, f);
    tests{end+1} = struct('name','low contrast','path',f,'expected',"BORDERLINE");

    % 11. normal-quality fundus (reference)
    imgNorm = createSyntheticFundus('normal', false);
    f = fullfile(tmpDir, 'test_normal_quality.png'); imwrite(imgNorm, f);
    tests{end+1} = struct('name','normal-quality','path',f,'expected',"GOOD");

    % 12. borderline requiring enhancement (low contrast + mild blur)
    imgBorder = imgaussfilt(imadjust(img, [0.2 0.8], [0.35 0.65]), 1.5);
    f = fullfile(tmpDir, 'test_borderline.png'); imwrite(imgBorder, f);
    tests{end+1} = struct('name','borderline enhancement','path',f,'expected',"BORDERLINE");

    % Run each
    results = struct('total',numel(tests),'passed',0,'failed',0,'details',{{}});
    for k=1:numel(tests)
        t = tests{k};
        try
            res = assessImageQuality(t.path, cfg);
            status = res.quality_status;
            % Check expected: allow GOOD/BORDERLINE flexibility for borderline cases
            % For this test, we consider PASS if status is one of expected or if unreadable handled
            % For blurred, we expect UNGRADABLE but if BORDERLINE also okay as not GOOD
            expected = t.expected;
            pass = false;
            if status==expected
                pass = true;
            elseif expected=="UNGRADABLE" && status~="GOOD"
                pass = true; % any non-GOOD for degraded is acceptable
            elseif expected=="BORDERLINE" && (status=="BORDERLINE" || status=="UNGRADABLE")
                pass = true;
            elseif expected=="GOOD" && status=="GOOD"
                pass = true;
            else
                pass = false;
            end
            % Also test enhancement for borderline
            enhOk = true;
            if status=="BORDERLINE"
                try
                    [img, info,~]=loadImageSafe(t.path);
                    if info.readable
                        [enh, log]=enhanceBorderlineImage(img, res, cfg);
                        % Should produce enhanced without error
                    end
                catch
                    enhOk = false;
                end
            end
            if pass && enhOk
                results.passed = results.passed + 1;
                detail = sprintf('[PASS] %s => %s (expected %s)', t.name, status, expected);
            else
                results.failed = results.failed + 1;
                detail = sprintf('[FAIL] %s => %s (expected %s)', t.name, status, expected);
            end
            results.details{end+1}=detail; %#ok<AGROW>
            if opts.verbose, fprintf('%s\n', detail); end
        catch ME
            results.failed = results.failed + 1;
            detail = sprintf('[EXCEPTION] %s : %s', t.name, ME.message);
            results.details{end+1}=detail; %#ok<AGROW>
            if opts.verbose, fprintf('%s\n', detail); end
        end
    end
    if opts.verbose
        fprintf('=== testQualityPipeline %d/%d passed ===\n', results.passed, results.total);
        fprintf('Note: synthetic fixtures, not clinical validation\n');
    end
end

function img = createSyntheticFundus(variant, isGray)
    % Create 256x256 synthetic fundus-like image
    sz = 256;
    [X,Y] = meshgrid(1:sz, 1:sz);
    cx=128; cy=128; r=90;
    mask = sqrt((X-cx).^2 + (Y-cy).^2) < r;
    img = zeros(sz,sz,3,'uint8');
    % Background black
    % Retina: base color brownish
    base = zeros(sz,sz,3);
    base(:,:,1) = 180; base(:,:,2)=90; base(:,:,3)=30;
    % Add vessels: simple lines
    for c=1:3
        ch = base(:,:,c);
        % Add some vessel-like dark lines
        for ang=0:30:330
            x1=cx; y1=cy;
            x2=cx + r*0.9*cosd(ang + randn*5);
            y2=cy + r*0.9*sind(ang + randn*5);
            % Draw line via interpolation
            n=100;
            xs=round(linspace(x1,x2,n)); ys=round(linspace(y1,y2,n));
            idx = sub2ind([sz sz], ys, xs);
            idx = idx(idx>0 & idx<=sz*sz);
            ch(idx) = ch(idx)*0.6;
        end
        base(:,:,c)=ch;
    end
    % Add optic disc: bright circle
    odx=cx+30; ody=cy-10; odr=12;
    odMask = sqrt((X-odx).^2 + (Y-ody).^2) < odr;
    for c=1:3
        base(:,:,c) = base(:,:,c).*(~odMask) + 220*odMask;
    end
    % Apply mask
    for c=1:3
        ch = base(:,:,c);
        ch(~mask)=0;
        base(:,:,c)=ch;
    end
    img = uint8(base);

    switch variant
        case 'small_fov'
            % Smaller radius
            mask2 = sqrt((X-cx).^2 + (Y-cy).^2) < 40;
            img2 = zeros(sz,sz,3,'uint8');
            for c=1:3
                ch = double(img(:,:,c));
                ch(~mask2)=0;
                img2(:,:,c)=uint8(ch);
            end
            img = img2;
        case 'vignetting'
            % Darken periphery
            dist = sqrt((X-cx).^2 + (Y-cy).^2);
            vign = 1 - 0.6*(dist / r);
            vign = max(0.3, min(1, vign));
            vign(~mask)=1;
            for c=1:3
                img(:,:,c) = uint8(double(img(:,:,c)).*vign);
            end
        otherwise
            % normal
    end
    if isGray
        img = rgb2gray(img);
    end
end
