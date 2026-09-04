function rerunGradCAM()
% rerunGradCAM  Generate Grad-CAM heatmaps with correct preprocessing
%
%   For each DR grade (G0-G4), pick a representative correctly-classified
%   image, generate Grad-CAM heatmap, and save overlay figures.

    fprintf('=== Grad-CAM Re-run (correct preprocessing) ===\n\n');

    cfgTL = transferLearningConfig();
    modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
    data = load(modelPath, 'trainedNetTL');
    net = data.trainedNetTL;

    outputDir = fullfile(cfgTL.projectRoot, 'results', 'phase20e', 'gradcam');
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    % Load corrected predictions
    csvPath = fullfile(cfgTL.paths.splitDir, 'val_classifier_corrected.csv');
    T = readtable(csvPath, 'TextType', 'string');

    grades = 0:4;
    gradeNames = {'G0_NoDR', 'G1_Mild', 'G2_Moderate', 'G3_Severe', 'G4_PDR'};

    for g = 1:5
        grade = grades(g);
        % Find correctly classified images for this grade
        mask = T.dr_grade == grade & T.predicted_grade == grade;
        idx = find(mask, 1);
        if isempty(idx)
            fprintf('  No correctly classified G%d found, skipping\n', grade);
            continue;
        end

        imgPath = char(T.file_path_absolute{idx});
        img = imread(imgPath);
        n = preprocessFundus(img, cfgTL.image.size);

        % Generate Grad-CAM
        [cam, camScore, predIdx] = gradcamSimple(net, n, 'TargetClass', g);

        % Create overlay
        fig = figure('Visible', 'off', 'Position', [100 100 800 400]);
        subplot(1,2,1);
        imshow(uint8(imresize(img, [224 224])));
        title(sprintf('Input (True: %s)', gradeNames{g}));

        subplot(1,2,2);
        imshow(uint8(imresize(img, [224 224])));
        hold on;
        h = imagesc(cam, [0, 1]);
        set(h, 'AlphaData', 0.4);
        colormap(fig, jet);
        colorbar;
        hold off;
        title(sprintf('Grad-CAM (P=%.3f)', camScore));

        % Save
        figName = sprintf('gradcam_%s_%s.png', gradeNames{g}, T.image_id{idx});
        saveas(fig, fullfile(outputDir, figName));
        close(fig);

        fprintf('  %s: True=%d Pred=%d CamScore=%.3f -> %s\n', ...
            T.image_id{idx}, grade, T.predicted_grade(idx), camScore, figName);
    end

    fprintf('\nGrad-CAM figures saved to: %s\n', outputDir);
    fprintf('=== DONE ===\n');
end
