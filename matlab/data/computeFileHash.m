function hashStr = computeFileHash(filePath, algorithm)
% computeFileHash  Compute hex hash of a file for duplicate detection
%
%   hashStr = computeFileHash(filePath)
%   hashStr = computeFileHash(filePath, algorithm)  e.g. 'MD5' (default) or 'SHA-256'
%
%   Returns:
%     hashStr - lower-case hex string, or '' on failure
%
%   Uses Java MessageDigest when available; falls back to DataHash-free
%   byte-sum method if Java unavailable (less robust but avoids extra toolbox).
%   No raw files are modified.
%
%   This is used for audit duplicate-image detection (optional, best-effort).

    if nargin < 2 || isempty(algorithm)
        algorithm = 'MD5';
    end
    hashStr = '';

    if ~exist(filePath, 'file')
        return;
    end

    % Try Java path first (available in MATLAB desktop / runtime with JVM)
    try
        import java.security.MessageDigest
        import java.io.FileInputStream
        md = MessageDigest.getInstance(algorithm);
        fis = FileInputStream(filePath);
        buffer = javaArray('byte', 8192);
        % Read in chunks
        n = fis.read(buffer);
        while n ~= -1
            if n == numel(buffer)
                md.update(buffer, 0, n);
            else
                % Partial buffer - copy first n bytes
                tmp = javaArray('byte', n);
                for b = 1:n
                    tmp(b) = buffer(b);
                end
                md.update(tmp, 0, n);
            end
            n = fis.read(buffer);
        end
        fis.close();
        jbytes = md.digest();
        % Convert to hex
        hashStr = sprintf('%02x', typecast(jbytes, 'uint8'));
        hashStr = lower(hashStr);
        return;
    catch ME %#ok<NASGU>
        % fall through to fallback
    end

    % Fallback: fast byte-sum / file-size hybrid (not cryptographic but detects exact duplicates)
    try
        fid = fopen(filePath, 'rb');
        if fid == -1
            return;
        end
        data = fread(fid, Inf, '*uint8');
        fclose(fid);
        if isempty(data)
            hashStr = 'empty';
            return;
        end
        % Simple: size + sum + first/last bytes signature
        s = sum(uint64(data));
        h = sprintf('fb_%d_%d_%d_%d', numel(data), s, data(1), data(end));
        hashStr = h;
    catch
        hashStr = '';
    end
end
