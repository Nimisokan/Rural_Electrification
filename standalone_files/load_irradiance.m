clc; clear; close all;

%% =========================================================================
%  load_irradiance.m  —  STANDALONE VERSION
%
%  PURPOSE:
%    Loads hourly solar irradiance and temperature data for all three
%    operator locations, computes Global Horizontal Irradiance (GHI)
%    in W/m² and generates all irradiance figures for the report.
%
%  DATA SOURCE:
%    Renewables.ninja Point API — MERRA-2 Modern-Era Retrospective analysis
%    for Research and Applications, Version 2 reanalysis dataset [RenNin]
%    Cite: [PfeSta:16] for solar reanalysis methodology.
%
%  LOCATIONS:
%    Kigali  (Ampersand): -1.9441°N, 30.0619°E — tilt 2°,  azimuth 0°
%    system loss = 0.12
%    Lagos   (Spiro):      6.5244°N,  3.3792°E — tilt 7°,  azimuth 180°
%    system loss = 0.16
%    Kampala (Zembo):      0.3476°N, 32.5825°E — tilt 5°,  azimuth 180°
%    system loss = 0.12
%
%  IRRADIANCE COMPUTATION:
%    GHI [W/m²] = (irradiance_direct + irradiance_diffuse) * 1000
%    Raw Renewables.ninja columns are in kW/m² — multiply by 1000 for W/m².
%    system_loss (12-16%) is applied to the 'electricity' column only
%    and NOT to the raw irradiance columns used here. PV model applies its
%    own panel efficiency and loss factors to the raw irradiance.
%
%  FIGURES GENERATED:
%    irradiance_annual.pdf              — full year smoothed GHI trend
%    irradiance_week.pdf                — sample week January, diurnal profile
%    irradiance_monthly.pdf             — monthly average GHI, grouped bar chart
%    temperature_annual.pdf             — annual temperature profile, all cities
%    irradiance_validation_2019_2024.pdf — inter-annual validation: 2019 vs 2024
% =========================================================================

%% =========================================================================
%  BLOCK 1 — Load 2024 CSV files (primary dataset)
%
%  NumHeaderLines=3: skips three Renewables.ninja metadata rows.
%  Row 4 is the column header; data starts at row 5.
%  Columns used: irradiance_direct, irradiance_diffuse, temperature.
%  2024 is a leap year — 8784 rows per file (366 x 24).
% =========================================================================

kigali_table  = readtable('ampersand_kigali_irradiance_2024.csv',  'NumHeaderLines', 3);
lagos_table   = readtable('spiro_lagos_irradiance_2024.csv',        'NumHeaderLines', 3);
kampala_table = readtable('zembo_kampala_irradiance_2024.csv',      'NumHeaderLines', 3);

%% =========================================================================
%  BLOCK 2 — Compute GHI and extract temperature
%
%  GHI = (irradiance_direct + irradiance_diffuse) * 1000   [W/m²]
%
%  irradiance_direct:  beam radiation arriving directly from the sun
%  irradiance_diffuse: scattered radiation from sky and clouds
%  GHI is the total incident solar resource at the tilted panel surface.
%
%  temperature [°C]: ambient temperature — used by pv_model_main.m to
%  compute panel operating temperature and thermal efficiency loss.
%  Higher ambient temperature reduces PV output (~-0.4%/°C above 25°C).
% =========================================================================

kigali_irradiance  = (kigali_table.irradiance_direct  + kigali_table.irradiance_diffuse)  * 1000;
lagos_irradiance   = (lagos_table.irradiance_direct   + lagos_table.irradiance_diffuse)   * 1000;
kampala_irradiance = (kampala_table.irradiance_direct + kampala_table.irradiance_diffuse) * 1000;

kigali_temp  = kigali_table.temperature;
lagos_temp   = lagos_table.temperature;
kampala_temp = kampala_table.temperature;

%% =========================================================================
%  BLOCK 3 — Sanity checks
%
%  Expected ranges for SSA equatorial locations:
%    Annual GHI:  1400-2200 kWh/m²
%    Peak GHI:    800-1200 W/m²
%    Night hours: ~4000-4500
%    Mean temp:   15-30°C
%

% =========================================================================

fprintf('\n--- Irradiance and temperature sanity check (2024) ---\n')
fprintf('%-10s  Annual GHI: %6.0f kWh/m²  Peak: %5.0f W/m²  Night hrs: %4d  Mean temp: %.1f°C\n', ...
    'Kigali',  sum(kigali_irradiance)/1000,  max(kigali_irradiance),  ...
    sum(kigali_irradiance==0),  mean(kigali_temp))
