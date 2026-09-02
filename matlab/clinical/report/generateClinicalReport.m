function report = generateClinicalReport(imageInfo, quality, classification, ...
    lesionEvidence, gradcam, clinicalDecision)
% generateClinicalReport  Generate structured clinical screening report
%
%   report = generateClinicalReport(imageInfo, quality, classification, ...
%       lesionEvidence, gradcam, clinicalDecision)
%
%   Input:
%       imageInfo         - Struct with .path, .timestamp
%       quality           - Struct from quality assessment
%       classification    - Struct with .gradeNum, .gradeName, .scores, .referable
%       lesionEvidence    - Struct from extractLesionEvidence
%       gradcam           - Struct from gradcamSimple (optional)
%       clinicalDecision  - Struct from applyClinicalLogic
%
%   Output:
%       report - Structured clinical report struct

    report = struct();

    % === Image Information ===
    report.imageInfo = struct();
    if isfield(imageInfo, 'path')
        report.imageInfo.path = imageInfo.path;
    else
        report.imageInfo.path = 'Unknown';
    end
    if isfield(imageInfo, 'timestamp')
        report.imageInfo.timestamp = imageInfo.timestamp;
    else
        report.imageInfo.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    end

    % === Quality Assessment ===
    report.quality = struct();
    if isfield(quality, 'status')
        report.quality.status = quality.status;
    else
        report.quality.status = 'UNKNOWN';
    end
    if isfield(quality, 'score')
        report.quality.score = quality.score;
    else
        report.quality.score = 0;
    end
    if isfield(quality, 'brightness')
        report.quality.brightness = quality.brightness;
    else
        report.quality.brightness = 0;
    end
    if isfield(quality, 'contrast')
        report.quality.contrast = quality.contrast;
    else
        report.quality.contrast = 0;
    end

    % === Classification ===
    report.classification = struct();
    if isfield(classification, 'gradeNum')
        report.classification.gradeNum = classification.gradeNum;
    else
        report.classification.gradeNum = -1;
    end
    if isfield(classification, 'gradeName')
        report.classification.gradeName = classification.gradeName;
    else
        report.classification.gradeName = 'Unknown';
    end
    if isfield(classification, 'scores')
        report.classification.scores = classification.scores;
    else
        report.classification.scores = zeros(1, 5);
    end
    if isfield(classification, 'referable')
        report.classification.referable = classification.referable;
    else
        report.classification.referable = false;
    end
    if isfield(classification, 'probability')
        report.classification.probability = classification.probability;
    else
        report.classification.probability = 0;
    end

    % === Lesion Evidence ===
    report.evidence = struct();
    if ~isempty(lesionEvidence) && isstruct(lesionEvidence)
        if isfield(lesionEvidence, 'microaneurysms')
            report.evidence.microaneurysms = lesionEvidence.microaneurysms.count;
        else
            report.evidence.microaneurysms = 0;
        end
        if isfield(lesionEvidence, 'hemorrhages')
            report.evidence.hemorrhages = lesionEvidence.hemorrhages.count;
        else
            report.evidence.hemorrhages = 0;
        end
        if isfield(lesionEvidence, 'exudates')
            report.evidence.exudates = lesionEvidence.exudates.count;
        else
            report.evidence.exudates = 0;
        end
        if isfield(lesionEvidence, 'neovascularization')
            report.evidence.neovascularization = lesionEvidence.neovascularization.detected;
        else
            report.evidence.neovascularization = false;
        end
        if isfield(lesionEvidence, 'severity')
            report.evidence.severity = lesionEvidence.severity;
        else
            report.evidence.severity = 'unknown';
        end
        if isfield(lesionEvidence, 'totalLesions')
            report.evidence.totalLesions = lesionEvidence.totalLesions;
        else
            report.evidence.totalLesions = 0;
        end
    else
        report.evidence.microaneurysms = 0;
        report.evidence.hemorrhages = 0;
        report.evidence.exudates = 0;
        report.evidence.neovascularization = false;
        report.evidence.severity = 'unknown';
        report.evidence.totalLesions = 0;
    end

    % === Grad-CAM ===
    report.explainability = struct();
    if ~isempty(gradcam) && isstruct(gradcam)
        report.explainability.gradcamAvailable = true;
        if isfield(gradcam, 'cam')
            report.explainability.primaryRegion = 'Attention map generated';
        else
            report.explainability.primaryRegion = 'Available';
        end
    else
        report.explainability.gradcamAvailable = false;
        report.explainability.primaryRegion = 'Not available';
    end

    % === Clinical Decision ===
    report.clinicalDecision = struct();
    if ~isempty(clinicalDecision) && isstruct(clinicalDecision)
        if isfield(clinicalDecision, 'status')
            report.clinicalDecision.status = clinicalDecision.status;
        else
            report.clinicalDecision.status = 'UNKNOWN';
        end
        if isfield(clinicalDecision, 'referableDecision')
            report.clinicalDecision.referableDecision = clinicalDecision.referableDecision;
        else
            report.clinicalDecision.referableDecision = 'UNKNOWN';
        end
        if isfield(clinicalDecision, 'confidenceLevel')
            report.clinicalDecision.confidenceLevel = clinicalDecision.confidenceLevel;
        else
            report.clinicalDecision.confidenceLevel = 'UNKNOWN';
        end
        if isfield(clinicalDecision, 'consistency')
            report.clinicalDecision.consistency = clinicalDecision.consistency;
        else
            report.clinicalDecision.consistency = 'UNKNOWN';
        end
        if isfield(clinicalDecision, 'consistencyWarning')
            report.clinicalDecision.consistencyWarning = clinicalDecision.consistencyWarning;
        else
            report.clinicalDecision.consistencyWarning = '';
        end
        if isfield(clinicalDecision, 'recommendation')
            report.clinicalDecision.recommendation = clinicalDecision.recommendation;
        else
            report.clinicalDecision.recommendation = '';
        end
    else
        report.clinicalDecision.status = 'UNKNOWN';
        report.clinicalDecision.referableDecision = 'UNKNOWN';
        report.clinicalDecision.confidenceLevel = 'UNKNOWN';
        report.clinicalDecision.consistency = 'UNKNOWN';
        report.clinicalDecision.consistencyWarning = '';
        report.clinicalDecision.recommendation = '';
    end

    % === Generate Text Report ===
    report.text = generateTextReport(report);

    % === Warnings ===
    report.warnings = generateWarnings(report);

    % === Disclaimer ===
    report.disclaimer = generateDisclaimer();

    % === Structured Fields for GUI ===
    report.display = generateDisplayFields(report);
