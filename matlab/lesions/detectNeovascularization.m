function result = detectNeovascularization(img, retinalMask, vesselResult, cfg)
% detectNeovascularization  NV candidate detection (RESEARCH PROTOTYPE)
%
%   result = detectNeovascularization(img, retinalMask, vesselResult, cfg)
%
%   Research-prototype neovascularization candidate detector using
%   vessel-derived features. NO clinical validation claim.
%   If datasets lack NV ground truth, marks validation as unavailable.

    if nargin < 4 || isempty(cfg), cfg = phase3Config(); end

    result = struct();
    result.nv_candidate = false;
    result.nv_score = 0;
    result.nv_confidence = 0;
    result.supporting_features = struct();
    result.status = 'NO_GROUND_TRUTH';

    % Convert to grayscale
    if ndims(img) == 3 && size(img, 3) == 3
        gray = 0.2989*double(img(:,:,1)) + 0.5870*double(img(:,:,2)) + 0.1140*double(img(:,:,3));
    else
        gray = double(img);
    end
    if max(gray(:)) <= 1, gray = gray * 255; end
    [H, W] = size(gray);

    if isempty(retinalMask) || ~isequal(size(retinalMask), [H W])
        retinalMask = true(H, W);
    end
    retinalMask = logical(retinalMask);

    % Check if vessel segmentation was successful
    if isempty(vesselResult) || ~isfield(vesselResult, 'vessel_mask') || isempty(vesselResult.vessel_mask)
        result.status = 'NO_VESSEL_SEGMENTATION';
        return;
    end

    vesselMask = vesselResult.vessel_mask;
    if ~isequal(size(vesselMask), [H W])
        result.status = 'VESSEL_MASK_SIZE_MISMATCH';
        return;
    end

    try
        % Feature 1: Local vessel density
        % Abnormally high density may indicate NV
        blockSize = 32;
        localDensity = zeros(H, W);
        for y = 1:blockSize:H
            for x = 1:blockSize:W
                yEnd = min(y+blockSize-1, H);
                xEnd = min(x+blockSize-1, W);
                block = vesselMask(y:yEnd, x:xEnd);
                retBlock = retinalMask(y:yEnd, x:xEnd);
                if nnz(retBlock) > 0
                    localDensity(y:yEnd, x:xEnd) = nnz(block) / nnz(retBlock);
                end
            end
        end

        % Feature 2: Vessel tortuosity (simplified)
        % High tortuosity in small regions may indicate NV
        try
            skel = vesselResult.skeleton;
            if isempty(skel)
                skel = bwmorph(vesselMask, 'skel', Inf);
            end
            % Compute local curvature via skeleton branch analysis
            tortuosityMap = zeros(H, W);
            CC = bwconncomp(skel);
            for k = 1:CC.NumObjects
                pixels = CC.PixelIdxList{k};
                if numel(pixels) < cfg.vessels.skeletonMinLength
                    continue;
                end
                [py, px] = ind2sub([H, W], pixels);
                % Compute tortuosity as sum of angle changes / path length
                dx = diff(px); dy = diff(py);
                angles = atan2(dy, dx);
                angleChanges = abs(diff(angles));
                pathLength = sum(sqrt(dx.^2 + dy.^2));
                if pathLength > 0
                    tort = sum(angleChanges) / pathLength;
                    tortuosityMap(pixels) = tort;
                end
            end
        catch
            tortuosityMap = zeros(H, W);
        end

        % Feature 3: Fine vessel proliferation
        % Small isolated vessel segments may indicate NV
        fineVesselMask = bwareaopen(vesselMask, 5);
        fineVesselMask = fineVesselMask & ~bwareaopen(vesselMask, 50);

        % Aggregate features
        meanDensity = mean(localDensity(retinalMask));
        maxDensity = max(localDensity(retinalMask));
        meanTortuosity = mean(tortuosityMap(retinalMask));
        fineVesselFraction = nnz(fineVesselMask & retinalMask) / max(1, nnz(retinalMask));

        % NV score (combining features)
        nvScore = 0;
        if meanDensity > cfg.nv.abnormalDensityThresh
            nvScore = nvScore + 0.3;
        end
        if maxDensity > cfg.nv.abnormalDensityThresh * 1.5
            nvScore = nvScore + 0.2;
        end
        if meanTortuosity > cfg.nv.tortuosityThresh
            nvScore = nvScore + 0.25;
        end
        if fineVesselFraction > cfg.nv.fineVesselThresh
            nvScore = nvScore + 0.25;
        end

        % Candidate decision
        nvCandidate = nvScore > 0.5;
        confidence = min(1, nvScore);

        result.nv_candidate = nvCandidate;
        result.nv_score = nvScore;
        result.nv_confidence = confidence;
        result.supporting_features = struct( ...
            'mean_density', meanDensity, ...
            'max_density', maxDensity, ...
            'mean_tortuosity', meanTortuosity, ...
            'fine_vessel_fraction', fineVesselFraction);
        result.status = 'COMPLETED_NO_VALIDATION';

    catch ME
        result.status = 'DETECTION_FAILED';
        result.error = ME.message;
    end
end
