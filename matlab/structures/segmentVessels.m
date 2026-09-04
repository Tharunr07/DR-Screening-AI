function result = segmentVessels(img, retinalMask, cfg)
% segmentVessels  Retinal vessel segmentation (RESEARCH PROTOTYPE)
%
%   result = segmentVessels(img, retinalMask, cfg)
%
%   Multi-scale vessel segmentation using contrast enhancement, background
%   normalization, and morphological filtering.
%   Primary validation dataset: DRIVE.

    if nargin < 3 || isempty(cfg), cfg = phase3Config(); end

    result = struct();
    result.vessel_mask = [];
    result.skeleton = [];
    result.vessel_area_fraction = NaN;
    result.vessel_density = NaN;
    result.total_vessel_length = NaN;
    result.status = 'FAILED';
    result.method = 'NONE';

    % Convert to grayscale double
    if ndims(img) == 3 && size(img, 3) == 3
        R = double(img(:,:,1));
        G = double(img(:,:,2));
        B = double(img(:,:,3));
        gray = 0.2989*R + 0.5870*G + 0.1140*B;
        greenCh = G;
    else
        gray = double(img);
        greenCh = gray;
    end
    if max(gray(:)) <= 1
        gray = gray * 255;
        greenCh = greenCh * 255;
    end
    [H, W] = size(gray);

    if isempty(retinalMask) || ~isequal(size(retinalMask), [H W])
        retinalMask = true(H, W);
    end
    retinalMask = logical(retinalMask);

    try
        % Step 1: Background normalization
        sigma = cfg.ma.greenBackgroundSigma;
        if exist('imgaussfilt', 'file')
            bg = imgaussfilt(greenCh, sigma);
        else
            h = fspecial('gaussian', round(6*sigma)+1, sigma);
            bg = imfilter(greenCh, h, 'replicate');
        end
        normGreen = greenCh ./ (bg + 1e-6);

        % Step 2: Vessel enhancement via top-hat (vessels are darker than local background)
        % Use elongated structuring elements at multiple angles
        vesselMask = false(H, W);
        angles = 0:15:165;
        minLength = cfg.vessels.matchedFilterLength;

        for a = angles
            % Create line structuring element
            se = strel('line', minLength, a);
            % Top-hat to find dark linear structures
            tophat = imtophat(normGreen, se);
            % Also try black top-hat (closing - original) for bright vessels
            bgat = imbothat(normGreen, se);
            % Combine
            combined = max(tophat, bgat);
            threshold = cfg.vessels.hysteresisHigh;
            vesselMask = vesselMask | (combined > threshold);
        end

        % Step 3: Additional Hessian-based enhancement
        try
            smoothed = imgaussfilt(normGreen, 1.5);
            [Dxx, Dxy, Dyy] = deal(zeros(H, W));
            [Dxx(:,2:end-1), Dyy(2:end-1,:)] = deal(smoothed(:,3:end)-2*smoothed(:,2:end-1)+smoothed(:,1:end-2), ...
                smoothed(3:end,:)-2*smoothed(2:end-1,:)+smoothed(1:end-2,:));
            Dxy(2:end-1,2:end-1) = (smoothed(3:end,3:end)-smoothed(3:end,1:end-2)-smoothed(1:end-2,3:end)+smoothed(1:end-2,1:end-2))/4;
            lambda1 = 0.5*(Dxx+Dyy+sqrt((Dxx-Dyy).^2+4*Dxy.^2));
            lambda2 = 0.5*(Dxx+Dyy-sqrt((Dxx-Dyy).^2+4*Dxy.^2));
            vesselness = zeros(H, W);
            valid = (lambda2 < 0) & (abs(lambda1) < abs(lambda2)*0.5);
            vesselness(valid) = abs(lambda2(valid)).^2 ./ (abs(lambda1(valid)) + eps);
            vesselness = mat2gray(vesselness);
            vesselMask = vesselMask | (vesselness > cfg.vessels.hysteresisLow);
        catch
        end

        % Step 4: Apply retinal mask and cleanup
        vesselMask = vesselMask & retinalMask;
        vesselMask = bwareaopen(vesselMask, cfg.vessels.minVesselArea);

        % Close small gaps
        vesselMask = imclose(vesselMask, strel('disk', 1));

        % Step 5: Skeletonize
        try
            skel = bwmorph(vesselMask, 'skel', Inf);
            skel = bwmorph(skel, 'spur', 5);
            totalLength = nnz(skel);
        catch
            skel = false(size(vesselMask));
            totalLength = 0;
        end

        % Metrics
        retinalPixels = nnz(retinalMask);
        vesselAreaFraction = nnz(vesselMask) / max(1, retinalPixels);
        vesselDensity = nnz(vesselMask) / max(1, H * W);

        if vesselAreaFraction > 0.02 && vesselAreaFraction < 0.25
            status = 'GOOD';
        elseif vesselAreaFraction > 0.01
            status = 'BORDERLINE';
        else
            status = 'POOR';
        end

        result.vessel_mask = vesselMask;
        result.skeleton = skel;
        result.vessel_area_fraction = vesselAreaFraction;
        result.vessel_density = vesselDensity;
        result.total_vessel_length = totalLength;
        result.status = status;
        result.method = 'TOPHAT_HESSIAN';

    catch ME
        result.status = 'SEGMENTATION_FAILED';
        result.method = 'TOPHAT_HESSIAN';
        result.error = ME.message;
    end
end
