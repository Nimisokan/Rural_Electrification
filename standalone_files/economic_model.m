% =========================================================================
%  economic_model.m  —  STANDALONE VERSION WITH FIGURES
%
%  Comparative financial analysis:
%    Ampersand (Kigali, Rwanda) | Spiro (Lagos, Nigeria) | Zembo (Kampala, Uganda)
%
%  Computes CAPEX, OPEX, revenue,profit, NPV, IRR, payback period,
%  LCOE, and LCOS for all three operators.
%  All base-case parameters read from the three operator CSV files.
%
 
%  OUTPUT FILES (saved to working directory):
%    capex_breakdown.pdf    
%    revenue_vs_opex.pdf       
%    payback_period.pdf      
%    npv_comparison.pdf       
%    cashflow_cumulative.pdf  
%    lcoe_lcos.pdf             
% =========================================================================

clc;clear;close all;

%% =========================================================================
%  BLOCK 1 — Load CSV files into MATLAB tables
% =========================================================================

% readtable() reads a CSV and returns a MATLAB table object whose columns
% match the CSV headers (Parameter, Value, Unit, CitationKey, ReportNote).
amp   = readtable('ampersand_data.csv', 'TextType', 'string');
spiro = readtable('spiro_data.csv',     'TextType', 'string');
zembo = readtable('zembo_data.csv',     'TextType', 'string');

% getparam: anonymous function that looks up a parameter by name and returns
% its Value from the matching row. t.Parameter == name produces a logical
% index vector; t.Value uses it to extract the matching cell.
% Values come out as strings 
getparam = @(t, name) t.Value(t.Parameter == name);

%% =========================================================================
%  BLOCK 2 — Parameter extraction
%
%  Every base-case number comes from the CSV files here. No computation
%  happens in this block 
% =========================================================================

% --- Battery specs ---
% Voltage [V] — not used in financial calculations; read for completeness
% and for the Simulink charge model which shares the same CSV.
amp_battery_voltage   = getparam(amp,   'Battery voltage');    % 72 V
spiro_battery_voltage = getparam(spiro, 'Battery voltage');    % 60 V
zembo_battery_voltage = getparam(zembo, 'Battery voltage');    % 60 V

% Capacity [kWh] — used in battery inventory CAPEX and the EFC calculation.
amp_battery_capacity   = getparam(amp,   'Battery capacity');  % 2.88 kWh
spiro_battery_capacity = getparam(spiro, 'Battery capacity');  % 3.40 kWh
zembo_battery_capacity = getparam(zembo, 'Battery capacity');  % 2.70 kWh

% Range per swap [km] — context only, not used in any financial formula.
amp_battery_range   = getparam(amp,   'Battery range per swap');  % 72 km
spiro_battery_range = getparam(spiro, 'Battery range per swap');  % 80 km
zembo_battery_range = getparam(zembo, 'Battery range per swap');  % 65 km

% --- Swap operations ---
% Swap time [min] — used in Simulink service time block, not in economics.
amp_swap_time   = getparam(amp,   'Swap time');   % 2 min
spiro_swap_time = getparam(spiro, 'Swap time');   % 2 min
zembo_swap_time = getparam(zembo, 'Swap time');   % 2 min

% Swap price [USD/swap] — the per-transaction revenue rate.
% All three operators use pay-per-swap in the corrected model.
% Ampersand: $1.60 confirmed [EV24:25].
% Zembo:     $1.65 confirmed [PCTech:24].
% Spiro:     $$3.50 is derived from East African operator pricing adjusted for Lagos
%   market conditions [SpiTec:25]. Sensitivity range $1.00-$6.00 tested
%   in sensitivity_analysis.m.
amp_swap_price   = getparam(amp,   'Swap price');   % $1.60
spiro_swap_price = getparam(spiro,   'Swap price'); %  $3.50                           
zembo_swap_price = getparam(zembo, 'Swap price');   % $1.65


amp_swaps_per_day   = getparam(amp,   'Swaps per day per station');  % 200
spiro_swaps_per_day = getparam(spiro, 'Swaps per day per station');  % 180
zembo_swaps_per_day = getparam(zembo, 'Swaps per day per station');  % 44



% --- Infrastructure ---
% Docking cabinet count — drives cabinet CAPEX and sets server count in
% the Simulink M/G/c queueing model.
amp_docking_cabinets   = getparam(amp,   'Docking cabinets');   % 5
spiro_docking_cabinets = getparam(spiro, 'Docking cabinets');   % 5
zembo_docking_cabinets = getparam(zembo, 'Docking cabinets');   % 3

% Cost per cabinet [$] — multiplied by count in Block 3 to get cabinet CAPEX.
amp_cost_per_cabinet   = getparam(amp,   'Cost per docking cabinet');  % $3,500
spiro_cost_per_cabinet = getparam(spiro, 'Cost per docking cabinet');  % $3,500
zembo_cost_per_cabinet = getparam(zembo, 'Cost per docking cabinet');  % $3,500

% --- PV system ---
% Rated power [Wp] — the full installed DC system capacity, not a single panel.
% e.g. 37,000 Wp = 37 kWp for Ampersand and Spiro; 8,085 Wp for Zembo.
amp_pv_system_power   = getparam(amp,   'PV system rated power');   % 37,000 Wp
spiro_pv_system_power = getparam(spiro, 'PV system rated power');   % 37,000 Wp
zembo_pv_system_power = getparam(zembo, 'PV system rated power');   % 8,550 Wp

% Installed cost [$/Wp] — includes panels, inverter, mounting, wiring.
% $1.30/Wp is the IRENA 2016 conservative upper bound [IRENA:16].
amp_pv_installed_cost   = getparam(amp,   'PV installed cost');   % $1.30/Wp
spiro_pv_installed_cost = getparam(spiro, 'PV installed cost');   % $1.30/Wp
zembo_pv_installed_cost = getparam(zembo, 'PV installed cost');   % $1.30/Wp

% Total PV cost [$] = installed cost [$/Wp] x system power [Wp].
% Computed here because it feeds into both CAPEX (Block 3) and the figure.
amp_pv_cost   = amp_pv_installed_cost   * amp_pv_system_power;    % ~$48,100
spiro_pv_cost = spiro_pv_installed_cost * spiro_pv_system_power;  % ~$48,100
zembo_pv_cost = zembo_pv_installed_cost * zembo_pv_system_power;  % ~$11,115

