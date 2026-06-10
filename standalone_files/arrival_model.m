clc; clear; close all;

%% 
%  arrival_model.m  —  PLOTTING AND VALIDATION (STANDALONE)
%
%  Generates hourly battery swap arrival profiles for three operators:
%    Ampersand  — Kigali,   Rwanda  (565 swaps/day/station)
%    Spiro      — Lagos,    Nigeria (180 swaps/day/station)
%    Zembo      — Kampala,  Uganda  ( 44 swaps/day/station)
%
%  PURPOSE:
%    Standalone plotting and validation only. Does NOT connect to Simulink
%    or economic_model.m — those are handled in separate pipeline scripts.
%
%  METHOD:
%    Non-Homogeneous Poisson Process (NHPP). The arrival rate lambda
%    varies by hour — NOT constant across the day. Within each hour h,
%    arrivals are homogeneous Poisson with fixed rate lambda(h).
%    The model uses piecewise-constant hourly rates, consistent with the
%    empirical hourly resolution of the source data [SheGre:23, NgeJunRod:24].
%
%  WEIGHT PROFILE SOURCE — KIGALI:
%    Kigali weights are read directly from SheGre:23 Figure 7 (Battery
%    swapping probability for each hour in day, Nairobi real data).
%    Applied to Kigali as the closest available SSA swap station dataset.
%    Key features visible in Fig 7:
%      - Hours 2-7:  zero swap activity (bars at baseline)
%      - Hour 8-9:   small morning rise (2-4%)
%      - Hours 10-13: midday plateau (5.5-6.5%)
%      - Hours 14-18: broad afternoon-evening peak, hour 17 highest (9.5%)
%      - Hour 19:    sharp drop (3.5%) — riders finish shifts
%      - Hours 20-22: secondary evening activity (5.5-6.5%)
%      - Hours 23-24: decline
%      - Hour 1:     small residual (~1%)
%
%  OVERNIGHT WEIGHTS (hours 2-7):
%    Figure 7 shows these hours as zero. However, setting lambda(h)=0
%    causes division by zero when computing Simulink inter-arrival times
%    (mean_iat = 3600/lambda). To avoid this, hours 2-7 are set to 0.25

%
%  LAGOS AND KAMPALA:
%    Stated assumptions adapted from the Kigali/Nairobi shape [SheGre:23].
%    Lagos: stronger afternoon-evening peak reflecting megacity commuter
%           volumes; broader morning rise.
%    Kampala: flatter overall profile reflecting informal boda patterns;
%             less pronounced single peak.
%
%  FIGURES:
%    arrivals_profiles.pdf    — hourly lambda bar charts, 3 cities (Fig 1)
%    arrivals_validation.pdf  — validation panels, all 3 cities (Fig 2)
%    arrivals_heatmap.pdf     — 365-day heatmap, all 3 cities (Fig 3)
% =========================================================================

hours = 1:24;

colors = [0.20 0.47 0.75;   % blue   — Ampersand / Kigali
          0.90 0.45 0.18;   % orange — Spiro     / Lagos
          0.27 0.65 0.38];  % green  — Zembo     / Kampala

%% =========================================================================
%  BLOCK 1 — Traffic weight profiles
%
%  Integer weights scaled so peak hour = 10 (Kigali hour 17).
%  Overnight hours 2-7 set to 0.25
%  All values are RELATIVE — only ratios matter, not magnitude.
%  Normalised to proportions in Block 2.
%
%  READING FROM SheGre:23 FIG 7 (Kigali):
%  Hour  Fig7%   Weight (scaled to peak=10)
%   1    ~1.0       1
%   2     0.0       0.25  (residual — see overnight note)
%   3     0.0       0.25
%   4     0.0       0.25
%   5     0.0       0.25
%   6     0.0       0.25
%   7     0.0       0.25
%   8    ~2.1       2
%   9    ~4.2       4
%  10    ~6.8       7
%  11    ~6.3       6
%  12    ~6.1       6
%  13    ~5.8       6
%  14    ~7.9       8
%  15    ~7.7       8
%  16    ~8.4       9
%  17    ~9.5      10  <- peak
%  18    ~8.7       9
%  19    ~3.7       4
%  20    ~5.7       6
%  21    ~6.2       6
%  22    ~6.7       7
%  23    ~4.0       4
%  24    ~1.2       1
% =========================================================================

% --- Kigali weights [SheGre:23 Fig 7 — Nairobi swap probability] ---
kigali_weights = ...
   [1, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25,  2,  4,  7, 6,  6,  6,  8,  8,  9, 10,  9,  4,  6,  6,  7,  4,  1];

