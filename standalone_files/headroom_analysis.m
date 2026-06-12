%% =========================================================================
%  headroom_analysis.m  —  FULLY STANDALONE
%
%  PURPOSE:
%    Computes hourly surplus energy (headroom) available for third-party
%    supply at each operator location after swap demand is met.
%
%  OUTPUTS (workspace):
%    headroom_daily_kigali/lagos/kampala  [366x1, kWh/day]
%    headroom_hourly_kigali/lagos/kampala [1x24,  mean kWh/hr]
%    ess_soc_stat_kigali/lagos/kampala    [8784x1, kWh]
%    households_kigali/lagos/kampala      [366x1,  count]
%
%  FIGURES SAVED:
%    headroom_annual.pdf      daily surplus over full year
%    headroom_diurnal.pdf     mean surplus by hour of day
%    headroom_households.pdf  equivalent households supportable
%    headroom_ess_soc.pdf     stationary ESS SoC dry-season sample week
%    headroom_pv_sizing.pdf   headroom vs PV oversizing (Zembo rural case)
% =========================================================================

clc; clear; close all;
fprintf('\n=== headroom_analysis.m ===\n\n')

%% =========================================================================
%  BLOCK 1 — Load irradiance CSVs
%  NumHeaderLines=3 skips Renewables.ninja metadata rows.
%  GHI [W/m²] = (irradiance_direct + irradiance_diffuse) * 1000
%  Raw Renewables.ninja columns are in kW/m²
% =========================================================================

fprintf('Block 1: Loading irradiance data...\n')

kigali_table  = readtable('ampersand_kigali_irradiance_2024.csv',  'NumHeaderLines', 3);
lagos_table   = readtable('spiro_lagos_irradiance_2024.csv',       'NumHeaderLines', 3);
kampala_table = readtable('zembo_kampala_irradiance_2024.csv',     'NumHeaderLines', 3);

kigali_irradiance  = (kigali_table.irradiance_direct  + kigali_table.irradiance_diffuse)  * 1000;
lagos_irradiance   = (lagos_table.irradiance_direct   + lagos_table.irradiance_diffuse)   * 1000;
kampala_irradiance = (kampala_table.irradiance_direct + kampala_table.irradiance_diffuse) * 1000;

kigali_temp  = kigali_table.temperature;
lagos_temp   = lagos_table.temperature;
kampala_temp = kampala_table.temperature;

fprintf('  Kigali  GHI: %.0f kWh/m²  Mean temp: %.1f°C\n', sum(kigali_irradiance)/1000,  mean(kigali_temp))
fprintf('  Lagos   GHI: %.0f kWh/m²  Mean temp: %.1f°C\n', sum(lagos_irradiance)/1000,   mean(lagos_temp))
fprintf('  Kampala GHI: %.0f kWh/m²  Mean temp: %.1f°C\n', sum(kampala_irradiance)/1000, mean(kampala_temp))

%% =========================================================================
%  BLOCK 2 — Load operator parameters from CSV
%  getparam extracts numeric Value by matching Parameter name exactly
% =========================================================================

fprintf('\nBlock 2: Loading operator parameters...\n')

amp_data = readtable('ampersand_data.csv', 'TextType', 'string');
spi_data = readtable('spiro_data.csv',     'TextType', 'string');
zem_data = readtable('zembo_data.csv',     'TextType', 'string');

getparam = @(t, name) t.Value(t.Parameter == name);

swaps_kigali  = getparam(amp_data, "Swaps per day per station");  % 200
swaps_lagos   = getparam(spi_data, "Swaps per day per station");  % 180
swaps_kampala = getparam(zem_data, "Swaps per day per station");  % 44

capacity_kigali  = getparam(amp_data, "Battery capacity");  % 2.88 kWh
capacity_lagos   = getparam(spi_data, "Battery capacity");  % 3.40 kWh
capacity_kampala = getparam(zem_data, "Battery capacity");  % 2.70 kWh

pv_power_kigali  = getparam(amp_data, "PV system rated power");  % 37000 Wp
pv_power_lagos   = getparam(spi_data, "PV system rated power");  % 37000 Wp
pv_power_kampala = getparam(zem_data, "PV system rated power");  % 8085 Wp

inv_count_kigali  = getparam(amp_data, "Battery inventory count");  % 150
inv_count_lagos   = getparam(spi_data, "Battery inventory count");  % 135
inv_count_kampala = getparam(zem_data, "Battery inventory count");  % 33

swaps_per_bike_kigali  = getparam(amp_data, "Swaps per bike per day");  % 3.7 [AmpCle:25]
swaps_per_bike_lagos   = getparam(spi_data, "Swaps per bike per day");  % 2.0 [SpiSem:23]
swaps_per_bike_kampala = getparam(zem_data, "Swaps per bike per day");  % 2.0 [ZemAbt:26]

