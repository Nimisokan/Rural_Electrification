%% =========================================================================
%  load_irradiance_main.m  —  PIPELINE VERSION
%
%  PURPOSE:
%    Loads hourly solar irradiance data for all three operator locations
%    and computes GHI vectors for use by pv_model_main.m.
%    No figures — use load_irradiance.m (standalone) for plots.
%
%  PIPELINE POSITION:
%    Run FIRST — before pv_model_main.m, arrival_model_main.m,
%   charge_time.m, and economic_model_main.m.
%    Called by main.m at the start of the pipeline.
%
%  DATA SOURCE:
%    Renewables.ninja Point API — MERRA-2 reanalysis [RenNin, PfeSta:16]
%    Year: 2024 — most recent complete year available at time of download.
%    Hourly resolution, 8784 rows per file.
%
%  LOCATIONS:
%    Kigali  (Ampersand): -1.9441°N, 30.0619°E — tilt 2°,  azimuth 180°
%    Lagos   (Spiro):      6.5244°N,  3.3792°E — tilt 7°,  azimuth 180°
%    Kampala (Zembo):      0.3476°N, 32.5825°E — tilt 5°,  azimuth 180°
%
%  OUTPUTS — written to workspace for pv_model_main.m:
%    kigali_irradiance   [8784x1]  hourly GHI in W/m²
%    lagos_irradiance    [8784x1]
%    kampala_irradiance  [8784x1]
%    kigali_temp         [8784x1]  hourly ambient temperature in °C
%    lagos_temp          [8784x1]
%    kampala_temp        [8784x1]
% =========================================================================

%% =========================================================================
%  BLOCK 1 — Load CSV files
%
%  NumHeaderLines=3: skips three Renewables.ninja metadata rows.
%  Row 4 is the column header; data starts at row 5.
%  Columns: time, local_time, electricity, irradiance_direct,
%           irradiance_diffuse, temperature
% =========================================================================

kigali_table  = readtable('ampersand_kigali_irradiance_2024.csv',  'NumHeaderLines', 3);
lagos_table   = readtable('spiro_lagos_irradiance_2024.csv',        'NumHeaderLines', 3);
kampala_table = readtable('zembo_kampala_irradiance_2024.csv',      'NumHeaderLines', 3);

%% =========================================================================
%  BLOCK 2 — Compute GHI and extract temperature
%
%  GHI [W/m²] = (irradiance_direct + irradiance_diffuse) * 1000
%    irradiance_direct:  beam radiation from sun directly
%    irradiance_diffuse: scattered radiation from sky/clouds
%    Raw columns are in kW/m² — multiply by 1000 for W/m²
%    system_loss is NOT applied here — PV model handles efficiency losses
%
%  temperature [°C]: ambient temperature used by pv_model_main.m to
%    compute panel operating temperature and thermal efficiency loss.
%    Higher temperature reduces PV output (typically -0.35 to -0.45%/°C).
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
%  Annual GHI should be in the range 1400-2200 kWh/m² for SSA locations.
%  Peak GHI should not exceed ~1200 W/m² (physical limit for these latitudes).
%  Zero hours should be roughly 4200-4560 (equatorial night ~11.5-12.5 hrs/day).
%  If any check fails, re-examine the CSV loading and column names.
% =========================================================================

fprintf('\n=== load_irradiance_main.m ===\n')
fprintf('%-10s  Annual GHI: %7.1f kWh/m²  Peak: %5.1f W/m²  Night hrs: %4d  Mean temp: %.1f°C\n', ...
    'Kigali',  sum(kigali_irradiance)/1000,  max(kigali_irradiance),  ...
    sum(kigali_irradiance==0),  mean(kigali_temp))
fprintf('%-10s  Annual GHI: %7.1f kWh/m²  Peak: %5.1f W/m²  Night hrs: %4d  Mean temp: %.1f°C\n', ...
    'Lagos',   sum(lagos_irradiance)/1000,   max(lagos_irradiance),   ...
    sum(lagos_irradiance==0),   mean(lagos_temp))
fprintf('%-10s  Annual GHI: %7.1f kWh/m²  Peak: %5.1f W/m²  Night hrs: %4d  Mean temp: %.1f°C\n', ...
    'Kampala', sum(kampala_irradiance)/1000, max(kampala_irradiance), ...
    sum(kampala_irradiance==0), mean(kampala_temp))
fprintf('\nWorkspace ready:\n')
fprintf('  kigali_irradiance, lagos_irradiance, kampala_irradiance  [8784x1, W/m²]\n')
fprintf('  kigali_temp,       lagos_temp,       kampala_temp        [8784x1, °C]\n')
