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
%           .prediction     - DR grade prediction
%           .referable      - Referable DR classification
%           .confidence     - Prediction confidence
%           .explainability - Attention/heatmap data
%           .report         - Human-readable report
%           .timestamp      - Processing timestamp
%           .success        - Boolean success flag
%           .error          - Error message (if failed)

    % Parse inputs
    p = inputParser;
    addRequired(p, 'imagePath', @ischar);
    addParameter(p, 'ModelPath', '', @ischar);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, imagePath, varargin{:});

    result = struct();
    result.imagePath = imagePath;
    result.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    result.success = false;
    result.error = '';

    try
        % Load configuration
        cfgTL = transferLearningConfig();
        cfg7 = deepLearningConfig();

        % Load trained model
        modelPath = p.Results.ModelPath;
        if isempty(modelPath)
            modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
        end

        if ~exist(modelPath, 'file')
            error('Model not found: %s', modelPath);
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
            error('Image file not found: %s', imagePath);
        end

        img = imread(imagePath);

        % Validate image
        if ndims(img) < 3 || size(img, 3) < 3
            error('Image must be RGB (3 channels). Got %d channels.', size(img, 3));
        end

        if size(img, 1) < 100 || size(img, 2) < 100
            error('Image too small (%dx%d). Minimum 100x100.', size(img, 1), size(img, 2));
        end

        % Step 2: Image quality assessment
        if p.Results.Verbose
            fprintf('[DRScreening] Step 2: Quality assessment\n');
        end

        quality = assessImageQuality(img, cfg7);
        result.quality = quality;

        if strcmp(quality.status, 'UNGRADABLE')
            if p.Results.Verbose
                fprintf('[DRScreening] Image quality: UNGRADABLE - cannot process\n');
            end
            result.prediction = -1;
            result.referable = false;
            result.confidence = 0;
            result.structures = struct();
            result.explainability = struct();
            result.report = generateReport(result, 'Image quality too low for analysis');
            result.success = true;
            return;
        end

        % Step 3: Preprocess image
        if p.Results.Verbose
            fprintf('[DRScreening] Step 3: Preprocessing\n');
        end

        imgResized = imresize(img, cfgTL.image.size, 'bicubic');

        % ImageNet normalization
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

        % Create single-image datastore
        imgDS = arrayDatastore(imgNorm, 'IterationDimension', 3);

        % Classify
        [pred, scores] = classify(trainedNetTL, imgNorm);

        grades = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
        gradeNum = double(pred) - 1;

        % Referable probability
        refProb = sum(scores(3:5));
        isReferable = refProb >= 0.1951;

        result.prediction = struct();
        result.prediction.grade = gradeNum;
        result.prediction.label = grades{gradeNum + 1};
        result.prediction.scores = scores;
        result.prediction.gradeLabels = grades;

        result.referable = struct();
        result.referable.isReferable = isReferable;
        result.referable.probability = refProb;
        result.referable.threshold = 0.1951;

        result.confidence = max(scores);

        % Step 5: Retinal structure analysis (placeholder)
        if p.Results.Verbose
            fprintf('[DRScreening] Step 5: Structure analysis\n');
        end

        result.structures = struct();
        result.structures.hasVessels = true;
        result.structures.hasLesions = gradeNum >= 2;

        % Step 6: Explainability (attention heatmap)
        if p.Results.Verbose
            fprintf('[DRScreening] Step 6: Explainability\n');
        end

        result.explainability = generateAttentionMap(imgNorm, trainedNetTL, gradeNum);

        % Step 7: Generate report
        if p.Results.Verbose
            fprintf('[DRScreening] Step 7: Generating report\n');
        end

        result.report = generateReport(result);

        result.success = true;

        if p.Results.Verbose
            fprintf('[DRScreening] Complete: Grade %d (%s), Referable=%d, Confidence=%.1f%%\n', ...
                gradeNum, grades{gradeNum+1}, isReferable, result.confidence*100);
        end

    catch ME
        result.error = ME.message;
        result.success = false;
        result.prediction = struct();
        result.referable = struct();
        result.confidence = 0;
        result.structures = struct();
        result.explainability = struct();
        result.report = generateReport(result, ME.message);

        if p.Results.Verbose
            fprintf('[DRScreening] ERROR: %s\n', ME.message);
        end
    end
end

function quality = assessImageQuality(img, cfg)
    quality = struct();
    quality.score = 0;
    quality.status = 'UNKNOWN';

    % Simple quality metrics
    gray = rgb2gray(img);

    % Brightness
    brightness = mean(gray(:));
    quality.brightness = brightness;

    % Contrast
    contrast = std(double(gray(:)));
    quality.contrast = contrast;

    % Blur detection (Laplacian variance)
    lap = fspecial('laplacian');
    blur = conv2(double(gray), lap, 'same');
    quality.blurScore = var(blur(:));

    % Quality scoring
    score = 1.0;

    % Penalize extreme brightness
    if brightness < 40 || brightness > 220
        score = score * 0.3;
    elseif brightness < 60 || brightness > 200
        score = score * 0.7;
    end

    % Penalize low contrast
    if contrast < 20
        score = score * 0.5;
    elseif contrast < 35
        score = score * 0.8;
    end

    % Penalize blur
    if quality.blurScore < 100
        score = score * 0.3;
    elseif quality.blurScore < 500
        score = score * 0.7;
    end

    quality.score = score;

    if score >= 0.6
        quality.status = 'GOOD';
    elseif score >= 0.3
        quality.status = 'BORDERLINE';
    else
        quality.status = 'UNGRADABLE';
    end
end

function attn = generateAttentionMap(img, net, gradeNum)
    attn = struct();
    attn.heatmap = zeros(size(img, 1), size(img, 2));

    % Simple gradient-based attention (simplified)
    % In production, use proper Grad-CAM
    try
        scores = predict(net, img);
        [~, topClass] = max(scores);
        attn.topClass = topClass;
        attn.scores = scores;
    catch
        attn.topClass = gradeNum + 1;
        attn.scores = zeros(1, 5);
    end
end

function report = generateReport(result, varargin)
    report = struct();
    report.timestamp = result.timestamp;

    if nargin > 1
        report.error = varargin{1};
        report.status = 'ERROR';
        report.summary = sprintf('Processing failed: %s', varargin{1});
        return;
    end

    report.status = 'COMPLETE';

    % Quality section
    if isfield(result, 'quality')
        report.qualityStatus = result.quality.status;
        report.qualityScore = result.quality.score;
    else
        report.qualityStatus = 'UNKNOWN';
        report.qualityScore = 0;
    end

    % Prediction section
    if isfield(result, 'prediction') && isstruct(result.prediction) && isfield(result.prediction, 'grade')
        report.drGrade = result.prediction.grade;
        report.drLabel = result.prediction.label;
        report.isReferable = result.referable.isReferable;
        report.referableProb = result.referable.probability;
        report.confidence = result.confidence;

        % Summary
        if result.referable.isReferable
            report.summary = sprintf('REFERABLE DR detected (Grade %d: %s, confidence %.1f%%)', ...
                result.prediction.grade, result.prediction.label, result.confidence*100);
        else
            report.summary = sprintf('Non-referable DR (Grade %d: %s, confidence %.1f%%)', ...
                result.prediction.grade, result.prediction.label, result.confidence*100);
        end
    else
        report.summary = 'Classification not available';
    end
end
