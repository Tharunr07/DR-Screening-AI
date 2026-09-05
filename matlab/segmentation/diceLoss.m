function loss = diceLoss(Y, T)
% diceLoss  Dice loss for binary semantic segmentation
%   Y: HxWxCxN predicted probabilities
%   T: HxWx1xN categorical targets

    % Get number of observations
    N = size(Y, 4);
    totalLoss = 0;

    for i = 1:N
        % Extract lesion channel
        Ylesion = Y(:,:,2,i);
        Tlesion = double(T(:,:,1,i) == categorical(2));

        % Dice
        intersection = sum(Ylesion(:) .* Tlesion(:));
        denom = sum(Ylesion(:)) + sum(Tlesion(:));
        dice = (2 * intersection + 1) / (denom + 1);
        totalLoss = totalLoss + (1 - dice);
    end

    loss = totalLoss / N;
end
