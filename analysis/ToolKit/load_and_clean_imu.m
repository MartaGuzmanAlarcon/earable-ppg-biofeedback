function [acc_raw, acc_filt, step_ts] = load_and_clean_imu(imu_file_list, sensor_side, recording_path, fs, max_walk, g_walk, cutoff)
% Process IMU data for walking trials.
%
% Inputs:
%   - imu_file_list: Directory struct with accelerometer CSVs.
%   - sensor_side: 'L' or 'R' tag.
%   - recording_path: Folder path.
%   - fs: Sampling frequency (Hz).
%   - max_walk: Max steps per minute (SPM).
%   - g_walk: Detection threshold in G (e.g., 1.1).
%   - cutoff: Low-pass filter frequency (Hz).
% Outputs:
%   - acc_raw: Raw magnitude in G (9.81 m/s^2 = 1G).
%   - acc_filt: Filtered magnitude in G (low-pass).
%   - step_ts: Timestamps (sec) for detected steps (Empty if still).

    % 1. Find and load the correct file
    all_matches = find(contains({imu_file_list.name}, ['-' sensor_side '_']));
    if isempty(all_matches)
        acc_raw = []; acc_filt = []; step_ts = []; return; 
    end
    
    [~, idx] = max([imu_file_list(all_matches).bytes]);
    target_file = imu_file_list(all_matches(idx)).name;
    raw_table = readtable(fullfile(recording_path, target_file));
    
    % 2. Clean and sort data 
    raw_table = sortrows(raw_table, 'timestamp');
    [~, u_idx] = unique(raw_table.timestamp, 'stable');
    clean_table = raw_table(u_idx, :);
    
    % 3. Convert m/s^2 to G
    % Magnitude is divided by 9.81 to align with 1g threshold logic 
    acc_raw = sqrt(clean_table.X.^2 + clean_table.Y.^2 + clean_table.Z.^2) / 9.81;
    
    % 4. Apply zero-phase low-pass filter to prevent time shifts - update
    % when using the beep
    [b, a] = butter(2, cutoff / (fs/2), 'low');
    acc_filt = filtfilt(b, a, acc_raw); 
    
    % 5. Create relative time vector (seconds)
    t_imu = (clean_table.timestamp - clean_table.timestamp(1)) / 1e6;
    
    % 6. Detect steps
    % Use a refractory period (min_dist) based on max expected cadence
    min_dist = 60 / max_walk; 
    [~, step_ts] = findpeaks(acc_filt, t_imu, ...
        'MinPeakHeight', g_walk, ...
        'MinPeakDistance', min_dist);
    
    step_ts = step_ts';
end