function runAllBatches()
% runAllBatches  Run all Phase 20C.1 batches with unique output dirs

    baseDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20c1');
    
    batches = {
        'batch1', 1, 150;
        'batch2', 151, 300;
        'batch3', 301, 450;
        'batch4a', 451, 530;
        'batch4b', 531, 611;
    };
    
    for b = 1:size(batches, 1)
        name = batches{b, 1};
        s = batches{b, 2};
        e = batches{b, 3};
        outDir = fullfile(baseDir, name);
        fprintf('\n========== BATCH %s: images %d-%d ==========\n', name, s, e);
        runPhase20C1('StartImage', s, 'EndImage', e, 'OutputDir', outDir, 'Verbose', true);
    end
    
    fprintf('\n========== ALL BATCHES COMPLETE ==========\n');
end
