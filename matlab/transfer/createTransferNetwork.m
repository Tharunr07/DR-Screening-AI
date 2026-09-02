function [lgraph] = createTransferNetwork(cfg)
% createTransferNetwork  Create ResNet-18 with ImageNet pretrained weights
%
%   [lgraph] = createTransferNetwork(cfg)
%
%   Creates ResNet-18 architecture and loads converted PyTorch pretrained weights.
%   Returns layerGraph for use with trainNetwork.

    if nargin < 1, cfg = transferLearningConfig(); end

    fprintf('[createTransferNet] Loading ImageNet-pretrained ResNet-18\n');

    % Get untrained ResNet-18 architecture
    lgraph = resnet18('Weights', 'none');

    % Load converted PyTorch weights (MATLAB-compatible names)
    weightFile = cfg.paths.pretrainedWeights;
    if ~exist(weightFile, 'file')
        error('Pretrained weights not found: %s\nRun convert_resnet18_matlab.py first.', weightFile);
    end
    W = load(weightFile);
    fprintf('[createTransferNet] Loaded %d weight tensors\n', numel(fieldnames(W)));

    % Load weights into layers by replacing layers with new ones
    loadedCount = 0;
    layers = lgraph.Layers;
    layerNames = {layers.Name};

    for i = 1:numel(layers)
        layer = layers(i);

        if isa(layer, 'nnet.cnn.layer.Convolution2DLayer')
            weightKey = layer.Name;
            if isfield(W, weightKey)
                % Create new layer with loaded weights
                newLayer = convolution2dLayer(layer.FilterSize, layer.NumFilters, ...
                    'Name', layer.Name, ...
                    'Stride', layer.Stride, ...
                    'Padding', layer.PaddingSize, ...
                    'Weights', W.(weightKey), ...
                    'Bias', ones(1, 1, layer.NumFilters), ...
                    'WeightLearnRateFactor', layer.WeightLearnRateFactor, ...
                    'BiasLearnRateFactor', layer.BiasLearnRateFactor);
                lgraph = replaceLayer(lgraph, layer.Name, newLayer);
                loadedCount = loadedCount + 1;
            end

        elseif isa(layer, 'nnet.cnn.layer.BatchNormalizationLayer')
            scaleKey = [layer.Name '_Scale'];
            biasKey = [layer.Name '_Bias'];
            meanKey = [layer.Name '_Mean'];
            varKey = [layer.Name '_Variance'];

            if isfield(W, scaleKey)
                % Directly set properties on existing BN layer
                newBN = layer;
                newBN.Scale = W.(scaleKey);
                newBN.Offset = W.(biasKey);
                newBN.TrainedMean = W.(meanKey);
                newBN.TrainedVariance = W.(varKey);
                lgraph = replaceLayer(lgraph, layer.Name, newBN);
                loadedCount = loadedCount + 1;
            end
        end
    end

    % Replace classification head
    poolIdx = find(strcmp(layerNames, 'pool5'), 1);
    if isempty(poolIdx)
        for idx = numel(layers):-1:1
            if isa(layers(idx), 'nnet.cnn.layer.GlobalAveragePooling2DLayer')
                poolIdx = idx;
                break;
            end
        end
    end

    % Remove layers after pooling
    if poolIdx < numel(layers)
        lgraph = removeLayers(lgraph, layerNames(poolIdx+1:end));
    end

    % Add new classification head for DR grading
    numClasses = cfg.nGrades;

    newLayers = [
        fullyConnectedLayer(512, 'Name', 'fc_dr_1', ...
            'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10)
        reluLayer('Name', 'relu_dr_1')
        dropoutLayer(0.5, 'Name', 'dropout_dr_1')
        fullyConnectedLayer(128, 'Name', 'fc_dr_2', ...
            'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10)
        reluLayer('Name', 'relu_dr_2')
        dropoutLayer(0.3, 'Name', 'dropout_dr_2')
        fullyConnectedLayer(numClasses, 'Name', 'fc_dr_output', ...
            'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10)
        softmaxLayer('Name', 'prob')
        classificationLayer('Name', 'classification', ...
            'Classes', categorical(0:4))
    ];

    lgraph = addLayers(lgraph, newLayers);
    lgraph = connectLayers(lgraph, layers(poolIdx).Name, 'fc_dr_1');

    fprintf('[createTransferNet] Network: %d layers, %d classes, %d weights loaded\n', ...
        numel(lgraph.Layers), numClasses, loadedCount);
end