fprintf('  Ampersand: %g swaps/day  %.2f kWh/bat  %.0f Wp PV  %g inv\n', ...
    swaps_kigali,  capacity_kigali,  pv_power_kigali,  inv_count_kigali)
fprintf('  Spiro:     %g swaps/day  %.2f kWh/bat  %.0f Wp PV  %g inv\n', ...
    swaps_lagos,   capacity_lagos,   pv_power_lagos,   inv_count_lagos)
fprintf('  Zembo:     %g swaps/day  %.2f kWh/bat  %.0f Wp PV  %g inv\n', ...
    swaps_kampala, capacity_kampala, pv_power_kampala, inv_count_kampala)

%% =========================================================================
%  BLOCK 3 — PV sizing
%  Replicates pv_model_main.m logic exactly.
%  Panel constants from Ngendahayo et al. [NgeJunRod:24] Table 1.
%  Thermal correction: eta_T = 1 + gamma*(T_mean - T_STC)
%  Daily demand: Ed = swaps * capacity * discharge_fraction
%  Panel yield:  Ep = sum(GHI) * eff * A * eta_T / (1000 * days)
%  Panel count:  N  = ceil(Ed / Ep)
%  Hourly yield: pv_hourly = N * eff * A * eta_T .* GHI / 1000
%
%  System efficiency factor eta_s not applied — hourly irradiance
%  integration does not require the PSH-based eta_s correction.
%  Real-world output ~10-15% lower due to wiring, inverter and soiling
%  losses — acknowledged as a limitation in Section 4.2.
% =========================================================================

fprintf('\nBlock 3: Computing PV sizing and hourly yield...\n')

eff_panel          = 0.149;   % Sharp NU-E245 efficiency  [NgeJunRod:24 Table 1]
A_panel            = 1.64;    % m²                        [NgeJunRod:24 Table 1]
Wp_panel           = 245;     % rated Wp per panel         [NgeJunRod:24 Table 1]
days_in_year       = 366;     % 2024 leap year
discharge_fraction = 0.36;    % mean arrival SoC = 0.64   [NgeJunRod:24 Table 1]
temp_coeff         = -0.004;  % -0.4%/°C mono-Si          [NgeJunRod:24]
T_STC              = 25;      % standard test condition °C

eta_T_kigali  = 1 + temp_coeff * (mean(kigali_temp)  - T_STC);
eta_T_lagos   = 1 + temp_coeff * (mean(lagos_temp)   - T_STC);
eta_T_kampala = 1 + temp_coeff * (mean(kampala_temp) - T_STC);

Ed_kigali  = swaps_kigali  * capacity_kigali  * discharge_fraction;
Ed_lagos   = swaps_lagos   * capacity_lagos   * discharge_fraction;
Ed_kampala = swaps_kampala * capacity_kampala * discharge_fraction;

Ep_kigali  = sum(kigali_irradiance)  * eff_panel * A_panel * eta_T_kigali  / (1000 * days_in_year);
Ep_lagos   = sum(lagos_irradiance)   * eff_panel * A_panel * eta_T_lagos   / (1000 * days_in_year);
Ep_kampala = sum(kampala_irradiance) * eff_panel * A_panel * eta_T_kampala / (1000 * days_in_year);

panels_kigali  = ceil(Ed_kigali  / Ep_kigali);
panels_lagos   = ceil(Ed_lagos   / Ep_lagos);
panels_kampala = ceil(Ed_kampala / Ep_kampala);

fprintf('  Ampersand: Ed=%.1f kWh/day  Ep=%.3f kWh/panel/day  N=%d panels\n', Ed_kigali,  Ep_kigali,  panels_kigali)
fprintf('  Spiro:     Ed=%.1f kWh/day  Ep=%.3f kWh/panel/day  N=%d panels\n', Ed_lagos,   Ep_lagos,   panels_lagos)
fprintf('  Zembo:     Ed=%.1f kWh/day  Ep=%.3f kWh/panel/day  N=%d panels\n', Ed_kampala, Ep_kampala, panels_kampala)

pv_hourly_kigali  = panels_kigali  * eff_panel * A_panel * eta_T_kigali  .* kigali_irradiance  / 1000;
pv_hourly_lagos   = panels_lagos   * eff_panel * A_panel * eta_T_lagos   .* lagos_irradiance   / 1000;
pv_hourly_kampala = panels_kampala * eff_panel * A_panel * eta_T_kampala .* kampala_irradiance / 1000;

pv_hourly_kigali2  = panels_kigali  * 1.5* eff_panel * A_panel * eta_T_kigali  .* kigali_irradiance  / 1000;
pv_hourly_lagos2   = panels_lagos   * 1.5*eff_panel * A_panel * eta_T_lagos   .* lagos_irradiance   / 1000;
pv_hourly_kampala2 = panels_kampala * 1.5* eff_panel * A_panel * eta_T_kampala .* kampala_irradiance / 1000;


