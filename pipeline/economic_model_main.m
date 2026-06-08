% =========================================================================
%  economic_model_main.m  —  PIPELINE VERSION
%
%  PURPOSE:
%    Comparative financial analysis of three African e-motorcycle battery
%    swap station operators: Ampersand (Kigali), Spiro (Lagos), Zembo (Kampala).
%    Computes CAPEX, OPEX, revenue, profit, NPV, IRR, payback, LCOE, LCOS.
%
%  PIPELINE POSITION:
%    Run AFTER  pv_modelmain.m       (needs amp/spiro/zembo_pv_annual_yield_kwh)
%    Run AFTER  sim() loop in main.m (needs amp/spiro/zembo_sim_swaps_per_day)
%    Run BEFORE sensitivity_analysis.m (exports all financial metrics)
%    DO NOT add clc/clear/close — workspace must carry over from pipeline.
%
%  SENSITIVITY ANALYSIS INTERFACE:
%    This script reads ALL parameters from workspace variables, NOT from CSV.
%    CSV loading is done ONCE in Block 1 (only if variables not already set).
%    sensitivity_analysis.m overrides specific workspace variables BEFORE
%    calling this script — those overrides are respected throughout.
%
%  OUTPUTS — all financial metrics written to workspace:
%    amp/spiro/zembo_capex          [scalar, USD]
%    amp/spiro/zembo_opex           [scalar, USD/yr]
%    amp/spiro/zembo_annual_revenue [scalar, USD/yr]
%    amp/spiro/zembo_annual_profit  [scalar, USD/yr]
%    amp/spiro/zembo_profit_margin  [scalar, fraction]
%    amp/spiro/zembo_payback        [scalar, years]
%    amp/spiro/zembo_npv            [scalar, USD]
%    amp/spiro/zembo_irr            [scalar, fraction]
%    amp/spiro/zembo_lcoe           [scalar, USD/kWh]
%    amp/spiro/zembo_lcos           [scalar, USD/kWh]
% =========================================================================

%% Block 1 — Load base case parameters from CSV (only if not already in workspace)
%
%  This block runs ONLY on first call from main.m.
%  On subsequent calls from sensitivity_analysis.m the variables already
%  exist in the workspace and CSV is NOT re-read — preserving overrides.

