function exportClinicalReport(report, outputPath, varargin)
% exportClinicalReport  Export clinical report to text file
%
%   exportClinicalReport(report, outputPath)
%   exportClinicalReport(report, outputPath, 'Format', 'txt')
%
%   Input:
%       report     - Struct from generateClinicalReport
%       outputPath - Path to output file
%
%   Name-Value Pairs:
%       'Format'   - Output format: 'txt' (default), 'csv'

    p = inputParser;
    addRequired(p, 'report', @isstruct);
    addRequired(p, 'outputPath', @ischar);
    addParameter(p, 'Format', 'txt', @ischar);
    parse(p, report, outputPath, varargin{:});

    format = p.Results.Format;

    % Create output directory if needed
    outputDir = fileparts(outputPath);
    if ~isempty(outputDir) && ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    switch lower(format)
        case 'txt'
            exportTxt(report, outputPath);
        case 'csv'
            exportCsv(report, outputPath);
        otherwise
            error('Unknown format: %s', format);
    end
end

function exportTxt(report, outputPath)
% exportTxt  Export report as text file

    fid = fopen(outputPath, 'w');
    if fid == -1
        error('Cannot open file for writing: %s', outputPath);
    end

    % Write text report
    fprintf(fid, '%s\n', report.text);

    fclose(fid);
end

function exportCsv(report, outputPath)
% exportCsv  Export report as CSV file

    fid = fopen(outputPath, 'w');
    if fid == -1
        error('Cannot open file for writing: %s', outputPath);
    end

    % Header
    fprintf(fid, 'Field,Value\n');

    % Image Information
    fprintf(fid, 'Image Path,"%s"\n', report.imageInfo.path);
    fprintf(fid, 'Date/Time,"%s"\n', report.imageInfo.timestamp);

    % Quality
    fprintf(fid, 'Image Quality,%s\n', report.quality.status);
    fprintf(fid, 'Quality Score,%.2f\n', report.quality.score);
    fprintf(fid, 'Brightness,%.1f\n', report.quality.brightness);
    fprintf(fid, 'Contrast,%.1f\n', report.quality.contrast);

    % Classification
    fprintf(fid, 'DR Grade,%d\n', report.classification.gradeNum);
    fprintf(fid, 'DR Grade Name,"%s"\n', report.classification.gradeName);
    fprintf(fid, 'Referable,%d\n', report.classification.referable);
    fprintf(fid, 'Referable Decision,"%s"\n', report.clinicalDecision.referableDecision);
    fprintf(fid, 'Probability,%.4f\n', report.classification.probability);
    fprintf(fid, 'Confidence Level,"%s"\n', report.clinicalDecision.confidenceLevel);

    % Evidence
    fprintf(fid, 'Microaneurysms,%d\n', report.evidence.microaneurysms);
    fprintf(fid, 'Hemorrhages,%d\n', report.evidence.hemorrhages);
    fprintf(fid, 'Exudates,%d\n', report.evidence.exudates);
    fprintf(fid, 'Neovascularization,%d\n', report.evidence.neovascularization);
    fprintf(fid, 'Total Lesions,%d\n', report.evidence.totalLesions);
    fprintf(fid, 'Lesion Severity,"%s"\n', report.evidence.severity);

    % Clinical Decision
    fprintf(fid, 'Clinical Status,"%s"\n', report.clinicalDecision.status);
    fprintf(fid, 'Consistency,"%s"\n', report.clinicalDecision.consistency);
    if ~isempty(report.clinicalDecision.consistencyWarning)
        fprintf(fid, 'Consistency Warning,"%s"\n', strrep(report.clinicalDecision.consistencyWarning, '"', '""'));
    end
    fprintf(fid, 'Recommendation,"%s"\n', strrep(report.clinicalDecision.recommendation, '"', '""'));

    % Model Probabilities
    grades = {'G0', 'G1', 'G2', 'G3', 'G4'};
    for i = 1:5
        fprintf(fid, '%s Probability,%.4f\n', grades{i}, report.classification.scores(i));
    end

    % Explainability
    fprintf(fid, 'Grad-CAM Available,%d\n', report.explainability.gradcamAvailable);

    % Warnings
    if ~isempty(report.warnings)
        warningText = strjoin(report.warnings, '; ');
        fprintf(fid, 'Warnings,"%s"\n', strrep(warningText, '"', '""'));
    end

    fclose(fid);
end