%% =========================================================================
%  BLOCK 4 — Arrival model
%  Replicates arrival_model_main.m to get lambda vectors [1x24]
%  Weight profiles from [SheGre:23] Fig 7 (Kigali) and stated assumptions
%  Normalised weights scaled by daily swap count give arrivals/hour
% =========================================================================

fprintf('\nBlock 4: Computing arrival rates...\n')

kigali_weights  = [1,0.25,0.25,0.25,0.25,0.25,0.25,2,4,7,6,6,6,8,8,9,10,9,4,6,6,7,4,1];
lagos_weights   = [1,0.25,0.25,0.25,0.25,0.25,0.25,3,5,7,6,5,5,7,8,10,10,9,4,5,5,6,3,1];
kampala_weights = [1,0.25,0.25,0.25,0.25,0.25,0.25,2,4,6,6,6,6,7,7,8,8,7,4,5,5,5,3,1];

lambda_kigali  = (kigali_weights  / sum(kigali_weights))  * swaps_kigali;
lambda_lagos   = (lagos_weights   / sum(lagos_weights))   * swaps_lagos;
lambda_kampala = (kampala_weights / sum(kampala_weights)) * swaps_kampala;

fprintf('  Kigali  peak lambda: %.1f arr/hr at hour %d\n', max(lambda_kigali),  find(lambda_kigali  == max(lambda_kigali)))
fprintf('  Lagos   peak lambda: %.1f arr/hr at hour %d\n', max(lambda_lagos),   find(lambda_lagos   == max(lambda_lagos)))
fprintf('  Kampala peak lambda: %.1f arr/hr at hour %d\n', max(lambda_kampala), find(lambda_kampala == max(lambda_kampala)))

%% =========================================================================
%  BLOCK 5 — Hourly swap demand [kWh/hr]
%  demand(h) = lambda(h) * energy_per_swap
%  Repeat 24-hour pattern across all 366 days -> [8784x1]
%  Deterministic expected demand — same pattern every day
% =========================================================================

fprintf('\nBlock 5: Computing hourly swap demand...\n')

E_per_swap_kigali  = capacity_kigali  * discharge_fraction;
E_per_swap_lagos   = capacity_lagos   * discharge_fraction;
E_per_swap_kampala = capacity_kampala * discharge_fraction;

demand_kigali  = repmat(lambda_kigali(:),  days_in_year, 1) * E_per_swap_kigali;
demand_lagos   = repmat(lambda_lagos(:),   days_in_year, 1) * E_per_swap_lagos;
demand_kampala = repmat(lambda_kampala(:), days_in_year, 1) * E_per_swap_kampala;

fprintf('  Ampersand annual demand: %.1f MWh/yr  (daily avg: %.1f kWh/day)\n', sum(demand_kigali)/1000,  sum(demand_kigali)/days_in_year)
fprintf('  Spiro     annual demand: %.1f MWh/yr  (daily avg: %.1f kWh/day)\n', sum(demand_lagos)/1000,   sum(demand_lagos)/days_in_year)
fprintf('  Zembo     annual demand: %.1f MWh/yr  (daily avg: %.1f kWh/day)\n', sum(demand_kampala)/1000, sum(demand_kampala)/days_in_year)

%% =========================================================================
%  BLOCK 6 — ESS sizing and dispatch
%
%  Stationary ESS [NgeJunRod:24]: 43 kWh LFP buffer — power buffer only,
%  not overnight energy store. Sized consistently with supervisor paper.
%  ESS sensitivity (43 kWh to 130 kWh) is evaluated in Chapter 8.
%
%  Shelf fraction: fraction of inventory on shelves at any moment.
%  Derived from swaps per bike per day — time not riding = time on shelf.
%  shelf_fraction = (24 - 24/swaps_per_bike) / 24
%
%  Total effective storage = stationary ESS + on-shelf inventory buffer.
%  Inventory buffer cannot be discharged for electrification — reserved
%  for swap operations. Not a separate cost item — paid for in CAPEX.
%
%  SoC_min = 20% of stationary ESS (8.6 kWh) — minimum operating reserve.
%  SoC_init = 50% of ESS_total — neutral starting condition.
% =========================================================================

fprintf('\nBlock 6: Computing ESS sizing and running dispatch...\n')

ESS_stationary = 43;                       
SoC_min        = 0.20 * ESS_stationary;    
DoD            = 0.80;                     % LFP [NgeJunRod:24]

shelf_fraction_kigali  = (24 - 24/swaps_per_bike_kigali)  / 24;  % 0.73
shelf_fraction_lagos   = (24 - 24/swaps_per_bike_lagos)   / 24;  % 0.50
shelf_fraction_kampala = (24 - 24/swaps_per_bike_kampala) / 24;  % 0.50