% --- Stationary ESS (Energy Storage System) ---
% The ESS is the fixed buffer battery bank at the station — separate from
% the swap batteries. It stores PV energy and smooths supply to the chargers.
% Size [kWh] — used in LCOS and total ESS capital cost.
amp_ess_size   = getparam(amp,   'ESS size');   % 43 kWh
spiro_ess_size = getparam(spiro, 'ESS size');   % 43 kWh
zembo_ess_size = getparam(zembo, 'ESS size');   % 43 kWh

% Unit cost [$/kWh] — applied to both the ESS and the swap battery inventory.
% Using the same rate for both is a stated simplification (see Limitations).
amp_ess_cost_per_kwh   = getparam(amp,   'ESS cost');   % $300/kWh
spiro_ess_cost_per_kwh = getparam(spiro, 'ESS cost');   % $300/kWh
zembo_ess_cost_per_kwh = getparam(zembo, 'ESS cost');   % $300/kWh

% Total ESS capital cost [$] = unit cost [$/kWh] x size [kWh].
amp_ess_total_cost   = amp_ess_cost_per_kwh   * amp_ess_size;    % $12,900
spiro_ess_total_cost = spiro_ess_cost_per_kwh * spiro_ess_size;  % $12,900
zembo_ess_total_cost = zembo_ess_cost_per_kwh * zembo_ess_size;  % $12,900

% --- Swap battery inventory ---
% The pool of charged batteries held at the station ready for swapping.
% This is the largest single CAPEX component for all three operators.
amp_battery_inventory_count   = getparam(amp,   'Battery inventory count');  % 150
spiro_battery_inventory_count = getparam(spiro, 'Battery inventory count');  % 135
zembo_battery_inventory_count = getparam(zembo, 'Battery inventory count');  % 33

% Total inventory cost [$] = count x capacity [kWh] x unit cost [$/kWh].
% Using ESS $/kWh as a proxy for swap battery cost understates CAPEX by
% 20-40% (swap batteries command a ruggedisation premium) 
swap_battery_premium =1.30;
amp_battery_inventory_cost   = amp_battery_inventory_count   * amp_battery_capacity   * amp_ess_cost_per_kwh*swap_battery_premium;
spiro_battery_inventory_cost = spiro_battery_inventory_count * spiro_battery_capacity * spiro_ess_cost_per_kwh*swap_battery_premium;
zembo_battery_inventory_cost = zembo_battery_inventory_count * zembo_battery_capacity * zembo_ess_cost_per_kwh*swap_battery_premium;

% --- Project cost parameters ---
% Installation overhead [fraction] — applied to total hardware cost.
% 20% covers civil works, wiring, and commissioning [CrossBound:24].
amp_installation_overhead   = getparam(amp,   'Installation overhead');   % 0.20
spiro_installation_overhead = getparam(spiro, 'Installation overhead');   % 0.20
zembo_installation_overhead = getparam(zembo, 'Installation overhead');   % 0.20

% Annual O&M rate [fraction of CAPEX] — paid every year for maintenance.
% 2.5% is the industry standard for commercial BESS [DomEle:26].
amp_annual_om_rate   = getparam(amp,   'Annual OM rate');   % 0.025
spiro_annual_om_rate = getparam(spiro, 'Annual OM rate');   % 0.025
zembo_annual_om_rate = getparam(zembo, 'Annual OM rate');   % 0.025

% Annual staff cost [$/yr] — fixed labour cost, two attendants per station.
amp_annual_staff_cost   = getparam(amp,   'Annual staff cost');   % $2,400 (Kigali)
spiro_annual_staff_cost = getparam(spiro, 'Annual staff cost');   % $3,000 (Lagos)
zembo_annual_staff_cost = getparam(zembo, 'Annual staff cost');   % $2,000 (Kampala)

% --- Financial parameters ---
% Discount rate [fraction] — the cost of capital used to discount future
% cash flows. 10% is the DFI-blended concessional rate justified by
% development finance backing for all three operators [CATF:24].
amp_discount_rate   = getparam(amp,   'Discount rate');   % 0.10
spiro_discount_rate = getparam(spiro, 'Discount rate');   % 0.10
zembo_discount_rate = getparam(zembo, 'Discount rate');   % 0.10

% Project lifetime [years] — horizon for NPV, LCOE, and LCOS.
% 20 years is consistent with IEC/IEA solar PV lifetime standards.
amp_project_lifetime   = getparam(amp,   'Project lifetime');   % 20
spiro_project_lifetime = getparam(spiro, 'Project lifetime');   % 20
zembo_project_lifetime = getparam(zembo, 'Project lifetime');   % 20

% Panel degradation rate [fraction/yr] — PV output loss per year.
% 0.5%/yr is the standard value for monocrystalline silicon panels.
% Used in LCOE Block 9 to compute lifetime energy with year-by-year decay.
amp_degradation   = getparam(amp,   'Panel degradation rate');   % 0.005
spiro_degradation = getparam(spiro, 'Panel degradation rate');   % 0.005
zembo_degradation = getparam(zembo, 'Panel degradation rate');   % 0.005

%% =========================================================================
%  BLOCK 3 — CAPEX (Capital Expenditure)
%
%  Total upfront cost to build and commission one station.
%  Two-layer structure:
%    hardware_cost = sum of four physical components (no overhead yet)
%    capex         = hardware_cost x (1 + installation overhead)
%
%  Hardware components:
%    1. Docking cabinets  = count x cost per cabinet
%    2. PV system         = installed cost [$/Wp] x system power [Wp]
%    3. Stationary ESS    = unit cost [$/kWh] x size [kWh]
%    4. Battery inventory = count x capacity [kWh] x unit cost [$/kWh]
%
%  hardware_cost is retained as a named variable because it is also needed
%  in Block 10 (LCOS) to compute the ESS fraction of total hardware cost.
% =========================================================================

% ... is MATLAB line continuation — the expression continues on the next line.
amp_hardware_cost   = (amp_docking_cabinets   * amp_cost_per_cabinet)   ...
                    + amp_pv_cost   + amp_ess_total_cost   + amp_battery_inventory_cost;
spiro_hardware_cost = (spiro_docking_cabinets * spiro_cost_per_cabinet) ...
                    + spiro_pv_cost + spiro_ess_total_cost + spiro_battery_inventory_cost;
zembo_hardware_cost = (zembo_docking_cabinets * zembo_cost_per_cabinet) ...
                    + zembo_pv_cost + zembo_ess_total_cost + zembo_battery_inventory_cost;

