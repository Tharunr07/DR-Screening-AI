function timing = measureReviewTime(varargin)
% measureReviewTime  Measure time for complete clinical review workflow
%
%   timing = measureReviewTime()
%   timing = measureReviewTime('NumTrials', 5, 'Verbose', true)
%
%   Measures time for:
%       - Image loading
%       - Quality assessment
%       - AI classification
%       - Grad-CAM generation
%       - Lesion evidence extraction
%       - Report generation
%       - Complete pipeline

    p = inputParser;
    addParameter(p, 'NumTrials', 5, @isnumeric);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});

    numTrials = p.Results.NumTrials;
    verbose = p.Results.Verbose;

    timing = struct();
    timing.imageLoad = [];
    timing.qualityAssess = [];
    timing.classification = [];
    timing.gradcam = [];
    timing.lesionEvidence = [];
    timing.reportGeneration = [];
    timing.totalPipeline = [];

    try
        % Get a test image
        cfgTL = transferLearningConfig();
        T = readtable('data/splits/test.csv');
        idx = find(T.dr_grade == 2, 1);
        imgPath = T.file_path_absolute{idx};

        if verbose
            fprintf('=== USABILITY TIMING ===\n');
            fprintf('Image: %s\n\n', imgPath);
        end

        % Load model once
        load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');

        for trial = 1:numTrials
            if verbose
                fprintf('Trial %d/%d...\n', trial, numTrials);
            end

            % 1. Image loading
            tic;
            img = imread(imgPath);
            timing.imageLoad(trial) = toc;

            % 2. Quality assessment
            tic;
            gray = rgb2gray(img);
            brightness = mean(gray(:));
            contrast = std(double(gray(:)));
            timing.qualityAssess(trial) = toc;

            % 3. Preprocessing
            tic;
            n = preprocessFundus(img, cfgTL.image.size);
            timing.preprocess(trial) = toc;

            % 4. AI classification
            tic;
            [pred, scores] = classify(trainedNetTL, n);
            timing.classification(trial) = toc;

            % 5. Grad-CAM generation
            tic;
            [cam, ~, ~] = gradcamSimple(trainedNetTL, n);
            timing.gradcam(trial) = toc;

            % 6. Lesion evidence
            tic;
            evidence = extractLesionEvidence(img);
            timing.lesionEvidence(trial) = toc;

            % 7. Report generation
            tic;
            gradeNum = double(pred) - 1;
            refProb = sum(scores(3:5));
            isReferable = refProb >= 0.1951;
            grades = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
            report = sprintf('Grade %d (%s), Referable=%d, Confidence=%.1f%%, Evidence=%s', ...
                gradeNum, grades{gradeNum+1}, isReferable, max(scores)*100, evidence.summary);
            timing.reportGeneration(trial) = toc;

            % Total pipeline
            timing.totalPipeline(trial) = timing.imageLoad(trial) + ...
                timing.qualityAssess(trial) + timing.preprocess(trial) + ...
                timing.classification(trial) + timing.gradcam(trial) + ...
                timing.lesionEvidence(trial) + timing.reportGeneration(trial);
        end

        % Compute statistics
        timing.stats = struct();
        fields = {'imageLoad', 'qualityAssess', 'classification', 'gradcam', ...
                  'lesionEvidence', 'reportGeneration', 'totalPipeline'};
        for f = 1:numel(fields)
            field = fields{f};
            timing.stats.(field).mean = mean(timing.(field));
            timing.stats.(field).median = median(timing.(field));
            timing.stats.(field).std = std(timing.(field));
            timing.stats.(field).min = min(timing.(field));
            timing.stats.(field).max = max(timing.(field));
        end

        if verbose
            fprintf('\n=== TIMING RESULTS ===\n');
            fprintf('%-20s %8s %8s %8s\n', 'Stage', 'Mean', 'Median', 'Std');
            fprintf('%-20s %8s %8s %8s\n', '-----', '----', '------', '---');
            for f = 1:numel(fields)
                field = fields{f};
                fprintf('%-20s %8.4f %8.4f %8.4f sec\n', field, ...
                    timing.stats.(field).mean, ...
                    timing.stats.(field).median, ...
                    timing.stats.(field).std);
            end
            fprintf('\nTotal pipeline: %.3f sec (median)\n', timing.stats.totalPipeline.median);
            fprintf('Images per hour: %.0f\n', 3600 / timing.stats.totalPipeline.median);
        end

    catch ME
        timing.error = ME.message;
        if verbose
            fprintf('ERROR: %s\n', ME.message);
        end
    end
end
