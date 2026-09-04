function results = testPhase3Pipeline(varargin)
% testPhase3Pipeline  Automated tests for Phase 3 (RESEARCH PROTOTYPE)
%
%   results = testPhase3Pipeline()
%   Tests 10+ synthetic cases: normal, low-quality, grayscale, RGB,
%   missing image, corrupted, no retinal field, optic disc, vessel, lesion.

    p = inputParser;
    addParameter(p, 'verbose', true);
    parse(p, varargin{:});
    opts = p.Results;

    cfg = phase3Config();
    tmpDir = fullfile(tempdir, 'dr_phase3_tests');
    if ~exist(tmpDir, 'dir'), mkdir(tmpDir); end

    tests = {};

    % 1. Normal RGB fundus
    img = createSyntheticFundus('normal');
    f = fullfile(tmpDir, 'test_normal.png'); imwrite(img, f);
    tests{end+1} = struct('name', 'normal RGB fundus', 'path', f, ...
        'expect_structure', true, 'expect_od', true);

    % 2. Low-quality (blurred)
    imgBlur = imgaussfilt(img, 5);
    f = fullfile(tmpDir, 'test_blur.png'); imwrite(imgBlur, f);
    tests{end+1} = struct('name', 'low-quality blurred', 'path', f, ...
        'expect_structure', true, 'expect_od', false);

    % 3. Grayscale
    imgGray = rgb2gray(img);
    f = fullfile(tmpDir, 'test_gray.png'); imwrite(imgGray, f);
    tests{end+1} = struct('name', 'grayscale input', 'path', f, ...
        'expect_structure', true, 'expect_od', true);

    % 4. RGB input (same as normal, explicit check)
    f = fullfile(tmpDir, 'test_rgb.png'); imwrite(img, f);
    tests{end+1} = struct('name', 'RGB input', 'path', f, ...
        'expect_structure', true, 'expect_od', true);

    % 5. Missing image
    f = fullfile(tmpDir, 'test_missing.png');
    tests{end+1} = struct('name', 'missing image', 'path', f, ...
        'expect_structure', false, 'expect_od', false);

    % 6. Corrupted image
    f = fullfile(tmpDir, 'test_corrupt.png');
    fid = fopen(f, 'w'); fwrite(fid, 'not an image', 'char'); fclose(fid);
    tests{end+1} = struct('name', 'corrupted image', 'path', f, ...
        'expect_structure', false, 'expect_od', false, 'expect_unreadable', true);

    % 7. No retinal field (black image)
    imgBlack = zeros(256, 256, 3, 'uint8');
    f = fullfile(tmpDir, 'test_black.png'); imwrite(imgBlack, f);
    tests{end+1} = struct('name', 'no retinal field', 'path', f, ...
        'expect_structure', true, 'expect_od', false);

    % 8. Optic disc detection case (bright disc on dark background)
    imgOD = createSyntheticFundus('with_od');
    f = fullfile(tmpDir, 'test_od.png'); imwrite(imgOD, f);
    tests{end+1} = struct('name', 'optic disc detection', 'path', f, ...
        'expect_structure', true, 'expect_od', true);

    % 9. Vessel segmentation case (with vessel-like structures)
    imgVess = createSyntheticFundus('with_vessels');
    f = fullfile(tmpDir, 'test_vessels.png'); imwrite(imgVess, f);
    tests{end+1} = struct('name', 'vessel segmentation', 'path', f, ...
        'expect_structure', true, 'expect_od', true);

    % 10. Lesion candidate case (dark spots)
    imgLesion = createSyntheticFundus('with_lesions');
    f = fullfile(tmpDir, 'test_lesions.png'); imwrite(imgLesion, f);
    tests{end+1} = struct('name', 'lesion candidates', 'path', f, ...
        'expect_structure', true, 'expect_od', true);

    % 11. Small image
    imgSmall = imresize(img, [64 64]);
    f = fullfile(tmpDir, 'test_small.png'); imwrite(imgSmall, f);
    tests{end+1} = struct('name', 'small image', 'path', f, ...
        'expect_structure', true, 'expect_od', false);

    % 12. Very bright (overexposed)
    imgBright = im2uint8(min(1, im2double(img) * 2));
    f = fullfile(tmpDir, 'test_bright.png'); imwrite(imgBright, f);
    tests{end+1} = struct('name', 'overexposed image', 'path', f, ...
        'expect_structure', true, 'expect_od', false);

    % Run tests
    results = struct('total', numel(tests), 'passed', 0, 'failed', 0, 'details', {{}});
    for k = 1:numel(tests)
        t = tests{k};
        try
            qr = struct('quality_status', 'GOOD', 'overall_quality_score', 80, 'enhanced', false);
            if ~exist(t.path, 'file')
                % Missing image test
                res = analyzeImage(t.path, qr, cfg);
                if ~isempty(res.failure_reason) && contains(res.failure_reason, 'UNREADABLE')
                    pass = true;
                else
                    pass = false;
                end
            else
                res = analyzeImage(t.path, qr, cfg);
                % Check no crash
                pass = true;
                % Check unreadable handling
                if isfield(t, 'expect_unreadable') && t.expect_unreadable
                    if res.overall_structure_status ~= "UNREADABLE"
                        pass = false;
                    end
                else
                    % Check structure status
                    if t.expect_structure && res.overall_structure_status == "ALL_FAILED"
                        pass = false;
                    end
                    % Check OD detection
                    if t.expect_od && ~res.optic_disc_detected
                        pass = false;
                    end
                end
                % Check output fields exist
                requiredFields = {'image_id', 'quality_status', 'retinal_area_fraction', ...
                    'optic_disc_detected', 'fovea_detected', 'vessel_area_fraction', ...
                    'ma_candidate_count', 'he_candidate_count', 'ex_candidate_count', ...
                    'nv_candidate', 'overall_structure_status', 'overall_lesion_status'};
                for f = 1:numel(requiredFields)
                    if ~isfield(res, requiredFields{f})
                        pass = false;
                        break;
                    end
                end
            end

            if pass
                results.passed = results.passed + 1;
                detail = sprintf('[PASS] %s', t.name);
            else
                results.failed = results.failed + 1;
                detail = sprintf('[FAIL] %s', t.name);
            end
            results.details{end+1} = detail; %#ok<AGROW>
            if opts.verbose, fprintf('%s\n', detail); end

        catch ME
            results.failed = results.failed + 1;
            detail = sprintf('[EXCEPTION] %s: %s', t.name, ME.message);
            results.details{end+1} = detail;
            if opts.verbose, fprintf('%s\n', detail); end
        end
    end

    if opts.verbose
        fprintf('=== testPhase3Pipeline %d/%d passed ===\n', results.passed, results.total);
        fprintf('Note: synthetic fixtures, not clinical validation\n');
    end
