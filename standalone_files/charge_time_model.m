function t_total = charge_time_model(SOC_arrival, capacity)
% =========================================================================
%  charge_time_model.m
%  CC-CV battery charging model for LFP batteries.
%  Called by docking_station_model.slx Charging Server block.
%
%  INPUTS:
%    SOC_arrival [scalar]      battery SOC on arrival [0 - 0.95]
%    capacity    [scalar, kWh] battery capacity in kWh
%
%  OUTPUT:
%    t_total [scalar, seconds] total charge time
%
%  CC PHASE (SOC_arrival to 0.90): constant 3.3 kW
%  CV PHASE (0.90 to 0.95):        constant 1.65 kW
%  Parameters from NgeJunRod:24 Table 1.
% =========================================================================

P_CC     = 3.3;    % kW  [NgeJunRod:24 Table 1]
P_CV     = 1.65;   % kW  [NgeJunRod:24 Table 1]
SOC_CC   = 0.90;
SOC_full = 0.95;

if SOC_arrival < SOC_CC
    t_CC    = (SOC_CC   - SOC_arrival) * capacity / P_CC;
    t_CV    = (SOC_full - SOC_CC)      * capacity / P_CV;
    t_total = t_CC + t_CV;

elseif SOC_arrival < SOC_full
    t_CC    = 0;
    t_CV    = (SOC_full - SOC_arrival) * capacity / P_CV;
    t_total = t_CC + t_CV;

else
    t_total = 0;
end

t_total = t_total * 3600;   % hours -> seconds

end