end

function text = generateTextReport(report)
% generateTextReport  Generate formatted text report

    lines = {};

    % Header
    lines{end+1} = '====================================================';
    lines{end+1} = '       DR-SCREENING-AI CLINICAL SCREENING REPORT';
    lines{end+1} = '====================================================';
    lines{end+1} = '';

    % Image Information
    lines{end+1} = 'Patient/Image Information';
    lines{end+1} = '-------------------------';
    lines{end+1} = sprintf('Image ID: %s', report.imageInfo.path);
    lines{end+1} = sprintf('Date/Time: %s', report.imageInfo.timestamp);
    lines{end+1} = sprintf('Image Quality: %s', report.quality.status);
    lines{end+1} = sprintf('Quality Score: %.2f', report.quality.score);
    lines{end+1} = '';

    % Quality Assessment Detail
    lines{end+1} = 'QUALITY ASSESSMENT';
    lines{end+1} = '------------------';
    if strcmp(report.quality.status, 'GOOD')
        lines{end+1} = 'Image suitable for automated screening.';
    elseif strcmp(report.quality.status, 'BORDERLINE')
        lines{end+1} = 'Image quality borderline. Result should be interpreted with caution.';
    else
        lines{end+1} = 'IMAGE QUALITY: POOR';
        lines{end+1} = '';
        lines{end+1} = 'Screening cannot be reliably performed.';
        lines{end+1} = 'Image quality insufficient for reliable screening.';
        lines{end+1} = '';
        lines{end+1} = 'ACTION: RECAPTURE';
        lines{end+1} = 'Please recapture the fundus image with improved';
        lines{end+1} = 'illumination, focus, and field of view.';
    end
    lines{end+1} = '';

    % Only show clinical results if quality is not POOR
    if ~strcmp(report.quality.status, 'POOR')
        % Screening Result
        lines{end+1} = 'SCREENING RESULT';
        lines{end+1} = '----------------';
        lines{end+1} = sprintf('DR Grade: G%d - %s', report.classification.gradeNum, report.classification.gradeName);
        lines{end+1} = sprintf('Referable: %s', report.clinicalDecision.referableDecision);
        lines{end+1} = sprintf('Probability: %.4f', report.classification.probability);
        lines{end+1} = sprintf('Confidence: %s', report.clinicalDecision.confidenceLevel);
        lines{end+1} = sprintf('Clinical Consistency: %s', report.clinicalDecision.consistency);
        lines{end+1} = '';

        % Lesion Evidence
        lines{end+1} = 'LESION-LEVEL EVIDENCE';
        lines{end+1} = '---------------------';
        lines{end+1} = sprintf('Microaneurysms: %d detected', report.evidence.microaneurysms);
        lines{end+1} = sprintf('Hemorrhages: %d detected', report.evidence.hemorrhages);
        lines{end+1} = sprintf('Exudates: %d detected', report.evidence.exudates);
        if report.evidence.neovascularization
            lines{end+1} = 'Neovascularization: DETECTED';
        else
            lines{end+1} = 'Neovascularization: Not detected';
        end
        lines{end+1} = '';

        % Severity Assessment
        lines{end+1} = 'SEVERITY ASSESSMENT';
        lines{end+1} = '-------------------';
        lines{end+1} = sprintf('Overall lesion evidence: %s', upper(report.evidence.severity));
        lines{end+1} = sprintf('Total lesions: %d', report.evidence.totalLesions);
        lines{end+1} = '';

        % Model Probabilities
        lines{end+1} = 'MODEL PROBABILITIES';
        lines{end+1} = '-------------------';
        grades = {'G0', 'G1', 'G2', 'G3', 'G4'};
        for i = 1:5
            lines{end+1} = sprintf('%s: %.1f%%', grades{i}, report.classification.scores(i)*100);
        end
        lines{end+1} = '';

        % Explainability
        lines{end+1} = 'EXPLAINABILITY';
        lines{end+1} = '--------------';
        if report.explainability.gradcamAvailable
            lines{end+1} = 'Grad-CAM: Available';
            lines{end+1} = sprintf('Primary attention region: %s', report.explainability.primaryRegion);
        else
            lines{end+1} = 'Grad-CAM: Not available';
        end
        lines{end+1} = 'Lesion evidence: Available';
        lines{end+1} = '';

        % Consistency Warning
        if ~isempty(report.clinicalDecision.consistencyWarning)
            lines{end+1} = 'QUALITY / SAFETY WARNINGS';
            lines{end+1} = '-------------------------';
            lines{end+1} = report.clinicalDecision.consistencyWarning;
            lines{end+1} = '';
        end

        % Clinical Action
        lines{end+1} = 'CLINICAL ACTION';
        lines{end+1} = '---------------';
        lines{end+1} = sprintf('Referral recommended: %s', string(report.classification.referable));
        lines{end+1} = sprintf('Suggested action: %s', report.clinicalDecision.recommendation);
        lines{end+1} = '';
    end

    % Disclaimer
    lines{end+1} = 'DISCLAIMER';
    lines{end+1} = '----------';
    lines{end+1} = 'This system is a research prototype and is not';
    lines{end+1} = 'intended for autonomous clinical diagnosis.';
    lines{end+1} = 'Final clinical decisions must be made by a';
    lines{end+1} = 'qualified healthcare professional.';
    lines{end+1} = '====================================================';

    text = strjoin(lines, newline);
