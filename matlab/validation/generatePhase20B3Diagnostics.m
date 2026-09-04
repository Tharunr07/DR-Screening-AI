function generatePhase20B3Diagnostics(varargin)
% generatePhase20B3Diagnostics  Before/after + per-image Grad-CAM diagnostics
%
%   generatePhase20B3Diagnostics()
%   generatePhase20B3Diagnostics('NumImages', 5)
%
%   For up to NumImages representative fundus images (validation split or
%   APTOS train; NEVER the held-out test set), saves to results/demo/gradcam/:
%     gradcam_<id>_orig.png      - original fundus image
%     gradcam_<id>_raw.png       - raw (pre-normalization) ReLU CAM
%     gradcam_<id>_norm.png      - normalized CAM in [0,1]
%     gradcam_<id>_overlay.png   - overlay on original + predicted grade
%     gradcam_before_after.png   - rand(224,224) placeholder vs genuine CAM
%
%   Filenames are fixed and deterministic. No thresholds are tuned here.

    p = inputParser;
    addParameter(p, 'NumImages', 5, @isnumeric);
    addParameter(p, 'OutputDir', fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'demo', 'gradcam'), @ischar);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    outputDir = p.Results.OutputDir;
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    verbose = p.Results.Verbose;

    cfgTL = transferLearningConfig();
    modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
    assert(exist(modelPath, 'file') > 0, 'Frozen model not found: %s', modelPath);
    data = load(modelPath, 'trainedNetTL');
    net = data.trainedNetTL;

    paths = collectImagePaths(cfgTL, p.Results.NumImages);
    assert(~isempty(paths), 'No representative images found.');

    if verbose
        fprintf('=== Phase 20B.3 Grad-CAM diagnostics ===\n');
        fprintf('Images: %d | Output: %s\n\n', numel(paths), outputDir);
    end

    % --- Before/after figure (first image) ---
    firstImg = imread(paths{1});
    [~, firstId, ~] = fileparts(paths{1});
    n1 = preprocessFundus(firstImg, cfgTL.image.size);
    [pred1, ~] = classify(net, n1);
    [camAfter, ~, ~] = gradcamSimple(net, n1, 'TargetClass', double(pred1));

    % Deterministic stand-in for the old placeholder's statistics:
    % the old code displayed rand(224,224) — uniform noise, mean ~0.5,
    % spatially uncorrelated. We render a fixed hash-noise pattern with the
    % same statistics to illustrate it (labeled as such). No RNG is used
    % anywhere in the Grad-CAM path (Phase 20B.3).
    [XX, YY] = meshgrid(1:224, 1:224);
    camBefore = mod(sin(XX * 12.9898 + YY * 78.233) * 43758.5453, 1);

    fig = figure('Visible', 'off', 'Position', [50, 50, 1100, 420], 'Color', 'white');
    subplot(1, 3, 1);
    imshow(firstImg);
    title(sprintf('Original (%s)', strrep(firstId, '_', '\_')), 'FontSize', 10);
    subplot(1, 3, 2);
    imagesc(camBefore, [0, 1]); axis image off; colormap(jet); colorbar;
    title('BEFORE: rand(224,224) placeholder', 'FontSize', 10, 'Color', [0.7 0 0]);
    subplot(1, 3, 3);
    imagesc(camAfter, [0, 1]); axis image off; colormap(jet); colorbar;
    title(sprintf('AFTER: genuine Grad-CAM (G%d)', double(pred1) - 1), ...
        'FontSize', 10, 'Color', [0 0.45 0]);
    saveas(fig, fullfile(outputDir, 'gradcam_before_after.png'));
    close(fig);
    if verbose
        fprintf('Wrote gradcam_before_after.png\n');
    end

    % --- Per-image diagnostics ---
    for i = 1:numel(paths)
        img = imread(paths{i});
        [~, imgId, ~] = fileparts(paths{i});
        safeId = regexprep(imgId, '[^A-Za-z0-9_]', '_');
        n = preprocessFundus(img, cfgTL.image.size);

        [pred, scores] = classify(net, n);
        grade = double(pred) - 1;
        [camNorm, ~, ~] = gradcamSimple(net, n, 'TargetClass', double(pred));
        camRaw = rawReLUCAM(net, n, double(pred));
        camDisp = imresize(camNorm, [size(img, 1), size(img, 2)]);

        imwrite(img, fullfile(outputDir, sprintf('gradcam_%s_orig.png', safeId)));
        imwrite(mat2gray(camRaw), fullfile(outputDir, sprintf('gradcam_%s_raw.png', safeId)));
        imwrite(mat2gray(camNorm), fullfile(outputDir, sprintf('gradcam_%s_norm.png', safeId)));

        fig = figure('Visible', 'off', 'Position', [50, 50, 500, 460], 'Color', 'white');
        imshow(img); hold on;
        h = imagesc(camDisp, [0, 1]);
        set(h, 'AlphaData', 0.4);
        colormap(jet);
        title(sprintf('G%d (P=%.1f%%) — attention aid, not a diagnosis', ...
            grade, max(scores) * 100), 'FontSize', 10);
        hold off;
        saveas(fig, fullfile(outputDir, sprintf('gradcam_%s_overlay.png', safeId)));
        close(fig);

        if verbose
            fprintf('[%d/%d] %s -> grade G%d\n', i, numel(paths), safeId, grade);
        end
    end

    if verbose
        fprintf('\nDiagnostics complete: %s\n', outputDir);
    end
