function evidence = extractLesionEvidence(img, varargin)
% extractLesionEvidence  Extract all lesion evidence from fundus image
%
%   evidence = extractLesionEvidence(img)
%
%   Runs all lesion detectors and aggregates results.
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

    try
        % Run all detectors
        evidence.microaneurysms = detectMicroaneurysms(img);
        evidence.hemorrhages = detectHemorrhages(img);
        evidence.exudates = detectExudates(img);
        evidence.neovascularization = detectNeovascularization(img);

        % Compute total lesions
        totalMA = evidence.microaneurysms.count;
        totalHem = evidence.hemorrhages.count;
        totalExu = evidence.exudates.count;
        totalNeo = evidence.neovascularization.detected;

        evidence.totalLesions = totalMA + totalHem + totalExu + totalNeo;

        % Determine severity based on evidence
        if evidence.totalLesions == 0
            evidence.severity = 'none';
            evidence.summary = 'No lesion candidates detected.';
        elseif evidence.totalLesions <= 3
            evidence.severity = 'mild';
            evidence.summary = sprintf('Mild: %d lesion(s) detected.', evidence.totalLesions);
        elseif evidence.totalLesions <= 10
            evidence.severity = 'moderate';
            evidence.summary = sprintf('Moderate: %d lesion(s) detected.', evidence.totalLesions);
        else
            evidence.severity = 'severe';
            evidence.summary = sprintf('Severe: %d lesion(s) detected.', evidence.totalLesions);
        end

        % Add specific findings to summary
        findings = {};
        if totalMA > 0
            findings{end+1} = sprintf('%d microaneurysm(s)', totalMA);
        end
        if totalHem > 0
            findings{end+1} = sprintf('%d hemorrhage(s)', totalHem);
        end
        if totalExu > 0
            findings{end+1} = sprintf('%d exudate(s)', totalExu);
        end
        if totalNeo
            findings{end+1} = 'neovascularization candidate';
        end

        if ~isempty(findings)
            evidence.summary = sprintf('%s Findings: %s.', ...
                evidence.summary, strjoin(findings, ', '));
        end

    catch ME
        evidence.summary = sprintf('Error extracting evidence: %s', ME.message);
    end
end
