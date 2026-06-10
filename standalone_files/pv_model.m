

%% =========================================================================
%  pv_model.m  —  STANDALONE VERSION (plots + validation)
%
%  PURPOSE:
%    Sizes the PV system for each operator based on daily energy demand
%    and location-specific irradiance. Computes energy yield per panel,
%    number of panels required, and annual PV yield per operator.
%    
%
%  METHOD:
%    Ed  = swaps/day x battery_capacity x discharge_fraction  [kWh/day]
%    Ep  = sum(irradiance) x eff_panel x A_panel / (1000 x 366) [kWh/panel/day]
%    N   = ceil(Ed / Ep)                                        [panels]
%    annual_yield = N x Ep x 366                               [kWh/yr]
%
%  PANEL CONSTANTS — stated assumptions [NgeJunRod:24 Table 1]:
%    eff_panel = 0.149  (14.9% efficiency, Sharp NU-E245)
%    A_panel   = 1.64   m² (Sharp NU-E245 datasheet)
%
%  DISCHARGE FRACTION — [NgeJunRod:24 Table 1]:
%    discharge_fraction = 0.36
%    Riders arrive with average 64% SOC remaining — station charges
%    the depleted 36% per swap. Previous value of 0.75 was incorrect.
%
%  DATA SOURCE:
%    Irradiance loaded directly here for standalone use.
%    Renewables.ninja MERRA-2 reanalysis 2024 [RenNin, PfeSta:16]
%    2024 is a leap year — 8784 hours, 366 days.
%
%  PIPELINE POSITION:
%    Run AFTER  load_irradiance.m  (irradiance loaded here for standalone)
%    Run BEFORE economic_model_main.m (exports annual yield to LCOE block)
%
%  OUTPUTS:
%    panels_ampersand, panels_spiro, panels_zembo  [scalar, count]
%    Ed_ampersand, Ed_spiro, Ed_zembo              [scalar, kWh/day]
%    amp_pv_annual_yield_kwh                       [scalar, kWh/yr]
%    spiro_pv_annual_yield_kwh                     [scalar, kWh/yr]
%    zembo_pv_annual_yield_kwh                     [scalar, kWh/yr]
%
%  FIGURES:
%    panels_required.pdf  — number of panels required per operator
%    energy_demand.pdf    — daily energy demand per operator
%    pv_yield.pdf         — annual PV yield per operator
% =========================================================================

%% =========================================================================
%  BLOCK 1 — Load irradiance data
%
%  Loaded directly here for standalone use — in pv_model_main.m these
%  lines are removed as load_irradiance_main.m already places irradiance
%  vectors in the workspace.
%
%  NumHeaderLines=3: skips three Renewables.ninja metadata rows.
%  GHI [W/m²] = (irradiance_direct + irradiance_diffuse) * 1000
% =========================================================================

kigali_table  = readtable('ampersand_kigali_irradiance_2024.csv',  'NumHeaderLines', 3);
lagos_table   = readtable('spiro_lagos_irradiance_2024.csv',        'NumHeaderLines', 3);
kampala_table = readtable('zembo_kampala_irradiance_2024.csv',      'NumHeaderLines', 3);

kigali_irradiance  = (kigali_table.irradiance_direct  + kigali_table.irradiance_diffuse)  * 1000;
lagos_irradiance   = (lagos_table.irradiance_direct   + lagos_table.irradiance_diffuse)   * 1000;
kampala_irradiance = (kampala_table.irradiance_direct + kampala_table.irradiance_diffuse) * 1000;

fprintf('Rows loaded — Kigali: %d, Lagos: %d, Kampala: %d (expected 8784)\n', ...
    height(kigali_table), height(lagos_table), height(kampala_table))

%% =========================================================================
%  BLOCK 2 — Load operator parameters from CSV
%
%  Swap counts and battery capacities read from CSV — single source of
%  truth consistent with arrival_model_main.m and economic_model_main.m.
%
%  NOTE: ampersand_data.csv Battery capacity shows 2.52 kWh (72V x 35Ah).
%  Correct value is 2.88 kWh (72V x 40Ah) per NgeJunRod:24 Table 1.
%  Hardcoded as 2.88 here pending CSV correction before final submission.
% =========================================================================

