function masks = loadPhase3Masks(maskDir, dataset, imageId)
% loadPhase3Masks  Load persisted Phase 3 binary lesion masks
%
%   masks = loadPhase3Masks(maskDir, dataset, imageId)
%
%   Returns struct with fields:
%     maMask, heMask, exMask, vesselMask, fovMask
%     available (boolean)
%     imgHeight, imgWidth

    masks = struct( ...
        'maMask', false(1), ...
        'heMask', false(1), ...
        'exMask', false(1), ...
        'vesselMask', false(1), ...
        'fovMask', false(1), ...
        'available', false, ...
        'imgHeight', 0, ...
        'imgWidth', 0);

    filename = fullfile(maskDir, sprintf('%s_%s.mat', dataset, imageId));

    if ~exist(filename, 'file')
        return;
    end

    try
        data = load(filename);

        if isfield(data, 'maMask') && ~isempty(data.maMask)
            masks.maMask = logical(data.maMask);
        end
        if isfield(data, 'heMask') && ~isempty(data.heMask)
            masks.heMask = logical(data.heMask);
        end
        if isfield(data, 'exMask') && ~isempty(data.exMask)
            masks.exMask = logical(data.exMask);
        end
        if isfield(data, 'vesselMask') && ~isempty(data.vesselMask)
            masks.vesselMask = logical(data.vesselMask);
        end
        if isfield(data, 'fovMask') && ~isempty(data.fovMask)
            masks.fovMask = logical(data.fovMask);
        end
        if isfield(data, 'imgHeight')
            masks.imgHeight = data.imgHeight;
        end
        if isfield(data, 'imgWidth')
            masks.imgWidth = data.imgWidth;
        end
        masks.available = true;
    catch
        masks.available = false;
    end
end