% --- Lagos weights [Stated assumption, adapted from SheGre:23 Fig 7] ---
% Stronger afternoon-evening peak (hours 16-18) for megacity commuter volumes.
% Broader morning rise (hours 8-10). Overnight residuals same as Kigali.

lagos_weights = ...
   [1, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25,  3,  5,  7,  6,  5,  5,  7,  8, 10, 10,  9,  4,  5,  5,  6,  3,  1];

% --- Kampala weights [Stated assumption, adapted from SheGre:23 Fig 7] ---
% Flatter overall profile — informal boda patterns, less pronounced peak.
% More evenly spread across midday (hours 9-18). Overnight residuals same.

kampala_weights = ...
   [1, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25,  2,  4,  6,  6,  6,  6,  7,  7,  8,  8,  7,  4,  5,  5,  5,  3,  1];

%% 
%  BLOCK 2 — Daily swap totals and lambda computation
%
%  STEP 1 — Normalise: norm(h) = weight(h) / sum(weights)
%    Each norm(h) = fraction of daily swaps expected in hour h. Sum = 1.
%
%  STEP 2 — Scale: lambda(h) = norm(h) * swaps_per_day
%    lambda(h) = Poisson rate for hour h (expected mean arrivals).
%

kigali_swaps  = 565;
lagos_swaps   = 180;
kampala_swaps = 44;

kigali_norm    = kigali_weights   / sum(kigali_weights);
lambda_kigali  = kigali_norm  * kigali_swaps;

lagos_norm     = lagos_weights    / sum(lagos_weights);
lambda_lagos   = lagos_norm   * lagos_swaps;

kampala_norm   = kampala_weights  / sum(kampala_weights);
lambda_kampala = kampala_norm * kampala_swaps;

% One stochastic draw per city (used in pipeline scripts)
arrivals_kigali  = poissrnd(lambda_kigali);
arrivals_lagos   = poissrnd(lambda_lagos);
arrivals_kampala = poissrnd(lambda_kampala);

% Sanity check — sum(lambda) must equal swaps_per_day exactly
fprintf('\n--- Lambda sanity check ---\n')
fprintf('Kigali  sum(lambda) = %.1f  (target: %d)\n', sum(lambda_kigali),  kigali_swaps)
fprintf('Lagos   sum(lambda) = %.1f  (target: %d)\n', sum(lambda_lagos),   lagos_swaps)
fprintf('Kampala sum(lambda) = %.1f  (target: %d)\n', sum(lambda_kampala), kampala_swaps)

[~, pk_k] = max(lambda_kigali);
[~, pk_l] = max(lambda_lagos);
[~, pk_m] = max(lambda_kampala);

fprintf('\n--- Peak hours ---\n')
fprintf('Kigali  peak: %02d:00  lambda = %.1f arrivals/hr\n', pk_k, lambda_kigali(pk_k))
fprintf('Lagos   peak: %02d:00  lambda = %.1f arrivals/hr\n', pk_l, lambda_lagos(pk_l))
fprintf('Kampala peak: %02d:00  lambda = %.1f arrivals/hr\n', pk_m, lambda_kampala(pk_m))

%% =========================================================================
%  BLOCK 3 — FIGURE 1: Hourly arrival profiles (three cities)
%
%  Plots lambda (expected mean arrivals/hour) as bar chart.
%  Lambda plotted rather than one random draw — shows underlying
%  deterministic model structure cleanly for the report.
%
%  VISUAL CHECK against SheGre:23 Fig 7 (Kigali):
%    - Hours 2-7 should be near-flat (very small bars from 0.5 weights)
%    - Peak should be at hour 17
%    - Broad afternoon-evening plateau hours 14-18
%    - Secondary activity hours 20-22
%    - Morning rise hours 8-10 smaller than afternoon peak
% =========================================================================

fig1 = figure('Position', [50 50 1100 400],'Color','white');

lambda_all  = {lambda_kigali,  lambda_lagos,  lambda_kampala};
swaps_all   = {kigali_swaps,   lagos_swaps,   kampala_swaps};
city_labels = {'Kigali — Ampersand', 'Lagos — Spiro', 'Kampala — Zembo'};

for i = 1:3
    ax = subplot(1, 3, i);

    bar(ax, hours, lambda_all{i}, 'FaceColor', colors(i,:), 'EdgeColor', 'none')

    xlabel(ax, 'Hour of Day', 'FontSize', 11)
    if i == 1
        ylabel(ax, 'Mean Arrivals per Hour (\lambda)', 'FontSize', 11)
    end
    title(ax, city_labels{i}, 'FontSize', 12, 'FontWeight', 'bold')

    set(ax, 'XTick', [1 4 8 12 16 20 24], ...
            'XTickLabel', {'1','4','8','12','16','20','24'}, 'FontSize', 10)

    
    text(ax, 1.5, max(lambda_all{i}) * 0.93, ...
        sprintf('Total: %d swaps/day', swaps_all{i}), ...
        'FontSize', 9, 'Color', colors(i,:) * 0.7, 'FontWeight', 'bold')

    ylim(ax, [0, max(lambda_all{i}) * 1.18])
    xlim(ax, [0.5, 24.5])
    grid(ax, 'on'); box(ax, 'off')
