function runPhase20ADiagnostics(varargin)
% runPhase20ADiagnostics  Forensic diagnostic visualization for Phase 20A audit
%
%   runPhase20ADiagnostics()
%   runPhase20ADiagnostics('ImagePaths', {path1, path2, ...})
%   runPhase20ADiagnostics('NumImages', 5)
%
%   Produces per-image diagnostic figures showing every pipeline stage:
%     - Original image
%     - Retinal field mask (approximate)
%     - Vessel mask
%     - Optic disc mask
%     - Microaneurysm candidates
%     - Hemorrhage candidates
%     - Exudate candidates
%     - Neovascularization candidates
%     - Grad-CAM heatmap
%     - Combined evidence overlay
%
%   Also saves a summary CSV with lesion counts per image.
%
%   This script does NOT modify the model or any frozen artifacts.

    p = inputParser;
    addParameter(p, 'ImagePaths', {}, @iscell);
    addParameter(p, 'NumImages', 5, @isnumeric);
    addParameter(p, 'OutputDir', fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20a_diagnostics'), @ischar);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    outputDir = p.Results.OutputDir;
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    if p.Results.Verbose
        fprintf('=== Phase 20A Forensic Diagnostics ===\n');
        fprintf('Output directory: %s\n', outputDir);
    end

    % Select images to analyze
    imagePaths = p.Results.ImagePaths;
    if isempty(imagePaths)
        imagePaths = selectRepresentativeImages(p.Results.NumImages);
    end

    nImages = numel(imagePaths);
    if p.Results.Verbose
        fprintf('Analyzing %d images\n\n', nImages);
    end

    % Summary table
    summaryTable = table();
    summaryIdx = 0;

    for imgIdx = 1:nImages
        imgPath = imagePaths{imgIdx};
        [~, imgName, ~] = fileparts(imgPath);

        if p.Results.Verbose
            fprintf('[%d/%d] Processing: %s\n', imgIdx, nImages, imgName);
        end

        try
            % Load image
            img = imread(imgPath);
            if size(img, 3) < 3
                if p.Results.Verbose
                    fprintf('  Skipping grayscale image\n');
                end
                continue;
            end

            % Run full pipeline
            result = runDiagnosticPipeline(img, imgPath);

            % Create diagnostic figure
            createDiagnosticFigure(img, result, imgName, outputDir);

            % Add to summary
            summaryIdx = summaryIdx + 1;
            summaryTable.image{summaryIdx} = imgName;
            summaryTable.ma_count(summaryIdx) = result.evidence.microaneurysms.count;
            summaryTable.he_count(summaryIdx) = result.evidence.hemorrhages.count;
            summaryTable.ex_count(summaryIdx) = result.evidence.exudates.count;
            summaryTable.nv_detected(summaryIdx) = result.evidence.neovascularization.detected;
            summaryTable.total_lesions(summaryIdx) = result.evidence.totalLesions;
            summaryTable.severity{summaryIdx} = result.evidence.severity;
            summaryTable.grade(summaryIdx) = result.gradeNum;
            summaryTable.referable(summaryIdx) = result.referable;
            summaryTable.confidence(summaryIdx) = result.confidence;

            if p.Results.Verbose
                fprintf('  Grade: %d | Ref: %d | MA: %d | HE: %d | EX: %d | NV: %d | Severity: %s\n', ...
                    result.gradeNum, result.referable, ...
                    result.evidence.microaneurysms.count, ...
                    result.evidence.hemorrhages.count, ...
                    result.evidence.exudates.count, ...
                    result.evidence.neovascularization.detected, ...
                    result.evidence.severity);
            end

        catch ME
            if p.Results.Verbose
                fprintf('  ERROR: %s\n', ME.message);
            end
        end
    end

    % Save summary
    if summaryIdx > 0
        summaryTable = summaryTable(1:summaryIdx, :);
        writetable(summaryTable, fullfile(outputDir, 'diagnostic_summary.csv'));
        if p.Results.Verbose
            fprintf('\nSummary saved to: %s\n', fullfile(outputDir, 'diagnostic_summary.csv'));
        end
    end

    if p.Results.Verbose
        fprintf('\n=== Diagnostics Complete ===\n');
    end
end

function imagePaths = selectRepresentativeImages(nImages)
% selectRepresentativeImages  Select representative fundus images for diagnosis

    imagePaths = {};

    % Try to load from test split
    testCsv = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'splits', 'test.csv');
    if exist(testCsv, 'file')
        T = readtable(testCsv);
        % Get first nImages images with absolute paths
        for i = 1:min(nImages, height(T))
            if ismember('file_path_absolu', T.Properties.VariableNames)
                imagePaths{end+1} = T.file_path_absolu{i};
            elseif ismember('file_path', T.Properties.VariableNames)
                imagePaths{end+1} = fullfile(fileparts(mfilename('fullpath')), '..', '..', T.file_path{i});
            end
        end
    end

    % Fallback: use first nImages from APTOS train
    if isempty(imagePaths)
        aptosDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'data', 'raw', 'APTOS2019', 'train_images');
        if exist(aptosDir, 'dir')
            files = dir(fullfile(aptosDir, '*.png'));
            for i = 1:min(nImages, numel(files))
                imagePaths{end+1} = fullfile(files(i).folder, files(i).name);
            end
        end
    end
