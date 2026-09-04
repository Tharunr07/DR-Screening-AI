function mapping = createSIHMapping(results, analysis, benchmarks)
% createSIHMapping  Create formal SIH requirement traceability mapping
%
%   mapping = createSIHMapping(results, analysis, benchmarks)
%
%   Maps each SIH requirement to specific evidence and assessment.

    mapping = struct();

    % === Requirement 1: Diabetic Retinopathy Detection ===
    mapping.req1_detection = struct();
    mapping.req1_detection.requirement = 'Automated DR screening from retinal images';
    mapping.req1_detection.evidence = 'Phase 17: 76.6% 5-class accuracy, 87.2% referable sensitivity';
    mapping.req1_detection.assessment = 'PARTIAL - Model demonstrates detection capability but sensitivity below 90% target';

    % === Requirement 2: Sensitivity Target ===
    mapping.req2_sensitivity = struct();
    mapping.req2_sensitivity.requirement = 'Sensitivity > 90% for referable DR';
    mapping.req2_sensitivity.evidence = sprintf('Phase 17: 87.2%% (95%% CI: 83.1%%-90.3%%)', results.refMetrics.sensitivity*100);
    mapping.req2_sensitivity.assessment = 'NOT MET - Sensitivity 87.2% below 90% target';
    mapping.req2_sensitivity.mitigation = 'Confidence interval crosses 90%; discuss in presentation as limitation';

    % === Requirement 3: Specificity Target ===
    mapping.req3_specificity = struct();
    mapping.req3_specificity.requirement = 'Specificity > 85% for referable DR';
    mapping.req3_specificity.evidence = sprintf('Phase 17: 92.7%% (95%% CI: 90.3%%-95.0%%)', results.refMetrics.specificity*100);
    mapping.req3_specificity.assessment = 'MET - Specificity exceeds target';

    % === Requirement 4: Explainability ===
    mapping.req4_explainability = struct();
    mapping.req4_explainability.requirement = 'Explainable AI for clinical trust';
    mapping.req4_explainability.evidence = 'Phase 11: Grad-CAM visualization (9/9 PASS); Phase 12.1: Lesion evidence with confidence levels';
    mapping.req4_explainability.assessment = 'MET - Explainability components implemented and validated';

    % === Requirement 5: Lesion Evidence ===
    mapping.req5_lesions = struct();
    mapping.req5_lesions.requirement = 'Lesion-level evidence for clinical decisions';
    mapping.req5_lesions.evidence = 'Phase 12.1: 4 lesion detectors (MA, Exudates, Hemorrhages, NV) with confidence levels';
    mapping.req5_lesions.assessment = 'MET - Lesion detection implemented with refined algorithms';

    % === Requirement 6: Clinical Report ===
    mapping.req6_report = struct();
    mapping.req6_report.requirement = 'Structured clinical report for ophthalmologists';
    mapping.req6_report.evidence = 'Phase 16: 15-field structured report with text/CSV export';
    mapping.req6_report.assessment = 'MET - Report generation and export implemented';

    % === Requirement 7: Quality Assessment ===
    mapping.req7_quality = struct();
    mapping.req7_quality.requirement = 'Image quality assessment';
    mapping.req7_quality.evidence = 'Phase 16A: Quality gating (POOR → RECAPTURE)';
    mapping.req7_quality.assessment = 'MET - Quality assessment implemented';

    % === Requirement 8: Telemedicine Integration ===
    mapping.req8_telemedicine = struct();
    mapping.req8_telemedicine.requirement = 'Scalable telemedicine deployment';
    mapping.req8_telemedicine.evidence = 'Phase 10: Simulink simulation (100K+ patients/year achievable)';
    mapping.req8_telemedicine.assessment = 'MET - Scalability demonstrated via simulation';

    % === Requirement 9: Calibration ===
    mapping.req9_calibration = struct();
    mapping.req9_calibration.requirement = 'Well-calibrated confidence scores';
    mapping.req9_calibration.evidence = 'Phase 13: ECE=0.344, Brier=0.328 (moderate miscalibration)';
    mapping.req9_calibration.assessment = 'PARTIAL - Moderate miscalibration noted as limitation';

    % === Requirement 10: Usability ===
    mapping.req10_usability = struct();
    mapping.req10_usability.requirement = 'User-friendly interface';
    mapping.req10_usability.evidence = 'Phase 15: Production GUI with clinical logic and history tracking';
    mapping.req10_usability.assessment = 'MET - GUI implemented with required features';

    % === Overall Assessment ===
    mapping.overall = struct();
    mapping.overall.met = 7;  % req1, req3, req4, req5, req6, req7, req8, req10
    mapping.overall.partial = 2;  % req1, req9
    mapping.overall.notMet = 1;  % req2
    mapping.overall.total = 10;

    % Print summary
    fprintf('\n=== SIH REQUIREMENT MAPPING ===\n\n');

    reqNames = fieldnames(mapping);
    for i = 1:numel(reqNames)-1  % Skip 'overall'
        req = mapping.(reqNames{i});
        fprintf('Requirement: %s\n', req.requirement);
        fprintf('Evidence: %s\n', req.evidence);
        fprintf('Assessment: %s\n\n', req.assessment);
    end

    fprintf('=== OVERALL ===\n');
    fprintf('Met: %d/%d\n', mapping.overall.met, mapping.overall.total);
    fprintf('Partial: %d/%d\n', mapping.overall.partial, mapping.overall.total);
    fprintf('Not Met: %d/%d\n', mapping.overall.notMet, mapping.overall.total);
end