end

sgtitle('Expected Hourly Arrival Rates ', ...
    'FontSize', 14, 'FontWeight', 'bold')
exportgraphics(fig1, 'arrivals_profiles.pdf', 'Resolution', 300)
fprintf('\nFigure 1 saved: arrivals_profiles.pdf\n')

%% =========================================================================
%  BLOCK 4 — VALIDATION: 365-day independent simulation (all 3 cities)
%

%  CHECK 1 — Mean = Variance per hour (PRIMARY Poisson identity):
%    For X ~ Poisson(lambda): E[X] = Var[X] = lambda exactly.
%    Compute sample mean and variance per hour across 365 days.
%    Plot variance vs mean — 24 dots should lie on y=x diagonal.
%    Deviation = Poisson assumption violated for that hour.
%    Applied to all three cities — Zembo especially important at low
%    lambda values (~1-2 arrivals/hr) where Poisson behaviour differs.
%
%  CHECK 2 — Daily totals distribution:
%    Sum of 24 Poisson(lambda(h)) is Poisson(sum(lambda)) = Poisson(target).
%    Histogram of 365 daily totals should be centred on target swap count
%    with spread ~sqrt(target). Confirms Block 2 normalisation is correct.
%

% =========================================================================
 
n_days = 365;

sim_kigali  = zeros(n_days, 24);
sim_lagos   = zeros(n_days, 24);
sim_kampala = zeros(n_days, 24);
 
for d = 1:n_days
    % Fresh independent poissrnd draw for each day 
    sim_kigali(d,:)  = poissrnd(lambda_kigali);
    sim_lagos(d,:)   = poissrnd(lambda_lagos);
    sim_kampala(d,:) = poissrnd(lambda_kampala);
end
 
sim_all   = {sim_kigali, sim_lagos, sim_kampala};
swap_targets = {kigali_swaps, lagos_swaps, kampala_swaps};
city_names   = {'Kigali', 'Lagos', 'Kampala'};
 
fprintf('\n--- Validation results ---\n')
for i = 1:3
    hm = mean(sim_all{i}, 1);   % [1x24] hourly mean across 365 days
    hv = var(sim_all{i}, 0, 1); % [1x24] hourly variance across 365 days
    dt = sum(sim_all{i}, 2);    % [365x1] daily totals
 
    % Only compute deviation for hours with lambda > 0.5 to avoid
    % inflated % errors from very small overnight lambda values
    lam = {lambda_kigali, lambda_lagos, lambda_kampala};
    active = lam{i} > 0.5;
 
    fprintf('%s  Max Mean=Var deviation (active hrs): %.1f%%  ', ...
        city_names{i}, max(abs(hv(active)-hm(active))./hm(active))*100)
    fprintf('Daily mean: %.1f (target: %d)  Std: %.1f (theory: %.1f)\n', ...
        mean(dt), swap_targets{i}, std(dt), sqrt(swap_targets{i}))
end

 
%% =========================================================================
%  BLOCK 5 — FIGURE 2: Validation plots (2x3 panel — all three cities)
%
%  Top row:    Mean=Variance check per city (3 subplots)
%  Bottom row: Daily totals histogram per city (3 subplots)
%
%  Validating all three cities because:
%    - Zembo (kampala_swaps=44) has very small lambda at many hours (~1-3)
%      Low-count Poisson behaves differently and is worth checking separately
%    - Spiro (lagos_swaps=180) is an intermediate case
%    - Kigali is the primary operator but all three feed the Simulink model
% =========================================================================
 
fig2 = figure('Position', [50 50 1100 800], 'Color', 'white');
 
