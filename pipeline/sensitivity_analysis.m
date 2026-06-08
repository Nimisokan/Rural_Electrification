%% =========================================================================
%  sensitivity_analysis.m
%
%  PURPOSE:
%    Sweeps key parameters one at a time around the base case and evaluates
%    the effect on NPV, IRR, payback, and LCOE for all three operators.
%    Generates report-quality figures including tornado diagrams.
%
%  PIPELINE POSITION:
%    Run AFTER main.m — base case workspace must be populated.
%    Overrides specific workspace variables, reruns economic_model_main.m,
%    then restores base case. Does NOT call sim() or pv_modelmain.m
%    (except for discharge fraction sweep which needs pv_model_main.m).
%
%  SWEEPS:
%    1.  Discount rate            [0.08 to 0.20]
%    2.  Swap price               [per operator ranges]
%    3.  PV installed cost        [$0.80 to $1.30/Wp]
%    4.  Discharge fraction       [0.25 to 0.50]
%    5.  O&M rate                 [2.5% to 15%]
%    6.  Spiro demand growth      [180 to 1000 swaps/day]
%    7.  Ampersand network scale  [200 to 565 swaps/day]
%    8.  Installation overhead    [20% to 40%] — rural deployment context
%    9.  Rural deployment         Zembo at 20 swaps/day, 20% discount, 15% O&M
%    10. Lagos rainy season       20% demand reduction June-August (illustrative)
%
%  OUTPUTS:
%    Figures saved as PDFs for report
%    All sensitivity results in workspace struct: sens
% =========================================================================

fprintf('\n=== SENSITIVITY ANALYSIS START ===\n\n');

eco_params_loaded = false;
run('economic_model_main.m');

%% =========================================================================
%  SETUP — save base case values
% =========================================================================

base.amp_npv     = amp_npv;
base.spiro_npv   = spiro_npv;
base.zembo_npv   = zembo_npv;
base.amp_payback   = amp_payback;
base.spiro_payback = spiro_payback;
base.zembo_payback = zembo_payback;
base.amp_lcoe   = amp_lcoe;
base.spiro_lcoe = spiro_lcoe;
base.zembo_lcoe = zembo_lcoe;
base.amp_irr   = amp_irr;
base.spiro_irr = spiro_irr;
base.zembo_irr = zembo_irr;

base.amp_discount_rate   = amp_discount_rate;
base.spiro_discount_rate = spiro_discount_rate;
base.zembo_discount_rate = zembo_discount_rate;
base.amp_swap_price   = amp_swap_price;
base.spiro_swap_price = spiro_swap_price;
base.zembo_swap_price = zembo_swap_price;
base.amp_pv_installed_cost   = amp_pv_installed_cost;
base.spiro_pv_installed_cost = spiro_pv_installed_cost;
base.zembo_pv_installed_cost = zembo_pv_installed_cost;
base.discharge_fraction      = discharge_fraction;
base.amp_annual_om_rate   = amp_annual_om_rate;
base.spiro_annual_om_rate = spiro_annual_om_rate;
base.zembo_annual_om_rate = zembo_annual_om_rate;
base.amp_swaps_per_day   = amp_swaps_per_day;
base.spiro_swaps_per_day = spiro_swaps_per_day;
base.zembo_swaps_per_day = zembo_swaps_per_day;
base.amp_installation_overhead   = amp_installation_overhead;
base.spiro_installation_overhead = spiro_installation_overhead;
base.zembo_installation_overhead = zembo_installation_overhead;

fprintf('Base case saved.\n\n');

colors = [0.20 0.47 0.75;   % blue   — Ampersand
          0.90 0.45 0.18;   % orange — Spiro
          0.27 0.65 0.38];  % green  — Zembo

%% =========================================================================
%  SWEEP 1 — Discount Rate
% =========================================================================

fprintf('Sweep 1: Discount rate...\n');
discount_rates = [0.08, 0.10, 0.12, 0.15, 0.18, 0.20];
n1 = length(discount_rates);

sens.discount.rates     = discount_rates;
sens.discount.amp_npv   = zeros(1, n1);
sens.discount.spiro_npv = zeros(1, n1);
sens.discount.zembo_npv = zeros(1, n1);
sens.discount.amp_irr   = zeros(1, n1);
sens.discount.spiro_irr = zeros(1, n1);
sens.discount.zembo_irr = zeros(1, n1);

for i = 1:n1
    amp_discount_rate   = discount_rates(i);
    spiro_discount_rate = discount_rates(i);
    zembo_discount_rate = discount_rates(i);
    eco_params_loaded   = true;
    run('economic_model_main.m');
    sens.discount.amp_npv(i)   = amp_npv;
    sens.discount.spiro_npv(i) = spiro_npv;
    sens.discount.zembo_npv(i) = zembo_npv;
    sens.discount.amp_irr(i)   = amp_irr;
    sens.discount.spiro_irr(i) = spiro_irr;
    sens.discount.zembo_irr(i) = zembo_irr;
end

amp_discount_rate   = base.amp_discount_rate;
spiro_discount_rate = base.spiro_discount_rate;
zembo_discount_rate = base.zembo_discount_rate;
fprintf('Sweep 1 complete.\n\n');

%% =========================================================================
%  SWEEP 2 — Swap Price (per operator)
% =========================================================================

