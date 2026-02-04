function [v_a, v_t, v_i, n_a, n_t] = validate_pulse_quality(sig, amps, times, idx, fs, step_times, motion_window)
    % Filters candidate peaks based on noise, motion, and physiology.
    %
    % Note/Idea:We compare these 'Valid Candidates' against the Device's 'Beep' to calculate accuracy.
    %      - Missed Beep = False Negative (Device failed to detect).
    %      - Extra Beep  = False Positive (Device triggered on noise).

    % INPUTS:
    %   - sig:           Filtered PPG signal (vector).
    %   - amps, times, idx: Detected candidate peak data.
    %   - fs:            Sampling frequency (Hz).
    %   - step_times:    Array of timestamps (s) where steps were detected by IMU.
    %   - motion_window: Time window (s) to reject beats coinciding with steps (e.g., 0.10).
    %
    % OUTPUTS:
    %   - v_*:           Validated beat data (Amps, Times, Indices).
    %   - n_*:           Rejected noise/artifact data (for visualization).
    
    % Initialize output arrays
    v_a = []; v_t = []; v_i = [];
    n_a = []; n_t = [];
    
    % LOCAL NOISE CALCULATION 
    % Calculate the moving standard deviation (2-second sliding window).
    % High value = Walking/Motion. Low value = Still.
    % This helps establish a dynamic threshold.
    local_noise_profile = movstd(sig, fs * 2); 
    
    % GLOBAL AMPLITUDE REFERENCE 
    % Get the median amplitude of all candidates to detect impossible outliers.
    median_amp = median(amps);

    % Iterate through every candidate peak to validate logic
    for k = 1:length(times)
        
        % Current candidate properties
        curr_t = times(k);
        curr_amp = amps(k);
        curr_idx = idx(k);
        
        is_valid = true; % Assume valid until proven otherwise
        
        % RULE A: SIGNAL-TO-NOISE RATIO (SNR) -> for removing eg: head mov,talking,swalling, loose sensor etc
        % The pulse must be 55% taller than the local noise floor. CHECK
        % EXAMPLE
        noise_threshold = local_noise_profile(curr_idx) * 0.55;
        
        if curr_amp < noise_threshold
            is_valid = false;
        end
        
        % RULE B: MOTION ARTIFACT (IMU CROSS-CHECK) - COMENTARLA
        % If a "beat" happens exactly when a step happens (using IMU data), 
        % it is likely a foot impact vibration, not a heartbeat.
        if ~isempty(step_times)
            % Distance to closest step
            dist_to_step = min(abs(step_times - curr_t));
            
            if dist_to_step < motion_window
                is_valid = false; % REJECT: Coincides with step impact  ASK
            end
        end

        % RULE C: PHYSIOLOGICAL REFRACTORY PERIOD 
        % Hearts cannot beat faster than ~200 BPM (0.3s interval) while walking.
        % We check the time distance from the *last valid beat*.
        if ~isempty(v_t) && is_valid
            last_valid_time = v_t(end);
            rr_interval = curr_t - last_valid_time;
            
            if rr_interval < 0.30 % CHECK VALUE 0.3 OR 0.
                is_valid = false; % REJECT: Physiologically impossible speed (likely noise)
            end
        end
        
        % RULE D: EXTREME OUTLIERS 
        % Reject if peak is 5x bigger than median (likely sensor bump).
        if curr_amp > (median_amp * 5)
            is_valid = false;
        end

        % FINAL SORTING 
        if is_valid
            v_a(end+1) = curr_amp;
            v_t(end+1) = curr_t;
            v_i(end+1) = curr_idx;
        else
            n_a(end+1) = curr_amp;
            n_t(end+1) = curr_t;
        end
    end
end