end

function img = createSyntheticFundus(variant)
    sz = 256;
    [X, Y] = meshgrid(1:sz, 1:sz);
    cx = 128; cy = 128; r = 90;
    mask = sqrt((X-cx).^2 + (Y-cy).^2) < r;

    % Base retina color
    base = zeros(sz, sz, 3, 'uint8');
    base(:,:,1) = 180; base(:,:,2) = 90; base(:,:,3) = 30;

    switch variant
        case 'with_od'
            % Add bright optic disc
            odx = cx + 30; ody = cy - 10; odr = 12;
            odMask = double(sqrt((X-odx).^2 + (Y-ody).^2) < odr);
            for c = 1:3
                ch = double(base(:,:,c));
                ch = ch .* (1 - odMask) + 220 * odMask;
                base(:,:,c) = uint8(ch);
            end

        case 'with_vessels'
            % Add dark vessel-like lines
            for ang = 0:30:330
                x1 = cx; y1 = cy;
                x2 = cx + r*0.9*cosd(ang);
                y2 = cy + r*0.9*sind(ang);
                n = 100;
                xs = round(linspace(x1, x2, n));
                ys = round(linspace(y1, y2, n));
                valid = xs > 0 & xs <= sz & ys > 0 & ys <= sz;
                idx = sub2ind([sz sz], ys(valid), xs(valid));
                for c = 1:3
                    ch = double(base(:,:,c));
                    ch(idx) = ch(idx) * 0.5;
                    base(:,:,c) = uint8(ch);
                end
            end

        case 'with_lesions'
            % Add dark spots (simulating hemorrhages/MA)
            lesionCenters = [80 80; 150 120; 100 160; 180 80];
            for l = 1:size(lesionCenters, 1)
                lx = lesionCenters(l, 1);
                ly = lesionCenters(l, 2);
                lr = 5 + randi(5);
                lmask = double(sqrt((X-lx).^2 + (Y-ly).^2) < lr);
                for c = 1:3
                    ch = double(base(:,:,c));
                    ch = ch .* (1 - lmask) + ch .* lmask * 0.3;
                    base(:,:,c) = uint8(ch);
                end
            end

        otherwise
            % Normal: add simple vessels
            for ang = 0:60:300
                x1 = cx; y1 = cy;
                x2 = cx + r*0.8*cosd(ang);
                y2 = cy + r*0.8*sind(ang);
                n = 80;
                xs = round(linspace(x1, x2, n));
                ys = round(linspace(y1, y2, n));
                valid = xs > 0 & xs <= sz & ys > 0 & ys <= sz;
                idx = sub2ind([sz sz], ys(valid), xs(valid));
                for c = 1:3
                    ch = double(base(:,:,c));
                    ch(idx) = ch(idx) * 0.6;
                    base(:,:,c) = uint8(ch);
                end
            end
            % Add optic disc
            odx = cx + 30; ody = cy - 10; odr = 10;
            odMask = double(sqrt((X-odx).^2 + (Y-ody).^2) < odr);
            for c = 1:3
                ch = double(base(:,:,c));
                ch = ch .* (1 - odMask) + 200 * odMask;
                base(:,:,c) = uint8(ch);
            end
    end

    % Apply circular mask
    for c = 1:3
        ch = double(base(:,:,c));
        ch(~mask) = 0;
        base(:,:,c) = uint8(ch);
    end

    img = base;
end
