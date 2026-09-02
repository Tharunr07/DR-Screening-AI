function result = runDRScreening(imagePath, varargin)
% runDRScreening  End-to-end DR screening from fundus image to clinical report
%
%   result = runDRScreening(imagePath)
%   result = runDRScreening(imagePath, 'Name', Value, ...)
%
%   Input:
%       imagePath - Path to fundus image file
%
%   Name-Value Pairs:
%       'ModelPath'  - Path to trained model (default: auto-detect)
%       'Verbose'    - Print progress (default: true)
%
%   Output:
%       result - Struct with fields:
%           .imagePath      - Input image path
%           .quality        - Quality assessment struct
%           .structures     - Retinal structure analysis
%           .prediction     - DR grade prediction (struct with .grade, .label, .scores)
%           .referable      - Referable DR classification (struct with .isReferable, .probability, .threshold)
%           .confidence     - Prediction confidence
%           .explainability - Attention/heatmap data
%           .report         - Human-readable report (struct with .summary, .status)
%           .timestamp      - Processing timestamp
%           .success        - Boolean success flag
%           .error          - Error message (if failed)

    % Parse inputs
    p = inputParser;
    addRequired(p, 'imagePath', @ischar);
    addParameter(p, 'ModelPath', '', @ischar);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, imagePath, varargin{:});

    % Initialize all result fields to safe defaults
    result = struct();
    result.imagePath = imagePath;
    result.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    result.success = false;
    result.error = '';
    result.quality = struct('status', 'UNKNOWN', 'score', 0, 'brightness', 0, 'contrast', 0, 'blurScore', 0);
    result.prediction = struct('grade', -1, 'label', 'Unknown', 'scores', zeros(1,5), 'gradeLabels', {{}});
    result.referable = struct('isReferable', false, 'probability', 0, 'threshold', 0.1951);
    result.confidence = 0;
    result.structures = struct();
    result.explainability = struct();
    result.report = struct('status', 'PENDING', 'summary', 'Processing...', 'timestamp', result.timestamp);

    try
        % Load configuration
        cfgTL = transferLearningConfig();

        % Load trained model
        modelPath = p.Results.ModelPath;
        if isempty(modelPath)
            modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
        end

        if ~exist(modelPath, 'file')
            error('DRScreening:ModelNotFound', 'Model not found: %s', modelPath);
        end

        if p.Results.Verbose
            fprintf('[DRScreening] Loading model from %s\n', modelPath);
        end
        load(modelPath, 'trainedNetTL');

        % Step 1: Load and validate image
        if p.Results.Verbose
            fprintf('[DRScreening] Step 1: Loading image\n');
        end

        if ~exist(imagePath, 'file')
            error('DRScreening:ImageNotFound', 'Image file not found: %s', imagePath);
        end

        img = imread(imagePath);

        if ndims(img) < 3 || size(img, 3) < 3
            error('DRScreening:InvalidChannels', 'Image must be RGB (3 channels). Got %d channels.', size(img, 3));
        end

        if size(img, 1) < 100 || size(img, 2) < 100
            error('DRScreening:ImageTooSmall', 'Image too small (%dx%d). Minimum 100x100.', size(img, 1), size(img, 2));
        end

        % Step 2: Image quality assessment
        if p.Results.Verbose
            fprintf('[DRScreening] Step 2: Quality assessment\n');
        end

        gray = rgb2gray(img);
        brightness = double(mean(gray(:)));
        contrast = double(std(double(gray(:))));

        qualityScore = 1.0;
        if brightness < 40 || brightness > 220
            qualityScore = qualityScore * 0.3;
        elseif brightness < 60 || brightness > 200
            qualityScore = qualityScore * 0.7;
        end
        if contrast < 20
            qualityScore = qualityScore * 0.5;
        elseif contrast < 35
            qualityScore = qualityScore * 0.8;
        end

        if qualityScore >= 0.6
            qualityStatus = 'GOOD';
        elseif qualityScore >= 0.3
            qualityStatus = 'BORDERLINE';
        else
            qualityStatus = 'UNGRADABLE';
        end

        result.quality = struct('status', qualityStatus, 'score', qualityScore, ...
            'brightness', brightness, 'contrast', contrast, 'blurScore', 0);

        if strcmp(qualityStatus, 'UNGRADABLE')
            if p.Results.Verbose
                fprintf('[DRScreening] Image quality: UNGRADABLE - cannot process\n');
            end
            result.report = struct('status', 'UNGRADABLE', ...
                'summary', 'Image quality too low for analysis', ...
                'timestamp', result.timestamp);
            result.success = true;
            return;
        end

        % Step 3: Preprocess image
        if p.Results.Verbose
            fprintf('[DRScreening] Step 3: Preprocessing\n');
        end

        imgResized = imresize(img, cfgTL.image.size, 'bicubic');
        meanRGB = [0.485 0.456 0.406];
        stdRGB = [0.229 0.224 0.225];
        imgNorm = double(imgResized) / 255;
        for c = 1:3
            imgNorm(:,:,c) = (imgNorm(:,:,c) - meanRGB(c)) / stdRGB(c);
        end

        % Step 4: DR classification
        if p.Results.Verbose
            fprintf('[DRScreening] Step 4: DR classification\n');
        end

        [pred, scores] = classify(trainedNetTL, imgNorm);

        grades = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
        gradeNum = double(pred) - 1;
        refProb = sum(scores(3:5));
        isReferable = refProb >= 0.1951;

        result.prediction = struct('grade', gradeNum, 'label', grades{gradeNum + 1}, ...
            'scores', scores, 'gradeLabels', {grades});
        result.referable = struct('isReferable', isReferable, 'probability', refProb, 'threshold', 0.1951);
        result.confidence = max(scores);

        % Step 5: Explainability (simplified)
        if p.Results.Verbose
            fprintf('[DRScreening] Step 5: Explainability\n');
        end
        result.explainability = struct('topClass', gradeNum + 1, 'scores', scores);

        % Step 6: Generate report
        if p.Results.Verbose
            fprintf('[DRScreening] Step 6: Generating report\n');
        end

        if isReferable
            summary = sprintf('REFERABLE DR detected (Grade %d: %s, confidence %.1f%%)', ...
                gradeNum, grades{gradeNum+1}, result.confidence*100);
        else
            summary = sprintf('Non-referable DR (Grade %d: %s, confidence %.1f%%)', ...
                gradeNum, grades{gradeNum+1}, result.confidence*100);
        end

        result.report = struct('status', 'COMPLETE', 'summary', summary, ...
            'qualityStatus', qualityStatus, 'qualityScore', qualityScore, ...
            'drGrade', gradeNum, 'drLabel', grades{gradeNum+1}, ...
            'isReferable', isReferable, 'referableProb', refProb, ...
            'confidence', result.confidence, 'timestamp', result.timestamp);

        result.success = true;

        if p.Results.Verbose
            fprintf('[DRScreening] Complete: Grade %d (%s), Referable=%d, Confidence=%.1f%%\n', ...
                gradeNum, grades{gradeNum+1}, isReferable, result.confidence*100);
        end

    catch ME
        result.error = ME.message;
        result.success = false;
        result.prediction = struct('grade', -1, 'label', 'Error', 'scores', zeros(1,5), 'gradeLabels', {{}});
        result.referable = struct('isReferable', false, 'probability', 0, 'threshold', 0.1951);
        result.confidence = 0;
        result.report = struct('status', 'ERROR', 'summary', sprintf('Processing failed: %s', ME.message), ...
            'timestamp', result.timestamp);

        if p.Results.Verbose
            fprintf('[DRScreening] ERROR: %s\n', ME.message);
        end
    end
end