% Total CAPEX = hardware cost x (1 + 0.70 installation overhead).
amp_capex   = amp_hardware_cost   * (1 + amp_installation_overhead);
spiro_capex = spiro_hardware_cost * (1 + spiro_installation_overhead);
zembo_capex = zembo_hardware_cost * (1 + zembo_installation_overhead);

% Console output for immediate verification against report table values.
% \n = newline. $%.2f = dollar sign then float to 2 decimal places.
fprintf('\n--- CAPEX ---\n')
fprintf('Ampersand: $%.2f\n', amp_capex)
fprintf('Spiro:     $%.2f\n', spiro_capex)
fprintf('Zembo:     $%.2f\n', zembo_capex)

%% =========================================================================
%  BLOCK 4 — OPEX (Annual Operating Expenditure)
%
%  Three-component model:
%    1. O&M reserve       = CAPEX x annual_om_rate  (2.5% of CAPEX per year)
%    2. Staff cost        = fixed annual labour cost
%    3. Battery replacement reserve = straight-line amortisation of battery
%                           inventory cost over the computed battery lifetime
%
%  The battery replacement reserve uses the Equivalent Full Cycle (EFC)
%  methodology. A partial discharge causes less degradation than a full
%  discharge, so raw swap cycles are scaled by the mean discharge fraction
%  to get EFC — the electrochemically meaningful cycle unit.
%
%    EFC/day  = (swaps/day / inventory count) x discharge_fraction
%    bat life = cycle_life_EFC / (EFC/day x 365)   [years]
%    reserve  = battery_inventory_cost / bat_life   [$/yr, straight-line]
%
%  discharge_fraction = 0.36 (mean fraction of capacity consumed per swap,
%  derived from the arrival SOC distribution in pv_model_main.m).
%  If this script runs standalone without pv_model_main.m having set it,
%  the if-block below supplies the same value as a fallback.
%
%  cycle_life_EFC = 3,000 — conservative mid-range for LFP at partial DoD.
% =========================================================================

% Fallback: use 0.36 if pv_model_main.m has not already set this variable.
% In the pipeline, discharge_fraction is set by pv_model_main.m; the
% standalone uses the same numerical value via this safety check.
if ~exist('discharge_fraction', 'var')
    discharge_fraction = 0.36;
end

% Conservative LFP cycle life at partial depth of discharge [NgeJunRod:24].
cycle_life_efc = 3000;

% EFC per battery per day:
%   swaps_per_day / inventory_count = raw cycles per battery per day
%   x discharge_fraction            = equivalent full cycles per battery per day
% e.g. Ampersand: (200/150) x 0.36 = 1.33 x 0.36 = 0.48 EFC/bat/day
amp_efc_per_day   = (amp_swaps_per_day   / amp_battery_inventory_count)   * discharge_fraction;
spiro_efc_per_day = (spiro_swaps_per_day / spiro_battery_inventory_count) * discharge_fraction;
zembo_efc_per_day = (zembo_swaps_per_day / zembo_battery_inventory_count) * discharge_fraction;

% Battery lifetime [years] = cycle life / (EFC/day x 365 days/yr).
% e.g. Ampersand: 3000 / (1.36 x 365) = 6.0 years.
amp_battery_life_years   = cycle_life_efc / (amp_efc_per_day   * 365);
spiro_battery_life_years = cycle_life_efc / (spiro_efc_per_day * 365);
zembo_battery_life_years = cycle_life_efc / (zembo_efc_per_day * 365);

% Annual replacement reserve [$/yr] = inventory cost / battery lifetime.
% Straight-line: equal amount set aside each year to fund the replacement.
amp_bat_replacement   = amp_battery_inventory_cost   / amp_battery_life_years;
spiro_bat_replacement = spiro_battery_inventory_cost / spiro_battery_life_years;
zembo_bat_replacement = zembo_battery_inventory_cost / zembo_battery_life_years;

% Base OPEX = O&M reserve + staff cost (without battery replacement).
amp_base_opex   = (amp_capex   * amp_annual_om_rate)   + amp_annual_staff_cost;
spiro_base_opex = (spiro_capex * spiro_annual_om_rate) + spiro_annual_staff_cost;
zembo_base_opex = (zembo_capex * zembo_annual_om_rate) + zembo_annual_staff_cost;

% Total annual OPEX = base OPEX + battery replacement reserve.
amp_opex   = amp_base_opex   + amp_bat_replacement;
spiro_opex = spiro_base_opex + spiro_bat_replacement;
zembo_opex = zembo_base_opex + zembo_bat_replacement;

% Three-column console output showing each OPEX component separately.
% %-12s = left-aligned string in 12-char field. %8.0f = 8-char float, 0 decimals.
fprintf('\n--- Annual OPEX (with battery replacement reserve) ---\n')
fprintf('%-12s  Base: $%8.0f   Bat repl: $%8.0f   Total: $%8.0f\n', ...
    'Ampersand', amp_base_opex,   amp_bat_replacement,   amp_opex)
fprintf('%-12s  Base: $%8.0f   Bat repl: $%8.0f   Total: $%8.0f\n', ...
    'Spiro',     spiro_base_opex, spiro_bat_replacement, spiro_opex)
fprintf('%-12s  Base: $%8.0f   Bat repl: $%8.0f   Total: $%8.0f\n', ...
    'Zembo',     zembo_base_opex, zembo_bat_replacement, zembo_opex)

fprintf('\n--- Battery Lifetime ---\n')
fprintf('Ampersand: %.1f yrs  (%.2f EFC/bat/day)\n', amp_battery_life_years,   amp_efc_per_day)
fprintf('Spiro:     %.1f yrs  (%.2f EFC/bat/day)\n', spiro_battery_life_years, spiro_efc_per_day)
fprintf('Zembo:     %.1f yrs  (%.2f EFC/bat/day)\n', zembo_battery_life_years, zembo_efc_per_day)

%% =========================================================================
%  BLOCK 5 — Annual Revenue
%
%  All three operators use pay-per-swap pricing.
%  Revenue = swap_price [$/swap] x swaps_per_day [swaps/day] x 365 [days/yr]
%
%  This is the base-case assumption: constant annual revenue with no
%  demand growth or seasonal variation. The sensitivity of NPV and IRR
%  to swap price is quantified in sensitivity_analysis.m.
%
%  When Simulink is integrated, swaps_per_day will come from the simulated
%  throughput (completed swaps after queue losses), which accounts for
%  capacity constraints and peak-hour congestion.
% =========================================================================

