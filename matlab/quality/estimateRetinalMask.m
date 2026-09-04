function mask = estimateRetinalMask(img, opts)
% estimateRetinalMask  Estimate usable retinal field vs black background
%
%   mask = estimateRetinalMask(img)
%   mask = estimateRetinalMask(img, opts)
%
%   Input img: HxWx3 RGB or HxW grayscale, uint8 or double 0-255
%   Output mask: HxW logical, true = retinal field, false = background
%
%   Method: green channel or luminance, Otsu + morphology, largest component
%   Supports circular and elliptical FOV. Conservative: if fails, returns
%   mask of pixels >15 (fallback) or whole image if completely dark.
%
%   No raw modification.

    if nargin < 2, opts = struct(); end
    if ndims(img)==3 && size(img,3)==3
        % Use green channel for fundus (best contrast) or luminance
        % Convert to grayscale via standard weights but also try green
        gray = 0.2989*double(img(:,:,1)) + 0.5870*double(img(:,:,2)) + 0.1140*double(img(:,:,3));
        green = double(img(:,:,2));
        % Blend: use max of green and luminance to be robust to color cast
        gray = max(gray, green*0.9);
    elseif ndims(img)==3 && size(img,3)==1
        gray = double(squeeze(img));
    else
        gray = double(img);
    end
    % Normalize to 0-255 if needed
    if max(gray(:)) <= 1
        gray = gray * 255;
    end
    H = size(gray,1); W = size(gray,2);

    % Initial threshold: Otsu on gray, but clamp to [12, 35] to avoid extreme
    try
        level = graythresh(uint8(gray)); % 0-1
        thresh = level * 255;
        thresh = max(12, min(35, thresh));
    catch
        thresh = 15;
    end
    bw = gray > thresh;

    % Remove small specks, keep largest component
    try
        bw = bwareaopen(bw, round(0.005 * H * W)); % remove <0.5% area
        % Fill holes inside retina (optic disc, etc. should be filled for FOV)
        bw = imfill(bw, 'holes');
        % Erode then dilate slightly to smooth border, but not too much
        se = strel('disk', 5);
        bw = imclose(bw, se);
        bw = imopen(bw, strel('disk',3));
        % Largest connected component = retinal field
        CC = bwconncomp(bw);
        if CC.NumObjects > 1
            numPixels = cellfun(@numel, CC.PixelIdxList);
            [~, idx] = max(numPixels);
            bw2 = false(size(bw));
            bw2(CC.PixelIdxList{idx}) = true;
            bw = bw2;
        end
        % If mask still covers >90% of image, likely failed (e.g., bright image with no black border)
        % Then use adaptive threshold higher
        areaFrac = nnz(bw) / (H*W);
        if areaFrac > 0.92
            % Try higher threshold 30
            bw2 = gray > 30;
            bw2 = bwareaopen(bw2, round(0.005*H*W));
            bw2 = imfill(bw2,'holes');
            if nnz(bw2)/(H*W) < 0.92 && nnz(bw2)/(H*W) > 0.15
                bw = bw2;
                % re-extract largest
                CC = bwconncomp(bw);
                if CC.NumObjects>1
                    numPixels = cellfun(@numel, CC.PixelIdxList);
                    [~, idx]=max(numPixels);
                    bw2=false(size(bw)); bw2(CC.PixelIdxList{idx})=true; bw=bw2;
                end
            end
        end
        % If still tiny (<8% area), fallback to simple >15 mask
        if nnz(bw)/(H*W) < 0.08
            bw = gray > 15;
            bw = bwareaopen(bw, round(0.002*H*W));
            bw = imfill(bw,'holes');
            CC=bwconncomp(bw);
            if CC.NumObjects>0
                numPixels=cellfun(@numel, CC.PixelIdxList);
                [~, idx]=max(numPixels);
                bw2=false(size(bw)); bw2(CC.PixelIdxList{idx})=true; bw=bw2;
            end
        end
    catch
        % Fallback
        bw = gray > 15;
    end

    mask = logical(bw);
    % Ensure at least some pixels
    if nnz(mask) < 500
        mask = gray > 10;
        if nnz(mask) < 500
            mask = true(size(gray)); % whole image as fallback
        end
    end
end