fprintf('%-10s  Annual GHI: %6.0f kWh/m²  Peak: %5.0f W/m²  Night hrs: %4d  Mean temp: %.1f°C\n', ...
    'Lagos',   sum(lagos_irradiance)/1000,   max(lagos_irradiance),   ...
    sum(lagos_irradiance==0),   mean(lagos_temp))
fprintf('%-10s  Annual GHI: %6.0f kWh/m²  Peak: %5.0f W/m²  Night hrs: %4d  Mean temp: %.1f°C\n', ...
    'Kampala', sum(kampala_irradiance)/1000, max(kampala_irradiance), ...
    sum(kampala_irradiance==0), mean(kampala_temp))

%% =========================================================================
%  BLOCK 4 — Operator colours (consistent across all project figures)
%
%  Blue   = Kigali  / Ampersand
%  Orange = Lagos   / Spiro
%  Green  = Kampala / Zembo
% =========================================================================

colors = [0.20 0.47 0.75;   % blue   — Kigali  / Ampersand
          0.90 0.45 0.18;   % orange — Lagos   / Spiro
          0.27 0.65 0.38];  % green  — Kampala / Zembo

%% =========================================================================
%  BLOCK 5 — FIGURE 1: Full year smoothed trend
%
%  Raw hourly data oscillates between 0 (night) and peak (midday) every
%  24 hours. At annual scale this produces an illegible filled band.
%  smoothdata with 'movmean' and window=720 applies a 30-day moving average
%  (720 = 24 hrs x 30 days), revealing the seasonal envelope clearly.
%
%  For equatorial SSA cities (all within 7° of equator), seasonal variation
%  is driven primarily by cloud cover during wet seasons rather than by
%  day-length changes. The 30-day smooth makes this wet/dry contrast visible.
% =========================================================================

fig1 = figure('Position', [50 50 1100 450], 'Color', 'white');

plot(smoothdata(kigali_irradiance,  'movmean', 720), 'Color', colors(1,:), 'LineWidth', 1.8)
hold on
plot(smoothdata(lagos_irradiance,   'movmean', 720), 'Color', colors(2,:), 'LineWidth', 1.8)
plot(smoothdata(kampala_irradiance, 'movmean', 720), 'Color', colors(3,:), 'LineWidth', 1.8)

% Month mid-point tick positions (hour of year at 15th of each month)
% February = 29 days (2024 is a leap year)
days_per_month  = [31,29,31,30,31,30,31,31,30,31,30,31];
month_midpoints = cumsum([0, days_per_month(1:11)]) * 24 + 15*24;
month_labels    = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};

set(gca, 'XTick', month_midpoints, 'XTickLabel', month_labels, 'FontSize', 11)
xlabel('Month (2024)', 'FontSize', 12)
ylabel('GHI (W/m²)', 'FontSize', 12)
title('Annual Solar Irradiance — 2024 MERRA-2  (30-day Moving Average)', ...
    'FontSize', 14, 'FontWeight', 'bold')
leg = legend('Kigali (Ampersand)', 'Lagos (Spiro)', 'Kampala (Zembo)', ...
    'FontSize', 11, 'Location', 'northeast', 'Box', 'off');
xlim([1 8784])
ylim([0 max([max(smoothdata(kigali_irradiance,'movmean',720)), ...
             max(smoothdata(lagos_irradiance,'movmean',720)), ...
             max(smoothdata(kampala_irradiance,'movmean',720))]) * 1.15])
grid on; box off
exportgraphics(fig1, 'irradiance_annual.pdf', 'Resolution', 300)
fprintf('\nFigure 1 saved: irradiance_annual.pdf\n')

%% =========================================================================
%  BLOCK 6 — FIGURE 2: Sample week (January, hours 1-168)
%
%  Raw hourly profile — no smoothing — shows the actual diurnal cycle
%  for a representative week. January is a dry season reference month
%  for all three cities, giving clear daily irradiance peaks.
%
%  168 hours = 7 days x 24 hours.
%  x-axis labelled with day names for readability.
% =========================================================================

fig2 = figure('Position', [50 50 1200 420], 'Color', 'white');
plot(1:168, kigali_irradiance(1:168),  'Color', colors(1,:), 'LineWidth', 1.2)
hold on
plot(1:168, lagos_irradiance(1:168),   'Color', colors(2,:), 'LineWidth', 1.2)
plot(1:168, kampala_irradiance(1:168), 'Color', colors(3,:), 'LineWidth', 1.2)

