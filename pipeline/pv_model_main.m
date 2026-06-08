%% =========================================================================
%  pv_model_main.m  —  PIPELINE VERSION
%
%  PURPOSE:
%    Sizes the PV system for each operator based on daily energy demand
%    and location-specific irradiance. Computes energy yield per panel,
%    number of panels required, and annual PV yield per operator.
%
%  PIPELINE POSITION:
%    Run AFTER  load_irradiance_main.m  (needs irradiance vectors in workspace)
%    Run BEFORE arrival_model_main.m, economic_model_main.m   (exports annual yield to LCOE block)
%    Called by main.m after load_irradiance_main.m
%
%  SENSITIVITY ANALYSIS:
%    Base case parameters come from CSV — single source of truth.
%    sensitivity_analysis.m overrides specific workspace variables
%    AFTER this script runs.
%    Example: discharge_fraction = 0.30; (test lower discharge)

%  INPUTS — from workspace (set by load_irradiance_main.m):
%    kigali_irradiance   [8784x1, W/m²]
%    lagos_irradiance    [8784x1, W/m²]
%    kampala_irradiance  [8784x1, W/m²]
%    kigali_temp         [8784x1, °C]    
%    lagos_temp          [8784x1, °C]   
%    kampala_temp        [8784x1, °C]  
%
%  OUTPUTS — written to workspace for economic_model_main.m:
%    panels_ampersand, panels_spiro, panels_zembo  [scalar, count]
%    Ed_ampersand, Ed_spiro, Ed_zembo              [scalar, kWh/day]
%    amp_pv_annual_yield_kwh                       [scalar, kWh/yr]
%    spiro_pv_annual_yield_kwh                     [scalar, kWh/yr]
%    zembo_pv_annual_yield_kwh                     [scalar, kWh/yr]
% =========================================================================

%% =========================================================================
%  BLOCK 1 — Load operator parameters from CSV
%
%  Swap counts and battery capacities read from CSV — single source of
%  truth consistent with arrival_model_main.m and economic_model_main.m.
%  Both scripts read from the same CSV files independently.
%
% =========================================================================

amp_data = readtable('ampersand_data.csv', 'TextType', 'string');
spi_data = readtable('spiro_data.csv',     'TextType', 'string');
zem_data = readtable('zembo_data.csv',     'TextType', 'string');

getparam = @(t, name) t.Value(t.Parameter == name);

% Daily swap totals [swaps/day/station]
swaps_ampersand = getparam(amp_data, "Swaps per day per station");   % 200
swaps_spiro     = getparam(spi_data, "Swaps per day per station");   % 180
swaps_zembo     = getparam(zem_data, "Swaps per day per station");   % 44

% Battery capacities [kWh] — read directly from CSV
capacity_ampersand = getparam(amp_data, "Battery capacity");          % 2.88 kWh
capacity_spiro     = getparam(spi_data, "Battery capacity");          % 3.40 kWh
capacity_zembo     = getparam(zem_data, "Battery capacity");          % 2.70 kWh

%% =========================================================================
%  BLOCK 2 — Panel constants and year parameters
%
%  eff_panel: panel conversion efficiency (fraction)
%    0.149 = 14.9% — Sharp NU-E245 monocrystalline [NgeJunRod:24 Table 1]
%
%  A_panel: single panel area [m²]
%    1.64 m² — Sharp NU-E245 datasheet [NgeJunRod:24 Table 1]
%
%  discharge_fraction: average fraction of battery capacity used per swap
%    0.36 — NgeJunRod:24 Table 1: average discharge on arrival = 36%
%    Energy per swap = battery_capacity x 0.36 [kWh]
%    sensitivity_analysis.m may override this value for sweep runs.
%
%  days_in_year: 366 for 2024 (leap year)
% =========================================================================

eff_panel          = 0.149;   % Sharp NU-E245 efficiency  [NgeJunRod:24 Table 1]
A_panel            = 1.64;    % Sharp NU-E245 area (m²)   [NgeJunRod:24 Table 1]
discharge_fraction = 0.36;    % avg discharge per swap     [NgeJunRod:24 Table 1]
days_in_year       = 366;     % 2024 leap year

%% =========================================================================
%  BLOCK 2b — Thermal efficiency correction
%
%  Panel output decreases with temperature above STC (25°C).
%  eta_T = 1 + temp_coeff x (T_mean - T_STC)
%
%  temp_coeff: -0.004 /°C (-0.4%/°C above 25°C)
%    Standard monocrystalline silicon value [NgeJunRod:24]
%  T_STC: 25°C — Standard Test Condition temperature
%  T_mean: annual mean ambient temperature from load_irradiance_main.m
%
%  Uses kigali_temp, lagos_temp, kampala_temp from workspace.
%  A correction factor below 1.0 means reduced output due to heat.
% =========================================================================

temp_coeff = -0.004;   % -0.4%/°C [NgeJunRod:24]
T_STC      = 25;       % Standard test condition temperature (°C)

T_kigali  = mean(kigali_temp);
T_lagos   = mean(lagos_temp);
T_kampala = mean(kampala_temp);

