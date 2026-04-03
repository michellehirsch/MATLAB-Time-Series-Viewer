%GENERATEALLSAMPLES Create sample data files for Time Series Viewer.
%   Run this script to regenerate all sample files in the samples/ directory.
%   Produces .mat files (timetable and legacy flat formats) and .csv files
%   covering a range of domains and loading paths.

sampleDir = fileparts(mfilename('fullpath'));

%% 1. Flight test — timetable format (.mat)
%  Two sample rates: 100 Hz body dynamics, 10 Hz air data
rng(1);
t_fast = (0:0.01:120)';   % 100 Hz, 2 minutes
t_slow = (0:0.1:120)';    % 10 Hz

% Altitude profile: takeoff, climb, cruise, descent, landing
alt = zeros(size(t_fast));
alt(t_fast < 10) = 0;
idx = t_fast >= 10 & t_fast < 40;
alt(idx) = 8000 * (1 - cos(pi*(t_fast(idx)-10)/30)) / 2;
alt(t_fast >= 40 & t_fast < 80) = 8000;
idx = t_fast >= 80 & t_fast < 110;
alt(idx) = 8000 * (1 + cos(pi*(t_fast(idx)-80)/30)) / 2;
alt(t_fast >= 110) = 0;
alt = alt + 10*randn(size(t_fast));

airspeed = 150 + 0.01*alt + 3*randn(size(t_fast));
pitch = 2*sin(2*pi*0.08*t_fast) + 0.3*randn(size(t_fast));
roll  = 5*sin(2*pi*0.05*t_fast) .* (1 + 0.5*sin(2*pi*0.01*t_fast)) + 0.5*randn(size(t_fast));
yaw_rate = 1.5*sin(2*pi*0.03*t_fast) + 0.2*randn(size(t_fast));
g_load = 1 + 0.05*sin(2*pi*0.1*t_fast) + 0.01*randn(size(t_fast));

oat = 15 - 0.002*interp1(t_fast, alt, t_slow, 'linear', 0) + 0.5*randn(size(t_slow));
mach = (150 + 0.01*interp1(t_fast, alt, t_slow, 'linear', 0)) / 340 + 0.005*randn(size(t_slow));

highRate = timetable(seconds(t_fast), alt, airspeed, pitch, roll, yaw_rate, g_load, ...
    'VariableNames', {'altitude_ft','airspeed_kts','pitch_deg','roll_deg','yaw_rate_dps','g_load'});
highRate.Properties.Description = 'Body dynamics (100 Hz)';

lowRate = timetable(seconds(t_slow), oat, mach, ...
    'VariableNames', {'OAT_degC','mach_number'});
lowRate.Properties.Description = 'Air data (10 Hz)';

save(fullfile(sampleDir, 'flight_test.mat'), 'highRate', 'lowRate');
fprintf('Created flight_test.mat\n');

%% 2. Vehicle dynamics — timetable format (.mat)
rng(2);
t = (0:0.005:60)';  % 200 Hz, 1 minute

speed_kmh = 30 + 20*sin(2*pi/60*t) + 2*randn(size(t));
steering_deg = 15*sin(2*pi*0.1*t) .* (1 + 0.3*sin(2*pi*0.02*t));
lateral_g = 0.3*sin(2*pi*0.1*t) + 0.02*randn(size(t));
long_g = 0.1*cos(2*pi/60*t) + 0.01*randn(size(t));
brake_pressure = max(0, 20*sin(2*pi*0.05*t - pi/3) + 5*randn(size(t)));
rpm = 2000 + 500*sin(2*pi/60*t) + 50*randn(size(t));
throttle_pct = 50 + 30*sin(2*pi/60*t + pi/4) + 3*randn(size(t));
throttle_pct = max(0, min(100, throttle_pct));

vehicle = timetable(seconds(t), speed_kmh, steering_deg, lateral_g, long_g, ...
    brake_pressure, rpm, throttle_pct, ...
    'VariableNames', {'speed_kmh','steering_deg','lateral_g','longitudinal_g', ...
    'brake_pressure_bar','engine_rpm','throttle_pct'});
vehicle.Properties.Description = 'Vehicle dynamics (200 Hz)';

save(fullfile(sampleDir, 'vehicle_dynamics.mat'), 'vehicle');
fprintf('Created vehicle_dynamics.mat\n');