% XTick every 24 hours marks day boundaries
set(gca, 'XTick', 0:24:168, ...
    'XTickLabel', {'Mon','Tue','Wed','Thu','Fri','Sat','Sun',''}, 'FontSize', 11)
xlabel('Day of Week (January 2024)', 'FontSize', 12)
ylabel('GHI (W/m²)', 'FontSize', 12)
title('Solar Irradiance — Sample Week January 2024', ...
    'FontSize', 14, 'FontWeight', 'bold')
legend('Kigali (Ampersand)', 'Lagos (Spiro)', 'Kampala (Zembo)', ...
    'FontSize', 11, 'Location', 'northeast', 'Box', 'off')
xlim([0 168])
ylim([0 max([kigali_irradiance(1:168); lagos_irradiance(1:168); ...
             kampala_irradiance(1:168)]) * 1.2])
grid on; box off
exportgraphics(fig2, 'irradiance_week.pdf', 'Resolution', 300)
fprintf('Figure 2 saved: irradiance_week.pdf\n')

%% =========================================================================
%  BLOCK 7 — FIGURE 3: Monthly average GHI comparison
%
%  Grouped bar chart: one group of 3 bars per month.
%  Shows wet/dry season contrast more clearly than the smoothed annual plot.
%
%  Monthly indexing uses cumulative day counts for 2024 (leap year).
%  hours_per_month(m)+1 : hours_per_month(m+1) gives index range for month m.
% =========================================================================

hours_per_month = [0, cumsum(days_per_month * 24)];

monthly_kigali  = zeros(1,12);
monthly_lagos   = zeros(1,12);
monthly_kampala = zeros(1,12);

for m = 1:12
    idx = (hours_per_month(m)+1) : hours_per_month(m+1);
    monthly_kigali(m)  = mean(kigali_irradiance(idx));
    monthly_lagos(m)   = mean(lagos_irradiance(idx));
    monthly_kampala(m) = mean(kampala_irradiance(idx));
end

fig3 = figure('Position', [50 50 1100 420], 'Color', 'white');

% bar expects rows=groups (months), cols=series (cities)
bar_data = [monthly_kigali; monthly_lagos; monthly_kampala]';
b = bar(bar_data, 'grouped');
b(1).FaceColor = colors(1,:);
b(2).FaceColor = colors(2,:);
b(3).FaceColor = colors(3,:);

set(gca, 'XTickLabel', month_labels, 'FontSize', 11)
xlabel('Month (2024)', 'FontSize', 12)
ylabel('Mean GHI (W/m²)', 'FontSize', 12)
title('Monthly Average Solar Irradiance — 2024', ...
    'FontSize', 14, 'FontWeight', 'bold')
legend('Kigali (Ampersand)', 'Lagos (Spiro)', 'Kampala (Zembo)', ...
    'FontSize', 11, 'Location', 'northeast', 'Box', 'off')
grid on; box off
exportgraphics(fig3, 'irradiance_monthly.pdf', 'Resolution', 300)
fprintf('Figure 3 saved: irradiance_monthly.pdf\n')

%% =========================================================================
%  BLOCK 8 — FIGURE 4: Annual temperature profile
%
%  Ambient temperature affects PV panel output through the temperature
%  coefficient of power (-0.4%/°C above 25°C STC).
%  30-day moving average applied to reveal seasonal trends.
%
%  Horizontal reference line at 25°C marks the STC temperature.
%  Above this line: panels derate. Below: panels outperform rated output.
%  Kigali at ~1500m altitude has the most favourable thermal conditions.
%  Lagos at sea level has the strongest thermal derating effect.
% =========================================================================

fig4 = figure('Position', [50 50 1100 500], 'Color', 'white');

plot(smoothdata(kigali_temp,  'movmean', 720), 'Color', colors(1,:), 'LineWidth', 1.8)
hold on
plot(smoothdata(lagos_temp,   'movmean', 720), 'Color', colors(2,:), 'LineWidth', 1.8)
plot(smoothdata(kampala_temp, 'movmean', 720), 'Color', colors(3,:), 'LineWidth', 1.8)

% Reference line at STC temperature (25°C)
yline(25, 'k--', 'LineWidth', 1.2, 'Label', 'STC 25°C', ...
    'FontSize', 10, 'LabelVerticalAlignment', 'bottom')

set(gca, 'XTick', month_midpoints, 'XTickLabel', month_labels, 'FontSize', 11)
xlabel('Month (2024)', 'FontSize', 12)
ylabel('Ambient Temperature (°C)', 'FontSize', 12)
title('Annual Ambient Temperature — 2024 MERRA-2  (30-day Moving Average)', ...
    'FontSize', 14, 'FontWeight', 'bold')
