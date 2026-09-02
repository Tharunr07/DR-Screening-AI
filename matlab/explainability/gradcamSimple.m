function [cam, predClass, scores] = gradcamSimple(net, img, varargin)
% gradcamSimple  Grad-CAM for ResNet-18 using FC weight projection
%
%   [cam, predClass, scores] = gradcamSimple(net, img)
%
%   Computes class-specific activation maps by projecting FC weights
%   back through the network to feature-map space.

    p = inputParser;
    addRequired(p, 'net');
    addRequired(p, 'img');
    addParameter(p, 'TargetClass', 0, @isnumeric);
    parse(p, net, img, varargin{:});

    targetClass = p.Results.TargetClass;

    if ndims(img) == 4
        img = img(:,:,:,1);
    end

    [pred, scores] = classify(net, img);
    predClass = double(pred);

    if targetClass == 0
        targetClass = predClass;
    end

    featureMaps = activations(net, img, 'res5b_branch2b', 'OutputAs', 'channels');

    W1 = getLayerWeights(net, 'fc_dr_1');
    W2 = getLayerWeights(net, 'fc_dr_2');
    W3 = getLayerWeights(net, 'fc_dr_output');

    grad = W3(targetClass, :) * W2 * W1;

    numChannels = size(featureMaps, 3);
    cam = zeros(size(featureMaps, 1), size(featureMaps, 2));

    for k = 1:numChannels
        cam = cam + grad(k) * featureMaps(:,:,k);
    end

    camMax = max(cam(:));
    camMin = min(cam(:));
    if camMax > camMin
        cam = (cam - camMin) / (camMax - camMin);
    else
        cam = zeros(size(cam));
    end

    cam = imresize(cam, [size(img, 1), size(img, 2)]);
    cam = max(min(cam, 1), 0);
end

function weights = getLayerWeights(net, layerName)
    layers = net.Layers;
    for i = 1:numel(layers)
        if isa(layers(i), 'nnet.cnn.layer.FullyConnectedLayer')
            if strcmp(layers(i).Name, layerName)
                weights = layers(i).Weights;
                return;
            end
        end
    end
    error('Layer not found: %s', layerName);
end