end

function warnings = generateWarnings(report)
% generateWarnings  Generate clinical warnings

    warnings = {};

    % Quality warnings
    if strcmp(report.quality.status, 'POOR')
        warnings{end+1} = 'IMAGE QUALITY: POOR - Screening may be unreliable';
    elseif strcmp(report.quality.status, 'BORDERLINE')
        warnings{end+1} = 'IMAGE QUALITY: BORDERLINE - Interpret with caution';
    end

    % Consistency warnings
    if ~isempty(report.clinicalDecision.consistencyWarning)
        warnings{end+1} = report.clinicalDecision.consistencyWarning;
    end

    % Confidence warnings
    if strcmp(report.clinicalDecision.confidenceLevel, 'LOW')
        warnings{end+1} = 'LOW CONFIDENCE - Clinical correlation recommended';
    end

    % High grade warnings
    if report.classification.gradeNum >= 3
        warnings{end+1} = sprintf('HIGH GRADE (G%d) - Urgent referral recommended', ...
            report.classification.gradeNum);
    end

    % Neovascularization warning
    if report.evidence.neovascularization
        warnings{end+1} = 'NEOVASCULARIZATION DETECTED - PDR suspected';
    end
end

function disclaimer = generateDisclaimer()
% generateDisclaimer  Generate standard disclaimer

    disclaimer = {
        'This system is a research prototype and is not'
        'intended for autonomous clinical diagnosis.'
        'Final clinical decisions must be made by a'
        'qualified healthcare professional.'
        ''
        'Model: Transfer Learning ResNet-18 (Phase 17 validated)'
        'Performance: Sensitivity 87.2%, Specificity 92.7%'
        'Note: External clinical validation not performed'
        ''
        'Lesion evidence is AI-assisted supporting evidence.'
        'Final diagnosis and treatment decisions require'
        'qualified ophthalmologist review.'
    };