% Ampersand: $1.60/swap x 565 swaps/day x 365 days = $329,960/yr
amp_annual_revenue = amp_swap_price * amp_swaps_per_day * 365;

% Spiro: $3.50/swap (stated assumption) x 180 swaps/day x 365 = $229,950/yr
spiro_annual_revenue = spiro_swap_price * spiro_swaps_per_day * 365;

% Zembo: $1.65/swap x 44 swaps/day x 365 = $26,499/yr
zembo_annual_revenue = zembo_swap_price * zembo_swaps_per_day * 365;

fprintf('\n--- Annual Revenue ---\n')
fprintf('Ampersand: $%.2f\n', amp_annual_revenue)
fprintf('Spiro:     $%.2f\n', spiro_annual_revenue)
fprintf('Zembo:     $%.2f\n', zembo_annual_revenue)

%% =========================================================================
%  BLOCK 6 — Annual Profit and Profit Margin
%
%  Annual profit = revenue - OPEX  (gross operating profit, before tax)
%  Profit margin = (profit / revenue) x 100  [%]
%
%  High margins reflect the near-zero marginal cost of solar-powered
%  stations once commissioned — solar fuel is free, so almost every
%  additional swap goes straight to profit.
% =========================================================================

amp_annual_profit   = amp_annual_revenue   - amp_opex;
spiro_annual_profit = spiro_annual_revenue - spiro_opex;
zembo_annual_profit = zembo_annual_revenue - zembo_opex;

amp_profit_margin   = (amp_annual_profit   / amp_annual_revenue)   * 100;
spiro_profit_margin = (spiro_annual_profit / spiro_annual_revenue) * 100;
zembo_profit_margin = (zembo_annual_profit / zembo_annual_revenue) * 100;

% %% in fprintf prints a literal percent sign.
fprintf('\n--- Annual Profit and Margin ---\n')
fprintf('Ampersand: $%.2f  (%.1f%%)\n', amp_annual_profit,   amp_profit_margin)
fprintf('Spiro:     $%.2f  (%.1f%%)\n', spiro_annual_profit, spiro_profit_margin)
fprintf('Zembo:     $%.2f  (%.1f%%)\n', zembo_annual_profit, zembo_profit_margin)

%% =========================================================================
%  BLOCK 7 — Payback Period (simple, undiscounted)
%
%  Payback = CAPEX / annual_profit  [years]
%
%  This is the undiscounted payback — it does not account for the time
%  value of money. The discounted payback is visible in Figure 5 as the
%  year where each operator's cumulative discounted cash flow crosses zero.
%  Both metrics are reported; DFI threshold is 5 years [CATF:24].
% =========================================================================

amp_payback   = amp_capex   / amp_annual_profit;
spiro_payback = spiro_capex / spiro_annual_profit;
zembo_payback = zembo_capex / zembo_annual_profit;

fprintf('\n--- Payback Period (years) ---\n')
fprintf('Ampersand: %.2f\n', amp_payback)
fprintf('Spiro:     %.2f\n', spiro_payback)
fprintf('Zembo:     %.2f\n', zembo_payback)

%% =========================================================================
%  BLOCK 8 — NPV and IRR
%
%  NPV (Net Present Value):
%    Discounted sum of all future cash flows minus the initial investment.
%    Positive NPV means the project creates value at the given discount rate.
%    NPV = -CAPEX + sum[ profit / (1+r)^t ]  for t = 1 to N
%
%    Implementation: build a cashflow vector of length N+1.
%      Index 1     = year 0 = -CAPEX (upfront outlay, not discounted)
%      Index 2:N+1 = years 1-N = +annual_profit (constant, no growth)
%    Divide element-wise by discount factor vector (1+r)^[0,1,...,N].
%    Year 0 is divided by (1+r)^0 = 1, leaving it unchanged — correct.
%
%    repmat(x, 1, N) creates a 1xN row vector of value x repeated N times.
%
%  IRR (Internal Rate of Return):
%    The discount rate r* at which NPV = 0. Solved by irr() from the
%    MATLAB Financial Toolbox. If unavailable, use:
%      amp_irr = fzero(@(r) sum(amp_cashflows ./ (1+r).^(0:amp_project_lifetime)), 0.1);
% =========================================================================

% Cashflow vectors: [-CAPEX, profit, profit, ..., profit] — N+1 elements.
amp_cashflows   = [-amp_capex,   repmat(amp_annual_profit,   1, amp_project_lifetime)];
spiro_cashflows = [-spiro_capex, repmat(spiro_annual_profit, 1, spiro_project_lifetime)];
zembo_cashflows = [-zembo_capex, repmat(zembo_annual_profit, 1, zembo_project_lifetime)];

% NPV: element-wise divide cashflows by discount factors then sum.
% (0:N) = [0,1,2,...,N] — exponent for each year's discount factor.
amp_npv   = sum(amp_cashflows   ./ (1 + amp_discount_rate)  .^ (0:amp_project_lifetime));
spiro_npv = sum(spiro_cashflows ./ (1 + spiro_discount_rate).^ (0:spiro_project_lifetime));
zembo_npv = sum(zembo_cashflows ./ (1 + zembo_discount_rate).^ (0:zembo_project_lifetime));

% IRR: rate at which NPV = 0. Requires Financial Toolbox.
amp_irr   = irr(amp_cashflows);
spiro_irr = irr(spiro_cashflows);
zembo_irr = irr(zembo_cashflows);

fprintf('\n--- NPV and IRR ---\n')
fprintf('Ampersand:  NPV = $%.2f   IRR = %.2f%%\n', amp_npv,   amp_irr   * 100)
fprintf('Spiro:      NPV = $%.2f   IRR = %.2f%%\n', spiro_npv, spiro_irr * 100)
fprintf('Zembo:      NPV = $%.2f   IRR = %.2f%%\n', zembo_npv, zembo_irr * 100)

