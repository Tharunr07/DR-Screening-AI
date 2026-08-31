function [data, featureMatrix, labels, meta] = prepareClassificationData(cfg)
% prepareClassificationData  Load splits, join Phase 2+3, build feature matrix
%
%   [data, featureMatrix, labels, meta] = prepareClassificationData(cfg)
%
%   Returns per-split data tables and a combined feature matrix for train/val.
%   Test data is separate for final evaluation only.

    if nargin < 1 || isempty(cfg), cfg = classificationConfig(); end

    % Load splits
    splitFiles = {'train.csv', 'val.csv', 'test.csv'};
    splitNames = {'train', 'val', 'test'};
    splits = struct();

    for s = 1:numel(splitFiles)
        path = fullfile(cfg.paths.splitDir, splitFiles{s});
        T = readtable(path, 'TextType', 'string');
        splits.(splitNames{s}) = T;
    end

    % Load Phase 2 quality results
    Tq = readtable(cfg.paths.qualityCSV, 'TextType', 'string');

    % Load Phase 3 structure results
    T3 = readtable(cfg.paths.structureCSV, 'TextType', 'string');

    fprintf('[prepareClassificationData] Split sizes: train=%d val=%d test=%d\n', ...
        height(splits.train), height(splits.val), height(splits.test));

    % Build feature matrix per split
    featureMatrix = struct();
    labels = struct();
    meta = struct();
    data = struct();

    for s = 1:numel(splitNames)
        sn = splitNames{s};
        T = splits.(sn);

        % Filter to labeled images only (APTOS2019 + IDRiD)
        hasLabel = ~isnan(T.dr_grade);
        labeledIdx = find(hasLabel);

        % Further filter: must have Phase 3 results
        hasPhase3 = ismember(T.image_id(labeledIdx), T3.image_id);
        validIdx = labeledIdx(hasPhase3);

        fprintf('[prepareClassificationData] %s: %d labeled, %d with Phase 3 features\n', ...
            sn, numel(labeledIdx), numel(validIdx));

        % Extract features
        nSamples = numel(validIdx);
        nFeatures = 25;  % from buildClassificationFeatures
        X = NaN(nSamples, nFeatures);
        Y = NaN(nSamples, 1);
        featureNames = {};
        sampleMeta = struct('image_id', {}, 'dataset', {}, 'split', {}, ...
            'quality_status', {}, 'quality_score', {});

        for i = 1:nSamples
            idx = validIdx(i);
            % Build combined row struct
            row = struct();
            % Manifest fields
            row.image_id = T.image_id(idx);
            row.dataset = T.dataset(idx);
            row.dr_grade = T.dr_grade(idx);

            % Phase 2 fields
            qRow = find(Tq.image_id == T.image_id(idx), 1);
            if ~isempty(qRow)
                row.overall_quality_score = Tq.overall_quality_score(qRow);
                row.quality_status = Tq.quality_status(qRow);
            end

            % Phase 3 fields
            p3Row = find(T3.image_id == T.image_id(idx), 1);
            if ~isempty(p3Row)
                p3Fields = T3.Properties.VariableNames;
                for f = 1:numel(p3Fields)
                    fn = p3Fields{f};
                    if ~ismember(fn, {'image_id', 'dataset', 'split'})
                        row.(fn) = T3.(fn)(p3Row);
                    end
                end
            end

            [feat, fNames, m] = buildClassificationFeatures(row, cfg);
            X(i, :) = feat;
            Y(i) = row.dr_grade;

            if isempty(featureNames), featureNames = fNames; end

            sampleMeta(i).image_id = string(row.image_id);
            sampleMeta(i).dataset = string(row.dataset);
            sampleMeta(i).split = string(sn);
            sampleMeta(i).quality_status = string(m.quality_status);
            sampleMeta(i).quality_score = m.quality_score;
        end

        featureMatrix.(sn) = X;
        labels.(sn) = Y;
        meta.(sn) = sampleMeta;
        data.(sn) = T(validIdx, :);
    end

    % Report class distribution
    fprintf('\n[prepareClassificationData] Class distribution:\n');
    for s = 1:numel(splitNames)
        sn = splitNames{s};
        Y = labels.(sn);
        fprintf('  %s (n=%d): ', sn, numel(Y));
        for g = 0:4
            fprintf('%d:%d ', g, sum(Y == g));
        end
        fprintf('\n');
    end
end