end

function display = generateDisplayFields(report)
% generateDisplayFields  Generate fields for GUI display

    display = struct();

    % Grade display
    if report.classification.gradeNum >= 0
        display.gradeText = sprintf('Grade %d: %s', ...
            report.classification.gradeNum, report.classification.gradeName);
    else
        display.gradeText = 'UNGRADABLE';
    end

    % Referable display
    display.referableText = report.clinicalDecision.referableDecision;

    % Confidence display
    display.confidenceText = sprintf('Prob: %.1f%% | Conf: %s', ...
        report.classification.probability*100, report.clinicalDecision.confidenceLevel);

    % Risk display
    if report.classification.gradeNum == 0
        display.riskText = 'Risk: NONE';
        display.riskColor = [0 0.5 0];
    elseif report.classification.gradeNum <= 2
        display.riskText = 'Risk: MODERATE';
        display.riskColor = [0.8 0.5 0];
    else
        display.riskText = 'Risk: HIGH';
        display.riskColor = [0.8 0 0];
    end

    % Quality display
    display.qualityText = sprintf('Quality: %s', report.quality.status);
    if strcmp(report.quality.status, 'GOOD')
        display.qualityColor = [0 0.5 0];
    elseif strcmp(report.quality.status, 'BORDERLINE')
        display.qualityColor = [0.8 0.5 0];
    else
        display.qualityColor = [0.8 0 0];
    end

    % Evidence displays
    display.evidenceMA = sprintf('Microaneurysms: %d detected', report.evidence.microaneurysms);
    display.evidenceHem = sprintf('Hemorrhages: %d detected', report.evidence.hemorrhages);
    display.evidenceExu = sprintf('Exudates: %d detected', report.evidence.exudates);
    if report.evidence.neovascularization
        display.evidenceNV = 'Neovascularization: DETECTED';
    else
        display.evidenceNV = 'Neovascularization: None detected';
    end
    display.evidenceSummary = sprintf('Severity: %s', report.evidence.severity);
end
