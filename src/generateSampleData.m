function tables = generateSampleData(savePath)
%GENERATESAMPLEDATA Create synthetic flight-test-like time series data.
%   TABLES = GENERATESAMPLEDATA() returns a cell array of timetables,
%   one per sample rate. tables{1} is 100 Hz data (altitude, airspeed,
%   pitch, roll), tables{2} is 20 Hz data (temperature, pressure).
%
%   TABLES = GENERATESAMPLEDATA(SAVEPATH) also saves the timetables to a
%   .mat file at SAVEPATH.

    % Time bases
    t  = linspace(0, 100, 10001)';   % 100 Hz, 0–100s
    t2 = linspace(0, 100, 2001)';    % 20 Hz,  0–100s

    % Altitude — ramp with smooth transitions (climb, cruise, descent)
    alt_profile = zeros(size(t));
    climb_end   = 20;   % seconds
    cruise_end  = 70;
    descent_end = 95;
    for k = 1:numel(t)
        tk = t(k);
        if tk < climb_end
            alt_profile(k) = 10000 * smoothstep(tk / climb_end);
        elseif tk < cruise_end
            alt_profile(k) = 10000;
        elseif tk < descent_end
            frac = (tk - cruise_end) / (descent_end - cruise_end);
            alt_profile(k) = 10000 * (1 - smoothstep(frac));
        else
            alt_profile(k) = 0;
        end
    end
    altitude = alt_profile + 20 * randn(size(t));

    % Airspeed — step changes with first-order lag + noise
    airspeed_cmd = 250 * ones(size(t));
    airspeed_cmd(t >= 10 & t < 40) = 300;
    airspeed_cmd(t >= 40 & t < 70) = 280;
    airspeed_cmd(t >= 70) = 260;
    tau = 3;  % time constant in seconds
    dt = t(2) - t(1);
    alpha_filt = dt / (tau + dt);
    airspeed = zeros(size(t));
    airspeed(1) = airspeed_cmd(1);
    for k = 2:numel(t)
        airspeed(k) = airspeed(k-1) + alpha_filt * (airspeed_cmd(k) - airspeed(k-1));
    end
    airspeed = airspeed + 2 * randn(size(t));

    % Pitch — sum of sinusoids + noise
    pitch = 3 * sin(2*pi*0.1*t) + 1.5 * sin(2*pi*0.25*t) + 0.5 * randn(size(t));

    % Roll — sinusoidal with varying amplitude
    roll_envelope = 5 + 10 * sin(2*pi*0.02*t);
    roll = roll_envelope .* sin(2*pi*0.15*t) + 0.3 * randn(size(t));

    % Temperature — slow drift + random walk (on t2)
    rng_state = rng;  % save RNG state
    rng(42);          % reproducible
    temp_walk = cumsum(0.05 * randn(size(t2)));
    temperature = 15 - 0.002 * altitude(round(linspace(1, numel(t), numel(t2)))) / 100 ...
                  + temp_walk + 0.2 * randn(size(t2));
    rng(rng_state);   % restore RNG state

    % Pressure — correlated with altitude (on t2)
    alt_interp = interp1(t, altitude, t2, 'linear');
    pressure = 1013.25 - 0.12 * alt_interp / 10 + 0.5 * randn(size(t2));

    % Build timetables grouped by sample rate
    highRate = timetable(seconds(t), altitude, airspeed, pitch, roll, ...
        'VariableNames', {'altitude','airspeed','pitch','roll'});
    highRate.Properties.Description = 'High-rate (100 Hz)';

    lowRate = timetable(seconds(t2), temperature, pressure, ...
        'VariableNames', {'temperature','pressure'});
    lowRate.Properties.Description = 'Low-rate (20 Hz)';

    tables = {highRate; lowRate};

    % Save to .mat file if requested
    if nargin >= 1 && ~isempty(savePath)
        save(savePath, 'highRate', 'lowRate');
    end
end

function y = smoothstep(x)
    x = max(0, min(1, x));
    y = 3*x.^2 - 2*x.^3;
end
