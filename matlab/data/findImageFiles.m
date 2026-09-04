function fileList = findImageFiles(rootDir, extensions)
% findImageFiles  Recursively locate supported image files
%
%   fileList = findImageFiles(rootDir)
%   fileList = findImageFiles(rootDir, extensions)
%
%   Inputs:
%     rootDir    - directory to search (string/char)
%     extensions - cell array of extensions with or without dot, e.g. {'.png','.jpg'}
%                  default: cfg.supportedExtensionsDot from datasetConfig
%
%   Output:
%     fileList - N x 1 cell array of absolute file paths (char)
%                empty cell {} if rootDir missing or no matches
%
%   Notes:
%     - Case-insensitive extension matching
%     - Skips hidden/system files gracefully
%     - Does NOT read image data (data-ingestion layer only discovers paths)

    if nargin < 1 || isempty(rootDir)
        fileList = {};
        return;
    end
    if nargin < 2 || isempty(extensions)
        cfg = datasetConfig();
        extensions = cfg.supportedExtensionsDot;
    end

    % Normalize extensions to lower-case with leading dot
    extNorm = cellfun(@(e) lower(strtrim(e)), extensions, 'UniformOutput', false);
    for k = 1:numel(extNorm)
        if ~startsWith(extNorm{k}, '.')
            extNorm{k} = ['.' extNorm{k}];
        end
    end

    fileList = {};

    if ~exist(rootDir, 'dir')
        return;
    end

    % Use recursive dir listing
    allFiles = dirRecursive(rootDir);
    for i = 1:numel(allFiles)
        f = allFiles{i};
        [~, ~, e] = fileparts(f);
        if any(strcmpi(e, extNorm))
            fileList{end+1,1} = f; %#ok<AGROW>
        end
    end
end

function out = dirRecursive(rootDir)
% Return absolute paths for all files under rootDir (recursive)
    out = {};
    try
        entries = dir(rootDir);
    catch
        return;
    end
    for k = 1:numel(entries)
        name = entries(k).name;
        if strcmp(name,'.') || strcmp(name,'..')
            continue;
        end
        fullPath = fullfile(entries(k).folder, name);
        if entries(k).isdir
            sub = dirRecursive(fullPath);
            out = [out; sub]; %#ok<AGROW>
        else
            out{end+1,1} = fullPath; %#ok<AGROW>
        end
    end
end