amp_data = readtable('ampersand_data.csv', 'TextType', 'string');
spi_data = readtable('spiro_data.csv',     'TextType', 'string');
zem_data = readtable('zembo_data.csv',     'TextType', 'string');

getparam = @(t, name) t.Value(t.Parameter == name);

% Daily swap totals [swaps/day/station]
swaps_ampersand = getparam(amp_data, "Swaps per day per station");   % 565
swaps_spiro     = getparam(spi_data, "Swaps per day per station");   % 180
swaps_zembo     = getparam(zem_data, "Swaps per day per station");   % 44

% Battery capacities [kWh]
% NOTE: Ampersand hardcoded 2.88 — CSV pending correction from 2.52
capacity_ampersand = 2.88;
capacity_spiro     = getparam(spi_data, "Battery capacity");          % 3.40 kWh
capacity_zembo     = getparam(zem_data, "Battery capacity");          % 2.70 kWh

fprintf('\n--- Parameters ---\n')
fprintf('%-10s  %d swaps/day  %.2f kWh battery\n', 'Ampersand', swaps_ampersand, capacity_ampersand)
fprintf('%-10s  %d swaps/day  %.2f kWh battery\n', 'Spiro',     swaps_spiro,     capacity_spiro)
fprintf('%-10s  %d swaps/day  %.2f kWh battery\n', 'Zembo',     swaps_zembo,     capacity_zembo)

%% =========================================================================
%  BLOCK 3 — Panel constants and year parameters
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
%
%  days_in_year: 366 for 2024 (leap year)
%    Used to convert annual irradiance sum to daily average yield per panel.
% =========================================================================

eff_panel          = 0.149;   % Sharp NU-E245 efficiency  [NgeJunRod:24 Table 1]
A_panel            = 1.64;    % Sharp NU-E245 area (m²)   [NgeJunRod:24 Table 1]
discharge_fraction = 0.36;    % avg discharge per swap     [NgeJunRod:24 Table 1]
days_in_year       = 366;     % 2024 leap year

%% =========================================================================
%  BLOCK 4 — Daily energy demand (Ed)
%
%  Ed [kWh/day] = swaps/day x battery_capacity x discharge_fraction
%
%  Total electrical energy the PV+ESS system must deliver each day
%  to fully recharge all batteries returned from riders.
%
%  Ed does not include inverter or charging losses — these are captured
%  in the economic model via OPEX and ESS round-trip efficiency.
% =========================================================================

Ed_ampersand = swaps_ampersand * capacity_ampersand * discharge_fraction;
Ed_spiro     = swaps_spiro     * capacity_spiro     * discharge_fraction;
Ed_zembo     = swaps_zembo     * capacity_zembo     * discharge_fraction;

fprintf('\n--- Daily energy demand ---\n')
fprintf('%-10s  Ed = %.1f kWh/day\n', 'Ampersand', Ed_ampersand)
fprintf('%-10s  Ed = %.1f kWh/day\n', 'Spiro',     Ed_spiro)
fprintf('%-10s  Ed = %.1f kWh/day\n', 'Zembo',     Ed_zembo)

%% =========================================================================
%  BLOCK 5 — Energy yield per panel per day (Ep)
%
%  Ep [kWh/panel/day] = sum(irradiance) x eff_panel x A_panel / (1000 x days)
%
%  sum(irradiance): total annual GHI in Wh/m² (sum of 8784 hourly W/m² values)
%  x eff_panel:     converts irradiance to electrical energy (fraction)
%  x A_panel:       scales from per-m² to per-panel area
%  / 1000:          converts Wh to kWh
%  / days_in_year:  converts annual total to daily average
%
%  Result is the average daily yield including nighttime hours (GHI=0)
%  — represents what one panel produces on average over a 24-hour period.
% =========================================================================

Ep_ampersand = sum(kigali_irradiance)  * eff_panel * A_panel / (1000 * days_in_year);
Ep_spiro     = sum(lagos_irradiance)   * eff_panel * A_panel / (1000 * days_in_year);
Ep_zembo     = sum(kampala_irradiance) * eff_panel * A_panel / (1000 * days_in_year);

