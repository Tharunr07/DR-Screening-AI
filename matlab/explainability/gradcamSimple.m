function [cam, predClass, scores] = gradcamSimple(net, img, varargin)
% gradcamSimple  Gradient-based Grad-CAM for the frozen ResNet-18 DR classifier
%
%   [cam, predClass, scores] = gradcamSimple(net, img)
%   [cam, predClass, scores] = gradcamSimple(net, img, 'TargetClass', k)
%   [cam, predClass, scores] = gradcamSimple(net, img, 'LayerName', name)
%
%   Standard Grad-CAM formulation (Selvaraju et al., 2017):
%
%       alpha_k^c = (1/Z) * sum_i sum_j d(y^c) / d(A_ij^k)
%       L^c       = ReLU( sum_k alpha_k^c * A^k )
%
%   where y^c is the pre-softmax logit for class c and A^k is the k-th
%   feature map of the target convolutional layer.
%
%   Gradient computation: the classification head of the frozen network is
%       pool5 (GAP, 512-d) -> fc_dr_1 (512) -> relu -> fc_dr_2 (128)
%       -> relu -> fc_dr_output (5 logits)
%   Because global average pooling is linear and the head is a short chain
%   of affine + ReLU operations, the exact gradient d(y^c)/d(A^k) is
%   computed in closed form with ReLU gating masks recorded from the
%   forward pass. No automatic differentiation is required and no
%   approximation is made (dropout is inactive at inference).
%
%   Inputs:
%       net  - Trained SeriesNetwork (frozen cc7bed8 classifier)
%       img  - Preprocessed image, HxWx3, ImageNet-normalized, [224x224x3]
%              (2-D grayscale is replicated to 3 channels; documented)
%
%   Name-Value Pairs:
%       'TargetClass' - MATLAB class index 1..5 (grade = index-1).
%                       Default 0 = predicted class.
%       'LayerName'   - Target convolutional layer.
%                       Default 'res5b_branch2b' (7x7x512, last conv block).
%
%   Outputs:
%       cam       - Class activation map, HxW double in [0,1], ReLU applied
%                   BEFORE normalization. Zeros if no positive evidence.
%       predClass - Predicted MATLAB class index (1..5; grade = index-1)
%       scores    - Class probabilities (1x5)
%
%   Determinism: no random component. Repeated calls on the same input
%   produce identical output within floating-point tolerance.
%
%   Failure mode: this function THROWS on invalid input (NaN/Inf, wrong
%   channels, invalid class, missing layer). Callers must catch and report
%   "Grad-CAM unavailable" instead of displaying fabricated data.

    p = inputParser;
    addRequired(p, 'net');
    addRequired(p, 'img');
    addParameter(p, 'TargetClass', 0, @isnumeric);
    addParameter(p, 'LayerName', 'res5b_branch2b', @ischar);
    parse(p, net, img, varargin{:});

    targetClass = p.Results.TargetClass;
    layerName = p.Results.LayerName;

    % --- Input sanitation ---
    if ndims(img) == 4
        img = img(:, :, :, 1);
    end
    if ~isfloat(img)
        img = double(img);
    end
    if ndims(img) == 2
        % Documented: replicate grayscale to 3 channels
        img = repmat(img, [1, 1, 3]);
    end
    if ndims(img) ~= 3 || size(img, 3) ~= 3
        error('gradcamSimple:InvalidImage', ...
            'Expected HxWx3 image, got %s.', mat2str(size(img)));
    end
    if isempty(img) || any(~isfinite(img(:)))
        error('gradcamSimple:InvalidImage', ...
            'Image is empty or contains NaN/Inf.');
    end

    % --- Forward pass: prediction ---
    [pred, scores] = classify(net, img);
    predClass = double(pred);  % MATLAB index 1..5

    if targetClass == 0
        targetClass = predClass;
    end
    if ~isscalar(targetClass) || targetClass ~= round(targetClass) ...
            || targetClass < 1 || targetClass > 5
        error('gradcamSimple:InvalidClass', ...
            'TargetClass must be an integer in 1..5 (grade = index-1). Got %s.', ...
            mat2str(targetClass));
    end
    if numel(scores) ~= 5
        error('gradcamSimple:UnexpectedScores', ...
            'Expected 5 class scores, got %d.', numel(scores));
    end

    % --- Feature maps from target layer ---
    try
        featureMaps = activations(net, img, layerName, 'OutputAs', 'channels');
    catch ME
        error('gradcamSimple:LayerError', ...
            'Cannot extract activations from layer ''%s'': %s', layerName, ME.message);
    end
    if isempty(featureMaps) || any(~isfinite(featureMaps(:)))
        error('gradcamSimple:BadActivations', ...
            'Feature maps are empty or contain NaN/Inf.');
    end
    [fH, fW, fC] = size(featureMaps);
    if fC ~= 512
        error('gradcamSimple:UnexpectedChannels', ...
            'Expected 512 channels at ''%s'', got %d.', layerName, fC);
    end
    F = double(featureMaps);

    % --- Head parameters ---
    [W1, b1] = getHeadParams(net, 'fc_dr_1');       % 512x512, 512x1
    [W2, b2] = getHeadParams(net, 'fc_dr_2');       % 128x512, 128x1
    [W3, b3] = getHeadParams(net, 'fc_dr_output');  % 5x128,   5x1
    if size(W1, 2) ~= fC || size(W1, 1) ~= 512 ...
            || size(W2, 1) ~= 128 || size(W3, 1) ~= 5
        error('gradcamSimple:HeadMismatch', ...
            'Head dimensions do not match %d-channel features.', fC);
    end

    % --- Forward through head with ReLU masks ---
    Z = fH * fW;
    pv = squeeze(sum(sum(F, 1), 2)) / Z;   % 512x1 pooled vector
    pv = pv(:);
    if any(~isfinite(pv))
        error('gradcamSimple:BadActivations', 'Pooled features contain NaN/Inf.');
    end

    h1pre = W1 * pv + b1;
    m1 = h1pre > 0;                        % ReLU gate mask
    h1 = h1pre .* m1;

    h2pre = W2 * h1 + b2;
    m2 = h2pre > 0;
    h2 = h2pre .* m2;

    logits = W3 * h2 + b3;                 % pre-softmax scores
    if any(~isfinite(logits))
        error('gradcamSimple:BadLogits', 'Head logits contain NaN/Inf.');
    end

    % --- Exact gradient of logit y^c w.r.t. pooled vector ---
    % dy/dh2 = W3(c,:) .* m2 ; dy/dh1 = (dy/dh2 * W2) .* m1 ; dy/dp = dy/dh1 * W1
    dy_dh2 = W3(targetClass, :) .* m2(:)';          % 1x128
    dy_dh1 = (dy_dh2 * W2) .* m1(:)';               % 1x512
    dy_dp = dy_dh1 * W1;                            % 1x512

    % alpha_k = (1/Z) * sum_ij d(y^c)/d(A_ij^k) = (dy/dp_k) / Z
    alpha = dy_dp(:) / Z;                           % 512x1

    % --- Weighted combination + ReLU (BEFORE normalization) ---
    cam = zeros(fH, fW);
    for k = 1:fC
        if alpha(k) ~= 0
            cam = cam + alpha(k) * F(:, :, k);
        end
    end
    cam = max(cam, 0);   % ReLU: keep only positive class evidence
    if any(~isfinite(cam(:)))
        error('gradcamSimple:BadCAM', 'CAM contains NaN/Inf.');
    end

    % --- Normalize AFTER ReLU ---
    camMax = max(cam(:));
    if camMax > 0
        cam = cam / camMax;
    else
        cam = zeros(size(cam));  % honest: no positive evidence
    end

    % --- Resize to input image size ---
    cam = imresize(cam, [size(img, 1), size(img, 2)]);
    cam = max(min(cam, 1), 0);
end

function [W, b] = getHeadParams(net, layerName)
% getHeadParams  Return head weights (OxI) and bias (Ox1 column) as double
    layers = net.Layers;
    for i = 1:numel(layers)
        if isa(layers(i), 'nnet.cnn.layer.FullyConnectedLayer') ...
                && strcmp(layers(i).Name, layerName)
            W = double(layers(i).Weights);
            b = double(layers(i).Bias(:));
            return;
        end
    end
    error('gradcamSimple:LayerNotFound', 'Head layer not found: %s', layerName);
end