if ~exist('eco_params_loaded', 'var') || eco_params_loaded == false

    amp   = readtable('ampersand_data.csv', 'TextType', 'string');
    spiro = readtable('spiro_data.csv',     'TextType', 'string');
    zembo = readtable('zembo_data.csv',     'TextType', 'string');

    getparam = @(t, name) t.Value(t.Parameter == name);

    % Battery capacities [kWh]
    amp_battery_capacity   = getparam(amp,   'Battery capacity');   % 2.88
    spiro_battery_capacity = getparam(spiro, 'Battery capacity');   % 3.40
    zembo_battery_capacity = getparam(zembo, 'Battery capacity');   % 2.70

    % Swap prices [USD/swap]
    amp_swap_price   = getparam(amp,   'Swap price');   % $1.60
    spiro_swap_price = getparam(spiro, 'Swap price');   % $3.50
    zembo_swap_price = getparam(zembo, 'Swap price');   % $1.65

    % Swaps per day per station
    amp_swaps_per_day   = getparam(amp,   'Swaps per day per station');   % 565
    spiro_swaps_per_day = getparam(spiro, 'Swaps per day per station');   % 180
    zembo_swaps_per_day = getparam(zembo, 'Swaps per day per station');   % 44

    % Docking cabinets
    amp_docking_cabinets   = getparam(amp,   'Docking cabinets');   % 5
    spiro_docking_cabinets = getparam(spiro, 'Docking cabinets');   % 5
    zembo_docking_cabinets = getparam(zembo, 'Docking cabinets');   % 3

    amp_cost_per_cabinet   = getparam(amp,   'Cost per docking cabinet');   % $3500
    spiro_cost_per_cabinet = getparam(spiro, 'Cost per docking cabinet');   % $3500
    zembo_cost_per_cabinet = getparam(zembo, 'Cost per docking cabinet');   % $3500

    % PV system
    amp_pv_system_power   = getparam(amp,   'PV system rated power');   % 37000 Wp
    spiro_pv_system_power = getparam(spiro, 'PV system rated power');   % 37000 Wp
    zembo_pv_system_power = getparam(zembo, 'PV system rated power');   % 37000 Wp

    amp_pv_installed_cost   = getparam(amp,   'PV installed cost');   % $1.30/Wp
    spiro_pv_installed_cost = getparam(spiro, 'PV installed cost');   % $1.30/Wp
    zembo_pv_installed_cost = getparam(zembo, 'PV installed cost');   % $1.30/Wp

    % ESS
    amp_ess_size   = getparam(amp,   'ESS size');   % 43 kWh
    spiro_ess_size = getparam(spiro, 'ESS size');   % 43 kWh
    zembo_ess_size = getparam(zembo, 'ESS size');   % 43 kWh

    amp_ess_cost_per_kwh   = getparam(amp,   'ESS cost');   % $300/kWh
    spiro_ess_cost_per_kwh = getparam(spiro, 'ESS cost');   % $300/kWh
    zembo_ess_cost_per_kwh = getparam(zembo, 'ESS cost');   % $300/kWh

    % Battery inventory
    amp_battery_inventory_count   = getparam(amp,   'Battery inventory count');   % 150
    spiro_battery_inventory_count = getparam(spiro, 'Battery inventory count');   % 135
    zembo_battery_inventory_count = getparam(zembo, 'Battery inventory count');   % 33

    % Project costs
    amp_installation_overhead   = getparam(amp,   'Installation overhead');   % 0.20
    spiro_installation_overhead = getparam(spiro, 'Installation overhead');   % 0.20
    zembo_installation_overhead = getparam(zembo, 'Installation overhead');   % 0.20

    amp_annual_om_rate   = getparam(amp,   'Annual OM rate');   % 0.025
    spiro_annual_om_rate = getparam(spiro, 'Annual OM rate');   % 0.025
    zembo_annual_om_rate = getparam(zembo, 'Annual OM rate');   % 0.025

    amp_annual_staff_cost   = getparam(amp,   'Annual staff cost');   % $2400
    spiro_annual_staff_cost = getparam(spiro, 'Annual staff cost');   % $3000
    zembo_annual_staff_cost = getparam(zembo, 'Annual staff cost');   % $2000

    % Financial parameters
    amp_discount_rate   = getparam(amp,   'Discount rate');   % 0.10
    spiro_discount_rate = getparam(spiro, 'Discount rate');   % 0.10
    zembo_discount_rate = getparam(zembo, 'Discount rate');   % 0.10

    amp_project_lifetime   = getparam(amp,   'Project lifetime');   % 20 years
    spiro_project_lifetime = getparam(spiro, 'Project lifetime');   % 20 years
    zembo_project_lifetime = getparam(zembo, 'Project lifetime');   % 20 years

    amp_degradation   = getparam(amp,   'Panel degradation rate');   % 0.005
    spiro_degradation = getparam(spiro, 'Panel degradation rate');   % 0.005
    zembo_degradation = getparam(zembo, 'Panel degradation rate');   % 0.005

    eco_params_loaded = true;
    fprintf('Block 1: Parameters loaded from CSV.\n')

else
    fprintf('Block 1: Using existing workspace parameters (sensitivity override active).\n')
end

%% Block 2 — Derived cost components
%
%  Computed from workspace parameters — respects any sensitivity overrides.

amp_pv_cost   = amp_pv_installed_cost   * amp_pv_system_power;
spiro_pv_cost = spiro_pv_installed_cost * spiro_pv_system_power;
zembo_pv_cost = zembo_pv_installed_cost * zembo_pv_system_power;

amp_ess_total_cost   = amp_ess_cost_per_kwh   * amp_ess_size;
spiro_ess_total_cost = spiro_ess_cost_per_kwh * spiro_ess_size;
zembo_ess_total_cost = zembo_ess_cost_per_kwh * zembo_ess_size;

amp_battery_inventory_cost   = amp_battery_inventory_count   * amp_battery_capacity   * amp_ess_cost_per_kwh;
spiro_battery_inventory_cost = spiro_battery_inventory_count * spiro_battery_capacity * spiro_ess_cost_per_kwh;
zembo_battery_inventory_cost = zembo_battery_inventory_count * zembo_battery_capacity * zembo_ess_cost_per_kwh;