end

function result = runDiagnosticPipeline(img, imgPath)
% runDiagnosticPipeline  Run the full analysis pipeline on one image

    result = struct();

    % Quality assessment
    gray = rgb2gray(img);
    brightness = mean(gray(:));
    contrast = std(double(gray(:)));
    lap = fspecial('laplacian');
    lapResult = conv2(double(gray), lap, 'same');
    blurVar = var(lapResult(:));

    score = 0;
    if brightness >= 40 && brightness <= 220; score = score + 1; end
    if contrast >= 20; score = score + 1; end
    if blurVar >= 100; score = score + 1; end

    if score == 3; qualityStatus = 'GOOD';
    elseif score == 2; qualityStatus = 'BORDERLINE';
    else; qualityStatus = 'POOR';
    end

    result.quality = struct('status', qualityStatus, 'brightness', brightness, ...
        'contrast', contrast, 'sharpness', blurVar);

    % Preprocess for classifier
    cfgTL = transferLearningConfig();
    n = preprocessFundus(img, cfgTL.image.size);

    % Classify (load model if needed)
    persistent trainedNet;
    if isempty(trainedNet)
        modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
        data = load(modelPath, 'trainedNetTL');
        trainedNet = data.trainedNetTL;
    end
    [pred, scores] = classify(trainedNet, n);
    gradeNum = double(pred) - 1;

    result.gradeNum = gradeNum;
    result.scores = scores;
    result.referable = gradeNum >= 2;
    result.confidence = max(scores);

    % Retinal field mask (approximate: circular crop)
    [rows, cols, ~] = size(img);
    centerR = rows / 2;
    centerC = cols / 2;
    radius = min(rows, cols) / 2 * 0.9;
    [X, Y] = meshgrid(1:cols, 1:rows);
    result.fovMask = ((X - centerC).^2 + (Y - centerR).^2) < radius^2;

    % Vessel mask (green channel threshold + morphological filtering)
    imgDouble = double(img) / 255;
    greenChannel = imgDouble(:,:,2);
    vesselMask = greenChannel < 0.4;
    se1 = strel('line', 10, 0);
    se2 = strel('line', 10, 60);
    se3 = strel('line', 10, 120);
    vesselMask = imopen(vesselMask, se1) | imopen(vesselMask, se2) | imopen(vesselMask, se3);
    vesselMask = imdilate(vesselMask, strel('disk', 2));
    result.vesselMask = vesselMask;

    % Optic disc mask
    grayDouble = rgb2gray(imgDouble);
    brightThresh = grayDouble > 0.7;
    brightThresh = imclose(brightThresh, strel('disk', 5));
    brightThresh = imfill(brightThresh, 'holes');
    discStats = regionprops(brightThresh, 'Area', 'Centroid', 'EquivDiameter');
    discMask = false(rows, cols);
    if ~isempty(discStats)
        areas = [discStats.Area];
        [~, maxIdx] = max(areas);
        discRadius = discStats(maxIdx).EquivDiameter / 2;
        center = discStats(maxIdx).Centroid;
        discMask = ((X - center(1)).^2 + (Y - center(2)).^2) < (discRadius * 1.3)^2;
    end
    result.discMask = discMask;

    % Lesion evidence
    evidence = extractLesionEvidence(img);
    result.evidence = evidence;

    % Grad-CAM
    try
        [cam, ~, ~] = gradcamSimple(trainedNet, n);
        result.gradcam = cam;
    catch
        result.gradcam = zeros(224, 224);
    end
end

