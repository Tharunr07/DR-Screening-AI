function mergePhase20C1Batches()
% mergePhase20C1Batches  Merge batch CSVs and print aggregate stats

    baseDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20c1');
    batchDirs = {'batch1', 'batch2', 'batch3', 'batch4a', 'batch4b'};
    
    allT = [];
    for b = 1:numel(batchDirs)
        csvPath = fullfile(baseDir, batchDirs{b}, 'phase20c1_per_image.csv');
        if ~exist(csvPath, 'file')
            fprintf('WARN: Missing %s\n', csvPath);
            continue;
        end
        T = readtable(csvPath);
        fprintf('Batch %s: %d images\n', batchDirs{b}, height(T));
        if isempty(allT)
            allT = T;
        else
            allT = [allT; T]; %#ok<AGROW>
        end
    end
    
    n = height(allT);
    fprintf('\n=== MERGED Phase 20C.1: %d images ===\n\n', n);
    
    % Write merged CSV
    mergedCsv = fullfile(baseDir, 'phase20c1_merged.csv');
    writetable(allT, mergedCsv);
    fprintf('Merged CSV: %s\n\n', mergedCsv);
    
    maC = allT.ma_count; heC = allT.he_count; exC = allT.ex_count;
    nvD = allT.nv_detected; totL = allT.total_lesions;
    grades = allT.dr_grade; predG = allT.pred_grade;
    gMatch = allT.grade_match; refGt = allT.referable_gt;
    refPred = allT.referable_pred; refMatch = allT.referable_match;
    maDen = allT.ma_density; heDen = allT.he_density; exDen = allT.ex_density;
    br = allT.brightness; co = allT.contrast; sh = allT.sharpness;
    qSt = allT.quality_status;
    
    % Lesion distributions
    types = {'MICROANEURYSM', 'HEMORRHAGE', 'EXUDATE'};
    counts = [maC, heC, exC];
    densities = [maDen, heDen, exDen];
    for lt = 1:3
        fprintf('--- %s ---\n', types{lt});
        c = counts(:,lt); d = densities(:,lt);
        fprintf('  Median:     %g\n', median(c));
        fprintf('  Mean:       %.2f\n', mean(c));
        fprintf('  Std:        %.2f\n', std(c));
        fprintf('  P90:        %g\n', prctile(c, 90));
        fprintf('  P95:        %g\n', prctile(c, 95));
        fprintf('  P99:        %g\n', prctile(c, 99));
        fprintf('  Max:        %g\n', max(c));
        fprintf('  Prevalence: %.1f%% (%d/%d)\n', sum(c>0)/n*100, sum(c>0), n);
        fprintf('  Density/Mpx: med=%.1f mean=%.1f P95=%.1f max=%.1f\n\n', ...
            median(d), mean(d), prctile(d,95), max(d));
    end
    
    fprintf('--- NV ---\n');
    fprintf('  Detected: %d/%d (%.1f%%)\n\n', sum(nvD>0), n, sum(nvD>0)/n*100);
    
    fprintf('--- TOTAL LESIONS ---\n');
    fprintf('  Median: %g  Mean: %.2f  P95: %g  P99: %g  Max: %g\n\n', ...
        median(totL), mean(totL), prctile(totL,95), prctile(totL,99), max(totL));
    
    % Classifier accuracy
    fprintf('--- CLASSIFIER ACCURACY ---\n');
    fprintf('  Grade match:     %.1f%% (%d/%d)\n', sum(gMatch)/n*100, sum(gMatch), n);
    fprintf('  Referable match: %.1f%% (%d/%d)\n\n', sum(refMatch)/n*100, sum(refMatch), n);
    for g = 0:4
        idx = grades == g;
        if sum(idx) > 0
            fprintf('  G%d: n=%d | grade_acc=%.1f%% | ref_acc=%.1f%%\n', ...
                g, sum(idx), sum(gMatch(idx))/sum(idx)*100, sum(refMatch(idx))/sum(idx)*100);
        end
    end
    
    % Confusion-like table
    fprintf('\n--- GRADE CONFUSION ---\n');
    fprintf('  Pred->  G0    G1    G2    G3    G4\n');
    for g = 0:4
        row = zeros(1,5);
        idx = grades == g;
        for pg = 0:5
            if pg < 5
                row(pg+1) = sum(predG(idx) == pg);
            end
        end
        fprintf('  Act G%d: %4d  %4d  %4d  %4d  %4d\n', g, row);
    end
    
    % Quality gate
    fprintf('\n--- QUALITY GATE ---\n');
    for s = {'GOOD', 'BORDERLINE', 'POOR'}
        cnt = sum(strcmp(qSt, s{1}));
        fprintf('  %s: %d (%.1f%%)\n', s{1}, cnt, cnt/n*100);
    end
    fprintf('  Brightness < 40:  %d (%.1f%%)\n', sum(br<40), sum(br<40)/n*100);
    fprintf('  Brightness > 220: %d (%.1f%%)\n', sum(br>220), sum(br>220)/n*100);
    fprintf('  Contrast < 20:    %d (%.1f%%)\n', sum(co<20), sum(co<20)/n*100);
    fprintf('  Sharpness < 100:  %d (%.1f%%)\n\n', sum(sh<100), sum(sh<100)/n*100);
    
    % Size distribution
    fprintf('--- IMAGE SIZE ---\n');
    maxDim = max(allT.width, allT.height);
    for bnd = [800, 1500, 3000]
        if bnd == 800
            label = '<=800'; cnt = sum(maxDim <= 800);
        elseif bnd == 1500
            label = '801-1500'; cnt = sum(maxDim > 800 & maxDim <= 1500);
        else
            label = '1501-3000'; cnt = sum(maxDim > 1500 & maxDim <= 3000);
        end
        fprintf('  %s: %d (%.1f%%)\n', label, cnt, cnt/n*100);
    end
    fprintf('  >3000: %d (%.1f%%)\n\n', sum(maxDim > 3000), sum(maxDim > 3000)/n*100);
    
    % Outliers
    fprintf('--- OUTLIER DETECTION ---\n');
    p99ma = prctile(maC, 99); p99he = prctile(heC, 99);
    p99ex = prctile(exC, 99); p99tl = prctile(totL, 99);
    fprintf('  P99 thresholds: MA>%g HE>%g EX>%g Total>%g\n', p99ma, p99he, p99ex, p99tl);
    oIdx = find(maC > p99ma | heC > p99he | exC > p99ex | totL > p99tl);
    fprintf('  Outliers: %d/%d\n', numel(oIdx), n);
    for oi = 1:min(numel(oIdx), 20)
        i = oIdx(oi);
        fprintf('  %2d. %s (G%d, %dx%d) MA=%d HE=%d EX=%d NV=%d T=%d\n', ...
            oi, allT.image_id{i}, grades(i), allT.width(i), allT.height(i), ...
            maC(i), heC(i), exC(i), nvD(i), totL(i));
    end
    
    fprintf('\n=== MERGE COMPLETE ===\n');
end