eta_T_kigali  = 1 + temp_coeff * (T_kigali  - T_STC);
eta_T_lagos   = 1 + temp_coeff * (T_lagos   - T_STC);
eta_T_kampala = 1 + temp_coeff * (T_kampala - T_STC);
eta_s_kigali  = 1 - 0.12;   % 0.88
eta_s_lagos   = 1 - 0.16;   % 0.84
eta_s_kampala = 1 - 0.12;

fprintf('Thermal correction factors:\n')
fprintf('  Kigali:  T_mean=%.1f°C  eta_T=%.4f\n', T_kigali,  eta_T_kigali)
fprintf('  Lagos:   T_mean=%.1f°C  eta_T=%.4f\n', T_lagos,   eta_T_lagos)
fprintf('  Kampala: T_mean=%.1f°C  eta_T=%.4f\n', T_kampala, eta_T_kampala)
%% =========================================================================
%  BLOCK 3 — Daily energy demand (Ed)
%
%  Ed [kWh/day] = swaps/day x battery_capacity x discharge_fraction
%
%  Total electrical energy the PV+ESS system must deliver each day
%  to fully recharge all batteries returned from riders.
% =========================================================================

Ed_ampersand = swaps_ampersand * capacity_ampersand * discharge_fraction;
Ed_spiro     = swaps_spiro     * capacity_spiro     * discharge_fraction;
Ed_zembo     = swaps_zembo     * capacity_zembo     * discharge_fraction;

%% =========================================================================
%  BLOCK 4 — Energy yield per panel per day (Ep)
%
%  Ep [kWh/panel/day] = sum(irradiance) x eff_panel x A_panel x eta_T / (1000 x days)
%
%  Irradiance vectors come from load_irradiance_main.m workspace.
%  sum(irradiance): total annual GHI in Wh/m² (sum of 8784 hourly W/m²)
%  / 1000:          converts Wh to kWh
%  / days_in_year:  converts annual total to daily average
%  eta_T:           thermal correction factor from Block 2b

% =========================================================================

Ep_ampersand = sum(kigali_irradiance)  * eff_panel * A_panel * eta_T_kigali*eta_s_kigali  /  days_in_year);
Ep_spiro     = sum(lagos_irradiance)   * eff_panel * A_panel * eta_T_lagos *eta_s_lagos  / ( days_in_year);
Ep_zembo     = sum(kampala_irradiance) * eff_panel * A_panel * eta_T_kampala*eta_s_kampala / (days_in_year);

%% =========================================================================
%  BLOCK 5 — Panels required
%
%  N = ceil(Ed / Ep)
%  ceil() rounds up — you cannot install a fractional panel.
%
%  Cross-check: N x 245 Wp/panel vs pv_system_rated_power in CSV (37000 Wp)
%  245 Wp is Sharp NU-E245 rated output [NgeJunRod:24 Table 1].
% =========================================================================

panels_ampersand = ceil(Ed_ampersand / Ep_ampersand);
panels_spiro     = ceil(Ed_spiro     / Ep_spiro);
panels_zembo     = ceil(Ed_zembo     / Ep_zembo);

%% =========================================================================
%  BLOCK 6 — Annual PV yield
%
%  annual_yield [kWh/yr] = N x Ep x days_in_year
%
%  Feeds into economic_model_main.m Block 9 LCOE calculation.
%  Replaces the static energy estimate previously used there.
% =========================================================================

amp_pv_annual_yield_kwh   = panels_ampersand * Ep_ampersand * days_in_year;
spiro_pv_annual_yield_kwh = panels_spiro     * Ep_spiro     * days_in_year;
zembo_pv_annual_yield_kwh = panels_zembo     * Ep_zembo     * days_in_year;

%% =========================================================================
%  BLOCK 7 — Console output
% =========================================================================

fprintf('\n=== pv_model_main.m complete ===\n')
fprintf('%-10s  Ed=%6.1f kWh/day  Ep=%.3f kWh/panel/day  N=%d panels  Yield=%.0f kWh/yr\n', ...
    'Ampersand', Ed_ampersand, Ep_ampersand, panels_ampersand, amp_pv_annual_yield_kwh)
fprintf('%-10s  Ed=%6.1f kWh/day  Ep=%.3f kWh/panel/day  N=%d panels  Yield=%.0f kWh/yr\n', ...
    'Spiro',     Ed_spiro,     Ep_spiro,     panels_spiro,     spiro_pv_annual_yield_kwh)
fprintf('%-10s  Ed=%6.1f kWh/day  Ep=%.3f kWh/panel/day  N=%d panels  Yield=%.0f kWh/yr\n', ...
    'Zembo',     Ed_zembo,     Ep_zembo,     panels_zembo,     zembo_pv_annual_yield_kwh)
fprintf('\nWorkspace ready:\n')
fprintf('  panels_ampersand, panels_spiro, panels_zembo        [scalar, count]\n')
fprintf('  Ed_ampersand, Ed_spiro, Ed_zembo                    [scalar, kWh/day]\n')
fprintf('  amp/spiro/zembo_pv_annual_yield_kwh                 [scalar, kWh/yr]\n')