fprintf('Sweep 2: Swap price...\n');
amp_prices   = [1.20, 1.40, 1.60, 1.80, 2.00];
spiro_prices = [1.50, 2.00, 3.50, 4.50, 6.00];
zembo_prices = [1.20, 1.40, 1.65, 1.90, 2.20];
n2 = length(amp_prices);

sens.price.amp_prices   = amp_prices;
sens.price.spiro_prices = spiro_prices;
sens.price.zembo_prices = zembo_prices;
sens.price.amp_npv     = zeros(1, n2);
sens.price.spiro_npv   = zeros(1, n2);
sens.price.zembo_npv   = zeros(1, n2);
sens.price.amp_payback   = zeros(1, n2);
sens.price.spiro_payback = zeros(1, n2);
sens.price.zembo_payback = zeros(1, n2);

for i = 1:n2
    amp_swap_price   = amp_prices(i);
    spiro_swap_price = spiro_prices(i);
    zembo_swap_price = zembo_prices(i);
    eco_params_loaded = true;
    run('economic_model_main.m');
    sens.price.amp_npv(i)     = amp_npv;
    sens.price.spiro_npv(i)   = spiro_npv;
    sens.price.zembo_npv(i)   = zembo_npv;
    sens.price.amp_payback(i)   = amp_payback;
    sens.price.spiro_payback(i) = spiro_payback;
    sens.price.zembo_payback(i) = zembo_payback;
end

amp_swap_price   = base.amp_swap_price;
spiro_swap_price = base.spiro_swap_price;
zembo_swap_price = base.zembo_swap_price;
fprintf('Sweep 2 complete.\n\n');

%% =========================================================================
%  SWEEP 3 — PV Installed Cost
% =========================================================================

fprintf('Sweep 3: PV installed cost...\n');
pv_costs = [0.80, 0.90, 1.00, 1.10, 1.20, 1.30];
n3 = length(pv_costs);

sens.pv_cost.costs     = pv_costs;
sens.pv_cost.amp_npv   = zeros(1, n3);
sens.pv_cost.spiro_npv = zeros(1, n3);
sens.pv_cost.zembo_npv = zeros(1, n3);

for i = 1:n3
    amp_pv_installed_cost   = pv_costs(i);
    spiro_pv_installed_cost = pv_costs(i);
    zembo_pv_installed_cost = pv_costs(i);
    eco_params_loaded = true;
    run('economic_model_main.m');
    sens.pv_cost.amp_npv(i)   = amp_npv;
    sens.pv_cost.spiro_npv(i) = spiro_npv;
    sens.pv_cost.zembo_npv(i) = zembo_npv;
end

amp_pv_installed_cost   = base.amp_pv_installed_cost;
spiro_pv_installed_cost = base.spiro_pv_installed_cost;
zembo_pv_installed_cost = base.zembo_pv_installed_cost;
fprintf('Sweep 3 complete.\n\n');

%% =========================================================================
%  SWEEP 4 — Discharge Fraction
%  Reruns pv_model_main.m since Ed changes with discharge fraction
% =========================================================================

fprintf('Sweep 4: Discharge fraction...\n');
discharge_fractions = [0.25, 0.30, 0.36, 0.42, 0.50];
n4 = length(discharge_fractions);

sens.discharge.fractions = discharge_fractions;
sens.discharge.amp_npv   = zeros(1, n4);
sens.discharge.spiro_npv = zeros(1, n4);
sens.discharge.zembo_npv = zeros(1, n4);

for i = 1:n4
    discharge_fraction = discharge_fractions(i);
    run('pv_model_main.m');
    eco_params_loaded = true;
    run('economic_model_main.m');
    sens.discharge.amp_npv(i)   = amp_npv;
    sens.discharge.spiro_npv(i) = spiro_npv;
    sens.discharge.zembo_npv(i) = zembo_npv;
end

discharge_fraction = base.discharge_fraction;
run('pv_model_main.m');
fprintf('Sweep 4 complete.\n\n');

%% =========================================================================
%  SWEEP 5 — O&M Rate
% =========================================================================

fprintf('Sweep 5: O&M rate...\n');
om_rates = [0.025, 0.05, 0.075, 0.10, 0.125, 0.15];
n5 = length(om_rates);

sens.om.rates       = om_rates;
sens.om.amp_npv     = zeros(1, n5);
sens.om.spiro_npv   = zeros(1, n5);
sens.om.zembo_npv   = zeros(1, n5);
sens.om.amp_payback   = zeros(1, n5);
sens.om.spiro_payback = zeros(1, n5);
sens.om.zembo_payback = zeros(1, n5);
sens.om.amp_margin   = zeros(1, n5);
sens.om.spiro_margin = zeros(1, n5);
sens.om.zembo_margin = zeros(1, n5);

for i = 1:n5
    amp_annual_om_rate   = om_rates(i);
    spiro_annual_om_rate = om_rates(i);
    zembo_annual_om_rate = om_rates(i);
    eco_params_loaded = true;
    run('economic_model_main.m');
    sens.om.amp_npv(i)     = amp_npv;
    sens.om.spiro_npv(i)   = spiro_npv;
    sens.om.zembo_npv(i)   = zembo_npv;
    sens.om.amp_payback(i)   = amp_payback;
    sens.om.spiro_payback(i) = spiro_payback;
    sens.om.zembo_payback(i) = zembo_payback;
    sens.om.amp_margin(i)   = amp_profit_margin;
    sens.om.spiro_margin(i) = spiro_profit_margin;
    sens.om.zembo_margin(i) = zembo_profit_margin;