fprintf('\n--- Energy yield per panel per day ---\n')
fprintf('%-10s  Ep = %.3f kWh/panel/day\n', 'Ampersand (Kigali)',  Ep_ampersand)
fprintf('%-10s  Ep = %.3f kWh/panel/day\n', 'Spiro     (Lagos)',   Ep_spiro)
fprintf('%-10s  Ep = %.3f kWh/panel/day\n', 'Zembo     (Kampala)', Ep_zembo)

%% =========================================================================
%  BLOCK 6 — Panels required and cross-check
%
%  N = ceil(Ed / Ep)
%
%  ceil() rounds up — you cannot install a fractional panel.
%  Rounding down would leave the system undersized.
%
%  Cross-check: N x 245 Wp/panel vs pv_system_rated_power in CSV (37000 Wp)
%  245 Wp is Sharp NU-E245 rated output [NgeJunRod:24 Table 1].
%  If the implied system size differs significantly from the CSV value,
%  the sizing methodology and CSV are inconsistent — flag in report.
% =========================================================================

panels_ampersand = ceil(Ed_ampersand / Ep_ampersand);
panels_spiro     = ceil(Ed_spiro     / Ep_spiro);
panels_zembo     = ceil(Ed_zembo     / Ep_zembo);

fprintf('\n--- Panels required ---\n')
fprintf('%-10s  N = %d panels  implied system = %.0f Wp  (CSV: 37000 Wp)\n', ...
    'Ampersand', panels_ampersand, panels_ampersand * 245)
fprintf('%-10s  N = %d panels  implied system = %.0f Wp  (CSV: 37000 Wp)\n', ...
    'Spiro',     panels_spiro,     panels_spiro     * 245)
fprintf('%-10s  N = %d panels  implied system = %.0f Wp  (CSV: 37000 Wp)\n', ...
    'Zembo',     panels_zembo,     panels_zembo     * 245)

%% =========================================================================
%  BLOCK 7 — Annual PV yield
%
%  annual_yield [kWh/yr] = N x Ep x days_in_year
%
%  Total electrical energy produced by the sized PV array per year.
%  Feeds into economic_model_main.m Block 9 (LCOE) replacing the static
%  energy estimate currently used there.
%
%  Note: does not account for annual panel degradation (~0.5%/yr).
%  Sensitivity analysis should sweep degradation rate over project lifetime.
% =========================================================================

amp_pv_annual_yield_kwh   = panels_ampersand * Ep_ampersand * days_in_year;
spiro_pv_annual_yield_kwh = panels_spiro     * Ep_spiro     * days_in_year;
zembo_pv_annual_yield_kwh = panels_zembo     * Ep_zembo     * days_in_year;

fprintf('\n--- Annual PV yield ---\n')
fprintf('%-10s  %.0f kWh/yr\n', 'Ampersand', amp_pv_annual_yield_kwh)
fprintf('%-10s  %.0f kWh/yr\n', 'Spiro',     spiro_pv_annual_yield_kwh)
fprintf('%-10s  %.0f kWh/yr\n', 'Zembo',     zembo_pv_annual_yield_kwh)

%% =========================================================================
%  BLOCK 8 — Operator colours (consistent across all project figures)
% =========================================================================

colors    = [0.20 0.47 0.75;   % blue   — Ampersand / Kigali
             0.90 0.45 0.18;   % orange — Spiro     / Lagos
             0.27 0.65 0.38];  % green  — Zembo     / Kampala

operators = {'Ampersand (Kigali)', 'Spiro (Lagos)', 'Zembo (Kampala)'};

%% =========================================================================
%  BLOCK 9 — FIGURE 1: Panels required
%
%  One bar per operator showing number of panels sized to meet daily demand.
%  Individual bar colours via FaceColor='flat' and CData property.
%  Value labels above each bar for direct readability.
%
%  Expected result:
%    Ampersand >> Spiro >> Zembo
%    Driven by swap volume — 565 vs 180 vs 44 swaps/day.
% =========================================================================

fig1 = figure('Position', [50 50 800 500], 'Color', 'white');

b1 = bar([panels_ampersand, panels_spiro, panels_zembo]);
b1.FaceColor = 'flat';
b1.CData     = colors;

