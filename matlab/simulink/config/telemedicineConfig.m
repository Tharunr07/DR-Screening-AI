function cfg = telemedicineConfig()
% telemedicineConfig  Configuration for DR telemedicine simulation
%
%   cfg = telemedicineConfig()
%
%   All parameters are evidence-based:
%       - AI timing from Phase 9 benchmark
%       - Image size from dataset statistics
%       - Referable rate from test set

    % === Patient Population ===
    cfg.annualPatients = 100000;
    cfg.workingDaysPerYear = 260;           % 5 days/week * 52 weeks
    cfg.dailyPatients = cfg.annualPatients / cfg.workingDaysPerYear;
    cfg.imagesPerPatient = 2;              % Both eyes

    % === Image Acquisition ===
    cfg.imageWidth = 2048;                 % From dataset
    cfg.imageHeight = 1536;
    cfg.imageChannels = 3;
    cfg.imageBits = 24;                    % 8 bits * 3 channels
    cfg.imageSizeMB = (cfg.imageWidth * cfg.imageHeight * 3) / (1024^2);  % ~8.8 MB
    cfg.imageSizeBits = cfg.imageSizeMB * 8 * 1024^2;
    cfg.acquisitionTimeSec = 30;           % Patient positioning + capture

    % === Network / Transmission ===
    cfg.bandwidthMbps = 10;                % Configurable: 1, 5, 10, 50, 100
    cfg.networkOverhead = 1.2;             % 20% protocol overhead
    cfg.transmissionTimeSec = (cfg.imageSizeBits * cfg.networkOverhead) / (cfg.bandwidthMbps * 1e6);

    % === AI Screening (measured from Phase 9) ===
    cfg.aiPreprocessingSec = 0.05;         % Resize + normalize
    cfg.aiInferenceSec = 0.026;            % Median from benchmark (0.026 sec)
    cfg.aiInferenceMeanSec = 0.153;        % Mean (for comparison)
    cfg.aiTotalSec = cfg.aiPreprocessingSec + cfg.aiInferenceSec;
    cfg.aiThroughputPerHour = 3600 / cfg.aiTotalSec;

    % === Clinical Decision ===
    cfg.referableRate = 0.433;             % From test set: 265/612
    cfg.sensitivity = 0.977;               % Phase 8 result
    cfg.specificity = 0.854;               % Phase 8 result

    % === Ophthalmologist Review ===
    cfg.ophthalmologistReviewTimeSec = 120;  % 2 minutes per case
    cfg.ophthalmologistCapacity = 30;       % cases/hour
    cfg.ophthalmologistDailyCapacity = cfg.ophthalmologistCapacity * 8;  % 8-hour day

    % === Queue Parameters ===
    cfg.maxWaitTimeSec = 3600;             % 1 hour max acceptable wait
    cfg.queueCapacity = 1000;              % Max queue size

    % === Resource Configurations ===
    cfg.scenarios = struct();

    % Scenario A: Minimal
    cfg.scenarios(1).name = 'Minimal';
    cfg.scenarios(1).acquisitionStations = 1;
    cfg.scenarios(1).aiWorkers = 1;
    cfg.scenarios(1).ophthalmologists = 1;

    % Scenario B: Moderate
    cfg.scenarios(2).name = 'Moderate';
    cfg.scenarios(2).acquisitionStations = 2;
    cfg.scenarios(2).aiWorkers = 1;
    cfg.scenarios(2).ophthalmologists = 2;

    % Scenario C: Scaled
    cfg.scenarios(3).name = 'Scaled';
    cfg.scenarios(3).acquisitionStations = 4;
    cfg.scenarios(3).aiWorkers = 2;
    cfg.scenarios(3).ophthalmologists = 3;

    % Scenario D: High capacity
    cfg.scenarios(4).name = 'HighCapacity';
    cfg.scenarios(4).acquisitionStations = 6;
    cfg.scenarios(4).aiWorkers = 2;
    cfg.scenarios(4).ophthalmologists = 4;

    % === Bandwidth Scenarios ===
    cfg.bandwidthScenarios = [1, 5, 10, 50, 100];  % Mbps

    % === Output ===
    cfg.paths.projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    cfg.paths.resultsDir = fullfile(cfg.paths.projectRoot, 'results', 'simulink');
    cfg.paths.figDir = fullfile(cfg.paths.resultsDir, 'figures');
    cfg.paths.throughputDir = fullfile(cfg.paths.resultsDir, 'throughput');
    cfg.paths.optimDir = fullfile(cfg.paths.resultsDir, 'resource_optimization');

    % Ensure directories exist
    if ~exist(cfg.paths.figDir, 'dir'), mkdir(cfg.paths.figDir); end
    if ~exist(cfg.paths.throughputDir, 'dir'), mkdir(cfg.paths.throughputDir); end
    if ~exist(cfg.paths.optimDir, 'dir'), mkdir(cfg.paths.optimDir); end
end
