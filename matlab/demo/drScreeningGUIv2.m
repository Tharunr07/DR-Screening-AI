function drScreeningGUIv2()
% drScreeningGUIv2  Production-grade DR Screening GUI
%
%   Usage: drScreeningGUIv2
%
%   Features:
%       - Professional header with system status
%       - Image quality assessment with recapture guidance
%       - One-click screening workflow
%       - Structured evidence panel
%       - Clinical report generation
%       - Export to text/CSV
%       - Screening history log

    % Create main figure
    fig = figure('Name', 'AI Diabetic Retinopathy Screening System', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Position', [50, 50, 1400, 850], ...
        'Color', [0.95 0.95 0.97], ...
        'Resize', 'on');

    % State
    state = struct();
    state.modelLoaded = false;
    state.currentImage = [];
    state.currentResult = [];
    state.currentImagePath = '';
    state.screeningHistory = {};
    state.screeningCount = 0;

    % --- HEADER ---
    headerPanel = uipanel(fig, 'Position', [0, 0.93, 1, 0.07], ...
        'BorderType', 'none', ...
        'BackgroundColor', [0.15 0.25 0.45]);

    uicontrol(headerPanel, 'Style', 'text', ...
        'Position', [20, 5, 600, 30], ...
        'String', 'AI DIABETIC RETINOPATHY SCREENING SYSTEM', ...
        'FontSize', 16, ...
        'FontWeight', 'bold', ...
        'ForegroundColor', 'white', ...
        'BackgroundColor', [0.15 0.25 0.45], ...
        'HorizontalAlignment', 'left');

    statusIndicator = uicontrol(headerPanel, 'Style', 'text', ...
        'Position', [1100, 5, 280, 30], ...
        'String', 'System: Ready', ...
        'FontSize', 11, ...
        'ForegroundColor', [0.8 0.9 0.8], ...
        'BackgroundColor', [0.15 0.25 0.45], ...
        'HorizontalAlignment', 'right');

    % --- LEFT COLUMN: Image + Quality ---
    leftPanel = uipanel(fig, 'Position', [0.01, 0.01, 0.42, 0.91], ...
        'Title', '', ...
        'FontSize', 10, ...
        'BackgroundColor', [0.95 0.95 0.97]);

    % Image display
    imgPanel = uipanel(leftPanel, 'Position', [0.02, 0.35, 0.96, 0.63], ...
        'Title', 'Fundus Image', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');

    imgAxes = axes(imgPanel, 'Position', [0.05, 0.1, 0.9, 0.85]);
    title(imgAxes, 'No image loaded', 'FontSize', 11);
    axis(imgAxes, 'off');

    % Quality assessment
    qualityPanel = uipanel(leftPanel, 'Position', [0.02, 0.02, 0.96, 0.31], ...
        'Title', 'Image Quality Assessment', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');

    qualityGrade = uicontrol(qualityPanel, 'Style', 'text', ...
        'Position', [10, 130, 200, 30], ...
        'String', 'Quality: --', ...
        'FontSize', 14, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');

    qualityDetails = uicontrol(qualityPanel, 'Style', 'text', ...
        'Position', [10, 95, 500, 30], ...
        'String', 'Brightness: -- | Contrast: -- | Sharpness: --', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');

    qualityGuidance = uicontrol(qualityPanel, 'Style', 'text', ...
        'Position', [10, 55, 500, 35], ...
        'String', '', ...
        'FontSize', 10, ...
        'ForegroundColor', [0.8 0.4 0], ...
        'HorizontalAlignment', 'left');

    qualityBar = uicontrol(qualityPanel, 'Style', 'text', ...
        'Position', [10, 10, 500, 25], ...
        'String', '', ...
        'FontSize', 9, ...
        'ForegroundColor', [0.4 0.4 0.4], ...
        'HorizontalAlignment', 'left');

    % --- MIDDLE COLUMN: Results ---
    midPanel = uipanel(fig, 'Position', [0.44, 0.01, 0.28, 0.91], ...
        'Title', '', ...
        'FontSize', 10, ...
        'BackgroundColor', [0.95 0.95 0.97]);

    % Screening result header
    resultHeader = uipanel(midPanel, 'Position', [0.03, 0.72, 0.94, 0.26], ...
        'Title', 'Screening Result', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');

    gradeText = uicontrol(resultHeader, 'Style', 'text', ...
        'Position', [10, 100, 250, 40], ...
        'String', 'Grade: --', ...
        'FontSize', 18, ...
        'FontWeight', 'bold', ...
        'ForegroundColor', [0 0.5 0], ...
        'HorizontalAlignment', 'center');

    refText = uicontrol(resultHeader, 'Style', 'text', ...
        'Position', [10, 60, 250, 35], ...
        'String', 'Referable: --', ...
        'FontSize', 14, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center');

    confText = uicontrol(resultHeader, 'Style', 'text', ...
        'Position', [10, 25, 250, 30], ...
        'String', 'Confidence: --', ...
        'FontSize', 12, ...
        'HorizontalAlignment', 'center');

    riskText = uicontrol(resultHeader, 'Style', 'text', ...
        'Position', [10, 0, 250, 25], ...
        'String', 'Risk: --', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center');

    % Evidence panel (supporting evidence)
    evidencePanel = uipanel(midPanel, 'Position', [0.03, 0.38, 0.94, 0.32], ...
        'Title', 'Lesion Evidence (Supporting)', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');

    evidenceMA = uicontrol(evidencePanel, 'Style', 'text', ...
        'Position', [10, 110, 280, 25], ...
        'String', 'Microaneurysms: --', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');

    evidenceHem = uicontrol(evidencePanel, 'Style', 'text', ...
        'Position', [10, 85, 280, 25], ...
        'String', 'Hemorrhages: --', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');

    evidenceExu = uicontrol(evidencePanel, 'Style', 'text', ...
        'Position', [10, 60, 280, 25], ...
        'String', 'Exudates: --', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');

    evidenceNV = uicontrol(evidencePanel, 'Style', 'text', ...
        'Position', [10, 35, 280, 25], ...
        'String', 'Neovascularization: --', ...
        'FontSize', 10, ...
        'HorizontalAlignment', 'left');

    evidenceSummary = uicontrol(evidencePanel, 'Style', 'text', ...
        'Position', [10, 5, 280, 25], ...
        'String', 'Overall: --', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left');

    % Consistency warning
    warningPanel = uipanel(midPanel, 'Position', [0.03, 0.38, 0.94, 0.32], ...
        'Title', 'Clinical Consistency', ...
        'FontSize', 10, ...
        'FontWeight', 'bold', ...
        'Visible', 'off');

    warningText = uicontrol(warningPanel, 'Style', 'text', ...
        'Position', [5, 5, 270, 100], ...
        'String', '', ...
        'FontSize', 9, ...
        'ForegroundColor', [0.8 0.4 0], ...
        'HorizontalAlignment', 'left', ...
        'Visible', 'off');

    % Class probabilities
    probPanel = uipanel(midPanel, 'Position', [0.03, 0.02, 0.94, 0.34], ...
        'Title', 'DR Grade Probabilities', ...
        'FontSize', 10);

    probAxes = axes(probPanel, 'Position', [0.12, 0.1, 0.82, 0.85]);

    % --- RIGHT COLUMN: Actions + History ---
    rightPanel = uipanel(fig, 'Position', [0.73, 0.01, 0.26, 0.91], ...
        'Title', '', ...
        'FontSize', 10, ...
        'BackgroundColor', [0.95 0.95 0.97]);

    % Action buttons
    actionPanel = uipanel(rightPanel, 'Position', [0.03, 0.65, 0.94, 0.33], ...
        'Title', 'Actions', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');

    uicontrol(actionPanel, 'Style', 'pushbutton', ...
        'Position', [10, 175, 250, 40], ...
        'String', 'Load Model', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'Callback', @(src,evt) loadModel());

    uicontrol(actionPanel, 'Style', 'pushbutton', ...
        'Position', [10, 130, 250, 40], ...
        'String', 'Upload Fundus Image', ...
        'FontSize', 11, ...
        'FontWeight', 'bold', ...
        'Callback', @(src,evt) uploadImage());

    uicontrol(actionPanel, 'Style', 'pushbutton', ...
        'Position', [10, 85, 250, 40], ...
        'String', 'Run Screening', ...
        'FontSize', 12, ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.85, 0.95, 0.85], ...
        'Callback', @(src,evt) runScreening());

    uicontrol(actionPanel, 'Style', 'pushbutton', ...
        'Position', [10, 40, 120, 35], ...
        'String', 'Report', ...
        'FontSize', 10, ...
        'Callback', @(src,evt) showClinicalReport());

    uicontrol(actionPanel, 'Style', 'pushbutton', ...
        'Position', [140, 40, 120, 35], ...
        'String', 'Show Heatmap', ...
        'FontSize', 10, ...
        'Callback', @(src,evt) showHeatmap());

    uicontrol(actionPanel, 'Style', 'pushbutton', ...
        'Position', [10, 5, 120, 30], ...
        'String', 'Export', ...
        'FontSize', 10, ...
        'Callback', @(src,evt) exportReport());

    uicontrol(actionPanel, 'Style', 'pushbutton', ...
        'Position', [140, 5, 120, 30], ...
        'String', 'Reset', ...
        'FontSize', 10, ...
        'Callback', @(src,evt) resetAll());

    % Screening history
    historyPanel = uipanel(rightPanel, 'Position', [0.03, 0.02, 0.94, 0.61], ...
        'Title', 'Screening History', ...
        'FontSize', 11, ...
        'FontWeight', 'bold');

    historyList = uicontrol(historyPanel, 'Style', 'listbox', ...
        'Position', [5, 5, 265, 195], ...
        'FontSize', 9, ...
        'Max', 100);

    clearHistoryBtn = uicontrol(historyPanel, 'Style', 'pushbutton', ...
        'Position', [5, -20, 265, 25], ...
        'String', 'Clear History', ...
        'FontSize', 9, ...
        'Callback', @(src,evt) clearHistory());

    % --- Callbacks ---

    function loadModel()
        try
            statusIndicator.String = 'System: Loading model...';
            statusIndicator.ForegroundColor = [1 0.8 0];
            drawnow;

            cfgTL = transferLearningConfig();
            modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
            data = load(modelPath, 'trainedNetTL');
            state.trainedNet = data.trainedNetTL;
            state.modelLoaded = true;

            statusIndicator.String = 'System: Model loaded';
            statusIndicator.ForegroundColor = [0.2 0.8 0.2];
        catch ME
            statusIndicator.String = 'System: Model load FAILED';
            statusIndicator.ForegroundColor = [1 0.2 0.2];
            errordlg(sprintf('Failed to load model: %s', ME.message), 'Error');
        end
    end

    function uploadImage()
        [file, path] = uigetfile({'*.png;*.jpg;*.jpeg', 'Image files'}, 'Select Fundus Image');
        if isequal(file, 0)
            return;
        end

        fullPath = fullfile(path, file);
        try
            img = imread(fullPath);
            state.currentImage = img;
            state.currentImagePath = fullPath;

            imshow(img, 'Parent', imgAxes);
            title(imgAxes, file, 'FontSize', 10);

            % Quality assessment
            assessQuality(img, file);

            statusIndicator.String = sprintf('Image: %s', file);
            statusIndicator.ForegroundColor = [0.2 0.6 0.9];
        catch ME
            errordlg(sprintf('Failed to load image: %s', ME.message), 'Error');
        end
    end

    function assessQuality(img, filename)
        gray = rgb2gray(img);
        brightness = mean(gray(:));
        contrast = std(double(gray(:)));
        lap = fspecial('laplacian');
        lapResult = conv2(double(gray), lap, 'same');
        blurVar = var(lapResult(:));

        % Quality scoring
        score = 0;
        issues = {};

        if brightness >= 40 && brightness <= 220
            score = score + 1;
        else
            if brightness < 40
                issues{end+1} = 'Too dark';
            else
                issues{end+1} = 'Too bright';
            end
        end

        if contrast >= 20
            score = score + 1;
        else
            issues{end+1} = 'Low contrast';
        end

        if blurVar >= 100
            score = score + 1;
        else
            issues{end+1} = 'Blurry';
        end

        % Grade quality
        if score == 3
            grade = 'GOOD';
            gradeColor = [0 0.5 0];
            guidance = 'Image is suitable for AI screening.';
        elseif score == 2
            grade = 'BORDERLINE';
            gradeColor = [0.8 0.5 0];
            guidance = 'Image may affect accuracy. Consider recapture if possible.';
        else
            grade = 'POOR';
            gradeColor = [0.8 0 0];
            guidance = 'Image quality insufficient. Please recapture with improved illumination and focus.';
        end

        qualityGrade.String = sprintf('Quality: %s', grade);
        qualityGrade.ForegroundColor = gradeColor;
        qualityDetails.String = sprintf('Brightness: %.0f | Contrast: %.0f | Sharpness: %.0f', brightness, contrast, blurVar);
        qualityGuidance.String = guidance;
        qualityBar.String = sprintf('Score: %d/3 | Image: %s', score, filename);
    end

    function runScreening()
        if ~state.modelLoaded
            errordlg('Load model first.', 'Error');
            return;
        end
        if isempty(state.currentImage)
            errordlg('Upload an image first.', 'Error');
            return;
        end

        try
            statusIndicator.String = 'Screening in progress...';
            statusIndicator.ForegroundColor = [1 0.8 0];
            drawnow;

            % Quality assessment
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

            % Quality scoring
            score = 0;
            if brightness >= 40 && brightness <= 220
                score = score + 1;
            end
            if contrast >= 20
                score = score + 1;
            end
            if blurVar >= 100
                score = score + 1;
            end

            if score == 3
                quality.status = 'GOOD';
            elseif score == 2
                quality.status = 'BORDERLINE';
            else
                quality.status = 'POOR';
            end

            % Preprocess
            cfgTL = transferLearningConfig();
            n = preprocessFundus(state.currentImage, cfgTL.image.size);

            % Classify
            [pred, scores] = classify(state.trainedNet, n);
            gradeNum = double(pred) - 1;

            % Lesion evidence
            evidence = extractLesionEvidence(state.currentImage);

            % Apply clinical logic (quality gating, referable consistency, etc.)
            result = applyClinicalLogic(gradeNum, scores, evidence, quality);

            % Update UI based on clinical result
            if strcmp(result.status, 'UNGRADABLE')
                % Image is ungradeable - show rejection
                gradeText.String = 'UNGRADABLE';
                gradeText.ForegroundColor = [0.8 0 0];
                refText.String = 'RECAPTURE';
                refText.ForegroundColor = [0.8 0 0];
                confText.String = 'N/A';
                riskText.String = 'N/A';
                riskText.ForegroundColor = [0.8 0 0];

                % Hide evidence panels
                evidenceMA.String = 'Microaneurysms: N/A (image ungradeable)';
                evidenceMA.ForegroundColor = [0.5 0.5 0.5];
                evidenceHem.String = 'Hemorrhages: N/A (image ungradeable)';
                evidenceHem.ForegroundColor = [0.5 0.5 0.5];
                evidenceExu.String = 'Exudates: N/A (image ungradeable)';
                evidenceExu.ForegroundColor = [0.5 0.5 0.5];
                evidenceNV.String = 'Neovascularization: N/A (image ungradeable)';
                evidenceNV.ForegroundColor = [0.5 0.5 0.5];
                evidenceSummary.String = 'N/A';
                evidenceSummary.ForegroundColor = [0.5 0.5 0.5];

                % Show warning
                warningPanel.Visible = 'on';
                warningText.Visible = 'on';
                warningText.String = result.recommendation;
                warningText.ForegroundColor = [0.8 0 0];

                statusIndicator.String = 'Image ungradeable - recapture required';
                statusIndicator.ForegroundColor = [1 0.2 0.2];
            else
                % Image is gradeable - show classification
                gradeText.String = sprintf('Grade %d: %s', result.gradeNum, result.gradeName);

                if result.referable
                    refText.String = 'Referable: YES';
                    refText.ForegroundColor = [0.8 0 0];
                else
                    refText.String = 'Referable: NO';
                    refText.ForegroundColor = [0 0.5 0];
                end

                % Show probability and confidence level
                confText.String = sprintf('Prob: %.1f%% | Conf: %s', ...
                    result.probability*100, result.confidenceLevel);

                % Risk assessment
                if result.gradeNum == 0
                    riskText.String = 'Risk: NONE';
                    riskText.ForegroundColor = [0 0.5 0];
                elseif result.gradeNum <= 2
                    riskText.String = 'Risk: MODERATE';
                    riskText.ForegroundColor = [0.8 0.5 0];
                else
                    riskText.String = 'Risk: HIGH';
                    riskText.ForegroundColor = [0.8 0 0];
                end

                % Evidence (labeled as supporting evidence)
                if evidence.microaneurysms.count > 0
                    evidenceMA.String = sprintf('Microaneurysms: %d (supporting)', evidence.microaneurysms.count);
                    evidenceMA.ForegroundColor = [0.8 0.4 0];
                else
                    evidenceMA.String = 'Microaneurysms: None detected';
                    evidenceMA.ForegroundColor = [0 0.5 0];
                end

                if evidence.hemorrhages.count > 0
                    evidenceHem.String = sprintf('Hemorrhages: %d (supporting)', evidence.hemorrhages.count);
                    evidenceHem.ForegroundColor = [0.8 0.4 0];
                else
                    evidenceHem.String = 'Hemorrhages: None detected';
                    evidenceHem.ForegroundColor = [0 0.5 0];
                end

                if evidence.exudates.count > 0
                    evidenceExu.String = sprintf('Exudates: %d (supporting)', evidence.exudates.count);
                    evidenceExu.ForegroundColor = [0.8 0.4 0];
                else
                    evidenceExu.String = 'Exudates: None detected';
                    evidenceExu.ForegroundColor = [0 0.5 0];
                end

                if evidence.neovascularization.detected
                    evidenceNV.String = 'NV: DETECTED (supporting)';
                    evidenceNV.ForegroundColor = [0.8 0 0];
                else
                    evidenceNV.String = 'NV: None detected';
                    evidenceNV.ForegroundColor = [0 0.5 0];
                end

                evidenceSummary.String = sprintf('Severity: %s (supporting)', evidence.severity);

                % Show consistency warning if needed
                if ~isempty(result.consistencyWarning)
                    warningPanel.Visible = 'on';
                    warningText.Visible = 'on';
                    warningText.String = result.consistencyWarning;
                    if strcmp(result.consistency, 'MAJOR_INCONSISTENCY')
                        warningText.ForegroundColor = [0.8 0 0];
                    else
                        warningText.ForegroundColor = [0.8 0.4 0];
                    end
                else
                    warningPanel.Visible = 'off';
                    warningText.Visible = 'off';
                end

                statusIndicator.String = sprintf('Screening complete: Grade %d (%s)', ...
                    result.gradeNum, result.gradeName);
                statusIndicator.ForegroundColor = [0.2 0.8 0.2];
            end

            % Class probabilities bar chart
            axes(probAxes);
            bar(scores, 'FaceColor', [0.3 0.6 0.9]);
            set(probAxes, 'XTickLabel', {'G0','G1','G2','G3','G4'});
            ylabel('Probability');
            title('DR Grade Distribution');
            ylim([0, 1]);

            % Store result
            state.currentResult = result;
            state.currentResult.scores = scores;
            state.currentResult.evidence = evidence;
            state.currentResult.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            state.currentResult.quality = quality;

            % Add to history
            addToHistory(result);

        catch ME
            statusIndicator.String = 'Screening FAILED';
            statusIndicator.ForegroundColor = [1 0.2 0.2];
            errordlg(sprintf('Screening failed: %s', ME.message), 'Error');
        end
    end

    function addToHistory(result)
        state.screeningCount = state.screeningCount + 1;
        screenID = sprintf('DR%03d', state.screeningCount);
        timestamp = datestr(now, 'HH:MM:SS');

        if strcmp(result.status, 'UNGRADABLE')
            entry = sprintf('%s | %s | UNGRADABLE | RECAPTURE', screenID, timestamp);
        else
            refStr = 'No';
            if result.referable; refStr = 'Yes'; end
            entry = sprintf('%s | %s | G%d %s | Ref:%s | %.0f%% | %s', ...
                screenID, timestamp, result.gradeNum, result.gradeName, ...
                refStr, result.probability*100, result.consistency);
        end

        state.screeningHistory{end+1} = entry;
        set(historyList, 'String', state.screeningHistory);
        set(historyList, 'Value', numel(state.screeningHistory));
    end

    function clearHistory()
        state.screeningHistory = {};
        state.screeningCount = 0;
        set(historyList, 'String', {});
    end

    function showClinicalReport()
        if isempty(state.currentResult)
            errordlg('Run screening first.', 'Error');
            return;
        end

        try
            % Generate clinical report
            imageInfo = struct('path', state.currentImagePath, ...
                'timestamp', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

            % Get quality info from actual screening result
            quality = state.currentResult.quality;

            % Classification from current result
            classification = struct('gradeNum', state.currentResult.gradeNum, ...
                'gradeName', state.currentResult.gradeName, ...
                'scores', state.currentResult.scores, ...
                'referable', state.currentResult.referable, ...
                'probability', state.currentResult.probability);

            % Evidence from current result
            evidence = state.currentResult.evidence;

            % Grad-CAM: genuine class-specific attention map.
            % NEVER substitute random or fabricated data. On any failure,
            % pass [] so the report honestly states "Grad-CAM: Not available".
            gradcam = [];
            try
                if state.modelLoaded && ~isempty(state.currentImage)
                    cfgG = transferLearningConfig();
                    nG = preprocessFundus(state.currentImage, cfgG.image.size);
                    [predG, ~] = classify(state.trainedNet, nG);
                    [camG, ~, ~] = gradcamSimple(state.trainedNet, nG, ...
                        'TargetClass', double(predG));
                    gradcam = struct('cam', camG, ...
                        'targetGrade', double(predG) - 1);
                end
            catch
                gradcam = [];
            end

            % Clinical decision from current result
            clinicalDecision = struct('status', 'GRADED', ...
                'referableDecision', state.currentResult.referableDecision, ...
                'confidenceLevel', state.currentResult.confidenceLevel, ...
                'consistency', state.currentResult.consistency, ...
                'consistencyWarning', state.currentResult.consistencyWarning, ...
                'recommendation', state.currentResult.recommendation);

            % Generate report
            report = generateClinicalReport(imageInfo, quality, classification, ...
                evidence, gradcam, clinicalDecision);

            % Display report in figure
            fig = figure('Name', 'Clinical Screening Report', ...
                'NumberTitle', 'off', ...
                'Position', [200, 100, 700, 600], ...
                'Color', 'white');

            % Create text display
            uicontrol(fig, 'Style', 'text', ...
                'Position', [10, 10, 680, 580], ...
                'String', report.text, ...
                'FontSize', 9, ...
                'FontName', 'Courier New', ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', 'white');

            statusIndicator.String = 'Clinical report displayed';
            statusIndicator.ForegroundColor = [0.2 0.6 0.9];
        catch ME
            errordlg(sprintf('Failed to generate report: %s', ME.message), 'Error');
        end
    end

    function showHeatmap()
        % showHeatmap  Display genuine class-specific Grad-CAM.
        %
        %   Uses the EXACT preprocessing of runScreening, predicts the DR
        %   class, and computes Grad-CAM for that predicted class. On any
        %   failure, reports "Grad-CAM unavailable" — never random data.
        if isempty(state.currentImage)
            errordlg('Upload an image first.', 'Grad-CAM unavailable');
            return;
        end
        if ~state.modelLoaded
            errordlg('Load model first.', 'Grad-CAM unavailable');
            return;
        end

        try
            % Identical preprocessing to runScreening
            cfgH = transferLearningConfig();
            nH = preprocessFundus(state.currentImage, cfgH.image.size);

            [predH, scoresH] = classify(state.trainedNet, nH);
            targetIdx = double(predH);      % MATLAB index 1..5
            targetGrade = targetIdx - 1;    % DR grade 0..4

            [camH, ~, ~] = gradcamSimple(state.trainedNet, nH, ...
                'TargetClass', targetIdx);

            % Resize attention map to displayed (original) image size
            camDisp = imresize(camH, [size(state.currentImage, 1), ...
                size(state.currentImage, 2)]);

            heatFig = figure('Name', 'Grad-CAM Explainability', ...
                'NumberTitle', 'off', ...
                'Position', [120, 80, 1200, 420], ...
                'Color', 'white');

            subplot(1, 3, 1);
            imshow(state.currentImage);
            title('Original fundus image', 'FontSize', 11);

            subplot(1, 3, 2);
            imagesc(camDisp, [0, 1]);
            axis image off;
            colormap(heatFig, jet);
            colorbar;
            title(sprintf('Grad-CAM (predicted class G%d)', targetGrade), ...
                'FontSize', 11);

            subplot(1, 3, 3);
            imshow(state.currentImage);
            hold on;
            hH = imagesc(camDisp, [0, 1]);
            set(hH, 'AlphaData', 0.4);
            hold off;
            title(sprintf('Overlay (G%d, P=%.1f%%)', targetGrade, ...
                max(scoresH)*100), 'FontSize', 11);

            annotation(heatFig, 'textbox', [0.02, 0.01, 0.96, 0.06], ...
                'String', ['Grad-CAM: model attention visualization. ' ...
                'Attention map is an AI explanation aid and is not a ' ...
                'lesion segmentation or clinical diagnosis.'], ...
                'FontSize', 9, 'HorizontalAlignment', 'center', ...
                'EdgeColor', 'none');

            statusIndicator.String = sprintf( ...
                'Grad-CAM displayed (class G%d)', targetGrade);
            statusIndicator.ForegroundColor = [0.2 0.6 0.9];
        catch ME
            errordlg(sprintf('Grad-CAM unavailable: %s', ME.message), ...
                'Grad-CAM unavailable');
        end
    end

    function exportReport()
        if isempty(state.currentResult)
            errordlg('Run screening first.', 'Error');
            return;
        end

        [file, path] = uiputfile({'*.txt', 'Text files'; '*.csv', 'CSV files'}, 'Export Report', ...
            fullfile('results', 'reports', sprintf('report_%s.txt', datestr(now, 'yyyymmdd_HHMMSS'))));

        if isequal(file, 0)
            return;
        end

        fullPath = fullfile(path, file);
        try
            r = state.currentResult;
            e = r.evidence;

            fid = fopen(fullPath, 'w');
            if fid == -1
                errordlg(sprintf('Cannot open file for writing:\n%s', fullPath), 'Export Error');
                return;
            end
            fprintf(fid, 'DR SCREENING REPORT\n');
            fprintf(fid, '==================\n\n');
            fprintf(fid, 'Date: %s\n', r.timestamp);
            fprintf(fid, 'Image: %s\n\n', state.currentImagePath);

            fprintf(fid, 'SCREENING RESULT\n');
            fprintf(fid, '----------------\n');
            fprintf(fid, 'DR Grade: %s (G%d)\n', r.gradeName, r.gradeNum);
            fprintf(fid, 'Referable DR: %s\n', string(r.referable));
            fprintf(fid, 'Confidence: %.1f%%\n', r.confidence);
            fprintf(fid, 'Referable Probability: %.4f\n', r.probability);
            fprintf(fid, 'Threshold: 0.1951\n\n');

            fprintf(fid, 'CLINICAL EVIDENCE\n');
            fprintf(fid, '-----------------\n');
            fprintf(fid, 'Microaneurysms: %d\n', e.microaneurysms.count);
            fprintf(fid, 'Hemorrhages: %d\n', e.hemorrhages.count);
            fprintf(fid, 'Exudates: %d\n', e.exudates.count);
            fprintf(fid, 'Neovascularization: %s\n', string(e.neovascularization.detected));
            fprintf(fid, 'Overall Severity: %s\n\n', e.severity);

            fprintf(fid, 'RECOMMENDATION\n');
            fprintf(fid, '--------------\n');
            if r.referable
                fprintf(fid, '→ Refer to ophthalmologist for clinical evaluation.\n\n');
            else
                fprintf(fid, '→ Routine follow-up. No immediate referral needed.\n\n');
            end

            fprintf(fid, 'DISCLAIMER\n');
            fprintf(fid, '----------\n');
            fprintf(fid, 'This is an AI-assisted screening result, not a definitive diagnosis.\n');
            fprintf(fid, 'Clinical correlation and ophthalmologist review are recommended.\n');
            fprintf(fid, 'Model: Transfer Learning ResNet-18 (Phase 17 validated)\n');
            fprintf(fid, 'Performance: 91.0%% referable sensitivity, 91.5%% referable specificity (internal evaluation)\n');
            fprintf(fid, 'Lesion evidence is AI-assisted supporting evidence.\n');

            fclose(fid);

            statusIndicator.String = sprintf('Report exported: %s', file);
            statusIndicator.ForegroundColor = [0.2 0.6 0.9];
            msgbox(sprintf('Report exported to:\n%s', fullPath), 'Export Complete');
        catch ME
            errordlg(sprintf('Export failed: %s', ME.message), 'Error');
        end
    end

    function resetAll()
        state.currentImage = [];
        state.currentResult = [];
        state.currentImagePath = '';

        cla(imgAxes);
        title(imgAxes, 'No image loaded');
        gradeText.String = 'Grade: --';
        gradeText.ForegroundColor = [0 0.5 0];
        refText.String = 'Referable: --';
        refText.ForegroundColor = [0 0 0];
        confText.String = 'Confidence: --';
        riskText.String = 'Risk: --';
        riskText.ForegroundColor = [0 0 0];

        evidenceMA.String = 'Microaneurysms: --';
        evidenceHem.String = 'Hemorrhages: --';
        evidenceExu.String = 'Exudates: --';
        evidenceNV.String = 'Neovascularization: --';
        evidenceSummary.String = 'Overall: --';

        qualityGrade.String = 'Quality: --';
        qualityDetails.String = 'Brightness: -- | Contrast: -- | Sharpness: --';
        qualityGuidance.String = '';
        qualityBar.String = '';

        cla(probAxes);

        statusIndicator.String = 'System: Ready';
        statusIndicator.ForegroundColor = [0.8 0.9 0.8];
    end

    % Add disclaimer at bottom
    disclaimerText = uicontrol(fig, 'Style', 'text', ...
        'Position', [50, 5, 1300, 20], ...
        'String', 'AI-assisted screening. Lesion evidence is supporting evidence. Final diagnosis requires ophthalmologist review.', ...
        'FontSize', 8, ...
        'ForegroundColor', [0.5 0.5 0.5], ...
        'BackgroundColor', [0.95 0.95 0.97], ...
        'HorizontalAlignment', 'center');
end