%% =========================================================================
%  BLOCK 9 — LCOE (Levelised Cost of Energy)
%
%  LCOE = (CAPEX + OPEX x N) / E_lifetime   [$/kWh]
%
%  E_lifetime is the total PV energy delivered over the project lifetime,
%  with panel degradation applied year by year:
%    E_yr(t) = E_yr1 x (1 - delta)^(t-1)    [kWh in year t]
%    E_lifetime = sum of E_yr(t) for t = 1 to N
%
%  delta = 0.005 (0.5%/yr) — standard monocrystalline degradation rate.
%  E_yr1 comes from pv_model_main.m in the pipeline. In standalone mode
%  the if-blocks below compute a fallback estimate from system rated power
%  and a conservative performance ratio of 0.75 at 5.0 peak sun hours/day.
%
%  Why PV yield as the energy denominator (not swap energy):
%  LCOE is a generation-side metric — cost per kWh produced by the PV
%  system. This allows direct comparison against published grid tariffs
%  and is consistent with the standard IEC LCOE formulation.
%
%  OPEX is not discounted in this formulation — this is the standard
%  engineering LCOE consistent with [NgeJunRod:24]. A fully discounted
%  LCOE is noted as a limitation in the report.
% =========================================================================

% Standalone fallbacks — only used if pv_model_main.m has not already run.
% Performance ratio 0.75 and 5.0 peak sun hours/day are conservative
% estimates appropriate for all three equatorial cities.
amp_pv_annual_yield_kwh =214858;
spiro_pv_annual_yield_kwh =80869;
zembo_pv_annual_yield_kwh =15654;

if ~exist('amp_pv_annual_yield_kwh', 'var')
    amp_pv_annual_yield_kwh   = amp_pv_system_power   / 1000 * 5.0 * 0.75 * 365;
end
if ~exist('spiro_pv_annual_yield_kwh', 'var')
    spiro_pv_annual_yield_kwh = spiro_pv_system_power / 1000 * 5.0 * 0.75 * 365;
end
if ~exist('zembo_pv_annual_yield_kwh', 'var')
    zembo_pv_annual_yield_kwh = zembo_pv_system_power / 1000 * 5.0 * 0.75 * 365;
end

% Year index vectors [1, 2, ..., N] — exponent is (t-1) so year 1 has
% zero degradation, year 20 has 19 years of 0.5%/yr loss (~9.5% total).
amp_years   = 1:amp_project_lifetime;
spiro_years = 1:spiro_project_lifetime;
zembo_years = 1:zembo_project_lifetime;

% Lifetime energy [kWh]: sum of annually degrading PV yield over N years.
amp_lifetime_energy   = sum(amp_pv_annual_yield_kwh   * (1 - amp_degradation)  .^ (amp_years   - 1));
spiro_lifetime_energy = sum(spiro_pv_annual_yield_kwh * (1 - spiro_degradation).^ (spiro_years - 1));
zembo_lifetime_energy = sum(zembo_pv_annual_yield_kwh * (1 - zembo_degradation).^ (zembo_years - 1));

% LCOE [$/kWh] = total lifetime cost / total lifetime energy.
amp_lcoe   = (amp_capex   + amp_opex   * amp_project_lifetime)   / amp_lifetime_energy;
spiro_lcoe = (spiro_capex + spiro_opex * spiro_project_lifetime) / spiro_lifetime_energy;
zembo_lcoe = (zembo_capex + zembo_opex * zembo_project_lifetime) / zembo_lifetime_energy;

fprintf('\n--- LCOE ($/kWh) ---\n')
fprintf('Ampersand: $%.4f  (lifetime energy: %.1f MWh)\n', amp_lcoe,   amp_lifetime_energy/1000)
fprintf('Spiro:     $%.4f  (lifetime energy: %.1f MWh)\n', spiro_lcoe, spiro_lifetime_energy/1000)
fprintf('Zembo:     $%.4f  (lifetime energy: %.1f MWh)\n', zembo_lcoe, zembo_lifetime_energy/1000)

%% =========================================================================
%  BLOCK 10 — LCOS (Levelised Cost of Storage)
%
%  LCOS = (ESS_CAPEX + OPEX x phi_ESS x N) / E_ESS   [$/kWh]
%
%  phi_ESS = ESS capital cost / total hardware cost
%    — fraction of total hardware value attributable to the stationary ESS.
%    — used to allocate a proportional share of annual OPEX to the ESS.
%    — approximation: assumes maintenance costs scale with asset value.
%
%  E_ESS = ESS size [kWh] x 1 cycle/day x 365 x N
%    — assumes one full charge-discharge cycle per day.
%    — the explicit "1" documents this assumption in the code.
% =========================================================================

% ESS fraction of hardware cost — the OPEX allocation weight.
amp_ess_opex_share   = amp_ess_total_cost   / amp_hardware_cost;
spiro_ess_opex_share = spiro_ess_total_cost / spiro_hardware_cost;
zembo_ess_opex_share = zembo_ess_total_cost / zembo_hardware_cost;

% Total ESS energy cycled [kWh] over the project lifetime.
amp_ess_energy   = amp_ess_size   * 1 * 365 * amp_project_lifetime;
spiro_ess_energy = spiro_ess_size * 1 * 365 * spiro_project_lifetime;
zembo_ess_energy = zembo_ess_size * 1 * 365 * zembo_project_lifetime;

% LCOS [$/kWh] = (ESS capital + ESS-allocated OPEX over lifetime) / E_ESS.
amp_lcos   = (amp_ess_total_cost   + amp_opex   * amp_ess_opex_share   * amp_project_lifetime)   / amp_ess_energy;
spiro_lcos = (spiro_ess_total_cost + spiro_opex * spiro_ess_opex_share * spiro_project_lifetime) / spiro_ess_energy;
zembo_lcos = (zembo_ess_total_cost + zembo_opex * zembo_ess_opex_share * zembo_project_lifetime) / zembo_ess_energy;

fprintf('\n--- LCOS ($/kWh) ---\n')
fprintf('Ampersand: $%.4f  (ESS share: %.1f%% of hardware)\n', amp_lcos,   amp_ess_opex_share*100)
fprintf('Spiro:     $%.4f  (ESS share: %.1f%% of hardware)\n', spiro_lcos, spiro_ess_opex_share*100)
fprintf('Zembo:     $%.4f  (ESS share: %.1f%% of hardware)\n', zembo_lcos, zembo_ess_opex_share*100)

%% =========================================================================
%  BLOCK 11 — FIGURES
%
%  Eight figures covering the full economic story:
%    Fig 1 — CAPEX breakdown         stacked horizontal bar
%    Fig 2 — Revenue vs OPEX         grouped bar + profit margin on twin y-axis
%    Fig 3 — Payback period          dot plot
%    Fig 4 — NPV comparison          dual-panel horizontal bar
%    Fig 5 — Cumulative cash flow    line chart
%    Fig 6 — LCOE and LCOS           horizontal lollipop