%% 3. Weather station — CSV format
rng(3);
hours = (0:0.25:168)';  % 15-min intervals, 1 week
n = numel(hours);

temp_C = 20 + 8*sin(2*pi*hours/24 - pi/2) + 3*cumsum(0.02*randn(n,1)) + 0.5*randn(n,1);
humidity = 60 + 15*sin(2*pi*hours/24 + pi/4) + 5*randn(n,1);
humidity = max(20, min(100, humidity));
wind_speed = abs(5 + 3*sin(2*pi*hours/12) + 2*randn(n,1));
wind_dir = mod(180 + 60*sin(2*pi*hours/48) + 20*randn(n,1), 360);
pressure_hPa = 1013 + 5*sin(2*pi*hours/72) + cumsum(0.05*randn(n,1));
precip_mm = max(0, -2 + 3*rand(n,1)) .* (rand(n,1) > 0.85);
solar_W = max(0, 800*sin(pi*mod(hours,24)/14 - pi/6)) .* (1 + 0.1*randn(n,1));

T = table(hours, temp_C, humidity, wind_speed, wind_dir, pressure_hPa, precip_mm, solar_W, ...
    'VariableNames', {'hours','temperature_C','humidity_pct','wind_speed_mps', ...
    'wind_direction_deg','pressure_hPa','precipitation_mm','solar_irradiance_W'});
writetable(T, fullfile(sampleDir, 'weather_station.csv'));
fprintf('Created weather_station.csv\n');

%% 4. Vibration analysis — timetable format (.mat)
rng(4);
fs = 2048;  % Hz
dur = 5;    % seconds
t = (0:1/fs:dur-1/fs)';
n = numel(t);

% Machine with bearing defect: fundamental + harmonics + defect frequency
f_shaft = 30;    % Hz
f_defect = 112;  % Hz (BPFO-like)
accel_x = 2*sin(2*pi*f_shaft*t) + 0.5*sin(2*pi*2*f_shaft*t) ...
    + 0.8*sin(2*pi*f_defect*t).*(1 + 0.5*sin(2*pi*f_shaft*t)) ...
    + 0.3*randn(n,1);
accel_y = 1.5*sin(2*pi*f_shaft*t + pi/6) + 0.3*sin(2*pi*2*f_shaft*t) ...
    + 0.4*sin(2*pi*f_defect*t) + 0.3*randn(n,1);
accel_z = 0.5*sin(2*pi*f_shaft*t) + 0.2*randn(n,1);
velocity_x = cumtrapz(t, accel_x);
velocity_x = velocity_x - mean(velocity_x);  % remove DC

vibration = timetable(seconds(t), accel_x, accel_y, accel_z, velocity_x, ...
    'VariableNames', {'accel_x_g','accel_y_g','accel_z_g','velocity_x_mms'});
vibration.Properties.Description = 'Vibration (2048 Hz)';

save(fullfile(sampleDir, 'vibration_analysis.mat'), 'vibration');
fprintf('Created vibration_analysis.mat\n');

%% 5. ECG-like biomedical — CSV format
rng(5);
fs = 500;  % Hz
dur = 30;  % seconds
t = (0:1/fs:dur-1/fs)';
n = numel(t);

% Synthetic ECG-like waveform
hr = 72;  % bpm
beat_period = 60/hr;
ecg = zeros(n,1);
for beat_t = 0:beat_period:dur
    dt_beat = t - beat_t;
    % P wave
    ecg = ecg + 0.15*exp(-((dt_beat-0.06)/0.02).^2);
    % QRS complex
    ecg = ecg - 0.1*exp(-((dt_beat-0.15)/0.005).^2);
    ecg = ecg + 1.0*exp(-((dt_beat-0.16)/0.008).^2);
    ecg = ecg - 0.15*exp(-((dt_beat-0.18)/0.006).^2);
    % T wave
    ecg = ecg + 0.3*exp(-((dt_beat-0.35)/0.04).^2);
end
ecg = ecg + 0.05*randn(n,1);

% Respiration signal
resp = 0.5*sin(2*pi*0.25*t) + 0.05*randn(n,1);

% SpO2
spo2 = 97 + sin(2*pi*0.03*t) + 0.2*randn(n,1);
spo2 = max(90, min(100, spo2));

