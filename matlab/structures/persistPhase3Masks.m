function persistPhase3Masks(result, maskDir, dataset, imageId)
% persistPhase3Masks  Save real Phase 3 binary lesion masks to disk
%
%   persistPhase3Masks(result, maskDir, dataset, imageId)
%
%   Saves binary masks as MAT files for:
%   - MA candidate mask
%   - HE candidate mask
%   - EX exudate mask
%   - Vessel mask
%
%   Uses deterministic filename: <dataset>_<imageId>.mat

    if ~exist(maskDir, 'dir'), mkdir(maskDir); end

    % Initialize all masks as empty logical
    maMask = false(1);
    heMask = false(1);
    exMask = false(1);
    vesselMask = false(1);
    fovMask = false(1);
    imgHeight = 0;
    imgWidth = 0;

    % Extract masks from detail structs
    if isfield(result, 'detail_ma') && isfield(result.detail_ma, 'candidate_mask') && ~isempty(result.detail_ma.candidate_mask)
        maMask = logical(result.detail_ma.candidate_mask);
        [imgHeight, imgWidth] = size(maMask);
    end

    if isfield(result, 'detail_he') && isfield(result.detail_he, 'candidate_mask') && ~isempty(result.detail_he.candidate_mask)
        heMask = logical(result.detail_he.candidate_mask);
        if imgHeight == 0, [imgHeight, imgWidth] = size(heMask); end
    end

    if isfield(result, 'detail_ex') && isfield(result.detail_ex, 'exudate_mask') && ~isempty(result.detail_ex.exudate_mask)
        exMask = logical(result.detail_ex.exudate_mask);
        if imgHeight == 0, [imgHeight, imgWidth] = size(exMask); end
    end

    if isfield(result, 'detail_vessels') && isfield(result.detail_vessels, 'vessel_mask') && ~isempty(result.detail_vessels.vessel_mask)
        vesselMask = logical(result.detail_vessels.vessel_mask);
        if imgHeight == 0, [imgHeight, imgWidth] = size(vesselMask); end
    end

    if isfield(result, 'detail_fov') && isfield(result.detail_fov, 'mask') && ~isempty(result.detail_fov.mask)
        fovMask = logical(result.detail_fov.mask);
        if imgHeight == 0, [imgHeight, imgWidth] = size(fovMask); end
    end

    % Ensure all masks are same size
    if imgHeight > 0
        if ~isequal(size(maMask), [imgHeight, imgWidth])
            maMask = imresize(maMask, [imgHeight, imgWidth]);
        end
        if ~isequal(size(heMask), [imgHeight, imgWidth])
            heMask = imresize(heMask, [imgHeight, imgWidth]);
        end
        if ~isequal(size(exMask), [imgHeight, imgWidth])
            exMask = imresize(exMask, [imgHeight, imgWidth]);
        end
        if ~isequal(size(vesselMask), [imgHeight, imgWidth])
            vesselMask = imresize(vesselMask, [imgHeight, imgWidth]);
        end
        if ~isequal(size(fovMask), [imgHeight, imgWidth])
            fovMask = imresize(fovMask, [imgHeight, imgWidth]);
        end
    end

    % Save as MAT
    filename = fullfile(maskDir, sprintf('%s_%s.mat', dataset, imageId));
    save(filename, 'maMask', 'heMask', 'exMask', 'vesselMask', 'fovMask', 'imgHeight', 'imgWidth', '-v7');
end
