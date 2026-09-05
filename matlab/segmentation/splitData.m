function [trainIdx, valIdx] = splitData(manifest, trainRatio, seed)
% splitData  Deterministic 80/20 split of IDRiD training data
%   trainRatio: fraction for training (default 0.8)
%   seed: random seed for reproducibility

    if nargin < 2; trainRatio = 0.8; end
    if nargin < 3; seed = 42; end

    trainMask = strcmp({manifest.split}, 'train');
    trainIndices = find(trainMask);
    n = numel(trainIndices);

    rng(seed);
    perm = randperm(n);
    nTrain = round(n * trainRatio);

    trainIdx = trainIndices(perm(1:nTrain));
    valIdx = trainIndices(perm(nTrain+1:end));

    fprintf('Split: %d train, %d val (seed=%d)\n', numel(trainIdx), numel(valIdx), seed);
end