set(gca, 'XTick', 1:3, 'XTickLabel', operators, 'FontSize', 11)
ylabel('Number of PV Panels Required', 'FontSize', 12)
title('PV Panel Sizing by Operator [NgeJunRod:24, RenNin]', ...
    'FontSize', 12, 'FontWeight', 'bold')

vals1 = [panels_ampersand, panels_spiro, panels_zembo];
for i = 1:3
    text(i, vals1(i) + max(vals1)*0.02, num2str(vals1(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, ...
        'FontWeight', 'bold', 'Color', colors(i,:)*0.75)
end

ylim([0 max(vals1) * 1.15])
grid on; box off
exportgraphics(fig1, 'panels_required.pdf', 'Resolution', 300)
fprintf('\nFigure 1 saved: panels_required.pdf\n')

%% =========================================================================
%  BLOCK 10 — FIGURE 2: Daily energy demand
%
%  Shows Ed per operator — the daily electrical load the PV system must meet.
%  Ed = swaps/day x battery_capacity x discharge_fraction.
%  Directly comparable to panel count in Figure 1 — higher Ed means more
%  panels, higher CAPEX, but also more energy delivered and more revenue.
% =========================================================================

fig2 = figure('Position', [50 50 800 500], 'Color', 'white');

b2 = bar([Ed_ampersand, Ed_spiro, Ed_zembo]);
b2.FaceColor = 'flat';
b2.CData     = colors;

set(gca, 'XTick', 1:3, 'XTickLabel', operators, 'FontSize', 11)
ylabel('Daily Energy Demand (kWh/day)', 'FontSize', 12)
title('Daily Energy Demand by Operator', 'FontSize', 12, 'FontWeight', 'bold')

vals2 = [Ed_ampersand, Ed_spiro, Ed_zembo];
for i = 1:3
    text(i, vals2(i) + max(vals2)*0.02, sprintf('%.1f', vals2(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, ...
        'FontWeight', 'bold', 'Color', colors(i,:)*0.75)
end

ylim([0 max(vals2) * 1.15])
grid on; box off
exportgraphics(fig2, 'energy_demand.pdf', 'Resolution', 300)
fprintf('Figure 2 saved: energy_demand.pdf\n')

%% =========================================================================
%  BLOCK 11 — FIGURE 3: Annual PV yield
%
%  Total electrical energy produced by each operator's PV array per year.
%  Plotted in MWh for readability (divide kWh by 1000).
%  This is the output fed into economic_model_main.m Block 9 LCOE block.
%
%  Annual yield should always exceed annual demand (Ed x 366) for each
%  operator — if not, the panel count is insufficient.
% =========================================================================

fig3 = figure('Position', [50 50 800 500], 'Color', 'white');

yields_mwh = [amp_pv_annual_yield_kwh, spiro_pv_annual_yield_kwh, zembo_pv_annual_yield_kwh] / 1000;
b3 = bar(yields_mwh);
b3.FaceColor = 'flat';
b3.CData     = colors;

set(gca, 'XTick', 1:3, 'XTickLabel', operators, 'FontSize', 11)
ylabel('Annual PV Yield (MWh/yr)', 'FontSize', 12)
title('Annual PV Yield by Operator [NgeJunRod:24, RenNin]', ...
    'FontSize', 12, 'FontWeight', 'bold')

for i = 1:3
    text(i, yields_mwh(i) + max(yields_mwh)*0.02, sprintf('%.1f MWh', yields_mwh(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 11, ...
        'FontWeight', 'bold', 'Color', colors(i,:)*0.75)
end

ylim([0 max(yields_mwh) * 1.15])
grid on; box off
exportgraphics(fig3, 'pv_yield.pdf', 'Resolution', 300)
fprintf('Figure 3 saved: pv_yield.pdf\n')

fprintf('\n=== pv_model.m complete ===\n')
fprintf('Workspace variables:\n')
fprintf('  panels_ampersand, panels_spiro, panels_zembo        [scalar, count]\n')
fprintf('  Ed_ampersand, Ed_spiro, Ed_zembo                    [scalar, kWh/day]\n')
fprintf('  amp/spiro/zembo_pv_annual_yield_kwh                 [scalar, kWh/yr]\n')