%% Block 3 — CAPEX
%
%  Hardware cost = docking cabinets + PV system + stationary ESS + battery inventory
%  CAPEX = hardware cost x (1 + installation overhead)

amp_hardware_cost   = (amp_docking_cabinets   * amp_cost_per_cabinet)   ...
                    + amp_pv_cost   + amp_ess_total_cost   + amp_battery_inventory_cost;
spiro_hardware_cost = (spiro_docking_cabinets * spiro_cost_per_cabinet) ...
                    + spiro_pv_cost + spiro_ess_total_cost + spiro_battery_inventory_cost;
zembo_hardware_cost = (zembo_docking_cabinets * zembo_cost_per_cabinet) ...
                    + zembo_pv_cost + zembo_ess_total_cost + zembo_battery_inventory_cost;

amp_capex   = amp_hardware_cost   * (1 + amp_installation_overhead);
spiro_capex = spiro_hardware_cost * (1 + spiro_installation_overhead);
zembo_capex = zembo_hardware_cost * (1 + zembo_installation_overhead);

%% Block 4 — OPEX (Annual)
%
%  Annual OPEX = (CAPEX x O&M rate) + annual staff cost

amp_opex   = (amp_capex   * amp_annual_om_rate)   + amp_annual_staff_cost;
spiro_opex = (spiro_capex * spiro_annual_om_rate) + spiro_annual_staff_cost;
zembo_opex = (zembo_capex * zembo_annual_om_rate) + zembo_annual_staff_cost;

%% Block 5 — Revenue (Annual)
%
%  Annual revenue = swap_price x swaps_per_day x 365

amp_annual_revenue = amp_swap_price * amp_swaps_per_day * (1 - amp_queue_loss_fraction) * 365;
spiro_annual_revenue = spiro_swap_price * spiro_swaps_per_day * (1 - spiro_queue_loss_fraction) * 365;
zembo_annual_revenue = zembo_swap_price * zembo_swaps_per_day * (1 - zembo_queue_loss_fraction) * 365;

%% Block 6 — Profit and Profit Margin

amp_annual_profit   = amp_annual_revenue   - amp_opex;
spiro_annual_profit = spiro_annual_revenue - spiro_opex;
zembo_annual_profit = zembo_annual_revenue - zembo_opex;

amp_profit_margin   = (amp_annual_profit   / amp_annual_revenue)   * 100;
spiro_profit_margin = (spiro_annual_profit / spiro_annual_revenue) * 100;
zembo_profit_margin = (zembo_annual_profit / zembo_annual_revenue) * 100;

%% Block 7 — Payback Period

amp_payback   = amp_capex   / amp_annual_profit;
spiro_payback = spiro_capex / spiro_annual_profit;
zembo_payback = zembo_capex / zembo_annual_profit;

%% Block 8 — NPV and IRR

amp_cashflows   = [-amp_capex,   repmat(amp_annual_profit,   1, amp_project_lifetime)];
spiro_cashflows = [-spiro_capex, repmat(spiro_annual_profit, 1, spiro_project_lifetime)];
zembo_cashflows = [-zembo_capex, repmat(zembo_annual_profit, 1, zembo_project_lifetime)];

amp_npv   = sum(amp_cashflows   ./ (1 + amp_discount_rate)  .^ (0:amp_project_lifetime));
spiro_npv = sum(spiro_cashflows ./ (1 + spiro_discount_rate).^ (0:spiro_project_lifetime));
zembo_npv = sum(zembo_cashflows ./ (1 + zembo_discount_rate).^ (0:zembo_project_lifetime));

try
    amp_irr   = irr(amp_cashflows);
    spiro_irr = irr(spiro_cashflows);
    zembo_irr = irr(zembo_cashflows);
catch
    % fzero fallback if Financial Toolbox unavailable
    amp_irr   = fzero(@(r) sum(amp_cashflows   ./ (1+r).^(0:amp_project_lifetime)),   0.1);
    spiro_irr = fzero(@(r) sum(spiro_cashflows ./ (1+r).^(0:spiro_project_lifetime)), 0.1);
    zembo_irr = fzero(@(r) sum(zembo_cashflows ./ (1+r).^(0:zembo_project_lifetime)), 0.1);