ESS_total_kigali  = ESS_stationary + (inv_count_kigali  * capacity_kigali  * DoD * shelf_fraction_kigali);
ESS_total_lagos   = ESS_stationary + (inv_count_lagos   * capacity_lagos   * DoD * shelf_fraction_lagos);
ESS_total_kampala = ESS_stationary + (inv_count_kampala * capacity_kampala * DoD * shelf_fraction_kampala);

SoC_init_kigali  = 0.50 * ESS_total_kigali;
SoC_init_lagos   = 0.50 * ESS_total_lagos;
SoC_init_kampala = 0.50 * ESS_total_kampala;

fprintf('  Shelf fractions:  Kigali=%.2f  Lagos=%.2f  Kampala=%.2f\n', ...
    shelf_fraction_kigali, shelf_fraction_lagos, shelf_fraction_kampala)
fprintf('  ESS_total:  Kigali=%.1f kWh  Lagos=%.1f kWh  Kampala=%.1f kWh\n', ...
    ESS_total_kigali, ESS_total_lagos, ESS_total_kampala)

[headroom_kigali,  ess_soc_kigali,  ~] = run_dispatch(...
    pv_hourly_kigali,  demand_kigali,  ESS_total_kigali,  SoC_min, SoC_init_kigali);
[headroom_lagos,   ess_soc_lagos,   ~] = run_dispatch(...
    pv_hourly_lagos,   demand_lagos,   ESS_total_lagos,   SoC_min, SoC_init_lagos);
[headroom_kampala, ess_soc_kampala, ~] = run_dispatch(...
    pv_hourly_kampala, demand_kampala, ESS_total_kampala, SoC_min, SoC_init_kampala);

[headroom_kigali2,  ess_soc_kigali,  ~] = run_dispatch(...
    pv_hourly_kigali2,  demand_kigali,  ESS_total_kigali,  SoC_min, SoC_init_kigali);
[headroom_lagos2,   ess_soc_lagos,   ~] = run_dispatch(...
    pv_hourly_lagos2,   demand_lagos,   ESS_total_lagos,   SoC_min, SoC_init_lagos);
[headroom_kampala2, ess_soc_kampala, ~] = run_dispatch(...
    pv_hourly_kampala2, demand_kampala, ESS_total_kampala, SoC_min, SoC_init_kampala);

fprintf('  Ampersand annual headroom: %.1f MWh/yr\n', sum(headroom_kigali)/1000)
fprintf('  Spiro     annual headroom: %.1f MWh/yr\n', sum(headroom_lagos)/1000)
fprintf('  Zembo     annual headroom: %.1f MWh/yr\n', sum(headroom_kampala)/1000)

ess_soc_stat_kigali  = ess_soc_kigali  * (ESS_stationary / ESS_total_kigali);
ess_soc_stat_lagos   = ess_soc_lagos   * (ESS_stationary / ESS_total_lagos);
ess_soc_stat_kampala = ess_soc_kampala * (ESS_stationary / ESS_total_kampala);

%% =========================================================================
%  BLOCK 7 — Aggregate to daily totals and mean diurnal profile
%  Reshape [8784x1] -> [24 x 366]: columns=days, rows=hours
%  sum(mat,1) -> [366x1] daily totals
%  mean(mat,2) -> [24x1] mean by hour of day
%  households = daily_headroom / 1.5 kWh [ESMAP2015]
% =========================================================================

fprintf('\nBlock 7: Aggregating profiles...\n')

household_daily_kwh = 1.5;   % IEA Tier 2 [ESMAP2015]

mat_kigali  = reshape(headroom_kigali,  24, days_in_year);
mat_lagos   = reshape(headroom_lagos,   24, days_in_year);
mat_kampala = reshape(headroom_kampala, 24, days_in_year);

mat_kigali2  = reshape(headroom_kigali2,  24, days_in_year);
mat_lagos2   = reshape(headroom_lagos2,   24, days_in_year);
mat_kampala2 = reshape(headroom_kampala2, 24, days_in_year);

headroom_daily_kigali  = sum(mat_kigali,  1)';
headroom_daily_lagos   = sum(mat_lagos,   1)';
headroom_daily_kampala = sum(mat_kampala, 1)';

headroom_daily_kigali2  = sum(mat_kigali2,  1)';
headroom_daily_lagos2   = sum(mat_lagos2,   1)';
headroom_daily_kampala2 = sum(mat_kampala2, 1)';

headroom_hourly_kigali  = mean(mat_kigali,  2)';
headroom_hourly_lagos   = mean(mat_lagos,   2)';
headroom_hourly_kampala = mean(mat_kampala, 2)';

headroom_hourly_kigali2  = mean(mat_kigali2,  2)';
headroom_hourly_lagos2   = mean(mat_lagos2,   2)';
headroom_hourly_kampala2 = mean(mat_kampala2, 2)';

households_kigali  = headroom_daily_kigali  / household_daily_kwh;
households_lagos   = headroom_daily_lagos   / household_daily_kwh;
households_kampala = headroom_daily_kampala / household_daily_kwh;

