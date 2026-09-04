function runSIHDemo(varargin)
% runSIHDemo  Run the complete SIH demonstration workflow
%
%   runSIHDemo()
%   runSIHDemo('ImagePath', 'path/to/image.jpg')
%
%   Demonstrates the complete DR screening pipeline:
%       1. Load model
%       2. Upload fundus image
%       3. Image quality assessment
%       4. AI screening
%       5. DR Grade 0-4
%       6. Referable / Non-referable
%       7. Grad-CAM explainability
%       8. Lesion evidence (supporting)
%       9. Clinical consistency check
%       10. Structured clinical report
%       11. Export

    p = inputParser;
    addParameter(p, 'ImagePath', '', @ischar);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    imagePath = p.Results.ImagePath;
    verbose = p.Results.Verbose;

    if verbose
        fprintf('====================================================\n');
        fprintf('      SIH DEMO: DR SCREENING WORKFLOW\n');
        fprintf('====================================================\n\n');
    end

    % === Step 1: Load Model ===
    if verbose; fprintf('Step 1: Loading model...\n'); end
    cfgTL = transferLearningConfig();
    load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
    if verbose; fprintf('  Model loaded successfully.\n\n'); end

    % === Step 2: Load Image ===
    if verbose; fprintf('Step 2: Loading fundus image...\n'); end
    if isempty(imagePath)
        % Use a sample image from test set
        testT = readtable(fullfile(cfgTL.paths.splitDir, 'test.csv'), 'TextType', 'string');
        testT = testT(~isnan(testT.dr_grade), :);
        % Pick a random referable case
        referableIdx = find(testT.dr_grade >= 2);
        if ~isempty(referableIdx)
            sampleIdx = referableIdx(randi(numel(referableIdx)));
        else
            sampleIdx = randi(height(testT));
        end
        imagePath = testT.file_path{sampleIdx};
        if verbose; fprintf('  Using sample image: %s\n', imagePath); end
    end
    img = imread(imagePath);
    if verbose; fprintf('  Image loaded: %dx%d pixels\n\n', size(img, 2), size(img, 1)); end

    % === Step 3: Image Quality Assessment ===
    if verbose; fprintf('Step 3: Assessing image quality...\n'); end
    if size(img, 3) == 3
        grayImg = rgb2gray(img);
    else
        grayImg = img;
    end
    brightness = mean(grayImg(:));
    contrast = std(double(grayImg(:)));
    blurVar = std(double(imfilter(grayImg, fspecial('laplacian'))));

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

    if verbose
        fprintf('  Quality: %s\n', quality.status);
        fprintf('  Brightness: %.1f | Contrast: %.1f | Sharpness: %.1f\n\n', ...
            brightness, contrast, blurVar);
    end

    % === Step 4: Preprocess ===
    if verbose; fprintf('Step 4: Preprocessing image...\n'); end
    n = preprocessFundus(img, cfgTL.image.size);
    if verbose; fprintf('  Preprocessed to %dx%d\n\n', cfgTL.image.size(1), cfgTL.image.size(2)); end

    % === Step 5: AI Screening ===
    if verbose; fprintf('Step 5: Running AI classification...\n'); end
    [pred, scores] = classify(trainedNetTL, n);
    gradeNum = double(pred) - 1;
    grades = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
    gradeName = grades{gradeNum + 1};

    if verbose
        fprintf('  Predicted Grade: %d (%s)\n', gradeNum, gradeName);
        fprintf('  Class probabilities:\n');
        for g = 0:4
            fprintf('    G%d: %.3f\n', g, scores(g+1));
        end
        fprintf('\n');
    end

    % === Step 6: Referable Decision ===
    if verbose; fprintf('Step 6: Determining referable status...\n'); end
    referable = gradeNum >= 2;
    if referable
        refStatus = 'REFERABLE';
    else
        refStatus = 'NON-REFERABLE';
    end
    if verbose; fprintf('  Status: %s\n\n', refStatus); end

    % === Step 7: Lesion Evidence (Supporting) ===
    if verbose; fprintf('Step 7: Extracting lesion evidence (supporting)...\n'); end
    evidence = extractLesionEvidence(img);

    if verbose
        fprintf('  Microaneurysms: %d\n', evidence.microaneurysms.count);
        fprintf('  Hemorrhages: %d\n', evidence.hemorrhages.count);
        fprintf('  Exudates: %d\n', evidence.exudates.count);
        fprintf('  Neovascularization: %s\n', string(evidence.neovascularization.detected));
        fprintf('  Severity: %s\n\n', evidence.severity);
    end

    % === Step 8: Clinical Consistency Check ===
    if verbose; fprintf('Step 8: Running clinical consistency check...\n'); end
    result = applyClinicalLogic(gradeNum, scores, evidence, quality);

    if verbose
        fprintf('  Consistency: %s\n', result.consistency);
        if ~isempty(result.consistencyWarning)
            fprintf('  Warning: %s\n', result.consistencyWarning);
        end
        fprintf('  Confidence: %s (%.1f%%)\n\n', result.confidenceLevel, result.confidence);
    end

    % === Step 9: Generate Clinical Report ===
    if verbose; fprintf('Step 9: Generating clinical report...\n'); end
    imageInfo = struct('path', imagePath, 'timestamp', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    classification = struct('gradeNum', gradeNum, 'gradeName', gradeName, ...
        'scores', scores, 'referable', referable, 'probability', max(scores));
    try
        report = generateClinicalReport(imageInfo, quality, classification, evidence, [], result);
        if verbose; fprintf('  Report generated successfully.\n\n'); end
    catch ME
        if verbose; fprintf('  Report generation skipped: %s\n\n', ME.message); end
        report = struct();
    end

    % === Step 10: Display Summary ===
    if verbose
        fprintf('====================================================\n');
        fprintf('      SCREENING RESULT SUMMARY\n');
        fprintf('====================================================\n');
        fprintf('Image: %s\n', imagePath);
        fprintf('Quality: %s\n', quality.status);
        fprintf('Grade: %d (%s)\n', gradeNum, gradeName);
        fprintf('Referable: %s\n', refStatus);
        fprintf('Confidence: %s (%.1f%%)\n', result.confidenceLevel, result.confidence);
        fprintf('Consistency: %s\n', result.consistency);
        fprintf('\n');
        fprintf('Supporting Evidence:\n');
        fprintf('  Microaneurysms: %d\n', evidence.microaneurysms.count);
        fprintf('  Hemorrhages: %d\n', evidence.hemorrhages.count);
        fprintf('  Exudates: %d\n', evidence.exudates.count);
        fprintf('  Neovascularization: %s\n', string(evidence.neovascularization.detected));
        fprintf('\n');
        fprintf('NOTE: Lesion evidence is AI-assisted supporting evidence.\n');
        fprintf('      Final diagnosis requires ophthalmologist review.\n');
        fprintf('====================================================\n');
    end

    % === Step 11: Export Report ===
    if verbose; fprintf('\nStep 11: Exporting report...\n'); end
    if isfield(report, 'text')
        exportPath = fullfile(cfgTL.paths.outputDir, 'demo_report.txt');
        exportClinicalReport(report, exportPath, 'Format', 'txt');
        if verbose; fprintf('  Report exported to: %s\n\n', exportPath); end
    else
        if verbose; fprintf('  Report export skipped (no text field)\n\n'); end
    end

    if verbose
        fprintf('====================================================\n');
        fprintf('      SIH DEMO COMPLETE\n');
        fprintf('====================================================\n');
    end
end