end

amp_annual_om_rate   = base.amp_annual_om_rate;
spiro_annual_om_rate = base.spiro_annual_om_rate;
zembo_annual_om_rate = base.zembo_annual_om_rate;
fprintf('Sweep 5 complete.\n\n');

%% =========================================================================
%  SWEEP 6 — Spiro Demand Growth (Lagos scenarios)
% =========================================================================

fprintf('Sweep 6: Spiro demand growth...\n');
spiro_demand = [180, 300, 450, 600, 800, 1000];
n6 = length(spiro_demand);

sens.spiro_demand.swaps   = spiro_demand;
sens.spiro_demand.npv     = zeros(1, n6);
sens.spiro_demand.payback = zeros(1, n6);
sens.spiro_demand.irr     = zeros(1, n6);
sens.spiro_demand.lcoe    = zeros(1, n6);

for i = 1:n6
    spiro_swaps_per_day = spiro_demand(i);
    eco_params_loaded = true;
    run('economic_model_main.m');
    sens.spiro_demand.npv(i)     = spiro_npv;
    sens.spiro_demand.payback(i) = spiro_payback;
    sens.spiro_demand.irr(i)     = spiro_irr;
    sens.spiro_demand.lcoe(i)    = spiro_lcoe;
end

spiro_swaps_per_day = base.spiro_swaps_per_day;
fprintf('Sweep 6 complete.\n\n');

%% =========================================================================
%  SWEEP 7 — Ampersand Network Scale
%  Tests the effect of scaling from the pilot station (200 swaps/day)
%  to the network-average throughput (565 swaps/day) documented in
%  Ampersand's published network statistics [AmpCle:25].
%  This is the most important demand sensitivity for Ampersand —
%  the base case is conservative by design at pilot scale.
% =========================================================================

fprintf('Sweep 7: Ampersand network scale...\n');
amp_demand = [200, 280, 360, 440, 520, 565];
n7 = length(amp_demand);

sens.amp_demand.swaps   = amp_demand;
sens.amp_demand.npv     = zeros(1, n7);
sens.amp_demand.payback = zeros(1, n7);
sens.amp_demand.irr     = zeros(1, n7);

for i = 1:n7
    amp_swaps_per_day = amp_demand(i);
    eco_params_loaded = true;
    run('economic_model_main.m');
    sens.amp_demand.npv(i)     = amp_npv;
    sens.amp_demand.payback(i) = amp_payback;
    sens.amp_demand.irr(i)     = amp_irr;
end

amp_swaps_per_day = base.amp_swaps_per_day;
fprintf('Sweep 7 complete.\n\n');

%% =========================================================================
%  SWEEP 8 — Installation Overhead (rural deployment context)
%  Base case uses 20% overhead validated against SEforALL urban SSA
%  benchmark data [SEforALL:24]. Rural deployments face higher costs:
%  remote site access, longer supply chains, fewer local contractors.
%  Sweep tests 20% to 40% to bracket urban-to-rural overhead range.
%  Zembo is the primary reference as the rural deployment case.
% =========================================================================

fprintf('Sweep 8: Installation overhead...\n');
overhead_rates = [0.20, 0.25, 0.30, 0.35, 0.40];
n8 = length(overhead_rates);

sens.overhead.rates     = overhead_rates;
sens.overhead.amp_npv   = zeros(1, n8);
sens.overhead.spiro_npv = zeros(1, n8);
sens.overhead.zembo_npv = zeros(1, n8);
sens.overhead.amp_capex   = zeros(1, n8);
sens.overhead.spiro_capex = zeros(1, n8);
sens.overhead.zembo_capex = zeros(1, n8);

for i = 1:n8
    amp_installation_overhead   = overhead_rates(i);
    spiro_installation_overhead = overhead_rates(i);
    zembo_installation_overhead = overhead_rates(i);
    eco_params_loaded = true;
    run('economic_model_main.m');
    sens.overhead.amp_npv(i)   = amp_npv;
    sens.overhead.spiro_npv(i) = spiro_npv;
    sens.overhead.zembo_npv(i) = zembo_npv;
    sens.overhead.amp_capex(i)   = amp_capex;
    sens.overhead.spiro_capex(i) = spiro_capex;
    sens.overhead.zembo_capex(i) = zembo_capex;
end

amp_installation_overhead   = base.amp_installation_overhead;
spiro_installation_overhead = base.spiro_installation_overhead;
zembo_installation_overhead = base.zembo_installation_overhead;
fprintf('Sweep 8 complete.\n\n');

%% =========================================================================
%  SWEEP 9 — Rural Deployment Scenario (Zembo)
%  Models a greenfield rural station operating at lower throughput
%  with commercial financing and higher maintenance costs.
%  Directly addresses the project brief: viability of off-grid rural
%  deployment where DFI concessional rates may not be available.
%
%  Parameters:
%    Swaps/day: 20 (very small rural market town)
%    Discount rate: 0.20 (commercial WACC without DFI backing)
%    O&M rate: 0.15 (remote location, higher maintenance costs)
%    Swap price: base Zembo price ($1.65/swap)
%    All other parameters: Zembo base case
% =========================================================================