households_kigali2  = headroom_daily_kigali2  / household_daily_kwh;
households_lagos2   = headroom_daily_lagos2   / household_daily_kwh;
households_kampala2 = headroom_daily_kampala2 / household_daily_kwh;


%% =========================================================================
%  BLOCK 8 — PV oversizing sensitivity (Zembo rural case)
%  Tests headroom at 1x, 1.5x, 2x, 3x base panel count.
%  Zembo is the primary rural deployment reference case.
%  Uses stationary ESS only (43 kWh) — greenfield rural station scenario
%  before full inventory is established. Upper bound on headroom.
% =========================================================================

fprintf('\nBlock 8: PV oversizing sensitivity (Zembo)...\n')

pv_multipliers   = [1.0, 1.5, 2.0, 3.0];
headroom_means   = zeros(size(pv_multipliers));
households_means = zeros(size(pv_multipliers));

for k = 1:length(pv_multipliers)
    pv_scaled = pv_hourly_kampala * pv_multipliers(k);
    [hroom, ~, ~] = run_dispatch(pv_scaled, demand_kampala, ...
        ESS_stationary, SoC_min, 0.50 * ESS_stationary);
    daily             = sum(reshape(hroom, 24, days_in_year), 1)';
    headroom_means(k)   = mean(daily);
    households_means(k) = mean(daily) / household_daily_kwh;
end

fprintf('  PV mult  Mean daily headroom  Mean households\n')
for k = 1:length(pv_multipliers)
    fprintf('   x%.1f       %6.1f kWh/day         %.0f\n', ...
        pv_multipliers(k), headroom_means(k), households_means(k))
end

%% =========================================================================
%  BLOCK 9 — Third-party supply potential breakdown (Zembo)
%  Translates mean daily headroom into multiple community load equivalents
%  at base case and PV oversizing scenarios.
% =========================================================================

fprintf('\nBlock 9: Third-party supply potential breakdown...\n')

load_names = {'IEA Tier 2 households (1.5 kWh/day)   ', ...
              'Smartphone charges    (0.015 kWh/phone)', ...
              'Health clinic         (1.0 kWh/day)    ', ...
              'Electric cooking      (0.5 kWh/meal)   ', ...
              'LED streetlights 10W  (0.08 kWh/light) ', ...
              'Community school      (2.0 kWh/day)    '};
load_kwh   = [1.50, 0.015, 1.00, 0.50, 0.08, 2.00];

base_kwh = mean(headroom_daily_kampala);
pv15_kwh = headroom_means(2);
pv20_kwh = headroom_means(3);

fprintf('\n%-44s %10s %10s %10s\n', 'Load type', 'Base 1x', '1.5x PV', '2x PV')
fprintf('%s\n', repmat('-', 1, 78))
for i = 1:length(load_names)
    fprintf('%s %10.0f %10.0f %10.0f\n', load_names{i}, ...
        floor(base_kwh  / load_kwh(i)), ...
        floor(pv15_kwh  / load_kwh(i)), ...
        floor(pv20_kwh  / load_kwh(i)))
end

%% =========================================================================
%  BLOCK 10 — Summary table
% =========================================================================

fprintf('\n========= HEADROOM ANALYSIS SUMMARY =========\n')
fprintf('%-14s %15s %15s %15s\n', 'Metric', 'Ampersand', 'Spiro', 'Zembo')
fprintf('%s\n', repmat('-', 1, 62))
fprintf('%-14s %15.1f %15.1f %15.1f\n', 'Annual (MWh)', ...
    sum(headroom_kigali)/1000, sum(headroom_lagos)/1000, sum(headroom_kampala)/1000)
fprintf('%-14s %15.1f %15.1f %15.1f\n', 'Mean day (kWh)', ...
    mean(headroom_daily_kigali), mean(headroom_daily_lagos), mean(headroom_daily_kampala))
fprintf('%-14s %15.0f %15.0f %15.0f\n', 'Mean HH', ...
    mean(households_kigali), mean(households_lagos), mean(households_kampala))
fprintf('%-14s %15.1f %15.1f %15.1f\n', 'Min day (kWh)', ...
    min(headroom_daily_kigali), min(headroom_daily_lagos), min(headroom_daily_kampala))
fprintf('%-14s %15.1f %15.1f %15.1f\n', 'ESS_total (kWh)', ...
    ESS_total_kigali, ESS_total_lagos, ESS_total_kampala)

%% =========================================================================
%  BLOCK 11 — Figures
% =========================================================================

fprintf('\nBlock 11: Generating figures...\n')

colors = [0.20 0.47 0.75;   % blue   — Ampersand / Kigali
          0.90 0.45 0.18;   % orange — Spiro     / Lagos
          0.27 0.65 0.38];  % green  — Zembo     / Kampala

day_axis     = (1:days_in_year)';
month_starts = [1,32,61,92,122,153,183,214,245,275,306,336];
month_labels = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
hours        = 1:24;

