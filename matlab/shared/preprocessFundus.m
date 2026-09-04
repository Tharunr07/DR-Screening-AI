function imgOut = preprocessFundus(img, targetSize)
% preprocessFundus  Canonical preprocessing matching Phase 8 training
%
%   imgOut = preprocessFundus(img, targetSize)
%
%   This is the ONE preprocessing function for all classifier inference.
%   It matches exactly what augmentedImageDatastore does during training:
%     1. Resize to targetSize using bicubic interpolation
%     2. Cast to single precision
%     3. NO normalization (model was trained on raw pixel values 0-255)
%
%   The model trainedNetTL.mat was trained with:
%     augmentedImageDatastore([224 224], imdsTrain, 'DataAugmentation', augmenter)
%   which outputs single-precision resized images in range [0, 255].
%
%   IMPORTANT: Do NOT apply ImageNet normalization (mean/std subtraction).
%   The model has never seen normalized inputs. Doing so causes the
%   G2 prediction collapse documented in PHASE20D2_TRAINING_FORENSIC_AUDIT.md.

    if nargin < 2
        targetSize = [224 224];
    end

    imgOut = imresize(img, targetSize, 'bilinear');
    imgOut = single(imgOut);
end