fprintf('Sweep 9: Rural deployment scenario (Zembo)...\n');
rural_swaps   = [20, 30, 44, 60, 80];   % range from very small to Zembo base
n9 = length(rural_swaps);

sens.rural.swaps      = rural_swaps;
sens.rural.npv        = zeros(1, n9);
sens.rural.payback    = zeros(1, n9);
sens.rural.irr        = zeros(1, n9);
sens.rural.viable     = zeros(1, n9);   % 1 = NPV > 0 and IRR > 18%

for i = 1:n9
    zembo_swaps_per_day  = rural_swaps(i);
    zembo_discount_rate  = 0.20;    % commercial WACC without DFI
    zembo_annual_om_rate = 0.15;    % remote location O&M
    eco_params_loaded    = true;
    run('economic_model_main.m');
    sens.rural.npv(i)     = zembo_npv;
    sens.rural.payback(i) = zembo_payback;
    sens.rural.irr(i)     = zembo_irr;
    sens.rural.viable(i)  = (zembo_npv > 0) && (zembo_irr > 0.18);
end

zembo_swaps_per_day  = base.zembo_swaps_per_day;
zembo_discount_rate  = base.zembo_discount_rate;
zembo_annual_om_rate = base.zembo_annual_om_rate;
fprintf('Sweep 9 complete.\n\n');

%% =========================================================================
%  SWEEP 10 — Lagos Rainy Season Demand Reduction (illustrative)
%  Models a 15-25% reduction in Lagos swap demand during the West African
%  monsoon season (June-August, approximately 92 days).
%  NOTE: This is an ILLUSTRATIVE sensitivity scenario. No empirical source
%  quantifying seasonal demand reduction for Lagos okada/e-motorcycle
%  operators was identified in the literature. The range 15-25% is
%  physically motivated by documented rider avoidance of wet roads but
%  should not be interpreted as a validated model parameter.
%  Effect on annual revenue: reduction × (92/365) × annual_revenue
% =========================================================================

fprintf('Sweep 10: Lagos rainy season demand (illustrative)...\n');
rainy_reduction = [0.00, 0.10, 0.15, 0.20, 0.25, 0.30];
n10 = length(rainy_reduction);

sens.rainy.reductions = rainy_reduction;
sens.rainy.spiro_npv  = zeros(1, n10);
sens.rainy.spiro_irr  = zeros(1, n10);

% Effect computed as fraction of annual revenue lost during monsoon period
% monsoon_fraction = 92 days / 365 days = 0.252
monsoon_fraction = 92 / 365;

for i = 1:n10
    % Scale Lagos daily swaps down during rainy season
    % Annual effective swaps = S*(1 - reduction*monsoon_fraction)
    effective_swaps = base.spiro_swaps_per_day * ...
        (1 - rainy_reduction(i) * monsoon_fraction);
    spiro_swaps_per_day = effective_swaps;
    eco_params_loaded = true;
    run('economic_model_main.m');
    sens.rainy.spiro_npv(i) = spiro_npv;
    sens.rainy.spiro_irr(i) = spiro_irr;
end

spiro_swaps_per_day = base.spiro_swaps_per_day;
fprintf('Sweep 10 complete.\n\n');

% Restore full base case
eco_params_loaded = false;
run('economic_model_main.m');

%% =========================================================================
%  FIGURES
% =========================================================================

%% Figure 1 — Tornado Diagram (NPV — Ampersand)

npv_ranges_amp = [
    max(sens.discount.amp_npv)  - min(sens.discount.amp_npv);
    max(sens.price.amp_npv)     - min(sens.price.amp_npv);
    max(sens.pv_cost.amp_npv)   - min(sens.pv_cost.amp_npv);
    max(sens.om.amp_npv)        - min(sens.om.amp_npv);
    max(sens.discharge.amp_npv) - min(sens.discharge.amp_npv);
    max(sens.overhead.amp_npv)  - min(sens.overhead.amp_npv);
];

npv_low_amp = [
    min(sens.discount.amp_npv);  min(sens.price.amp_npv);
    min(sens.pv_cost.amp_npv);   min(sens.om.amp_npv);
    min(sens.discharge.amp_npv); min(sens.overhead.amp_npv);
];
npv_high_amp = [
    max(sens.discount.amp_npv);  max(sens.price.amp_npv);
    max(sens.pv_cost.amp_npv);   max(sens.om.amp_npv);
    max(sens.discharge.amp_npv); max(sens.overhead.amp_npv);
];
param_labels = {'Discount rate','Swap price','PV installed cost',...
                'O\&M rate','Discharge fraction','Installation overhead'};

[~, sort_idx] = sort(npv_ranges_amp, 'ascend');
npv_low_amp  = npv_low_amp(sort_idx);
npv_high_amp = npv_high_amp(sort_idx);
param_labels_sorted = param_labels(sort_idx);
base_npv_amp = base.amp_npv;