% ---- Figure 1: Annual daily headroom ----
fig1 = figure('Position',[50 50 1100 400],'Color','white');
hold on
plot(day_axis, headroom_daily_kigali,  'Color',[colors(1,:) 0.18],'LineWidth',0.5)
plot(day_axis, headroom_daily_lagos,   'Color',[colors(2,:) 0.18],'LineWidth',0.5)
plot(day_axis, headroom_daily_kampala, 'Color',[colors(3,:) 0.18],'LineWidth',0.5)
p1 = plot(day_axis, movmean(headroom_daily_kigali,  30), '-','Color',colors(1,:),'LineWidth',2.5);
p2 = plot(day_axis, movmean(headroom_daily_lagos,   30), '-','Color',colors(2,:),'LineWidth',2.5);
p3 = plot(day_axis, movmean(headroom_daily_kampala, 30), '-','Color',colors(3,:),'LineWidth',2.5);
ymax = max([headroom_daily_kigali; headroom_daily_lagos; headroom_daily_kampala]) * 1.08;
if ymax == 0; ymax = 1; end
patch([153 244 244 153],[0 0 ymax ymax],[0.85 0.85 0.85],'FaceAlpha',0.30,'EdgeColor','none')
text(198, ymax*0.88,'Lagos rainy season','FontSize',9,'Color',[0.5 0.5 0.5],'HorizontalAlignment','center')
xlabel('Month (2024)','FontSize',12)
ylabel('Daily Headroom Available (kWh/day)','FontSize',12)
title('Annual Headroom Available for Third-Party Supply 1* panel — 2024 (30-day moving average)',...
    'FontSize',13,'FontWeight','bold')
legend([p1 p2 p3],{'Kigali (Ampersand)','Lagos (Spiro)','Kampala (Zembo)'},...
    'FontSize',11,'Location','southwest','Box','off')
set(gca,'XTick',month_starts,'XTickLabel',month_labels,'FontSize',11)
xlim([1 days_in_year]); ylim([0 ymax])
grid on; box off
exportgraphics(fig1,'headroom_annual.pdf','Resolution',300)
fprintf('  Saved: headroom_annual.pdf\n')

fig2= figure('Position',[50 50 1100 400],'Color','white');
hold on
plot(day_axis, headroom_daily_kigali2,  'Color',[colors(1,:) 0.18],'LineWidth',0.5)
plot(day_axis, headroom_daily_lagos2,   'Color',[colors(2,:) 0.18],'LineWidth',0.5)
plot(day_axis, headroom_daily_kampala2, 'Color',[colors(3,:) 0.18],'LineWidth',0.5)
p1 = plot(day_axis, movmean(headroom_daily_kigali2,  30), '-','Color',colors(1,:),'LineWidth',2.5);
p2 = plot(day_axis, movmean(headroom_daily_lagos2,   30), '-','Color',colors(2,:),'LineWidth',2.5);
p3 = plot(day_axis, movmean(headroom_daily_kampala2, 30), '-','Color',colors(3,:),'LineWidth',2.5);
ymax = max([headroom_daily_kigali2; headroom_daily_lagos2; headroom_daily_kampala2]) * 1.08;
if ymax == 0; ymax = 1; end
patch([153 244 244 153],[0 0 ymax ymax],[0.85 0.85 0.85],'FaceAlpha',0.30,'EdgeColor','none')
text(198, ymax*0.88,'Lagos rainy season','FontSize',9,'Color',[0.5 0.5 0.5],'HorizontalAlignment','center')
xlabel('Month (2024)','FontSize',12)
ylabel('Daily Headroom Available (kWh/day)','FontSize',12)
title('Annual Headroom Available for Third-Party Supply 1* panel — 2024 (30-day moving average)',...
    'FontSize',13,'FontWeight','bold')
legend([p1 p2 p3],{'Kigali (Ampersand)','Lagos (Spiro)','Kampala (Zembo)'},...
    'FontSize',11,'Location','southwest','Box','off')
set(gca,'XTick',month_starts,'XTickLabel',month_labels,'FontSize',11)
xlim([1 days_in_year]); ylim([0 ymax])
grid on; box off
exportgraphics(fig2,'headroom_annual2.pdf','Resolution',300)
fprintf('  Saved: headroom_annual2.pdf\n')

% ---- Figure 2: Diurnal headroom profile ----
fig3 = figure('Position',[50 50 900 400],'Color','white');
hold on
b1 = bar(hours-0.27, headroom_hourly_kigali,  0.27,'FaceColor',colors(1,:),'EdgeColor','none');
b2 = bar(hours,      headroom_hourly_lagos,   0.27,'FaceColor',colors(2,:),'EdgeColor','none');
b3 = bar(hours+0.27, headroom_hourly_kampala, 0.27,'FaceColor',colors(3,:),'EdgeColor','none');
xlabel('Hour of Day','FontSize',12)
ylabel('Mean Headroom (kWh/hr)','FontSize',12)
title('Average Hourly Headroom Available for Third-Party Supply','FontSize',13,'FontWeight','bold')
legend([b1 b2 b3],{'Kigali (Ampersand)','Lagos (Spiro)','Kampala (Zembo)'},...
    'FontSize',11,'Location','northeast','Box','off')
