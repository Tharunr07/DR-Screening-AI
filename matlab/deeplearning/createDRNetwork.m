function [layerGraph] = createDRNetwork(cfg)
% createDRNetwork  Create deep learning network for DR classification
%
%   [layerGraph] = createDRNetwork(cfg)
%
%   Creates ResNet-18 based architecture with custom classification head.
%   Returns layerGraph for use with trainNetwork.

    if nargin < 1, cfg = deepLearningConfig(); end

    fprintf('[createDRNetwork] Architecture: %s\n', cfg.network.architecture);

    % Get untrained ResNet-18
    lgraph = resnet18('Weights', 'none');

    % Find the last learnable layer before classification
    layers = lgraph.Layers;
    layerNames = {layers.Name};

    % Find the global average pooling layer
    poolIdx = find(strcmp(layerNames, 'pool5'), 1);
    if isempty(poolIdx)
        % Try to find any global average pooling layer
        for i = numel(layers):-1:1
            if isa(layers(i), 'nnet.cnn.layer.GlobalAveragePooling2DLayer')
                poolIdx = i;
                break;
            end
        end
    end

    fprintf('[createDRNetwork] Found pooling at layer %d: %s\n', poolIdx, layers(poolIdx).Name);

    % Remove layers after pooling
    if poolIdx < numel(layers)
        lgraph = removeLayers(lgraph, layerNames(poolIdx+1:end));
    end

    % Add new classification head
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

    layerGraph = lgraph;

    fprintf('[createDRNetwork] Network created: %d layers, %d classes\n', ...
        numel(lgraph.Layers), numClasses);
end