fig1 = figure('Position',[50 50 900 500],'Color','white');
y_pos = 1:6;
hold on
for i = 1:6
    x_low  = (npv_low_amp(i)  - base_npv_amp) / 1000;
    x_high = (npv_high_amp(i) - base_npv_amp) / 1000;
    patch([x_low x_high x_high x_low], ...
          [y_pos(i)-0.35 y_pos(i)-0.35 y_pos(i)+0.35 y_pos(i)+0.35], ...
          colors(1,:),'FaceAlpha',0.75,'EdgeColor',colors(1,:)*0.7)
end
xline(0,'k-','LineWidth',1.5)
set(gca,'YTick',y_pos,'YTickLabel',param_labels_sorted,'FontSize',11)
xlabel('Change in NPV from base case (\$000)','FontSize',12)
title('Ampersand — NPV Sensitivity (Tornado Diagram)','FontSize',13,'FontWeight','bold')
grid on; box off
exportgraphics(fig1,'tornado_ampersand.pdf','Resolution',300)
fprintf('Figure 1 saved: tornado_ampersand.pdf\n')

%% Figure 2 — Tornado Diagram (NPV — Spiro)

npv_ranges_spiro = [
    max(sens.discount.spiro_npv)  - min(sens.discount.spiro_npv);
    max(sens.price.spiro_npv)     - min(sens.price.spiro_npv);
    max(sens.pv_cost.spiro_npv)   - min(sens.pv_cost.spiro_npv);
    max(sens.om.spiro_npv)        - min(sens.om.spiro_npv);
    max(sens.discharge.spiro_npv) - min(sens.discharge.spiro_npv);
    max(sens.overhead.spiro_npv)  - min(sens.overhead.spiro_npv);
];
npv_low_spiro  = [min(sens.discount.spiro_npv); min(sens.price.spiro_npv);
                  min(sens.pv_cost.spiro_npv);  min(sens.om.spiro_npv);
                  min(sens.discharge.spiro_npv);min(sens.overhead.spiro_npv)];
npv_high_spiro = [max(sens.discount.spiro_npv); max(sens.price.spiro_npv);
                  max(sens.pv_cost.spiro_npv);  max(sens.om.spiro_npv);
                  max(sens.discharge.spiro_npv);max(sens.overhead.spiro_npv)];
param_labels2  = {'Discount rate','Swap price','PV installed cost',...
                  'O\&M rate','Discharge fraction','Installation overhead'};

[~, sort_idx2] = sort(npv_ranges_spiro,'ascend');
npv_low_spiro  = npv_low_spiro(sort_idx2);
npv_high_spiro = npv_high_spiro(sort_idx2);
param_labels2  = param_labels2(sort_idx2);
base_npv_spiro = base.spiro_npv;

fig2 = figure('Position',[50 50 900 500],'Color','white');
hold on
for i = 1:6
    x_low  = (npv_low_spiro(i)  - base_npv_spiro) / 1000;
    x_high = (npv_high_spiro(i) - base_npv_spiro) / 1000;
    patch([x_low x_high x_high x_low], ...
          [y_pos(i)-0.35 y_pos(i)-0.35 y_pos(i)+0.35 y_pos(i)+0.35], ...
          colors(2,:),'FaceAlpha',0.75,'EdgeColor',colors(2,:)*0.7)
end
xline(0,'k-','LineWidth',1.5)
set(gca,'YTick',y_pos,'YTickLabel',param_labels2,'FontSize',11)
xlabel('Change in NPV from base case (\$000)','FontSize',12)
title('Spiro — NPV Sensitivity (Tornado Diagram)','FontSize',13,'FontWeight','bold')
grid on; box off
exportgraphics(fig2,'tornado_spiro.pdf','Resolution',300)
fprintf('Figure 2 saved: tornado_spiro.pdf\n')

%% Figure 3 — Tornado Diagram (NPV — Zembo)

npv_ranges_zembo = [
    max(sens.discount.zembo_npv)  - min(sens.discount.zembo_npv);
    max(sens.price.zembo_npv)     - min(sens.price.zembo_npv);
    max(sens.pv_cost.zembo_npv)   - min(sens.pv_cost.zembo_npv);
    max(sens.om.zembo_npv)        - min(sens.om.zembo_npv);
    max(sens.discharge.zembo_npv) - min(sens.discharge.zembo_npv);
    max(sens.overhead.zembo_npv)  - min(sens.overhead.zembo_npv);
];
npv_low_zembo  = [min(sens.discount.zembo_npv); min(sens.price.zembo_npv);
                  min(sens.pv_cost.zembo_npv);  min(sens.om.zembo_npv);
                  min(sens.discharge.zembo_npv);min(sens.overhead.zembo_npv)];
npv_high_zembo = [max(sens.discount.zembo_npv); max(sens.price.zembo_npv);
                  max(sens.pv_cost.zembo_npv);  max(sens.om.zembo_npv);
                  max(sens.discharge.zembo_npv);max(sens.overhead.zembo_npv)];
param_labels3  = {'Discount rate','Swap price','PV installed cost',...
                  'O\&M rate','Discharge fraction','Installation overhead'};

[~, sort_idx3] = sort(npv_ranges_zembo,'ascend');
npv_low_zembo  = npv_low_zembo(sort_idx3);
npv_high_zembo = npv_high_zembo(sort_idx3);
param_labels3  = param_labels3(sort_idx3);
base_npv_zembo = base.zembo_npv;