end


function camRaw = rawReLUCAM(net, img, targetIdx)
% rawReLUCAM  Pre-normalization ReLU CAM for the raw diagnostic panel
    F = double(activations(net, img, 'res5b_branch2b', 'OutputAs', 'channels'));
    [fH, fW, ~] = size(F);
    Z = fH * fW;
    pv = squeeze(sum(sum(F, 1), 2)) / Z;
    pv = pv(:);
    layers = net.Layers;
    W1 = []; b1 = []; W2 = []; b2 = []; W3 = [];
    for i = 1:numel(layers)
        if isa(layers(i), 'nnet.cnn.layer.FullyConnectedLayer')
            switch layers(i).Name
                case 'fc_dr_1'
                    W1 = double(layers(i).Weights); b1 = double(layers(i).Bias(:));
                case 'fc_dr_2'
                    W2 = double(layers(i).Weights); b2 = double(layers(i).Bias(:));
                case 'fc_dr_output'
                    W3 = double(layers(i).Weights);
            end
        end
    end
    h1 = max(W1 * pv + b1, 0);
    m2mask = (W2 * h1 + b2) > 0;
    dy_dh2 = W3(targetIdx, :) .* m2mask(:)';
    dy_dh1 = (dy_dh2 * W2) .* ((W1 * pv + b1) > 0)';
    alpha = (dy_dh1 * W1)' / Z;
    camRaw = zeros(fH, fW);
    for k = 1:size(F, 3)
        camRaw = camRaw + alpha(k) * F(:, :, k);
    end
    camRaw = max(camRaw, 0);
    camRaw = imresize(camRaw, [size(img, 1), size(img, 2)]);
end

function paths = collectImagePaths(cfgTL, nMax)
% collectImagePaths  Validation split, else APTOS train. Never test.csv.
    paths = {};
    valCsv = fullfile(cfgTL.paths.splitDir, 'val.csv');
    if exist(valCsv, 'file')
        try
            T = readtable(valCsv);
            col = '';
            for k = 1:numel(T.Properties.VariableNames)
                nm = lower(T.Properties.VariableNames{k});
                if ~isempty(strfind(nm, 'path')) || ~isempty(strfind(nm, 'file'))
                    col = T.Properties.VariableNames{k};
                    break;
                end
            end
            if ~isempty(col)
                for i = 1:height(T)
                    cand = char(T.(col){i});
                    if ~exist(cand, 'file')
                        cand = fullfile(cfgTL.projectRoot, cand);
                    end
                    if exist(cand, 'file')
                        paths{end+1} = cand;
                        if numel(paths) >= nMax
                            return;
                        end
                    end
                end
            end
        catch
        end
    end
    aptosDir = fullfile(cfgTL.projectRoot, 'data', 'raw', 'APTOS2019', 'train_images');
    if exist(aptosDir, 'dir')
        files = dir(fullfile(aptosDir, '*.png'));
        for i = 1:numel(files)
            if numel(paths) >= nMax
                return;
            end
            paths{end+1} = fullfile(files(i).folder, files(i).name);
        end
    end
end
