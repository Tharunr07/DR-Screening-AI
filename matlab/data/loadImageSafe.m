function [img, info, err] = loadImageSafe(filePath)
% loadImageSafe  Robustly load an image without crashing the pipeline
%
%   [img, info, err] = loadImageSafe(filePath)
%
%   Inputs:
%     filePath - absolute or relative path to image file
%
%   Outputs:
%     img  - H x W x C image array, or [] on failure
%     info - struct with fields:
%              .exists, .readable, .format, .width, .height, .channels,
%              .bitDepth, .fileSizeBytes, .isGrayscale, .isRGB, .imfinfo
%     err  - '' on success, otherwise error message string
%
%   Behavior:
%     - Does NOT modify the original file
%     - Reports unreadable/corrupt files via err instead of throwing
%     - Detects grayscale vs RGB vs other channel counts
%     - Handles common formats: png, jpg, jpeg, tif, tiff, bmp, ppm/pgm
%     - Caller decides how to handle failures (audit logs them)

    img  = [];
    err  = '';
    info = struct( ...
        'exists', false, ...
        'readable', false, ...
        'format', 'UNKNOWN', ...
        'width', NaN, ...
        'height', NaN, ...
        'channels', NaN, ...
        'bitDepth', NaN, ...
        'fileSizeBytes', NaN, ...
        'isGrayscale', false, ...
        'isRGB', false, ...
        'imfinfo', [] ...
    );

    if nargin < 1 || isempty(filePath)
        err = 'Empty filePath';
        return;
    end

    if ~exist(filePath, 'file')
        err = sprintf('File not found: %s', filePath);
        return;
    end
    info.exists = true;

    % File size
    try
        d = dir(filePath);
        if ~isempty(d)
            info.fileSizeBytes = d.bytes;
        end
    catch
    end

    % Try imfinfo first (does not decode full image)
    try
        imf = imfinfo(filePath);
        % imfinfo may return struct array for multi-image files; take first
        if numel(imf) > 1
            imf = imf(1);
        end
        info.imfinfo = imf;
        if isfield(imf, 'Format')
            info.format = upper(imf.Format);
        end
        if isfield(imf, 'Width')
            info.width = imf.Width;
        end
        if isfield(imf, 'Height')
            info.height = imf.Height;
        end
        if isfield(imf, 'BitDepth')
            info.bitDepth = imf.BitDepth;
        end
        if isfield(imf, 'ColorType')
            % ColorType examples: 'truecolor', 'grayscale', 'indexed'
            ct = lower(imf.ColorType);
            if contains(ct, 'grayscale')
                info.isGrayscale = true;
            elseif contains(ct, 'truecolor') || contains(ct, 'rgb')
                info.isRGB = true;
            end
        end
    catch ME
        % imfinfo failure is not fatal; imread will be tried anyway
        info.imfinfo = [];
        err = sprintf('imfinfo failed: %s', ME.message);
        % do not return yet
    end

    % Attempt to read the image
    try
        % Use try/catch around imread to handle corrupt files
        tmp = imread(filePath);
        img = tmp;
        info.readable = true;
        err = ''; % clear any imfinfo-only error if read succeeded

        % Infer dimensions from actual data (authoritative)
        if ndims(img) == 2
            [h, w] = size(img);
            info.height = h;
            info.width  = w;
            info.channels = 1;
            info.isGrayscale = true;
            info.isRGB = false;
        elseif ndims(img) == 3
            [h, w, c] = size(img);
            info.height = h;
            info.width  = w;
            info.channels = c;
            if c == 1
                info.isGrayscale = true;
                info.isRGB = false;
            elseif c == 3
                info.isGrayscale = false;
                info.isRGB = true;
            else
                info.isGrayscale = false;
                info.isRGB = false;
            end
        else
            info.channels = size(img, 3);
        end

        % If format still UNKNOWN, infer from extension
        if strcmp(info.format, 'UNKNOWN')
            [~,~,ext] = fileparts(filePath);
            info.format = upper(strrep(ext,'.',''));
            if isempty(info.format)
                info.format = 'UNKNOWN';
            end
        end

    catch ME
        info.readable = false;
        if isempty(err)
            err = sprintf('imread failed: %s', ME.message);
        else
            err = sprintf('%s; imread failed: %s', err, ME.message);
        end
        img = [];
    end
end