fig3 = figure('Position',[50 50 900 500],'Color','white');
hold on
for i = 1:6
    x_low  = (npv_low_zembo(i)  - base_npv_zembo) / 1000;
    x_high = (npv_high_zembo(i) - base_npv_zembo) / 1000;
    patch([x_low x_high x_high x_low], ...
          [y_pos(i)-0.35 y_pos(i)-0.35 y_pos(i)+0.35 y_pos(i)+0.35], ...
          colors(3,:),'FaceAlpha',0.75,'EdgeColor',colors(3,:)*0.7)
end
xline(0,'k-','LineWidth',1.5)
set(gca,'YTick',y_pos,'YTickLabel',param_labels3,'FontSize',11)
xlabel('Change in NPV from base case (\$000)','FontSize',12)
title('Zembo — NPV Sensitivity (Tornado Diagram)','FontSize',13,'FontWeight','bold')
grid on; box off
exportgraphics(fig3,'tornado_zembo.pdf','Resolution',300)
fprintf('Figure 3 saved: tornado_zembo.pdf\n')

%% Figure 4 — NPV vs Discount Rate

fig4 = figure('Position',[50 50 800 450],'Color','white');
plot(discount_rates*100, sens.discount.amp_npv/1000,   'o-','Color',colors(1,:),'LineWidth',2,'MarkerSize',7)
hold on
plot(discount_rates*100, sens.discount.spiro_npv/1000, 's-','Color',colors(2,:),'LineWidth',2,'MarkerSize',7)
plot(discount_rates*100, sens.discount.zembo_npv/1000, '^-','Color',colors(3,:),'LineWidth',2,'MarkerSize',7)
yline(0,'k--','LineWidth',1.2)
xline(18,'k:','LineWidth',1.0,'Label','Commercial WACC lower bound (18%)','FontSize',9)
xline(22,'k:','LineWidth',1.0,'Label','Commercial WACC upper bound (22%)','FontSize',9)
xlabel('Discount Rate (%)','FontSize',12)
ylabel('NPV (\$000)','FontSize',12)
title('NPV Sensitivity to Discount Rate','FontSize',13,'FontWeight','bold')
legend({'Ampersand','Spiro','Zembo'},'Location','northeast','FontSize',11,'Box','off')
grid on; box off
exportgraphics(fig4,'sensitivity_discount_rate.pdf','Resolution',300)
fprintf('Figure 4 saved: sensitivity_discount_rate.pdf\n')

%% Figure 5 — NPV vs Swap Price

fig5 = figure('Position',[50 50 800 450],'Color','white');
plot(amp_prices,   sens.price.amp_npv/1000,   'o-','Color',colors(1,:),'LineWidth',2,'MarkerSize',7)
hold on
plot(spiro_prices, sens.price.spiro_npv/1000, 's-','Color',colors(2,:),'LineWidth',2,'MarkerSize',7)
plot(zembo_prices, sens.price.zembo_npv/1000, '^-','Color',colors(3,:),'LineWidth',2,'MarkerSize',7)
yline(0,'k--','LineWidth',1.2)
xlabel('Swap Price (USD)','FontSize',12)
ylabel('NPV (\$000)','FontSize',12)
title('NPV Sensitivity to Swap Price','FontSize',13,'FontWeight','bold')
legend({'Ampersand','Spiro','Zembo'},'Location','northwest','FontSize',11,'Box','off')
grid on; box off
exportgraphics(fig5,'sensitivity_swap_price.pdf','Resolution',300)
fprintf('Figure 5 saved: sensitivity_swap_price.pdf\n')

%% Figure 6 — NPV vs PV Installed Cost

fig6 = figure('Position',[50 50 800 450],'Color','white');
plot(pv_costs, sens.pv_cost.amp_npv/1000,   'o-','Color',colors(1,:),'LineWidth',2,'MarkerSize',7)
hold on
plot(pv_costs, sens.pv_cost.spiro_npv/1000, 's-','Color',colors(2,:),'LineWidth',2,'MarkerSize',7)
plot(pv_costs, sens.pv_cost.zembo_npv/1000, '^-','Color',colors(3,:),'LineWidth',2,'MarkerSize',7)
yline(0,'k--','LineWidth',1.2)
xlabel('PV Installed Cost (USD/Wp)','FontSize',12)
ylabel('NPV (\$000)','FontSize',12)
title('NPV Sensitivity to PV Installed Cost','FontSize',13,'FontWeight','bold')
legend({'Ampersand','Spiro','Zembo'},'Location','northeast','FontSize',11,'Box','off')
grid on; box off
exportgraphics(fig6,'sensitivity_pv_cost.pdf','Resolution',300)
fprintf('Figure 6 saved: sensitivity_pv_cost.pdf\n')

%% Figure 7 — NPV vs O&M Rate