end

%% Block 9 — LCOE

amp_years   = 1:amp_project_lifetime;
spiro_years = 1:spiro_project_lifetime;
zembo_years = 1:zembo_project_lifetime;

amp_lifetime_energy   = sum(amp_pv_annual_yield_kwh   * (1 - amp_degradation)  .^(amp_years   - 1));
spiro_lifetime_energy = sum(spiro_pv_annual_yield_kwh * (1 - spiro_degradation).^(spiro_years - 1));
zembo_lifetime_energy = sum(zembo_pv_annual_yield_kwh * (1 - zembo_degradation).^(zembo_years - 1));

amp_lcoe   = (amp_capex   + amp_opex   * amp_project_lifetime)   / amp_lifetime_energy;
spiro_lcoe = (spiro_capex + spiro_opex * spiro_project_lifetime) / spiro_lifetime_energy;
zembo_lcoe = (zembo_capex + zembo_opex * zembo_project_lifetime) / zembo_lifetime_energy;

%% Block 10 — LCOS

amp_ess_opex_share   = amp_ess_total_cost   / amp_hardware_cost;
spiro_ess_opex_share = spiro_ess_total_cost / spiro_hardware_cost;
zembo_ess_opex_share = zembo_ess_total_cost / zembo_hardware_cost;

amp_ess_energy   = amp_ess_size   * 365 * amp_project_lifetime;
spiro_ess_energy = spiro_ess_size * 365 * spiro_project_lifetime;
zembo_ess_energy = zembo_ess_size * 365 * zembo_project_lifetime;

amp_lcos   = (amp_ess_total_cost   + amp_opex   * amp_ess_opex_share   * amp_project_lifetime)   / amp_ess_energy;
spiro_lcos = (spiro_ess_total_cost + spiro_opex * spiro_ess_opex_share * spiro_project_lifetime) / spiro_ess_energy;
zembo_lcos = (zembo_ess_total_cost + zembo_opex * zembo_ess_opex_share * zembo_project_lifetime) / zembo_ess_energy;

%% Block 11 — Summary Table

fprintf('\n========= ECONOMIC MODEL SUMMARY =========\n')
fprintf('%-30s %12s %12s %12s\n', 'Metric', 'Ampersand', 'Spiro', 'Zembo')
fprintf('%s\n', repmat('-', 1, 66))
fprintf('%-30s %12.0f %12.0f %12.0f\n', 'CAPEX ($)',            amp_capex,           spiro_capex,           zembo_capex)
fprintf('%-30s %12.0f %12.0f %12.0f\n', 'Annual OPEX ($)',      amp_opex,            spiro_opex,            zembo_opex)
fprintf('%-30s %12.0f %12.0f %12.0f\n', 'Annual Revenue ($)',   amp_annual_revenue,  spiro_annual_revenue,  zembo_annual_revenue)
fprintf('%-30s %12.0f %12.0f %12.0f\n', 'Annual Profit ($)',    amp_annual_profit,   spiro_annual_profit,   zembo_annual_profit)
fprintf('%-30s %12.1f %12.1f %12.1f\n', 'Profit Margin (%%)',   amp_profit_margin,   spiro_profit_margin,   zembo_profit_margin)
fprintf('%-30s %12.2f %12.2f %12.2f\n', 'Payback Period (yr)',  amp_payback,         spiro_payback,         zembo_payback)
fprintf('%-30s %12.0f %12.0f %12.0f\n', 'NPV ($)',              amp_npv,             spiro_npv,             zembo_npv)
fprintf('%-30s %12.1f %12.1f %12.1f\n', 'IRR (%%)',             amp_irr*100,         spiro_irr*100,         zembo_irr*100)
fprintf('%-30s %12.4f %12.4f %12.4f\n', 'LCOE ($/kWh)',         amp_lcoe,            spiro_lcoe,            zembo_lcoe)
fprintf('%-30s %12.4f %12.4f %12.4f\n', 'LCOS ($/kWh)',         amp_lcos,            spiro_lcos,            zembo_lcos)