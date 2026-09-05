function drScreeningGUI()
% drScreeningGUI  Interactive DR Screening demonstration GUI
%
%   Usage: drScreeningGUI
%
%   Features:
%       - Upload fundus image
%       - Real-time quality assessment
%       - One-click DR classification
%       - Predicted grade + referable status + confidence
%       - Retinal structure visualization
%       - Explainability heatmap overlay
%       - Human-review report generation
%       - Export results

    % Create main figure
    fig = figure('Name', 'DR-Screening-AI', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Position', [100, 100, 1200, 750], ...
        'Color', [0.94 0.94 0.94], ...
        'Resize', 'on');

    % State
    state = struct();
    state.modelLoaded = false;
    state.currentImage = [];
    state.currentResult = [];

    % --- LEFT PANEL: Image Display ---
    imgPanel = uipanel(fig, 'Position', [0.02, 0.02, 0.48, 0.96], ...
        'Title', 'Fundus Image', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');

    imgAxes = axes(imgPanel, 'Position', [0.05, 0.15, 0.9, 0.8]);
    title(imgAxes, 'No image loaded');
    axis(imgAxes, 'off');

    qualityText = uicontrol(imgPanel, 'Style', 'text', ...
        'Position', [10, 5, 350, 25], ...
        'String', 'Quality: --', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');

    % --- RIGHT PANEL: Results ---
    resPanel = uipanel(fig, 'Position', [0.52, 0.02, 0.46, 0.96], ...
        'Title', 'Analysis Results', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');

    % Grade display
    uicontrol(resPanel, 'Style', 'text', ...
        'Position', [10, 680, 100, 25], ...
        'String', 'DR Grade:', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');

    gradeText = uicontrol(resPanel, 'Style', 'text', ...
        'Position', [120, 680, 300, 25], ...
        'String', '--', ...
        'FontSize', 14, ...
        'FontWeight', 'bold', ...
        'ForegroundColor', [0 0.5 0], ...
        'HorizontalAlignment', 'left');

    % Referable status
    uicontrol(resPanel, 'Style', 'text', ...
        'Position', [10, 645, 100, 25], ...
        'String', 'Referable:', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');

    refText = uicontrol(resPanel, 'Style', 'text', ...
        'Position', [120, 645, 300, 25], ...
        'String', '--', ...
        'FontSize', 14, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');

    % Confidence
    uicontrol(resPanel, 'Style', 'text', ...
        'Position', [10, 610, 100, 25], ...
        'String', 'Confidence:', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');

    confText = uicontrol(resPanel, 'Style', 'text', ...
        'Position', [120, 610, 300, 25], ...
        'String', '--', ...
        'FontSize', 12, ...
        'HorizontalAlignment', 'left');

    % Probability bar
    uicontrol(resPanel, 'Style', 'text', ...
        'Position', [10, 575, 120, 25], ...
        'String', 'Referable Prob:', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');

    probBar = uicontrol(resPanel, 'Style', 'text', ...
        'Position', [130, 575, 200, 25], ...
        'String', '', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');

    % Class probabilities
    probPanel = uipanel(resPanel, 'Position', [0.02, 0.35, 0.96, 0.28], ...
        'Title', 'Class Probabilities', ...
        'FontSize', 10);

    probAxes = axes(probPanel, 'Position', [0.1, 0.1, 0.85, 0.85]);

    % Explanation / heatmap
    uicontrol(resPanel, 'Style', 'pushbutton', ...
        'Position', [10, 240, 100, 35], ...
        'String', 'Heatmap', ...
        'FontSize', 10, ...
        'Callback', @(src,evt) showHeatmap());

    uicontrol(resPanel, 'Style', 'pushbutton', ...
        'Position', [120, 240, 100, 35], ...
        'String', 'Lesions', ...
        'FontSize', 10, ...
        'Callback', @(src,evt) showLesionEvidence());

    uicontrol(resPanel, 'Style', 'pushbutton', ...
        'Position', [230, 240, 100, 35], ...
        'String', 'Report', ...
        'FontSize', 10, ...
        'Callback', @(src,evt) showReport());

    % Status bar
    statusText = uicontrol(resPanel, 'Style', 'text', ...
        'Position', [10, 10, 400, 25], ...
        'String', 'Ready. Load a model and image to begin.', ...
        'FontSize', 9, ...
        'HorizontalAlignment', 'left');

    % --- BUTTONS ---
    uicontrol(fig, 'Style', 'pushbutton', ...
        'Position', [30, 710, 160, 35], ...
        'String', 'Load Model', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'Callback', @(src,evt) loadModel());

    uicontrol(fig, 'Style', 'pushbutton', ...
        'Position', [200, 710, 200, 35], ...
        'String', 'Upload Fundus Image', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'Callback', @(src,evt) uploadImage());

    uicontrol(fig, 'Style', 'pushbutton', ...
        'Position', [410, 710, 200, 35], ...
        'String', 'Run DR Screening', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.85, 0.95, 0.85], ...
        'Callback', @(src,evt) runScreening());

    uicontrol(fig, 'Style', 'pushbutton', ...
        'Position', [620, 710, 150, 35], ...
        'String', 'Export Report', ...
        'FontSize', 10, ...
        'Callback', @(src,evt) exportReport());

    uicontrol(fig, 'Style', 'pushbutton', ...
        'Position', [780, 710, 150, 35], ...
        'String', 'Reset', ...
        'FontSize', 10, ...
        'Callback', @(src,evt) resetAll());

    % --- Callbacks ---
    function loadModel()
        statusText.String = 'Loading model...';
        drawnow;

        try
            cfgTL = transferLearningConfig();
            modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');

            if ~exist(modelPath, 'file')
                [file, path] = uigetfile('*.mat', 'Select trained model');
                if isequal(file, 0)
                    statusText.String = 'Model load cancelled.';
                    return;
                end
                modelPath = fullfile(path, file);
            end

            load(modelPath, 'trainedNetTL');
            state.modelLoaded = true;
            state.trainedNet = trainedNetTL;
            state.cfgTL = cfgTL;
            statusText.String = sprintf('Model loaded: %s', modelPath);
        catch ME
            statusText.String = sprintf('Model load FAILED: %s', ME.message);
        end
    end

    function uploadImage()
        [file, path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif', 'Image Files'}, ...
            'Select Fundus Image');
        if isequal(file, 0)
            return;
        end

        imagePath = fullfile(path, file);
        try
            img = imread(imagePath);
            state.currentImage = img;
            state.currentImagePath = imagePath;

            axes(imgAxes);
            imshow(img);
            title(imgAxes, file, 'FontSize', 10);

            % Quick quality check
            gray = rgb2gray(img);
            brightness = mean(gray(:));
            contrast = std(double(gray(:)));
            lap = fspecial('laplacian');
            lapResult = conv2(double(gray), lap, 'same');
            blurVar = var(lapResult(:));

            if brightness < 40 || brightness > 220 || contrast < 20 || blurVar < 100
                qualityText.String = sprintf('Quality: BORDERLINE (B:%.0f C:%.0f Bv:%.0f)', brightness, contrast, blurVar);
                qualityText.ForegroundColor = [0.8 0.5 0];
            else
                qualityText.String = sprintf('Quality: GOOD (B:%.0f C:%.0f Bv:%.0f)', brightness, contrast, blurVar);
                qualityText.ForegroundColor = [0 0.5 0];
            end

            statusText.String = sprintf('Image loaded: %s (%dx%d)', file, size(img,1), size(img,2));
        catch ME
            statusText.String = sprintf('Image load FAILED: %s', ME.message);
        end
    end

    function runScreening()
        if ~state.modelLoaded
            statusText.String = 'ERROR: Load model first.';
            return;
        end
        if isempty(state.currentImage)
            statusText.String = 'ERROR: Upload an image first.';
            return;
        end

        statusText.String = 'Running DR screening...';
        drawnow;

        try
            % Quality assessment (canonical pipeline)
            gray = rgb2gray(state.currentImage);
            brightness = mean(gray(:));
            contrast = std(double(gray(:)));
            lap = fspecial('laplacian');
            lapResult = conv2(double(gray), lap, 'same');
            blurVar = var(lapResult(:));

            quality = struct();
            quality.brightness = brightness;
            quality.contrast = contrast;
            quality.sharpness = blurVar;

            score = 0;
            if brightness >= 40 && brightness <= 220; score = score + 1; end
            if contrast >= 20; score = score + 1; end
            if blurVar >= 100; score = score + 1; end

            if score == 3
                quality.status = 'GOOD';
            elseif score == 2
                quality.status = 'BORDERLINE';
            else
                quality.status = 'POOR';
            end

            % Preprocess
            imgNorm = preprocessFundus(state.currentImage, state.cfgTL.image.size);

            % Classify
            [pred, scores] = classify(state.trainedNet, imgNorm);
            gradeNum = double(pred) - 1;

            % Lesion evidence
            evidence = extractLesionEvidence(state.currentImage);

            % Clinical decision via canonical logic
            result = applyClinicalLogic(gradeNum, scores, evidence, quality);

            % Update UI
            gradeText.String = sprintf('Grade %d: %s', result.gradeNum, result.gradeName);

            if result.referable
                refText.String = 'YES';
                refText.ForegroundColor = [0.8 0 0];
            else
                refText.String = 'NO';
                refText.ForegroundColor = [0 0.5 0];
            end

            confText.String = sprintf('%.1f%%', result.confidence);
            probBar.String = sprintf('%.4f (max class prob)', result.probability);

            % Class probabilities bar chart
            axes(probAxes);
            bar(scores, 'FaceColor', [0.3 0.6 0.9]);
            set(probAxes, 'XTickLabel', {'G0','G1','G2','G3','G4'});
            ylabel('Probability');
            ylim([0, 1]);
            title('Output Distribution');

            % Store result (flat structure matching applyClinicalLogic output)
            state.currentResult = result;
            state.currentResult.scores = scores;
            state.currentResult.evidence = evidence;

            statusText.String = sprintf('Complete: Grade %d (%s), Referable=%d, Conf=%.1f%%', ...
                result.gradeNum, result.gradeName, result.referable, result.confidence);
        catch ME
            statusText.String = sprintf('Screening FAILED: %s', ME.message);
        end
    end

    function showHeatmap()
        if isempty(state.currentResult)
            statusText.String = 'Run screening first.';
            return;
        end

        try
            % Formal Grad-CAM
            imgNorm = preprocessFundus(state.currentImage, state.cfgTL.image.size);

            [cam, ~, ~] = gradcamSimple(state.trainedNet, imgNorm);

            % Get top class from stored results
            topClass = state.currentResult.gradeNum + 1;

            % Overlay
            fig = figure('Name', 'Grad-CAM Explainability', 'NumberTitle', 'off');
            imshow(state.currentImage);
            hold on;
            h = imagesc(cam, [0, 1]);
            set(h, 'AlphaData', 0.4);
            colormap(fig, jet);
            colorbar;
            title(sprintf('Grad-CAM (Predicted: G%d, %s)', topClass-1, state.currentResult.gradeName));
            hold off;

            statusText.String = 'Grad-CAM heatmap displayed.';
        catch ME
            statusText.String = sprintf('Heatmap FAILED: %s', ME.message);
        end
    end

    function showLesionEvidence()
        if isempty(state.currentImage)
            statusText.String = 'Load an image first.';
            return;
        end

        try
            statusText.String = 'Extracting lesion evidence...';
            drawnow;

            evidence = extractLesionEvidence(state.currentImage);

            % Create evidence figure
            fig = figure('Name', 'Lesion Evidence', 'NumberTitle', 'off', ...
                'Position', [150, 150, 900, 400]);

            % Original image
            subplot(2, 3, 1);
            imshow(state.currentImage);
            title('Original Fundus');

            % Microaneurysm mask
            subplot(2, 3, 2);
            imshow(state.currentImage);
            hold on;
            if evidence.microaneurysms.count > 0
                h = imagesc(evidence.microaneurysms.mask);
                set(h, 'AlphaData', 0.4);
            end
            hold off;
            title(sprintf('Microaneurysms: %d (supporting)', evidence.microaneurysms.count));

            % Hemorrhage mask
            subplot(2, 3, 3);
            imshow(state.currentImage);
            hold on;
            if evidence.hemorrhages.count > 0
                h = imagesc(evidence.hemorrhages.mask);
                set(h, 'AlphaData', 0.4);
            end
            hold off;
            title(sprintf('Hemorrhages: %d (supporting)', evidence.hemorrhages.count));

            % Exudate mask
            subplot(2, 3, 4);
            imshow(state.currentImage);
            hold on;
            if evidence.exudates.count > 0
                h = imagesc(evidence.exudates.mask);
                set(h, 'AlphaData', 0.4);
            end
            hold off;
            title(sprintf('Exudates: %d (supporting)', evidence.exudates.count));

            % Neovascularization
            subplot(2, 3, 5);
            imshow(state.currentImage);
            hold on;
            if evidence.neovascularization.detected
                h = imagesc(evidence.neovascularization.mask);
                set(h, 'AlphaData', 0.4);
            end
            hold off;
            title(sprintf('Neovascularization: %s (supporting)', string(evidence.neovascularization.detected)));

            % Summary
            subplot(2, 3, 6);
            axis off;
            summaryText = { ...
                'LESION EVIDENCE SUMMARY (SUPPORTING)', ...
                '', ...
                sprintf('Severity: %s (supporting)', evidence.severity), ...
                sprintf('Total lesions: %d', evidence.totalLesions), ...
                '', ...
                sprintf('Microaneurysms: %d (supporting)', evidence.microaneurysms.count), ...
                sprintf('Hemorrhages: %d (supporting)', evidence.hemorrhages.count), ...
                sprintf('Exudates: %d (supporting)', evidence.exudates.count), ...
                sprintf('Neovascularization: %s (supporting)', string(evidence.neovascularization.detected)), ...
                '', ...
                evidence.summary ...
            };
            text(0.1, 0.9, summaryText, 'FontSize', 9, 'VerticalAlignment', 'top');
            title('Evidence Summary');

            sgtitle('Lesion-Level Evidence Analysis (Supporting)', 'FontSize', 12, 'FontWeight', 'bold');

            statusText.String = sprintf('Lesion evidence (supporting): %s (%d total)', evidence.severity, evidence.totalLesions);
        catch ME
            statusText.String = sprintf('Lesion evidence FAILED: %s', ME.message);
        end
    end

    function showReport()
        if isempty(state.currentResult)
            statusText.String = 'Run screening first.';
            return;
        end

        r = state.currentResult;
        grades = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};

        reportStr = { ...
            '========================================', ...
            '   DR-SCREENING-AI CLINICAL REPORT', ...
            '========================================', ...
            '', ...
            sprintf('Date: %s', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'))), ...
            sprintf('Image: %s', state.currentImagePath), ...
            '', ...
            '--- QUALITY ---', ...
            sprintf('Quality: %s', qualityText.String), ...
            '', ...
            '--- CLASSIFICATION ---', ...
            sprintf('DR Grade: %d (%s)', r.gradeNum, r.gradeName), ...
            sprintf('Referable DR: %s', string(r.referable)), ...
            sprintf('Referable Probability: %.4f', r.probability), ...
            sprintf('Confidence: %.1f%%', r.confidence), ...
            '', ...
            '--- CLASS PROBABILITIES ---', ...
            sprintf('  G0 (No DR):    %.4f', r.scores(1)), ...
            sprintf('  G1 (Mild):     %.4f', r.scores(2)), ...
            sprintf('  G2 (Moderate): %.4f', r.scores(3)), ...
            sprintf('  G3 (Severe):   %.4f', r.scores(4)), ...
            sprintf('  G4 (PDR):      %.4f', r.scores(5)), ...
            '', ...
            '--- DISCLAIMER ---', ...
            'This is a research prototype. Not for clinical use.', ...
            'Results require qualified ophthalmologist review.', ...
            '========================================' ...
        };

        reportFig = figure('Name', 'Clinical Report', 'NumberTitle', 'off', ...
            'Position', [200, 200, 600, 500]);
        uicontrol(reportFig, 'Style', 'listbox', ...
            'Position', [10, 10, 580, 480], ...
            'String', reportStr, ...
            'FontSize', 10, ...
            'FontName', 'Consolas', ...
            'Enable', 'inactive');

        statusText.String = 'Report displayed.';
    end

    function exportReport()
        if isempty(state.currentResult)
            statusText.String = 'Run screening first.';
            return;
        end

        [file, path] = uiputfile('*.txt', 'Save Report', 'DR_Report.txt');
        if isequal(file, 0)
            return;
        end

        r = state.currentResult;
        grades = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};

        fid = fopen(fullfile(path, file), 'w');
        fprintf(fid, 'DR-SCREENING-AI CLINICAL REPORT\n');
        fprintf(fid, '========================================\n\n');
        fprintf(fid, 'Date: %s\n', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        fprintf(fid, 'Image: %s\n\n', state.currentImagePath);
        fprintf(fid, 'QUALITY: %s\n\n', qualityText.String);
        fprintf(fid, 'CLASSIFICATION:\n');
        fprintf(fid, '  DR Grade: %d (%s)\n', r.gradeNum, r.gradeName);
        fprintf(fid, '  Referable DR: %s\n', string(r.referable));
        fprintf(fid, '  Referable Probability: %.4f\n', r.probability);
        fprintf(fid, '  Confidence: %.1f%%\n\n', r.confidence);
        fprintf(fid, 'CLASS PROBABILITIES:\n');
        for g = 0:4
            fprintf(fid, '  G%d: %.4f\n', g, r.scores(g+1));
        end
        fprintf(fid, '\n========================================\n');
        fprintf(fid, 'DISCLAIMER: Research prototype. Not for clinical use.\n');
        fprintf(fid, 'Lesion detection is experimental and has not been clinically validated.\n');
        fprintf(fid, 'Lesion evidence is provided for research/supporting purposes only\n');
        fprintf(fid, 'and should not be interpreted as a confirmed clinical finding.\n');
        fclose(fid);

        statusText.String = sprintf('Report saved: %s', fullfile(path, file));
    end

    function resetAll()
        state.currentImage = [];
        state.currentResult = [];
        state.currentImagePath = '';

        axes(imgAxes);
        cla;
        title(imgAxes, 'No image loaded');

        gradeText.String = '--';
        gradeText.ForegroundColor = [0 0.5 0];
        refText.String = '--';
        refText.ForegroundColor = [0 0 0];
        confText.String = '--';
        probBar.String = '';
        qualityText.String = 'Quality: --';

        cla(probAxes);
        title(probAxes, 'Class Probabilities');

        statusText.String = 'Reset. Ready for new image.';
    end
end
