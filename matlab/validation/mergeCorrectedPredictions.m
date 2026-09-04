function mergeCorrectedPredictions()
% mergeCorrectedPredictions  Update Phase 20C.1 merged CSV with corrected classifier
%
%   Takes the existing lesion analysis (unchanged) and corrects only the
%   classifier-related columns using the corrected predictions.

    fprintf('=== Merging corrected predictions into Phase 20C.1 CSV ===\n\n');

    cfgTL = transferLearningConfig();

    % Load corrected classifier predictions
    correctedPath = fullfile(cfgTL.paths.splitDir, 'val_classifier_corrected.csv');
    Tc = readtable(correctedPath, 'TextType', 'string');

    % Load existing merged CSV
    mergedPath = fullfile(cfgTL.projectRoot, 'results', 'phase20c1', 'phase20c1_merged.csv');
    Tm = readtable(mergedPath, 'TextType', 'string');

    % Match by image_id
    [tf, loc] = ismember(Tm.image_id, Tc.image_id);
    fprintf('Matched %d/%d images\n', sum(tf), height(Tm));

    % Update classifier columns
    matchedIdx = find(tf);
    for i = 1:length(matchedIdx)
        mi = matchedIdx(i);
        ci = loc(mi);
        Tm.pred_grade(mi) = Tc.predicted_grade(ci);
        Tm.grade_match(mi) = Tc.grade_match(ci);
        Tm.referable_pred(mi) = Tc.referable_predicted(ci);
        Tm.referable_match(mi) = (Tc.referable_predicted(ci) == Tc.referable_true(ci));
        Tm.confidence(mi) = Tc.confidence(ci);
    end

    % Recalculate consistency (lesion-grade agreement)
    for i = 1:height(Tm)
        totalLesions = Tm.total_lesions(i);
        predGrade = Tm.pred_grade(i);
        if predGrade < 0
            Tm.consistency{i} = 'UNGRADED';
        elseif totalLesions == 0 && predGrade == 0
            Tm.consistency{i} = 'CONSISTENT';
        elseif totalLesions > 0 && predGrade > 0
            Tm.consistency{i} = 'CONSISTENT';
        elseif totalLesions == 0 && predGrade > 0
            Tm.consistency{i} = 'FP_LESIONS';
        else
            Tm.consistency{i} = 'FN_LESIONS';
        end
    end

    % Save updated CSV
    writetable(Tm, mergedPath);
    fprintf('Saved updated merged CSV: %s\n', mergedPath);

    % Summary statistics
    valid = Tm.pred_grade >= 0;
    acc = sum(Tm.grade_match(valid)) / sum(valid);
    refMatch = sum(Tm.referable_match(valid)) / sum(valid);
    fprintf('\n--- Updated Summary ---\n');
    fprintf('Grade match: %.1f%% (%d/%d)\n', acc*100, sum(Tm.grade_match(valid)), sum(valid));
    fprintf('Referable match: %.1f%%\n', refMatch*100);

    % Per-grade accuracy
    for g = 0:4
        mask = Tm.dr_grade == g & valid;
        if sum(mask) > 0
            acc_g = sum(Tm.grade_match(mask)) / sum(mask);
            fprintf('  Grade %d accuracy: %.1f%% (%d/%d)\n', g, acc_g*100, sum(Tm.grade_match(mask)), sum(mask));
        end
    end

    % Lesion prevalence (unchanged from original)
    fprintf('\n--- Lesion Prevalence (unchanged) ---\n');
    fprintf('  MA: %.1f%% (%d/%d)\n', sum(Tm.ma_count > 0)/height(Tm)*100, sum(Tm.ma_count > 0), height(Tm));
    fprintf('  HE: %.1f%% (%d/%d)\n', sum(Tm.he_count > 0)/height(Tm)*100, sum(Tm.he_count > 0), height(Tm));
    fprintf('  EX: %.1f%% (%d/%d)\n', sum(Tm.ex_count > 0)/height(Tm)*100, sum(Tm.ex_count > 0), height(Tm));
    fprintf('  NV: %.1f%% (%d/%d)\n', sum(Tm.nv_detected > 0)/height(Tm)*100, sum(Tm.nv_detected > 0), height(Tm));

    fprintf('\n=== DONE ===\n');
end