for i = 1:3
    lam     = {lambda_kigali, lambda_lagos, lambda_kampala};
    hm      = mean(sim_all{i}, 1);
    hv      = var(sim_all{i},  0, 1);
    dt      = sum(sim_all{i},  2);
 
    % --- Top row: Mean = Variance ---
    % subplot(2,3,i): 2 rows x 3 cols, top row is subplots 1,2,3
    ax_top = subplot(2, 3, i);
    hold(ax_top, 'on')
 
    % scatter: one dot per hour (24 dots)
    % x=hourly mean, y=hourly variance
    % 50: marker size; colors(i,:): operator colour; 'filled': solid dots
    % 'MarkerEdgeColor','w': white ring separates overlapping dots
    scatter(ax_top, hm, hv, 50, colors(i,:), 'filled', ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.8)
 
    % Reference line y=x — Poisson identity Mean=Variance
    ref = max([hm, hv]);
    % plot([0 ref],[0 ref]): straight line from origin to (ref,ref) = y=x
    % 'k--': black dashed guide line
    plot(ax_top, [0 ref], [0 ref], 'k--', 'LineWidth', 1.5)
 
    xlabel(ax_top, 'Sample Mean', 'FontSize', 10)
    if i == 1
        ylabel(ax_top, 'Sample Variance', 'FontSize', 10)
    end
    title(ax_top, [city_names{i} ' — Mean=Var'], 'FontSize', 11, 'FontWeight', 'bold')
    legend(ax_top, {'Per-hour (24 hrs)', 'y = x'}, 'FontSize', 8, 'Box', 'off', 'Location', 'southeast')
    grid(ax_top, 'on'); box(ax_top, 'off')
 
    % --- Bottom row: Daily totals histogram ---
    % subplot(2,3,i+3): bottom row is subplots 4,5,6
    ax_bot = subplot(2, 3, i+3);
 
    % histogram: 30 bins, count normalisation, operator colour
    % 'FaceAlpha',0.7: slight transparency so xline labels show through
    histogram(ax_bot, dt, 30, 'FaceColor', colors(i,:), ...
        'EdgeColor', 'none', 'FaceAlpha', 0.7, 'Normalization', 'count')
    hold(ax_bot, 'on')
 

    xline(ax_bot, mean(dt), 'k-', 'LineWidth', 2, ...
        'Label', sprintf('Mean=%.1f', mean(dt)), 'FontSize', 10, ...
        'LabelVerticalAlignment', 'bottom')
    xline(ax_bot, swap_targets{i}, 'b--', 'LineWidth', 1.5, ...
        'Label', sprintf('Target=%d', swap_targets{i}), 'FontSize', 10, ...
        'LabelVerticalAlignment', 'top')
 
    xlabel(ax_bot, 'Daily Total Arrivals', 'FontSize', 11)
    if i == 1
        ylabel(ax_bot, 'Days (out of 365)', 'FontSize', 11)
    end
    title(ax_bot, [city_names{i} ' — Daily Totals'], 'FontSize', 12, 'FontWeight', 'bold')
    grid(ax_bot, 'on'); box(ax_bot, 'off')
end
 
sgtitle('Poisson Validation — All Three Cities', ...
    'FontSize', 14, 'FontWeight', 'bold')
exportgraphics(fig2, 'arrivals_validation.pdf', 'Resolution', 300)
fprintf('\nFigure 2 saved: arrivals_validation.pdf\n')


%% =========================================================================
%  BLOCK 6 — FIGURE 3: 365-day heatmap (all three cities)
%
%  VISUAL CHECK:
%    Kigali/Lagos: bright horizontal band around hour 17 (peak per Fig 7)
%    Kampala: more diffuse brightness across hours 9-18 (flatter profile)
%    All cities: column-to-column variation confirms independent daily draws
%    Hours 2-7: near-dark (very small lambda from 0.5 weights)
% =========================================================================
% 

fig3 = figure('Position', [50 50 1100 520], 'Color', 'white');
city_short = {'Kigali (Ampersand)', 'Lagos (Spiro)', 'Kampala (Zembo)'};

for i = 1:3
    ax = subplot(1, 3, i);

    % imagesc(M'): transpose [365x24] -> [24x365]
    % rows become hours (y-axis), cols become days (x-axis)
    imagesc(ax, sim_all{i}')

    % 'hot': intuitive traffic intensity colourmap (dark=quiet, bright=busy)
    colormap(ax, 'hot')


    set(ax, 'YDir', 'normal')
    set(ax, 'YTick', [1 4 8 12 16 20 24], ...
            'YTickLabel', {'1','4','8','12','16','20','24'}, 'FontSize', 11)

    xlabel(ax, 'Day of Year', 'FontSize', 12)
    if i == 1
        ylabel(ax, 'Hour of Day', 'FontSize', 12)
    end
    title(ax, city_short{i}, 'FontSize', 13, 'FontWeight', 'bold')

    % colorbar: colour scale showing arrivals count
    cb = colorbar(ax);
    cb.Label.String = 'Arrivals';
    cb.FontSize = 11;
end

sgtitle('Simulated Arrivals Heatmap — 365 Independent Days', ...
    'FontSize', 14, 'FontWeight', 'bold')
exportgraphics(fig3, 'arrivals_heatmap.pdf', 'Resolution', 300)
fprintf('Figure 3 saved: arrivals_heatmap.pdf\n')
fprintf('\nScript complete. Weights grounded in SheGre:23 Fig 7.\n')