function createDiagnosticFigure(img, result, imgName, outputDir)
% createDiagnosticFigure  Create a multi-panel diagnostic figure

    fig = figure('Name', sprintf('Phase 20A Diagnostic: %s', imgName), ...
        'NumberTitle', 'off', ...
        'Position', [50, 50, 1400, 900], ...
        'Color', 'white', ...
        'Visible', 'off');

    % Panel 1: Original image
    subplot(3, 4, 1);
    imshow(img);
    title(sprintf('Original: %s', imgName), 'FontSize', 9);

    % Panel 2: FOV mask
    subplot(3, 4, 2);
    imshow(result.fovMask);
    title('Retinal FOV Mask', 'FontSize', 9);

    % Panel 3: Vessel mask
    subplot(3, 4, 3);
    imshow(result.vesselMask);
    title('Vessel Mask', 'FontSize', 9);

    % Panel 4: Optic disc mask
    subplot(3, 4, 4);
    imshow(result.discMask);
    title('Optic Disc Mask', 'FontSize', 9);

    % Panel 5: Microaneurysm candidates
    subplot(3, 4, 5);
    imshow(img);
    if result.evidence.microaneurysms.count > 0 && ~isempty(result.evidence.microaneurysms.mask)
        imshowpair(img, result.evidence.microaneurysms.mask, 'blend');
    end
    title(sprintf('MA Candidates: %d', result.evidence.microaneurysms.count), 'FontSize', 9);

    % Panel 6: Hemorrhage candidates
    subplot(3, 4, 6);
    imshow(img);
    if result.evidence.hemorrhages.count > 0 && ~isempty(result.evidence.hemorrhages.mask)
        imshowpair(img, result.evidence.hemorrhages.mask, 'blend');
    end
    title(sprintf('HE Candidates: %d', result.evidence.hemorrhages.count), 'FontSize', 9);

    % Panel 7: Exudate candidates
    subplot(3, 4, 7);
    imshow(img);
    if result.evidence.exudates.count > 0 && ~isempty(result.evidence.exudates.mask)
        imshowpair(img, result.evidence.exudates.mask, 'blend');
    end
    title(sprintf('EX Candidates: %d', result.evidence.exudates.count), 'FontSize', 9);

    % Panel 8: NV candidates
    subplot(3, 4, 8);
    imshow(img);
    if result.evidence.neovascularization.detected && ~isempty(result.evidence.neovascularization.mask)
        imshowpair(img, result.evidence.neovascularization.mask, 'blend');
    end
    nvStr = 'None';
    if result.evidence.neovascularization.detected; nvStr = 'DETECTED'; end
    title(sprintf('NV: %s', nvStr), 'FontSize', 9);

    % Panel 9: Grad-CAM
    subplot(3, 4, 9);
    imshow(img);
    if any(result.gradcam(:))
        resizedCam = imresize(result.gradcam, [size(img,1), size(img,2)]);
        imagesc(resizedCam, 'AlphaData', 0.4);
        colormap(gca, jet);
    end
    title(sprintf('Grad-CAM (G%d)', result.gradeNum), 'FontSize', 9);

    % Panel 10: Combined evidence overlay
    subplot(3, 4, 10);
    combinedMask = false(size(img,1), size(img,2));
    if ~isempty(result.evidence.microaneurysms.mask)
        combinedMask = combinedMask | result.evidence.microaneurysms.mask;
    end
    if ~isempty(result.evidence.hemorrhages.mask)
        combinedMask = combinedMask | result.evidence.hemorrhages.mask;
    end
    if ~isempty(result.evidence.exudates.mask)
        combinedMask = combinedMask | result.evidence.exudates.mask;
    end
    if ~isempty(result.evidence.neovascularization.mask)
        combinedMask = combinedMask | result.evidence.neovascularization.mask;
    end
    imshow(img);
    if any(combinedMask(:))
        imshowpair(img, combinedMask, 'blend');
    end
    title('Combined Evidence', 'FontSize', 9);

    % Panel 11: Classification summary
    subplot(3, 4, 11);
    bar(result.scores, 'FaceColor', [0.3 0.6 0.9]);
    set(gca, 'XTickLabel', {'G0','G1','G2','G3','G4'});
    ylabel('Probability');
    ylim([0, 1]);
    refStr = 'NON-REF';
    if result.referable; refStr = 'REFERABLE'; end
    title(sprintf('Grade %d | %s | %.1f%%', result.gradeNum, refStr, result.confidence*100), 'FontSize', 9);

    % Panel 12: Evidence summary text
    subplot(3, 4, 12);
    axis off;
    summaryText = {
        sprintf('Quality: %s', result.quality.status)
        sprintf('Brightness: %.0f', result.quality.brightness)
        sprintf('Contrast: %.0f', result.quality.contrast)
        sprintf('Sharpness: %.0f', result.quality.sharpness)
        ''
        sprintf('MA: %d [%.2f]', result.evidence.microaneurysms.count, result.evidence.microaneurysms.confidence)
        sprintf('HE: %d [%.2f]', result.evidence.hemorrhages.count, result.evidence.hemorrhages.confidence)
        sprintf('EX: %d [%.2f]', result.evidence.exudates.count, result.evidence.exudates.confidence)
        sprintf('NV: %d [%.2f]', result.evidence.neovascularization.detected, result.evidence.neovascularization.confidence)
        ''
        sprintf('Total: %d', result.evidence.totalLesions)
        sprintf('Severity: %s', result.evidence.severity)
    };
    text(0.1, 0.9, strjoin(summaryText, '\n'), 'FontSize', 9, 'VerticalAlignment', 'top', ...
        'FontName', 'FixedWidth');
    title('Evidence Summary', 'FontSize', 9);

    % Save figure
    saveas(fig, fullfile(outputDir, sprintf('diagnostic_%s.png', imgName)));
    close(fig);
end
