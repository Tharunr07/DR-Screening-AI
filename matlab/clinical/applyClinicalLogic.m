function result = applyClinicalLogic(gradeNum, scores, evidence, quality)
% applyClinicalLogic  Apply clinical consistency rules to AI output
%
%   result = applyClinicalLogic(gradeNum, scores, evidence, quality)
%
%   Implements:
%       - Quality gating (reject POOR images)
%       - Referable consistency (G2+ only)
%       - Lesion-classifier consistency check
%       - Confidence level classification
%
%   Input:
%       gradeNum  - Predicted DR grade (0-4)
%       scores    - Class probabilities [1x5]
%       evidence  - Lesion evidence struct
%       quality   - Quality assessment struct
%
%   Output:
%       result    - Struct with clinical decision

    result = struct();

    % === Quality Gating ===
    if strcmp(quality.status, 'POOR')
        result.status = 'UNGRADABLE';
        result.gradeNum = -1;
        result.gradeName = 'Ungradable';
        result.referable = false;
        result.referableDecision = 'RECAPTURE';
        result.confidence = 0;
        result.confidenceLevel = 'NONE';
        result.consistency = 'N/A';
        result.consistencyWarning = '';
        result.recommendation = 'Image quality insufficient. Please recapture with improved illumination, focus, and field of view.';
        result.probability = max(scores);
        return;
    end

    % === Normal Classification ===
    result.status = 'GRADED';
    result.gradeNum = gradeNum;
    grades = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
    result.gradeName = grades{gradeNum + 1};

    % === Referable Decision (G2+ only) ===
    % SIH definition: G2, G3, G4 are referable
    result.referable = gradeNum >= 2;
    if result.referable
        result.referableDecision = 'REFERABLE';
    else
        result.referableDecision = 'NON-REFERABLE';
    end

    % === Confidence Analysis ===
    maxProb = max(scores);
    result.probability = maxProb;

    % Confidence level based on max probability
    if maxProb >= 0.7
        result.confidenceLevel = 'HIGH';
    elseif maxProb >= 0.4
        result.confidenceLevel = 'MEDIUM';
    else
        result.confidenceLevel = 'LOW';
    end

    % Confidence percentage (from max class probability)
    result.confidence = maxProb * 100;

    % === Lesion-Classifier Consistency ===
    [result.consistency, result.consistencyWarning] = checkConsistency(gradeNum, evidence);

    % === Final Recommendation ===
    result.recommendation = generateRecommendation(gradeNum, result.referable, ...
        result.consistency, quality.status, result.confidenceLevel);
end

function [consistency, warning] = checkConsistency(gradeNum, evidence)
% checkConsistency  Check if lesion evidence agrees with classifier grade

    warning = '';
    inconsistencyCount = 0;

    % Rule 1: Grade 0 with significant lesions
    if gradeNum == 0
        if evidence.microaneurysms.count > 5
            inconsistencyCount = inconsistencyCount + 1;
            warning = sprintf('%s- Grade 0 but %d microaneurysms detected\n', ...
                warning, evidence.microaneurysms.count);
        end
        if evidence.hemorrhages.count > 2
            inconsistencyCount = inconsistencyCount + 1;
            warning = sprintf('%s- Grade 0 but %d hemorrhages detected\n', ...
                warning, evidence.hemorrhages.count);
        end
        if evidence.exudates.count > 3
            inconsistencyCount = inconsistencyCount + 1;
            warning = sprintf('%s- Grade 0 but %d exudates detected\n', ...
                warning, evidence.exudates.count);
        end
        if evidence.neovascularization.detected
            inconsistencyCount = inconsistencyCount + 1;
            warning = sprintf('%s- Grade 0 but neovascularization detected\n', warning);
        end
    end

    % Rule 2: High grade (G3/G4) with no lesions
    if gradeNum >= 3
        if evidence.microaneurysms.count == 0 && ...
           evidence.hemorrhages.count == 0 && ...
           evidence.exudates.count == 0 && ...
           ~evidence.neovascularization.detected
            inconsistencyCount = inconsistencyCount + 1;
            warning = sprintf('%s- Grade %d but no lesion evidence detected\n', ...
                warning, gradeNum);
        end
    end

    % Rule 3: Severe lesion evidence with low grade
    if gradeNum <= 1
        totalLesions = evidence.microaneurysms.count + ...
                       evidence.hemorrhages.count + ...
                       evidence.exudates.count;
        if totalLesions > 10
            inconsistencyCount = inconsistencyCount + 1;
            warning = sprintf('%s- Grade %d but %d total lesions detected\n', ...
                warning, gradeNum, totalLesions);
        end
    end

    % Determine consistency level
    if inconsistencyCount == 0
        consistency = 'CONSISTENT';
    elseif inconsistencyCount == 1
        consistency = 'MINOR_INCONSISTENCY';
        warning = sprintf('AI result requires review:\n%s', strtrim(warning));
    else
        consistency = 'MAJOR_INCONSISTENCY';
        warning = sprintf('AI result requires urgent review:\n%s', strtrim(warning));
    end
end

function recommendation = generateRecommendation(gradeNum, isReferable, ...
    consistency, qualityStatus, confidenceLevel)
% generateRecommendation  Generate clinical recommendation

    % Base recommendation on grade
    if gradeNum == -1
        recommendation = 'Recapture image with improved quality.';
        return;
    end

    if isReferable
        baseRec = 'Refer to ophthalmologist for confirmatory examination.';
    else
        baseRec = 'Routine follow-up. No immediate referral needed.';
    end

    % Add consistency caveat
    if strcmp(consistency, 'MAJOR_INCONSISTENCY')
        consistencyNote = ' Note: AI result is inconsistent with lesion evidence. Manual review strongly recommended.';
    elseif strcmp(consistency, 'MINOR_INCONSISTENCY')
        consistencyNote = ' Note: Minor inconsistency detected between classifier and lesion evidence.';
    else
        consistencyNote = '';
    end

    % Add confidence caveat
    if strcmp(confidenceLevel, 'LOW')
        confidenceNote = ' Note: Model confidence is low. Clinical correlation recommended.';
    else
        confidenceNote = '';
    end

    recommendation = sprintf('%s%s%s', baseRec, consistencyNote, confidenceNote);
end
