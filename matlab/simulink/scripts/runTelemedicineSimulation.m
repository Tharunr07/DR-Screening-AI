function runTelemedicineSimulation()
% runTelemedicineSimulation  Run DR telemedicine capacity simulation
%
%   Modeled as a discrete-event simulation using queue theory.
%   No SimEvents required - pure MATLAB implementation.
%
%   Simulates:
%       Patient arrival → Image acquisition → Transmission → AI screening
%       → (if referable) Doctor review → Completion

    cfg = telemedicineConfig();
    fprintf('=== DR TELEMEDICINE SIMULATION ===\n\n');

    % Benchmark parameters
    fprintf('Configuration:\n');
    fprintf('  Annual patients: %d\n', cfg.annualPatients);
    fprintf('  Daily patients: %.0f\n', cfg.dailyPatients);
    fprintf('  Images/patient: %d\n', cfg.imagesPerPatient);
    fprintf('  Image size: %.1f MB\n', cfg.imageSizeMB);
    fprintf('  AI inference: %.3f sec (median)\n', cfg.aiInferenceSec);
    fprintf('  Referable rate: %.1f%%\n', cfg.referableRate * 100);
    fprintf('  Sensitivity: %.1f%%\n', cfg.sensitivity * 100);
    fprintf('  Specificity: %.1f%%\n', cfg.specificity * 100);
    fprintf('\n');

    % Run scenarios
    results = struct();
    for s = 1:numel(cfg.scenarios)
        scenario = cfg.scenarios(s);
        fprintf('--- Scenario %d: %s ---\n', s, scenario.name);
        fprintf('  Stations: %d | AI workers: %d | Ophthalmologists: %d\n', ...
            scenario.acquisitionStations, scenario.aiWorkers, scenario.ophthalmologists);

        result = simulateScenario(cfg, scenario);
        results.(scenario.name) = result;

        fprintf('  Throughput: %.0f patients/day\n', result.throughputPerDay);
        fprintf('  AI utilization: %.1f%%\n', result.aiUtilization * 100);
        fprintf('  Doctor utilization: %.1f%%\n', result.doctorUtilization * 100);
        fprintf('  Mean wait time: %.1f min\n', result.meanWaitTimeMin);
        fprintf('  Max queue: %.0f patients\n', result.maxQueueSize);
        fprintf('  Annual capacity: %.0f patients/year\n', result.annualCapacity);
        fprintf('  Meets target: %s\n', string(result.meetsTarget));
        fprintf('\n');
    end

    % Bandwidth analysis
    fprintf('--- Bandwidth Analysis ---\n');
    bandwidthResults = analyzeBandwidth(cfg, cfg.scenarios(2));
    for b = 1:numel(cfg.bandwidthScenarios)
        fprintf('  %d Mbps: transmission=%.2f sec, total=%.2f sec\n', ...
            cfg.bandwidthScenarios(b), ...
            bandwidthResults(b).transmissionTime, ...
            bandwidthResults(b).totalTime);
    end
    fprintf('\n');

    % Save results
    save(fullfile(cfg.paths.resultsDir, 'simulation_results.mat'), 'results', 'bandwidthResults', 'cfg');
    fprintf('Results saved to: %s\n', fullfile(cfg.paths.resultsDir, 'simulation_results.mat'));

    % Generate figures
    generateSimulationFigures(cfg, results, bandwidthResults);

    fprintf('\n=== SIMULATION COMPLETE ===\n');
end

function result = simulateScenario(cfg, scenario)
    % Discrete-event simulation of telemedicine pipeline

    numPatients = round(cfg.dailyPatients);
    numImages = numPatients * cfg.imagesPerPatient;

    % Transmission time per image
    transmissionTime = cfg.transmissionTimeSec;

    % AI processing
    aiTime = cfg.aiTotalSec;
    numAIWorkers = scenario.aiWorkers;

    % Doctor review (only referable cases)
    doctorTime = cfg.ophthalmologistReviewTimeSec;
    numDoctors = scenario.ophthalmologists;

    % Simulate queue dynamics
    % Patient arrival: uniform over 8-hour day
    daySeconds = 8 * 3600;
    arrivalTimes = sort(rand(1, numPatients) * daySeconds);

    % Acquisition queue
    acqStations = scenario.acquisitionStations;
    acqFinishTimes = zeros(1, acqStations);

    % AI queue
    aiFinishTimes = zeros(1, numAIWorkers);

    % Doctor queue
    docFinishTimes = zeros(1, numDoctors);

    % Statistics
    acquisitionWaitTimes = zeros(1, numPatients);
    aiWaitTimes = zeros(1, numPatients);
    doctorWaitTimes = zeros(numPatients, 1);
    totalWaitTimes = zeros(1, numPatients);
    isReferable = false(1, numPatients);

    for p = 1:numPatients
        arrival = arrivalTimes(p);

        % Acquisition: find earliest available station
        [earliestTime, earliestStation] = min(acqFinishTimes);
        acqStart = max(arrival, earliestTime);
        acqFinish = acqStart + cfg.acquisitionTimeSec;
        acqFinishTimes(earliestStation) = acqFinish;
        acquisitionWaitTimes(p) = acqStart - arrival;

        % Transmission
        transmitFinish = acqFinish + transmissionTime;

        % AI screening
        [earliestAITime, earliestAI] = min(aiFinishTimes);
        aiStart = max(transmitFinish, earliestAITime);
        aiFinish = aiStart + aiTime;
        aiFinishTimes(earliestAI) = aiFinish;
        aiWaitTimes(p) = aiStart - transmitFinish;

        % Determine if referable (based on true rate)
        isReferable(p) = rand() < cfg.referableRate;

        if isReferable(p)
            % Doctor review
            [earliestDocTime, earliestDoc] = min(docFinishTimes);
            docStart = max(aiFinish, earliestDocTime);
            docFinish = docStart + doctorTime;
            docFinishTimes(earliestDoc) = docFinish;
            doctorWaitTimes(p) = docStart - aiFinish;
        else
            doctorWaitTimes(p) = 0;
        end

        totalWaitTimes(p) = acquisitionWaitTimes(p) + aiWaitTimes(p) + doctorWaitTimes(p);
    end

    % Compute statistics
    result.throughputPerDay = numPatients;
    result.throughputPerHour = numPatients / (daySeconds / 3600);
    result.annualCapacity = result.throughputPerDay * cfg.workingDaysPerYear;

    % Utilization
    totalAIWork = numImages * aiTime;
    totalAIavailable = daySeconds * numAIWorkers;
    result.aiUtilization = totalAIWork / totalAIavailable;

    totalDocWork = sum(isReferable) * doctorTime;
    totalDocAvailable = daySeconds * numDoctors;
    result.doctorUtilization = totalDocWork / totalDocAvailable;

    % Wait times
    result.meanWaitTimeMin = mean(totalWaitTimes) / 60;
    result.maxWaitTimeMin = max(totalWaitTimes) / 60;
    result.p95WaitTimeMin = prctile(totalWaitTimes, 95) / 60;

    % Queue sizes
    result.maxQueueSize = max(acqFinishTimes) - min(acqFinishTimes);
    result.meanQueueSize = mean(totalWaitTimes) / cfg.acquisitionTimeSec;

    % Target check
    result.meetsTarget = result.meanWaitTimeMin <= (cfg.maxWaitTimeSec / 60);
    result.meetsAnnualTarget = result.annualCapacity >= cfg.annualPatients;

    % Referable statistics
    result.numReferable = sum(isReferable);
    result.referableRate = mean(isReferable);

    % Detailed wait breakdown
    result.acquisitionWaitMin = mean(acquisitionWaitTimes) / 60;
    result.aiWaitMin = mean(aiWaitTimes) / 60;
    result.doctorWaitMin = mean(doctorWaitTimes) / 60;
