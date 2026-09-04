function [cam, predClass, scores] = gradcam(net, img, varargin)
% gradcam  Formal Grad-CAM implementation for ResNet-18
%
%   [cam, predClass, scores] = gradcam(net, img)
%   [cam, predClass, scores] = gradcam(net, img, 'TargetClass', classIdx)
%
%   Inputs:
%       net  - Trained DAGNetwork (ResNet-18)
%       img  - Preprocessed image (H x W x 3, ImageNet-normalized)
%
%   Name-Value Pairs:
%       'TargetClass' - Class index for Grad-CAM (default: predicted class)
%       'LayerName'   - Target convolutional layer (default: 'res5b_branch2b')
%
%   Outputs:
%       cam       - Class activation map (H x W, values in [0,1])
%       predClass - Predicted class index
%       scores    - Class probabilities
%
%   Mathematical formulation:
%       1. Forward pass: extract feature maps F from target layer
%       2. Backward pass: compute gradients dF/dy_c for target class c
%       3. Global average pooling: alpha_k = mean(dF/dy_c)
%       4. Weighted combination: L = ReLU(sum(alpha_k * F_k))
%       5. Normalize to [0, 1]

    p = inputParser;
    addRequired(p, 'net');
    addRequired(p, 'img');
    addParameter(p, 'TargetClass', 0, @isnumeric);
    addParameter(p, 'LayerName', 'res5b_branch2b', @ischar);
    parse(p, net, img, varargin{:});

    targetClass = p.Results.TargetClass;
    layerName = p.Results.LayerName;

    % Ensure image is 4D (batch dimension)
    if ndims(img) == 3
        img = permute(img, [1 2 3 4]);  % H x W x C x 1
    end

    % Forward pass
    [pred, scores] = classify(net, img);
    predClass = double(pred);

    % If no target class specified, use predicted
    if targetClass == 0
        targetClass = predClass;
    end

    % Get activations from target layer using debugging
    % We'll use the gradient-based approach with dlarray
    try
        % Convert to dlarray for automatic differentiation
        dlImg = dlarray(single(img), 'SSCB');

        % Forward pass with gradient tracking
        [acts, dlScores] = forwardWithActivations(net, dlImg, layerName);

        % Extract scores for target class
        targetScore = dlScores(targetClass);

        % Backward pass: compute gradients
        grads = dlgradient(targetScore, acts);

        % Global average pooling of gradients
        alpha = mean(mean(grads, 1), 2);  % 1 x 1 x C x 1

        % Weighted combination of feature maps
        cam = zeros(size(acts, 1), size(acts, 2));
        for k = 1:size(acts, 3)
            cam = cam + double(alpha(:,:,k,1)) * double(acts(:,:,k,1));
        end

        % ReLU
        cam = max(cam, 0);

        % Normalize to [0, 1]
        camMax = max(cam(:));
        camMin = min(cam(:));
        if camMax > camMin
            cam = (cam - camMin) / (camMax - camMin);
        else
            cam = zeros(size(cam));
        end

        % Resize to input image size
        cam = imresize(cam, [size(img, 1), size(img, 2)]);

    catch ME
        % Fallback: gradient-magnitude based attention
        warning('Grad-CAM: Using fallback gradient-magnitude. Error: %s', ME.message);
        cam = fallbackGradcam(net, img, targetClass);
    end
end

function [acts, scores] = forwardWithActivations(net, dlImg, layerName)
    % Forward pass and extract activations from specific layer
    % This uses the network's forward method with activation extraction

    % Get all layer activations
    activations = activations(net, extractdata(dlImg), layerName);
    acts = dlarray(single(activations), 'SSCB');

    % Get final scores
    scores = predict(net, extractdata(dlImg));
    scores = dlarray(single(scores), 'BC');
end

function cam = fallbackGradcam(net, img, targetClass)
    % Fallback Grad-CAM using gradient magnitude
    % Used when automatic differentiation is not available

    % Forward pass
    [pred, scores] = classify(net, img);

    % Convert to dlarray
    dlImg = dlarray(single(img), 'SSCB');

    % Compute gradient of target class score w.r.t. input
    targetScore = dlarray(single(scores(targetClass)), 'BC');
    grads = dlgradient(targetScore, dlImg);

    % Convert to magnitude
    gradMag = sqrt(sum(double(grads).^2, 3));

    % Normalize
    gradMag = mat2gray(gradMag);

    % Resize to input size
    cam = imresize(gradMag, [size(img, 1), size(img, 2)]);
end
