%% =========================================================================
%  main.m  —  MASTER PIPELINE SCRIPT
%
%  PURPOSE:
%    Runs the full simulation and economic analysis pipeline in sequence.
%    Calls all four pipeline scripts and the Simulink docking station model.
%    Base case only — sensitivity sweeps are handled by sensitivity_analysis.m
%
%  PIPELINE ORDER:
%    Step 1 — load_irradiance_main.m   loads 2024 irradiance data
%    Step 2 — pv_modelmain.m           sizes PV system, computes annual yield
%    Step 3 — arrival_model_main.m     computes Poisson arrival rates
%    Step 4 — sim() loop               runs docking_station_model.slx x3
%    Step 5 — economic_model_main.m    computes all financial metrics
%
%  REQUIREMENTS:
%    docking_station_model.slx must be on the MATLAB path
%    All six irradiance CSVs must be in the working directory
%    All three operator CSVs must be in the working directory
%    MATLAB SimEvents toolbox required for Simulink queueing model
%    MATLAB Financial Toolbox required for irr() in economic_model_main.m
%
%  OUTPUT:
%    All results printed to console via Block 11 summary table
%    All workspace variables available for sensitivity_analysis.m
% =========================================================================

clear; clc; close all;

fprintf('=== PIPELINE START ===\n\n');

%% =========================================================================
%  STEP 1 — Load irradiance data
%  Outputs: kigali/lagos/kampala_irradiance [8784x1], kigali/lagos/kampala_temp [8784x1]
% =========================================================================

fprintf('Step 1: Loading irradiance data...\n');
run('load_irradiance_main.m');
fprintf('Step 1 complete.\n\n');

%% =========================================================================
%  STEP 2 — PV sizing
%  Inputs:  irradiance and temp vectors from Step 1
%  Outputs: panels_*, Ed_*, amp/spiro/zembo_pv_annual_yield_kwh
% =========================================================================

fprintf('Step 2: Sizing PV systems...\n');
run('pv_model_main.m');
fprintf('Step 2 complete.\n\n');

%% =========================================================================
%  STEP 3 — Arrival model
%  Outputs: mean_iat_*, swap_time_*, n_docking_*, n_batteries_*, capacity_*
%           lambda_*, arrivals_* (for validation/figures)
% =========================================================================

fprintf('Step 3: Computing arrival model...\n');
run('arrival_model_main.m');
fprintf('Step 3 complete.\n\n');

%% =========================================================================
%  STEP 4 — Simulink docking station simulation
%
%  Runs docking_station_model.slx once per city.
%  Before each run, generic workspace variables are overwritten with
%  city-specific values from arrival_model_main.m.
%  Simulink reads: mean_iat, swap_time, n_docking, n_batteries, capacity
%
%  sim_duration: 86400 seconds = 24 hours
%
%  Results stored in struct array:
%    results(1) = Kigali (Ampersand)
%    results(2) = Lagos  (Spiro)
%    results(3) = Kampala (Zembo)
%
%  swaps_completed is the Simulink output variable name — update this
%  to match the actual output port name in docking_station_model.slx
% =========================================================================

fprintf('Step 4: Running Simulink docking station model...\n');

sim_duration = '86400';   % 24 hours in seconds

city_names  = {'Kigali (Ampersand)', 'Lagos (Spiro)', 'Kampala (Zembo)'};
mean_iats   = {mean_iat_kigali,    mean_iat_lagos,    mean_iat_kampala};
swap_times  = {swap_time_kigali,   swap_time_lagos,   swap_time_kampala};
n_dockings  = {n_docking_kigali,   n_docking_lagos,   n_docking_kampala};
n_bats      = {n_batteries_kigali, n_batteries_lagos, n_batteries_kampala};
capacities  = {capacity_kigali,    capacity_lagos,    capacity_kampala};

for i = 1:3
    fprintf('  Running Simulink for %s...\n', city_names{i});

    % Overwrite generic workspace variables — Simulink reads these by name
    mean_iat    = mean_iats{i};
    swap_time   = swap_times{i};
    n_docking   = n_dockings{i};
    n_batteries = n_bats{i};
    capacity    = capacities{i};
    % Set mean IAT for current city as scalar for Simulink dialog
    mean_iat_scalar = mean_iats{i}(1);   % hour 1 rate for initialisation
    % Run Simulink model
    out = sim('docking_station_model', 'StopTime', sim_duration);

    % Store results
    % NOTE: update 'swaps_completed' to match the actual Simulink output
    % variable name from the To Workspace block in docking_station_model.slx
    results(i).city             = city_names{i};
    results(i).out              = out;
    results(i).swaps_completed = out.swaps_completed(end);
    results(i).mean_iat         = mean_iat;
    results(i).swap_time        = swap_time;
    results(i).n_docking        = n_docking;
    results(i).n_batteries      = n_batteries;
    results(i).queue_length = out.queue_length;
    results(i).wait_time     = out.wait_time;

    fprintf('  %s: %.0f swaps completed\n', city_names{i}, results(i).swaps_completed);
end

% Extract Simulink swap outputs for economic model
% These replace the CSV values in economic_model_main.m Block 2
% once Simulink results are validated
amp_sim_swaps_per_day   = results(1).swaps_completed;
spiro_sim_swaps_per_day = results(2).swaps_completed;
zembo_sim_swaps_per_day = results(3).swaps_completed;

amp_queue_loss_fraction   = (amp_swaps_per_day - amp_sim_swaps) / amp_swaps_per_day;
spiro_queue_loss_fraction = (spiro_swaps_per_day - spiro_sim_swaps) / spiro_swaps_per_day;
zembo_queue_loss_fraction = (zembo_swaps_per_day - zembo_sim_swaps) / zembo_swaps_per_day;

fprintf('Step 4 complete.\n\n');

%% =========================================================================
%  STEP 5 — Economic analysis
%  Inputs:  amp/spiro/zembo_pv_annual_yield_kwh from Step 2
%           amp/spiro/zembo_sim_swaps_per_day from Step 4 (when Simulink ready)
%           all operator parameters from CSV
%  Outputs: all financial metrics to workspace and summary table
% =========================================================================

fprintf('Step 5: Running economic analysis...\n');
run('economic_model_main.m');
fprintf('Step 5 complete.\n\n');

fprintf('=== PIPELINE COMPLETE ===\n');
fprintf('All results in workspace. Run sensitivity_analysis.m for sweeps.\n');