legend('Kigali (Ampersand)', 'Lagos (Spiro)', 'Kampala (Zembo)', ...
    'FontSize', 11, 'Location', 'northeast', 'Box', 'off')
xlim([1 8784])
grid on; box off
exportgraphics(fig4, 'temperature_annual.pdf', 'Resolution', 300)
fprintf('Figure 4 saved: temperature_annual.pdf\n')

%% =========================================================================
%  BLOCK 9 — FIGURE 5: Inter-annual validation — 2019 vs 2024
%
%  Compares annual GHI between the 2019 validation dataset and the
%  2024 primary dataset for all three locations.
%  Confirms inter-annual consistency and justifies use of 2024 data.
%
%  Expected differences: within normal inter-annual variability for
%  MERRA-2 reanalysis (~3-8%). Larger differences for Lagos reflect
%  genuine West African monsoon variability. Kigali difference also
%  reflects azimuth change between 2019 (180°) and 2024 (0°) downloads.
% =========================================================================

% Load 2019 data
kigali_2019  = readtable('ampersand_kigali_irradiance_2019.csv',  'NumHeaderLines', 3);
lagos_2019   = readtable('spiro_lagos_irradiance_2019.csv',        'NumHeaderLines', 3);
kampala_2019 = readtable('zembo_kampala_irradiance_2019.csv',      'NumHeaderLines', 3);

% Compute 2019 GHI vectors
ghi_kigali_2019  = (kigali_2019.irradiance_direct  + kigali_2019.irradiance_diffuse)  * 1000;
ghi_lagos_2019   = (lagos_2019.irradiance_direct   + lagos_2019.irradiance_diffuse)   * 1000;
ghi_kampala_2019 = (kampala_2019.irradiance_direct + kampala_2019.irradiance_diffuse) * 1000;

% Annual GHI totals [kWh/m²]
annual_2019 = [sum(ghi_kigali_2019)/1000, ...
               sum(ghi_lagos_2019)/1000,  ...
               sum(ghi_kampala_2019)/1000];
annual_2024 = [sum(kigali_irradiance)/1000, ...
               sum(lagos_irradiance)/1000,  ...
               sum(kampala_irradiance)/1000];

% Percentage differences
pct_diff = (annual_2024 - annual_2019) ./ annual_2019 * 100;
fprintf('\n--- Inter-annual validation ---\n')
fprintf('%-10s  2019: %.0f kWh/m²  2024: %.0f kWh/m²  Diff: %+.1f%%\n', ...
    'Kigali',  annual_2019(1), annual_2024(1), pct_diff(1))
fprintf('%-10s  2019: %.0f kWh/m²  2024: %.0f kWh/m²  Diff: %+.1f%%\n', ...
    'Lagos',   annual_2019(2), annual_2024(2), pct_diff(2))
fprintf('%-10s  2019: %.0f kWh/m²  2024: %.0f kWh/m²  Diff: %+.1f%%\n', ...
    'Kampala', annual_2019(3), annual_2024(3), pct_diff(3))

% Grouped bar chart
fig5 = figure('Position', [50 50 750 450], 'Color', 'white');
x = 1:3;
bw = 0.35;
b2019 = bar(x - bw/2, annual_2019, bw, 'FaceColor', [0.70 0.70 0.70]);
hold on
b2024 = bar(x + bw/2, annual_2024, bw, 'FaceColor', [0.25 0.50 0.78]);

% Add percentage difference labels above each pair
for i = 1:3
    text(x(i)-0.2, max(annual_2019(i), annual_2024(i)) + 50, ...
        sprintf('%+.1f%%', pct_diff(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', '#555555')
end

set(gca, 'XTick', x, 'XTickLabel', {'Kigali','Lagos','Kampala'}, 'FontSize', 12)
xlabel('Location', 'FontSize', 13)
ylabel('Annual GHI (kWh/m²)', 'FontSize', 13)
title('Inter-annual Validation: 2019 vs 2024 Annual GHI', ...
    'FontSize', 14, 'FontWeight', 'bold')
legend([b2019, b2024], {'2019 (validation)', '2024 (primary)'}, ...
    'Location', 'northeast', 'FontSize', 11, 'Box', 'off')
ylim([0 max([annual_2019, annual_2024]) * 1.15])
grid on; box off
exportgraphics(fig5, 'irradiance_validation_2019_2024.pdf', 'Resolution', 300)
fprintf('Figure 5 saved: irradiance_validation_2019_2024.pdf\n')