set(gca,'XTick',[1 4 8 12 16 20 24],...
    'XTickLabel',{'01:00','04:00','08:00','12:00','16:00','20:00','24:00'},'FontSize',10)
xlim([0.5 24.5]); grid on; box off
exportgraphics(fig3,'headroom_diurnal.pdf','Resolution',300)
fprintf('  Saved: headroom_diurnal.pdf\n')

fig4 = figure('Position',[50 50 900 400],'Color','white');
hold on
b1 = bar(hours-0.27, headroom_hourly_kigali2,  0.27,'FaceColor',colors(1,:),'EdgeColor','none');
b2 = bar(hours,      headroom_hourly_lagos2,   0.27,'FaceColor',colors(2,:),'EdgeColor','none');
b3 = bar(hours+0.27, headroom_hourly_kampala2, 0.27,'FaceColor',colors(3,:),'EdgeColor','none');
xlabel('Hour of Day','FontSize',12)
ylabel('Mean Headroom (kWh/hr)','FontSize',12)
title('Average Hourly Headroom Available for Third-Party Supply','FontSize',13,'FontWeight','bold')
legend([b1 b2 b3],{'Kigali (Ampersand)','Lagos (Spiro)','Kampala (Zembo)'},...
    'FontSize',11,'Location','northeast','Box','off')
set(gca,'XTick',[1 4 8 12 16 20 24],...
    'XTickLabel',{'01:00','04:00','08:00','12:00','16:00','20:00','24:00'},'FontSize',10)
xlim([0.5 24.5]); grid on; box off
exportgraphics(fig4,'headroom_diurnal2.pdf','Resolution',300)
fprintf('  Saved: headroom_diurnal2.pdf\n')

% ---- Figure 3: Households supportable ----
fig5 = figure('Position',[50 50 1100 400],'Color','white');
hold on
plot(day_axis, movmean(households_kigali,  30),'-','Color',colors(1,:),'LineWidth',2.5)
plot(day_axis, movmean(households_lagos,   30),'-','Color',colors(2,:),'LineWidth',2.5)
plot(day_axis, movmean(households_kampala, 30),'-','Color',colors(3,:),'LineWidth',2.5)
yline(10, 'k:',  'LineWidth',1.2,'Label','10 households','FontSize',9,'LabelHorizontalAlignment','left')
yline(50, 'k--', 'LineWidth',1.2,'Label','50 households','FontSize',9,'LabelHorizontalAlignment','left')
xlabel('Month (2024)','FontSize',12)
ylabel({'Households Supportable';'(1.5 kWh/day per household)'},'FontSize',12)
title('Third-Party Supply Potential — Equivalent Households Supportable from Daily Headroom',...
    'FontSize',13,'FontWeight','bold')
legend({'Kigali (Ampersand)','Lagos (Spiro)','Kampala (Zembo)'},...
    'FontSize',11,'Location','northeast','Box','off')
set(gca,'XTick',month_starts,'XTickLabel',month_labels,'FontSize',11)
xlim([1 days_in_year]); grid on; box off
exportgraphics(fig5,'headroom_households.pdf','Resolution',300)
fprintf('  Saved: headroom_households.pdf\n')


% ---- Figure 3: Households supportable ----
fig6 = figure('Position',[50 50 1100 400],'Color','white');
hold on
plot(day_axis, movmean(households_kigali2,  30),'-','Color',colors(1,:),'LineWidth',2.5)
plot(day_axis, movmean(households_lagos2,   30),'-','Color',colors(2,:),'LineWidth',2.5)
plot(day_axis, movmean(households_kampala2, 30),'-','Color',colors(3,:),'LineWidth',2.5)
yline(10, 'k:',  'LineWidth',1.2,'Label','10 households','FontSize',9,'LabelHorizontalAlignment','left')
yline(50, 'k--', 'LineWidth',1.2,'Label','50 households','FontSize',9,'LabelHorizontalAlignment','left')
xlabel('Month (2024)','FontSize',12)
ylabel({'Households Supportable';'(1.5 kWh/day per household)'},'FontSize',12)
title('Third-Party Supply Potential — Equivalent Households Supportable from Daily Headroom',...
    'FontSize',13,'FontWeight','bold')
legend({'Kigali (Ampersand)','Lagos (Spiro)','Kampala (Zembo)'},...
    'FontSize',11,'Location','northeast','Box','off')
set(gca,'XTick',month_starts,'XTickLabel',month_labels,'FontSize',11)
xlim([1 days_in_year]); grid on; box off
exportgraphics(fig6,'headroom_households2.pdf','Resolution',300)
fprintf('  Saved: headroom_households2.pdf\n')