fig7 = figure('Position',[50 50 800 450],'Color','white');
plot(om_rates*100, sens.om.amp_npv/1000,   'o-','Color',colors(1,:),'LineWidth',2,'MarkerSize',7)
hold on
plot(om_rates*100, sens.om.spiro_npv/1000, 's-','Color',colors(2,:),'LineWidth',2,'MarkerSize',7)
plot(om_rates*100, sens.om.zembo_npv/1000, '^-','Color',colors(3,:),'LineWidth',2,'MarkerSize',7)
yline(0,'k--','LineWidth',1.2)
xlabel('Annual O\&M Rate (\% of CAPEX)','FontSize',12)
ylabel('NPV (\$000)','FontSize',12)
title('NPV Sensitivity to O\&M Rate','FontSize',13,'FontWeight','bold')
legend({'Ampersand','Spiro','Zembo'},'Location','northeast','FontSize',11,'Box','off')
grid on; box off
exportgraphics(fig7,'sensitivity_om_rate.pdf','Resolution',300)
fprintf('Figure 7 saved: sensitivity_om_rate.pdf\n')

%% Figure 8 — Spiro Demand Growth Scenarios

fig8 = figure('Position',[50 50 800 450],'Color','white');
yyaxis left
plot(spiro_demand, sens.spiro_demand.npv/1000,'s-','Color',colors(2,:),'LineWidth',2,'MarkerSize',7)
yline(0,'k--','LineWidth',1)
ylabel('NPV (\$000)','FontSize',12)
yyaxis right
plot(spiro_demand, sens.spiro_demand.payback,'s--','Color',colors(2,:)*0.6,'LineWidth',2,'MarkerSize',7)
ylabel('Payback Period (years)','FontSize',12)
xlabel('Swaps per Day (Spiro, Lagos)','FontSize',12)
title('Spiro (Lagos) — Demand Growth Scenarios','FontSize',13,'FontWeight','bold')
legend({'NPV','Payback'},'Location','east','FontSize',11,'Box','off')
grid on; box off
exportgraphics(fig8,'sensitivity_spiro_demand.pdf','Resolution',300)
fprintf('Figure 8 saved: sensitivity_spiro_demand.pdf\n')

%% Figure 9 — Ampersand Network Scale

fig9 = figure('Position',[50 50 800 450],'Color','white');
yyaxis left
plot(amp_demand, sens.amp_demand.npv/1000,'o-','Color',colors(1,:),'LineWidth',2,'MarkerSize',7)
ylabel('NPV (\$000)','FontSize',12)
yyaxis right
plot(amp_demand, sens.amp_demand.irr*100,'o--','Color',colors(1,:)*0.7,'LineWidth',2,'MarkerSize',7)
yline(22,'k:','LineWidth',1.0,'Label','Commercial WACC upper bound (22%)','FontSize',9)
ylabel('IRR (%)','FontSize',12)
xlabel('Swaps per Day (Ampersand, Kigali)','FontSize',12)
title('Ampersand — Pilot to Network Scale','FontSize',13,'FontWeight','bold')
% Mark the two reference points
xline(200, 'k--','LineWidth',1.0,'Label','Pilot (200)','FontSize',9,...
    'LabelHorizontalAlignment','right')
xline(565, 'k--','LineWidth',1.0,'Label','Network avg (565)','FontSize',9,...
    'LabelHorizontalAlignment','left')
legend({'NPV','IRR'},'Location','northwest','FontSize',11,'Box','off')
grid on; box off
exportgraphics(fig9,'sensitivity_amp_scale.pdf','Resolution',300)
fprintf('Figure 9 saved: sensitivity_amp_scale.pdf\n')

%% Figure 10 — Installation Overhead (rural deployment)

fig10 = figure('Position',[50 50 800 450],'Color','white');
plot(overhead_rates*100, sens.overhead.amp_npv/1000,   'o-','Color',colors(1,:),'LineWidth',2,'MarkerSize',7)
hold on
plot(overhead_rates*100, sens.overhead.spiro_npv/1000, 's-','Color',colors(2,:),'LineWidth',2,'MarkerSize',7)
plot(overhead_rates*100, sens.overhead.zembo_npv/1000, '^-','Color',colors(3,:),'LineWidth',2,'MarkerSize',7)
yline(0,'k--','LineWidth',1.2)
xline(20,'k:','LineWidth',1.0,'Label','Urban base (20%)','FontSize',9,...
    'LabelHorizontalAlignment','right')
xline(40,'k:','LineWidth',1.0,'Label','Rural upper bound (40%)','FontSize',9,...
    'LabelHorizontalAlignment','left')
xlabel('Installation Overhead (\% of hardware cost)','FontSize',12)
ylabel('NPV (\$000)','FontSize',12)
title('NPV Sensitivity to Installation Overhead — Rural Deployment Context',...
    'FontSize',13,'FontWeight','bold')
legend({'Ampersand','Spiro','Zembo'},'Location','northeast','FontSize',11,'Box','off')
grid on; box off
exportgraphics(fig10,'sensitivity_overhead.pdf','Resolution',300)
fprintf('Figure 10 saved: sensitivity_overhead.pdf\n')

%% Figure 11 — Rural Deployment Scenario (Zembo)

fig11 = figure('Position',[50 50 800 450],'Color','white');
yyaxis left
bar(rural_swaps, sens.rural.npv/1000, 0.5,'FaceColor',colors(3,:),...
    'EdgeColor','none','FaceAlpha',0.85)
yline(0,'k--','LineWidth',1.2)
ylabel('NPV (\$000)','FontSize',12)
ax = gca; ax.YAxis(1).Color = colors(3,:);
yyaxis right
plot(rural_swaps, sens.rural.irr*100,'ko-','LineWidth',2,'MarkerSize',8,...
    'MarkerFaceColor','k')
