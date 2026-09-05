function manifest = buildEXManifest()
% buildEXManifest  Build dataset manifest for EX segmentation experiment

    baseDir = fileparts(mfilename('fullpath'));
    baseDir = fullfile(baseDir, '..', '..');

    idridTrainImg = fullfile(baseDir, 'data', 'raw', 'IDRiD', 'A. Segmentation', '1. Original Images', 'a. Training Set');
    idridTrainGT = fullfile(baseDir, 'data', 'raw', 'IDRiD', 'A. Segmentation', '2. All Segmentation Groundtruths', 'a. Training Set');
    idridTestImg = fullfile(baseDir, 'data', 'raw', 'IDRiD', 'A. Segmentation', '1. Original Images', 'b. Testing Set');
    idridTestGT = fullfile(baseDir, 'data', 'raw', 'IDRiD', 'A. Segmentation', '2. All Segmentation Groundtruths', 'b. Testing Set');
    ddrImg = fullfile(baseDir, 'data', 'raw', 'DDR', 'lesion_segmentation', 'lesion_segmentation', 'images', 'train');
    ddrGT = fullfile(baseDir, 'data', 'raw', 'DDR', 'lesion_segmentation', 'lesion_segmentation', 'annotations', 'train', 'EX');

    manifest = struct('image_path', {}, 'mask_path', {}, 'dataset', {}, 'split', {}, ...
        'lesion_class', {}, 'image_width', {}, 'image_height', {}, ...
        'foreground_pixels', {}, 'foreground_fraction', {}, 'mask_empty', {});
    idx = 0;

    % IDRiD Training
    trainGT_EX = fullfile(idridTrainGT, '3. Hard Exudates');
    listing = dir(fullfile(idridTrainImg, '*.jpg'));
    fprintf('IDRiD training: %d images\n', numel(listing));
    for i = 1:numel(listing)
        imgName = listing(i).name;
        imgPath = fullfile(idridTrainImg, imgName);
        [~, base, ~] = fileparts(imgName);
        maskPath = fullfile(trainGT_EX, [base '_EX.tif']);
        if ~exist(maskPath, 'file'); continue; end
        img = imread(imgPath); [h, w, ~] = size(img);
        mask = imread(maskPath); if ndims(mask)>2; mask=mask(:,:,1); end
        fg = sum(mask(:)>0); total = numel(mask);
        idx = idx+1;
        manifest(idx) = struct('image_path',imgPath,'mask_path',maskPath, ...
            'dataset','IDRiD','split','train','lesion_class','EX', ...
            'image_width',w,'image_height',h,'foreground_pixels',fg, ...
            'foreground_fraction',fg/total,'mask_empty',(fg==0));
    end
    idridTrainCount = idx;
    fprintf('  Manifest entries: %d\n', idridTrainCount);

    % IDRiD Testing
    testGT_EX = fullfile(idridTestGT, '3. Hard Exudates');
    listing = dir(fullfile(idridTestImg, '*.jpg'));
    fprintf('IDRiD testing: %d images\n', numel(listing));
    for i = 1:numel(listing)
        imgName = listing(i).name;
        imgPath = fullfile(idridTestImg, imgName);
        [~, base, ~] = fileparts(imgName);
        maskPath = fullfile(testGT_EX, [base '_EX.tif']);
        if ~exist(maskPath, 'file'); continue; end
        img = imread(imgPath); [h, w, ~] = size(img);
        mask = imread(maskPath); if ndims(mask)>2; mask=mask(:,:,1); end
        fg = sum(mask(:)>0); total = numel(mask);
        idx = idx+1;
        manifest(idx) = struct('image_path',imgPath,'mask_path',maskPath, ...
            'dataset','IDRiD','split','test','lesion_class','EX', ...
            'image_width',w,'image_height',h,'foreground_pixels',fg, ...
            'foreground_fraction',fg/total,'mask_empty',(fg==0));
    end
    idridTestCount = idx - idridTrainCount;
    fprintf('  Manifest entries: %d\n', idridTestCount);

    % DDR
    listing = dir(fullfile(ddrImg, '*.jpg'));
    fprintf('DDR: %d images\n', numel(listing));
    for i = 1:numel(listing)
        imgName = listing(i).name;
        imgPath = fullfile(ddrImg, imgName);
        [~, base, ~] = fileparts(imgName);
        maskPath = fullfile(ddrGT, [base '.tif']);
        if ~exist(maskPath, 'file'); continue; end
        img = imread(imgPath); [h, w, ~] = size(img);
        mask = imread(maskPath); if ndims(mask)>2; mask=mask(:,:,1); end
        fg = sum(mask(:)>0); total = numel(mask);
        idx = idx+1;
        manifest(idx) = struct('image_path',imgPath,'mask_path',maskPath, ...
            'dataset','DDR','split','external_test','lesion_class','EX', ...
            'image_width',w,'image_height',h,'foreground_pixels',fg, ...
            'foreground_fraction',fg/total,'mask_empty',(fg==0));
    end
    ddrCount = idx - idridTrainCount - idridTestCount;
    fprintf('  Manifest entries: %d\n', ddrCount);

    % Summary
    trainIdx = find(strcmp({manifest.split},'train'));
    testIdx = find(strcmp({manifest.split},'test'));
    extIdx = find(strcmp({manifest.split},'external_test'));

    fprintf('\n=== MANIFEST SUMMARY ===\n');
    fprintf('Total: %d\n', numel(manifest));
    fprintf('IDRiD train: %d (empty: %d)\n', numel(trainIdx), sum([manifest(trainIdx).mask_empty]));
    fprintf('IDRiD test:  %d (empty: %d)\n', numel(testIdx), sum([manifest(testIdx).mask_empty]));
    fprintf('DDR ext:     %d (empty: %d)\n', numel(extIdx), sum([manifest(extIdx).mask_empty]));

    fprintf('\nForeground fraction distribution (IDRiD train):\n');
    fgFracs = [manifest(trainIdx).foreground_fraction];
    fprintf('  Min: %.6f, Max: %.6f, Mean: %.6f, Median: %.6f\n', ...
        min(fgFracs), max(fgFracs), mean(fgFracs), median(fgFracs));

    % Save
    save(fullfile(baseDir, 'matlab', 'segmentation', 'manifest.mat'), 'manifest');
    fprintf('\nManifest saved.\n');
end