%
%  Shared conventions:
%    - Consistent operator colours: Ampersand=blue, Spiro=orange, Zembo=green
%    - xlim/ylim always set explicitly — MATLAB auto-scaling clips labels
%    - Legend only in Fig 1; all other figures use direct text() labels
%    - All figures exported at 300 DPI for print quality
%    - box(ax,'off') removes top and right border lines for a cleaner look
% =========================================================================

% Cell array of operator name strings for axis tick labels.
% Curly braces {} create a cell array — holds strings of different lengths.
operators = {'Ampersand', 'Spiro', 'Zembo'};

% Operator colour matrix [R G B] per row, values in [0,1].
% Consistent across all figures so readers identify operators by colour.
colors = [0.20 0.47 0.75;   % blue   — Ampersand
          0.90 0.45 0.18;   % orange — Spiro
          0.27 0.65 0.38];  % green  — Zembo

% -----------------------------------------------------------------------
%  FIGURE 1 — CAPEX breakdown: stacked horizontal bar
%
%  Why horizontal: operator names fit cleanly on the y-axis without rotation.
%  Why stacked not grouped: shows total CAPEX decomposition — the primary
%  question. Battery inventory is visually dominant in all three operators.
%
%  capex_components is a 3x4 matrix (rows=operators, cols=components).
%  barh(data,'stacked') maps each row to one bar, each column to one segment.
% -----------------------------------------------------------------------

% 3x4 data matrix: each entry is one cost component for one operator.
capex_components = [
    amp_docking_cabinets   * amp_cost_per_cabinet,   amp_pv_cost,   amp_ess_total_cost,   amp_battery_inventory_cost;
    spiro_docking_cabinets * spiro_cost_per_cabinet, spiro_pv_cost, spiro_ess_total_cost, spiro_battery_inventory_cost;
    zembo_docking_cabinets * zembo_cost_per_cabinet, zembo_pv_cost, zembo_ess_total_cost, zembo_battery_inventory_cost
];

% Component colours — independent of operator colours to avoid confusion.
comp_colors = [0.30 0.60 0.90;   % light blue — Cabinets
               0.98 0.80 0.20;   % yellow     — PV system
               0.45 0.78 0.50;   % green      — ESS buffer
               0.88 0.38 0.30];  % red        — Battery inventory

% figure('Position',[left bottom width height]) in screen pixels.
% 'Color','white' ensures clean white background on PDF export.
figure('Position', [100 100 680 320], 'Color', 'white');

% axes('Position',[left bottom width height]) in normalised [0,1] units.
% Left margin 0.18 = room for operator name labels on y-axis.
% Bottom margin 0.20 = room for the legend placed southoutside.
ax1 = axes('Position', [0.18 0.20 0.78 0.68]);

% barh returns b1, a 1x4 array of bar series objects (one per column).
b1 = barh(ax1, capex_components, 'stacked');
for k = 1:4
    b1(k).FaceColor = comp_colors(k,:);
end

set(ax1, 'YTick', 1:3, 'YTickLabel', operators, 'FontSize', 12)
xlabel(ax1, 'Cost (USD)', 'FontSize', 13)
title(ax1, 'CAPEX Breakdown by Operator (excl. installation overhead)', 'FontSize', 13)

% sum(matrix,2) sums across columns giving one hardware total per operator.
row_totals = sum(capex_components, 2);
xlim(ax1, [0, max(row_totals) * 1.18])   % 18% headroom so tips don't clip

% 'southoutside' places the legend below the axes — never overlaps bars.
lg1 = legend(ax1, {'Cabinets','PV System','ESS Buffer','Battery Inventory'}, ...
             'Orientation', 'horizontal', 'FontSize', 10, 'Box', 'off');
lg1.Location = 'southoutside';

grid(ax1, 'on'); box(ax1, 'off')
exportgraphics(gcf, 'capex_breakdown.pdf', 'Resolution', 300)

% -----------------------------------------------------------------------
%  FIGURE 2 — Revenue vs OPEX: grouped bar with profit margin overlay
%
%  Twin-axis technique: ax2R is positioned identically to ax2L with
%  'Color','none' (transparent) so ax2L bars show through it, and
%  'YAxisLocation','right' to place its scale on the right side.
%  linkaxes locks the x-axes together so both layers always align.
%  Direct text labels replace a legend box to avoid bar overlap.
% -----------------------------------------------------------------------

figure('Position', [80 100 620 420], 'Color', 'white');
ax2L = axes('Position', [0.16 0.13 0.72 0.75]);

rev_vals    = [amp_annual_revenue;  spiro_annual_revenue;  zembo_annual_revenue];
opex_vals   = [amp_opex;            spiro_opex;            zembo_opex];
margin_vals = [amp_profit_margin;   spiro_profit_margin;   zembo_profit_margin];

% [rev_vals, opex_vals] is Nx2 — bar(data,'grouped') puts side-by-side bars.
b2 = bar(ax2L, [rev_vals, opex_vals], 'grouped');
b2(1).FaceColor = [0.25 0.55 0.85];   % blue — Revenue
b2(2).FaceColor = [0.85 0.28 0.28];   % red  — OPEX

set(ax2L, 'XTick', 1:3, 'XTickLabel', operators, 'FontSize', 12)
ylabel(ax2L, 'USD / year', 'FontSize', 13)
title(ax2L, 'Annual Revenue vs OPEX  |  Profit Margin', 'FontSize', 14)
ylim(ax2L, [0, max(rev_vals) * 1.22])

% Transparent overlay axes for the right-side profit margin scale.
ax2R = axes('Position', ax2L.Position, 'Color', 'none', 'YAxisLocation', 'right');
hold(ax2R, 'on')
% 'k-o' = black solid line, circle markers. MarkerFaceColor 'k' = filled.
plot(ax2R, 1:3, margin_vals, 'k-o', 'LineWidth', 1.8, 'MarkerFaceColor', 'k', 'MarkerSize', 7)
ylabel(ax2R, 'Profit Margin (%)', 'FontSize', 13)
set(ax2R, 'XTick', [], 'FontSize', 12)
ylim(ax2R, [0, max(margin_vals) * 1.4])
linkaxes([ax2L ax2R], 'x')

text(ax2L, 0.72, max(rev_vals)*1.14, 'Revenue', 'Color', [0.25 0.55 0.85], 'FontSize', 10, 'FontWeight', 'bold')
text(ax2L, 0.72, max(rev_vals)*1.06, 'OPEX',    'Color', [0.85 0.28 0.28], 'FontSize', 10, 'FontWeight', 'bold')