T = table(t, ecg, resp, spo2, ...
    'VariableNames', {'time_s','ecg_mV','respiration','spo2_pct'});
writetable(T, fullfile(sampleDir, 'biomedical_signals.csv'));
fprintf('Created biomedical_signals.csv\n');

%% 6. Power grid — legacy flat vectors (.mat, no timetables)
%  Tests the vectorsToTimetables loading path
rng(6);
t = (0:1:3600)';  % 1 Hz, 1 hour
n = numel(t);

voltage = 230 + 5*sin(2*pi*t/600) + 2*randn(n,1);
current = 10 + 3*sin(2*pi*t/300) + abs(0.5*randn(n,1));
frequency = 50 + 0.05*sin(2*pi*t/900) + 0.01*randn(n,1);
power_kW = voltage .* current / 1000;
power_factor = 0.92 + 0.05*sin(2*pi*t/1200) + 0.01*randn(n,1);
power_factor = max(0.8, min(1.0, power_factor));
thd_pct = 3 + 1.5*sin(2*pi*t/1800) + 0.3*randn(n,1);
thd_pct = max(0, thd_pct);

save(fullfile(sampleDir, 'power_grid_legacy.mat'), ...
    't', 'voltage', 'current', 'frequency', 'power_kW', 'power_factor', 'thd_pct');
fprintf('Created power_grid_legacy.mat\n');

%% 7. Multi-rate sensors — timetable format (.mat)
%  Three different sample rates in one file
rng(7);
t_gps  = (0:0.1:300)';     % 10 Hz, 5 minutes
t_imu  = (0:0.005:300)';   % 200 Hz
t_baro = (0:1:300)';        % 1 Hz

lat = 37.7749 + 0.001*cumsum(0.001*randn(numel(t_gps),1));
lon = -122.4194 + 0.001*cumsum(0.001*randn(numel(t_gps),1));
gps_alt = 100 + 50*sin(2*pi*t_gps/120) + 2*randn(numel(t_gps),1);

ax = 0.1*sin(2*pi*0.5*t_imu) + 0.5*randn(numel(t_imu),1);
ay = 0.05*cos(2*pi*0.3*t_imu) + 0.5*randn(numel(t_imu),1);
az = -9.81 + 0.1*sin(2*pi*0.2*t_imu) + 0.3*randn(numel(t_imu),1);
gx = 0.5*sin(2*pi*0.1*t_imu) + 0.1*randn(numel(t_imu),1);
gy = 0.3*cos(2*pi*0.15*t_imu) + 0.1*randn(numel(t_imu),1);
gz = 0.1*sin(2*pi*0.05*t_imu) + 0.05*randn(numel(t_imu),1);

baro_alt = 100 + 50*sin(2*pi*t_baro/120) + 0.5*randn(numel(t_baro),1);
baro_press = 1013.25 - 0.12*baro_alt + 0.2*randn(numel(t_baro),1);
baro_temp = 15 - 0.0065*baro_alt + 0.1*randn(numel(t_baro),1);

gps = timetable(seconds(t_gps), lat, lon, gps_alt, ...
    'VariableNames', {'latitude','longitude','gps_altitude_m'});
gps.Properties.Description = 'GPS (10 Hz)';

imu = timetable(seconds(t_imu), ax, ay, az, gx, gy, gz, ...
    'VariableNames', {'accel_x','accel_y','accel_z','gyro_x','gyro_y','gyro_z'});
imu.Properties.Description = 'IMU (200 Hz)';

baro = timetable(seconds(t_baro), baro_alt, baro_press, baro_temp, ...
    'VariableNames', {'baro_altitude_m','pressure_hPa','temperature_C'});
baro.Properties.Description = 'Barometer (1 Hz)';

save(fullfile(sampleDir, 'multi_rate_sensors.mat'), 'gps', 'imu', 'baro');
fprintf('Created multi_rate_sensors.mat\n');

%% Summary
fprintf('\nAll sample files created in: %s\n', sampleDir);
d = [dir(fullfile(sampleDir, '*.mat')); dir(fullfile(sampleDir, '*.csv'))];
for k = 1:numel(d)
    fprintf('  %s (%.1f KB)\n', d(k).name, d(k).bytes/1024);
end