yline(18,'k:','LineWidth',1.0,'Label','Commercial WACC lower bound (18%)','FontSize',9)
ylabel('IRR (%)','FontSize',12)
ax.YAxis(2).Color = 'k';
xlabel('Swaps per Day','FontSize',12)
title({'Zembo — Rural Deployment Scenario';...
       '20\% discount rate, 15\% O\&M (no DFI backing)'},...
    'FontSize',12,'FontWeight','bold')
set(gca,'XTick',rural_swaps,'FontSize',11)
% Mark Zembo base case
xline(44,'k--','LineWidth',1.0,'Label','Zembo base (44)','FontSize',9,...
    'LabelHorizontalAlignment','right')
grid on; box off
exportgraphics(fig11,'sensitivity_rural.pdf','Resolution',300)
fprintf('Figure 11 saved: sensitivity_rural.pdf\n')

%% Figure 12 — Lagos Rainy Season (illustrative)

fig12 = figure('Position',[50 50 800 420],'Color','white');
yyaxis left
plot(rainy_reduction*100, sens.rainy.spiro_npv/1000,'s-','Color',colors(2,:),...
    'LineWidth',2,'MarkerSize',7)
ylabel('NPV (\$000)','FontSize',12)
ax12 = gca; ax12.YAxis(1).Color = colors(2,:);
yyaxis right
plot(rainy_reduction*100, sens.rainy.spiro_irr*100,'s--','Color',colors(2,:)*0.6,...
    'LineWidth',2,'MarkerSize',7)
yline(18,'k:','LineWidth',1.0)
ylabel('IRR (%)','FontSize',12)
ax12.YAxis(2).Color = colors(2,:)*0.6;
xlabel('Rainy Season Demand Reduction (\%)','FontSize',12)
title({'Spiro (Lagos) — Rainy Season Demand Sensitivity (Illustrative)';...
       'West African monsoon June--August (\approx92 days)'},...
    'FontSize',12,'FontWeight','bold')
set(gca,'XTick',rainy_reduction*100,'FontSize',11)
grid on; box off
% Add note that this is illustrative
text(0.98, 0.05, 'Note: illustrative scenario — no empirical source for reduction \%',...
    'Units','normalized','HorizontalAlignment','right',...
    'FontSize',8,'Color',[0.5 0.5 0.5],'FontAngle','italic')
exportgraphics(fig12,'sensitivity_rainy_season.pdf','Resolution',300)
fprintf('Figure 12 saved: sensitivity_rainy_season.pdf\n')

%% =========================================================================
%  SUMMARY CONSOLE OUTPUT
% =========================================================================

fprintf('\n========= SENSITIVITY SUMMARY =========\n\n')

fprintf('--- Discount Rate Effect on NPV ($) ---\n')
fprintf('%-12s', 'Ampersand'); fprintf('%10.0f', sens.discount.amp_npv);   fprintf('\n')
fprintf('%-12s', 'Spiro');     fprintf('%10.0f', sens.discount.spiro_npv); fprintf('\n')
fprintf('%-12s', 'Zembo');     fprintf('%10.0f', sens.discount.zembo_npv); fprintf('\n\n')

fprintf('--- Ampersand Network Scale ---\n')
fprintf('%-12s', 'Swaps/day'); fprintf('%10.0f', sens.amp_demand.swaps);  fprintf('\n')
fprintf('%-12s', 'NPV ($)');   fprintf('%10.0f', sens.amp_demand.npv);    fprintf('\n')
fprintf('%-12s', 'IRR (%%)');  fprintf('%10.1f', sens.amp_demand.irr*100);fprintf('\n\n')

fprintf('--- Rural Deployment Scenario (Zembo, 20%% discount, 15%% O&M) ---\n')
fprintf('%-12s', 'Swaps/day');   fprintf('%10.0f', sens.rural.swaps);       fprintf('\n')
fprintf('%-12s', 'NPV ($)');     fprintf('%10.0f', sens.rural.npv);         fprintf('\n')
fprintf('%-12s', 'IRR (%%)');    fprintf('%10.1f', sens.rural.irr*100);     fprintf('\n')
fprintf('%-12s', 'Viable');      fprintf('%10.0f', sens.rural.viable);      fprintf('\n\n')

fprintf('--- Installation Overhead Effect on NPV ---\n')
fprintf('%-12s', 'Overhead %%'); fprintf('%10.0f', overhead_rates*100);     fprintf('\n')
fprintf('%-12s', 'Zembo NPV');  fprintf('%10.0f', sens.overhead.zembo_npv); fprintf('\n\n')

fprintf('--- Lagos Rainy Season (illustrative) ---\n')
fprintf('%-12s', 'Reduction %%');fprintf('%10.0f', rainy_reduction*100);     fprintf('\n')
fprintf('%-12s', 'Spiro NPV');  fprintf('%10.0f', sens.rainy.spiro_npv);     fprintf('\n\n')

fprintf('=== SENSITIVITY ANALYSIS COMPLETE ===\n')
fprintf('12 figures saved as PDFs.\n')
fprintf('Results in workspace struct: sens\n')