grid(ax2L, 'on'); box(ax2L, 'off')
exportgraphics(gcf, 'revenue_vs_opex.pdf', 'Resolution', 300)

% -----------------------------------------------------------------------
%  FIGURE 3 — Payback period: dot plot
%
%  Why dot plot not bar chart: three single values — bars add visual weight
%  without information gain. Dot + guide line + label is cleaner.
%
%  Three drawing operations per operator:
%    1. Dotted guide line from x=0 to dot (helps read against x-axis)
%    2. Filled scatter marker at (payback, row)
%    3. Text label nudged right of the dot
% -----------------------------------------------------------------------

figure('Position', [100 100 560 280], 'Color', 'white');
ax3 = axes('Position', [0.18 0.15 0.65 0.72]);
paybacks = [amp_payback; spiro_payback; zembo_payback];
hold(ax3, 'on')

for i = 1:3
    % Guide line: [0 value] on x, same y both ends = horizontal dotted line.
    plot(ax3, [0 paybacks(i)], [i i], ':', 'Color', [0.75 0.75 0.75], 'LineWidth', 1)
    % Dot: 140pt^2 marker, operator colour, white border clears the guide line.
    scatter(ax3, paybacks(i), i, 140, colors(i,:), 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 1)
    % Label: 4% of x-range to the right of the dot.
    text(ax3, paybacks(i) + max(paybacks)*0.04, i, sprintf('%.2f yr', paybacks(i)), ...
        'VerticalAlignment', 'middle', 'FontSize', 11, 'Color', colors(i,:), 'FontWeight', 'bold')
end

set(ax3, 'YTick', 1:3, 'YTickLabel', operators, 'FontSize', 12, 'XGrid', 'on')
xlabel(ax3, 'Payback Period (years)', 'FontSize', 13)
title(ax3, 'Simple Payback Period by Operator', 'FontSize', 14)
xlim(ax3, [0, max(paybacks) * 1.35])
ylim(ax3, [0.3, 3.7])
box(ax3, 'off')
exportgraphics(gcf, 'payback_period.pdf', 'Resolution', 300)

% -----------------------------------------------------------------------
%  FIGURE 4 — NPV comparison: dual-panel horizontal bar
%
%  NPV values span orders of magnitude — a single axis makes the smallest
%  bar invisible. Two panels: left=full scale, right=zoomed to smallest.
%
%  fmtdollar: regex inserts comma separators into a dollar string.
%    sprintf('$%.0f',x) -> "$2303801"
%    regexprep with lookahead pattern -> "$2,303,801"
%
%  FaceAlpha trick: bars exceeding the zoom window are faded to 0.4
%  opacity; the zoomed bar is at 1.0. (i==zoom_idx) = 1 for target, 0 for others.
% -----------------------------------------------------------------------

fmtdollar = @(x) regexprep(sprintf('$%.0f', abs(x)), '(\d)(?=(\d{3})+(?!\d))', '$1,');

figure('Position', [100 100 520 480], 'Color', 'white');
npvs = [amp_npv; spiro_npv; zembo_npv];

% Left panel — full scale, all operators at true relative size.
ax4a = axes('Position', [0.12 0.15 0.50 0.72]);
hold(ax4a, 'on')
for i = 1:3
    barh(ax4a, i, npvs(i), 0.52, 'FaceColor', colors(i,:), 'EdgeColor', 'none')
end
xline(ax4a, 0, 'k-', 'LineWidth', 1.4)   % NPV = 0 viability threshold
set(ax4a, 'YTick', 1:3, 'YTickLabel', operators, 'FontSize', 12)
xlabel(ax4a, 'NPV (USD)', 'FontSize', 12)
title(ax4a, 'Net Present Value — Full Scale', 'FontSize', 13)
margin4a = max(abs(npvs)) * 0.25;
xlim(ax4a, [min([npvs; 0]) - margin4a, max(npvs) + margin4a])
ylim(ax4a, [0.4, 3.6])
for i = 1:3
    lbl = fmtdollar(npvs(i));
    if npvs(i) < 0; lbl = ['-' lbl]; end
    if npvs(i) >= 0
        text(ax4a, npvs(i) + max(abs(npvs))*0.03, i, lbl, 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'FontWeight', 'bold')
    else
        text(ax4a, npvs(i) - max(abs(npvs))*0.03, i, lbl, 'VerticalAlignment', 'middle', 'HorizontalAlignment', 'right', 'FontSize', 9.5, 'FontWeight', 'bold')
    end
end
grid(ax4a, 'on'); box(ax4a, 'off')

% Right panel — zoomed to 2.5x the smallest NPV so it fills the panel.
[~, zoom_idx] = min(abs(npvs));   % ~ discards min value, we only need the index
zoom_max = abs(npvs(zoom_idx)) * 2.5;

% ax4b = axes('Position', [0.70 0.15 0.26 0.72]);
% hold(ax4b, 'on')
% for i = 1:3
%     barh(ax4b, i, min(npvs(i), zoom_max * 0.98), 0.52, ...
%         'FaceColor', colors(i,:), 'EdgeColor', 'none', ...
%         'FaceAlpha', 0.4 + 0.6*(i == zoom_idx))
% end
% xline(ax4b, 0, 'k-', 'LineWidth', 1.4)
% for i = 1:3
%     if npvs(i) > zoom_max
%         text(ax4b, zoom_max * 0.96, i, ' >', 'FontSize', 10, 'Color', colors(i,:), 'VerticalAlignment', 'middle', 'FontWeight', 'bold')
%     end
% end
% lbl_z = fmtdollar(npvs(zoom_idx));
% text(ax4b, npvs(zoom_idx) + zoom_max*0.05, zoom_idx, lbl_z, 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'FontWeight', 'bold', 'Color', colors(zoom_idx,:))
% set(ax4b, 'YTick', 1:3, 'YTickLabel', operators, 'FontSize', 11)
% xlabel(ax4b, 'NPV (USD)', 'FontSize', 12)
% title(ax4b, 'Zoomed View', 'FontSize', 13)
% xlim(ax4b, [0, zoom_max]); ylim(ax4b, [0.4, 3.6])
% grid(ax4b, 'on'); box(ax4b, 'off')
% 
% % Dashed vertical separator between panels, in figure-normalised coordinates.
% annotation(gcf, 'line', [0.645 0.645], [0.1 0.95], 'Color', [0.7 0.7 0.7], 'LineStyle', '--', 'LineWidth', 1)
exportgraphics(gcf, 'npv_comparison.pdf', 'Resolution', 300)