% fig7 = figure('Position',[50 50 900 400],'Color','white');
% week      = 1:168;
% week_days = {'Mon','Tue','Wed','Thu','Fri','Sat','Sun'};
% hold on
% plot(week, ess_soc_kampala(week), '-','Color',colors(3,:),'LineWidth',2.5)
% yline(ESS_total_kampala-5,'k--','LineWidth',1.2,...
%     'Label',sprintf('ESS full (%.0f kWh)',ESS_total_kampala),...
%     'FontSize',9,'LabelHorizontalAlignment','right')
% yline(ESS_stationary,'k:','LineWidth',1.2,...
%     'Label','Stationary ESS (43 kWh)',...
%     'FontSize',9,'LabelHorizontalAlignment','right')
% yline(SoC_min,'r--','LineWidth',1.2,...
%     'Label','Min reserve (8.6 kWh)',...
%     'FontSize',9,'LabelHorizontalAlignment','right')
% for d = 0:6
%     xline(d*24+1,'Color',[0.8 0.8 0.8],'LineWidth',0.8)
%     text(d*24+12, ESS_total_kampala*1.04, week_days{d+1},...
%         'FontSize',10,'HorizontalAlignment','center','Color',[0.4 0.4 0.4])
% end
% xlabel('Day of Week','FontSize',12)
% ylabel('Total Effective ESS SoC (kWh)','FontSize',12)
% title({'Zembo (Kampala) — Total Effective ESS State of Charge';...
%        'Dry Season Sample Week (January 2024)'},...
%     'FontSize',13,'FontWeight','bold')
% ylim([0 ESS_total_kampala*1.15]); xlim([1 168])
% grid on; box off
% exportgraphics(fig4,'headroom_ess_soc.pdf','Resolution',300)
% fprintf('  Saved: headroom_ess_soc.pdf\n')

% ---- Figure 5: PV oversizing sensitivity (Zembo rural case) ----
fig7 = figure('Position',[50 50 680 380],'Color','white');
yyaxis left
bar(pv_multipliers, headroom_means, 0.5,'FaceColor',colors(3,:),'EdgeColor','none','FaceAlpha',0.85)
ylabel('Mean Daily Headroom (kWh/day)','FontSize',11)
ax = gca; ax.YAxis(1).Color = colors(3,:);
yyaxis right
plot(pv_multipliers, households_means,'ko-','LineWidth',2,'MarkerSize',8,'MarkerFaceColor','k')
ylabel('Mean Households Supportable','FontSize',11)
ax.YAxis(2).Color = 'k';
xlabel('PV System Size (multiple of base case)','FontSize',11)
title({'Zembo (Kampala) — Headroom vs PV Oversizing';...
       'Swap demand met at all sizing levels'},...
    'FontSize',12,'FontWeight','bold')
set(gca,'XTick',pv_multipliers,...
    'XTickLabel',{'1\times (base)','1.5\times','2\times','3\times'},'FontSize',11)
grid on; box off
exportgraphics(fig7,'headroom_pv_sizing.pdf','Resolution',300)
fprintf('  Saved: headroom_pv_sizing.pdf\n')

fprintf('\n=== headroom_analysis.m complete ===\n')

%% =========================================================================
%  FUNCTION: run_dispatch
%  EMS priority: swap demand first, ESS charging second, headroom third.
%  headroom(h) = spill = PV surplus the ESS cannot absorb when full.
%  INPUTS:
%    pv       [8784x1] hourly PV output kWh
%    demand   [8784x1] hourly swap demand kWh
%    ess_cap  scalar   ESS capacity kWh
%    soc_min  scalar   minimum reserve kWh
%    soc_init scalar   initial SoC kWh
%  OUTPUTS:
%    headroom [8784x1] kWh available for third-party supply
%    ess_soc  [8784x1] ESS state of charge kWh
%    unmet    [8784x1] swap demand not covered kWh (not reported)
% =========================================================================

function [headroom, ess_soc, unmet] = run_dispatch(pv, demand, ess_cap, soc_min, soc_init)
    n        = length(pv);
    headroom = zeros(n, 1);
    ess_soc  = zeros(n, 1);
    unmet    = zeros(n, 1);
    soc      = soc_init;
    for h = 1:n
        net = pv(h) - demand(h);
        if net >= 0
            soc_new     = min(soc + net, ess_cap);
            charged     = soc_new - soc;
            spill       = net - charged;
            headroom(h) = spill;
            soc         = soc_new;
        else
            deficit       = -net;
            dischargeable = max(0, soc - soc_min);
            discharged    = min(deficit, dischargeable);
            unmet(h)      = deficit - discharged;
            soc           = soc - discharged;
            headroom(h)   = 0;
        end
        ess_soc(h) = soc;
    end
    headroom = max(headroom, 0);
end