function evidence = extractLesionEvidence(img, varargin)
% extractLesionEvidence  Extract all lesion evidence from fundus image
%
%   evidence = extractLesionEvidence(img)
%
%   Runs all lesion detectors and aggregates results with confidence levels.
%
%   Input:
%       img - RGB fundus image (uint8 or double)
%
%   Output:
%       evidence - Struct with fields:
%           .microaneurysms - Microaneurysm detection results
%           .hemorrhages    - Hemorrhage detection results
%           .exudates       - Exudate detection results
%           .neovascularization - Neovascularization detection results
%           .summary        - Text summary of findings
%           .totalLesions   - Total lesion count
%           .severity       - Evidence severity (none/mild/moderate/severe)
%           .confidenceLevels - Confidence levels for each detector

    p = inputParser;
    addRequired(p, 'img');
    parse(p, img, varargin{:});

    % Initialize output
    evidence = struct();
    evidence.microaneurysms = [];
    evidence.hemorrhages = [];
    evidence.exudates = [];
    evidence.neovascularization = [];
    evidence.summary = '';
    evidence.totalLesions = 0;
    evidence.severity = 'none';
    evidence.confidenceLevels = struct();

    try
        % Run all detectors
        evidence.microaneurysms = detectMicroaneurysms(img);
        evidence.hemorrhages = detectHemorrhages(img);
        evidence.exudates = detectExudates(img);
        evidence.neovascularization = detectNeovascularization(img);

        % Assign confidence levels based on detector confidence
        evidence.confidenceLevels.microaneurysms = getConfidenceLevel(evidence.microaneurysms.confidence);
        evidence.confidenceLevels.hemorrhages = getConfidenceLevel(evidence.hemorrhages.confidence);
        evidence.confidenceLevels.exudates = getConfidenceLevel(evidence.exudates.confidence);
        evidence.confidenceLevels.neovascularization = getConfidenceLevel(evidence.neovascularization.confidence);

        % Compute total lesions (weighted by confidence)
        totalMA = evidence.microaneurysms.count;
        totalHem = evidence.hemorrhages.count;
        totalExu = evidence.exudates.count;
        totalNeo = evidence.neovascularization.detected;

        evidence.totalLesions = totalMA + totalHem + totalExu + totalNeo;

        % Determine severity based on evidence and confidence
        severityScore = computeSeverityScore(evidence);

        if severityScore == 0
            evidence.severity = 'none';
            evidence.summary = 'No lesion candidates detected.';
        elseif severityScore <= 2
            evidence.severity = 'mild';
            evidence.summary = sprintf('Mild: %d lesion(s) detected.', evidence.totalLesions);
        elseif severityScore <= 5
            evidence.severity = 'moderate';
            evidence.summary = sprintf('Moderate: %d lesion(s) detected.', evidence.totalLesions);
        else
            evidence.severity = 'severe';
            evidence.summary = sprintf('Severe: %d lesion(s) detected.', evidence.totalLesions);
        end

        % Add specific findings to summary
        findings = {};
        if totalMA > 0
            confLevel = evidence.confidenceLevels.microaneurysms;
            findings{end+1} = sprintf('%d microaneurysm(s) [%s confidence]', totalMA, confLevel);
        end
        if totalHem > 0
            confLevel = evidence.confidenceLevels.hemorrhages;
            findings{end+1} = sprintf('%d hemorrhage(s) [%s confidence]', totalHem, confLevel);
        end
        if totalExu > 0
            confLevel = evidence.confidenceLevels.exudates;
            findings{end+1} = sprintf('%d exudate(s) [%s confidence]', totalExu, confLevel);
        end
        if totalNeo
            confLevel = evidence.confidenceLevels.neovascularization;
            findings{end+1} = sprintf('neovascularization candidate [%s confidence]', confLevel);
        end

        if ~isempty(findings)
            evidence.summary = sprintf('%s Findings: %s.', ...
                evidence.summary, strjoin(findings, ', '));
        end

    catch ME
        evidence.summary = sprintf('Error extracting evidence: %s', ME.message);
    end
end

function level = getConfidenceLevel(confidence)
% getConfidenceLevel  Convert confidence score to level

    if confidence >= 0.7
        level = 'HIGH';
    elseif confidence >= 0.4
        level = 'MEDIUM';
    else
        level = 'LOW';
    end
end

function score = computeSeverityScore(evidence)
% computeSeverityScore  Compute severity score weighted by confidence

    score = 0;

    % Microaneurysms
    if evidence.microaneurysms.count > 0
        weight = getConfidenceWeight(evidence.microaneurysms.confidence);
        score = score + evidence.microaneurysms.count * weight;
    end

    % Hemorrhages (weighted higher)
    if evidence.hemorrhages.count > 0
        weight = getConfidenceWeight(evidence.hemorrhages.confidence);
        score = score + evidence.hemorrhages.count * weight * 1.5;
    end

    % Exudates
    if evidence.exudates.count > 0
        weight = getConfidenceWeight(evidence.exudates.confidence);
        score = score + evidence.exudates.count * weight;
    end

    % Neovascularization (weighted highest)
    if evidence.neovascularization.detected
        weight = getConfidenceWeight(evidence.neovascularization.confidence);
        score = score + 5 * weight;
    end
end

function weight = getConfidenceWeight(confidence)
% getConfidenceWeight  Get weight based on confidence level

    if confidence >= 0.7
        weight = 1.0;
    elseif confidence >= 0.4
        weight = 0.5;
    else
        weight = 0.2;
    end
end