% -----------------------------------------------------------------------
%  FIGURE 5 — Cumulative cash flow: line chart
%
%  cumsum(v) converts annual cash flows to a running total.
%  The y=0 crossing is the payback year — cumulative returns recover CAPEX.
%
%  Three line styles (solid/dashed/dotted) ensure the figure is readable
%  in greyscale print as well as colour.
%
%  Vertical offsets stagger the end-of-line operator labels so they
%  do not stack on top of each other at x=20 (all lifetimes are equal).
% -----------------------------------------------------------------------

years_amp   = 0:amp_project_lifetime;
years_spiro = 0:spiro_project_lifetime;
years_zembo = 0:zembo_project_lifetime;

% cumsum: running total from year 0 (-CAPEX) through year N.
cum_amp   = cumsum(amp_cashflows);
cum_spiro = cumsum(spiro_cashflows);
cum_zembo = cumsum(zembo_cashflows);

figure('Position', [100 100 720 440], 'Color', 'white');
ax5 = axes('Position', [0.10 0.12 0.76 0.78]);
hold(ax5, 'on')

plot(ax5, years_amp,   cum_amp,   '-',  'Color', colors(1,:), 'LineWidth', 2.2)
plot(ax5, years_spiro, cum_spiro, '--', 'Color', colors(2,:), 'LineWidth', 2.2)
plot(ax5, years_zembo, cum_zembo, ':',  'Color', colors(3,:), 'LineWidth', 2.2)

% Break-even reference at y=0, slightly transparent so it reads as background.
yline(ax5, 0, '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 1, 'Alpha', 0.6)

% Staggered end-of-line labels — offsets prevent stacking at x=20.
all_end_y = [cum_amp(end), cum_spiro(end), cum_zembo(end)];
end_yrs   = [amp_project_lifetime, spiro_project_lifetime, zembo_project_lifetime];
cf_pad    = max(abs([cum_amp, cum_spiro, cum_zembo])) * 0.14;
v_offsets = [cf_pad * 0.35, 0, -cf_pad * 0.35];

for i = 1:3
    text(ax5, end_yrs(i) + 0.4, all_end_y(i) + v_offsets(i), operators{i}, ...
        'Color', colors(i,:), 'FontSize', 11, 'FontWeight', 'bold', 'VerticalAlignment', 'middle')
end

set(ax5, 'FontSize', 12)
xlabel(ax5, 'Year', 'FontSize', 13)
ylabel(ax5, 'Cumulative Cash Flow (USD)', 'FontSize', 13)
title(ax5, 'Cumulative Cash Flow Over Project Lifetime', 'FontSize', 14)
max_yr = max([amp_project_lifetime, spiro_project_lifetime, zembo_project_lifetime]);
xlim(ax5, [0, max_yr + 3])
all_cf = [cum_amp, cum_spiro, cum_zembo];
ylim(ax5, [min([all_cf, 0]) - cf_pad, max(all_cf) + cf_pad])
grid(ax5, 'on'); box(ax5, 'off')
exportgraphics(gcf, 'cashflow_cumulative.pdf', 'Resolution', 300)

% -----------------------------------------------------------------------
%  FIGURE 6 — LCOE and LCOS: horizontal lollipop
%
%  Why lollipop not bar: values are small and close together ($0.10-$0.60).
%  Bars at these scales have low visual contrast. A thin stick + dot shows
%  the same information with far less ink, making differences clearer.
%
%  Two lollipops per operator at offset y-positions:
%    LCOE at y = i + 0.20 (above operator row)
%    LCOS at y = i - 0.20 (below operator row)
%  Colour encodes metric (blue=LCOE, red=LCOS), not operator.
% -----------------------------------------------------------------------

figure('Position', [100 100 640 340], 'Color', 'white');
ax6 = axes('Position', [0.18 0.14 0.70 0.74]);
hold(ax6, 'on')

lcoes  = [amp_lcoe,  spiro_lcoe,  zembo_lcoe];
lcoss  = [amp_lcos,  spiro_lcos,  zembo_lcos];
c_lcoe = [0.20 0.47 0.75];   % blue — LCOE
c_lcos = [0.88 0.38 0.30];   % red  — LCOS
offset = 0.20;

for i = 1:3
    y_lcoe = i + offset;
    y_lcos = i - offset;
    % Stick: horizontal line from x=0 to value.
    % Head: filled circle, white border separates it from the stick.
    plot(ax6, [0 lcoes(i)], [y_lcoe y_lcoe], '-', 'Color', c_lcoe, 'LineWidth', 2)
    scatter(ax6, lcoes(i), y_lcoe, 90, c_lcoe, 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.8)
    plot(ax6, [0 lcoss(i)], [y_lcos y_lcos], '-', 'Color', c_lcos, 'LineWidth', 2)
    scatter(ax6, lcoss(i), y_lcos, 90, c_lcos, 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 0.8)
end

% Labels at dot tips — 3% of x-range to the right to clear the dot.
all_vals = [lcoes, lcoss];
tip_pad  = max(all_vals) * 0.03;
for i = 1:3
    text(ax6, lcoes(i) + tip_pad, i + offset, sprintf('LCOE  $%.3f', lcoes(i)), ...
        'Color', c_lcoe, 'FontSize', 9.5, 'VerticalAlignment', 'middle', 'FontWeight', 'bold')
    text(ax6, lcoss(i) + tip_pad, i - offset, sprintf('LCOS  $%.3f', lcoss(i)), ...
        'Color', c_lcos, 'FontSize', 9.5, 'VerticalAlignment', 'middle', 'FontWeight', 'bold')
end

set(ax6, 'YTick', 1:3, 'YTickLabel', operators, 'FontSize', 12, 'XGrid', 'on')
xlabel(ax6, '$/kWh', 'FontSize', 13)
title(ax6, 'Levelised Cost of Energy & Storage by Operator', 'FontSize', 14)
xlim(ax6, [0, max(all_vals) * 1.55])
ylim(ax6, [0.5, 3.5])
box(ax6, 'off')
exportgraphics(gcf, 'lcoe_lcos.pdf', 'Resolution', 300)

% ----------------------------------------------------------------------


fprintf('\nAll figures saved.\n')