end

function results = analyzeBandwidth(cfg, scenario)
    results = struct();
    for b = 1:numel(cfg.bandwidthScenarios)
        bw = cfg.bandwidthScenarios(b);
        transmissionTime = (cfg.imageSizeBits * cfg.networkOverhead) / (bw * 1e6);
        totalTime = cfg.acquisitionTimeSec + transmissionTime + cfg.aiTotalSec;

        results(b).bandwidthMbps = bw;
        results(b).transmissionTime = transmissionTime;
        results(b).totalTime = totalTime;
        results(b).throughputPerHour = 3600 / totalTime;
    end
end

function generateSimulationFigures(cfg, results, bandwidthResults)
    figDir = cfg.paths.figDir;

    % Figure 1: Scenario comparison
    fig1 = figure('Name', 'Scenario Comparison', 'NumberTitle', 'off', ...
        'Position', [100, 100, 1000, 400]);

    scenarioNames = fieldnames(results);
    nScenarios = numel(scenarioNames);

    throughputVals = zeros(1, nScenarios);
    waitVals = zeros(1, nScenarios);
    aiUtil = zeros(1, nScenarios);
    docUtil = zeros(1, nScenarios);

    for i = 1:nScenarios
        r = results.(scenarioNames{i});
        throughputVals(i) = r.throughputPerDay;
        waitVals(i) = r.meanWaitTimeMin;
        aiUtil(i) = r.aiUtilization * 100;
        docUtil(i) = r.doctorUtilization * 100;
    end

    subplot(2,2,1);
    bar(throughputVals);
    set(gca, 'XTickLabel', scenarioNames);
    ylabel('Patients/Day');
    title('Daily Throughput');
    grid on;

    subplot(2,2,2);
    bar(waitVals);
    set(gca, 'XTickLabel', scenarioNames);
    ylabel('Minutes');
    title('Mean Wait Time');
    yline(cfg.maxWaitTimeSec/60, '--r', 'Target');
    grid on;

    subplot(2,2,3);
    bar(aiUtil);
    set(gca, 'XTickLabel', scenarioNames);
    ylabel('Utilization (%)');
    title('AI Worker Utilization');
    grid on;

    subplot(2,2,4);
    bar(docUtil);
    set(gca, 'XTickLabel', scenarioNames);
    ylabel('Utilization (%)');
    title('Doctor Utilization');
    grid on;

    sgtitle('Telemedicine Simulation: Scenario Comparison', 'FontSize', 13, 'FontWeight', 'bold');
    saveas(fig1, fullfile(figDir, 'fig6_scenario_comparison.png'));

    % Figure 2: Bandwidth impact
    fig2 = figure('Name', 'Bandwidth Impact', 'NumberTitle', 'off', ...
        'Position', [100, 100, 600, 400]);

    bws = [bandwidthResults.bandwidthMbps];
    transTimes = [bandwidthResults.transmissionTime];
    totalTimes = [bandwidthResults.totalTime];

    plot(bws, transTimes, 'bo-', 'LineWidth', 2, 'MarkerSize', 8);
    hold on;
    plot(bws, totalTimes, 'rs-', 'LineWidth', 2, 'MarkerSize', 8);
    xlabel('Bandwidth (Mbps)');
    ylabel('Time (seconds)');
    title('Transmission Time vs Bandwidth');
    legend('Transmission', 'Total (Acquire+Transmit+AI)', 'Location', 'northeast');
    grid on;

    saveas(fig2, fullfile(figDir, 'fig7_bandwidth_impact.png'));

    fprintf('Figures saved to: %s\n', figDir);
end
