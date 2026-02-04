function [morphology_matrix, sqi_score, valley_times] = normalize_pulse_shape(sig, peak_idx, fs, timestamps)    %
    % Each beat is normalized in time  
    % (to 200 samples) and amplitude (Z-Score) to allow morphological comparison.
    %
    % INPUTS:
    %   - sig:      Filtered PPG signal (1D vector).
    %   - peak_idx: Indices of validated systolic peaks (from validate_pulse_quality).
    %   - fs:       Sampling Frequency (Hz).
    %   - timestamps: Time vector of the signal 
    %
    % OUTPUTS:
    %   - morphology_matrix: Matrix [N_beats x 200]. Each row is one normalized heartbeat.
    %   - sqi_score:         Scalar (0.0 to 1.0). Signal Quality Index based on 
    %                        template correlation.
    %   - valley_times: Timestamps of the beat starts 
    
    % Number of detected peaks
    num_peaks = length(peak_idx);
    
    % SAFETY CHECK: We need at least 3 peaks to define 2 full intervals (Valley->Valley)
    if num_peaks < 3
        morphology_matrix = []; 
        sqi_score = 0; 
        valley_times = []; % Return empty if fails
        return; 
    end
    
    % 1. FIND VALLEYS
    % Look backwards from the Peak to find the start of the pulse (The Valley).
    valleys = zeros(num_peaks, 1);
    
    % JUSTIFICATION FOR 0.35s (SEARCH WINDOW):
    % - Typical "Pulse Rise Time" (Foot-to-Peak) is 0.10s - 0.20s.
    % - We use 0.35s as a "Safety Margin" to handle slower rise times caused by 
    %  motion artifacts or poor perfusion during walking.
    % TODO: check panel
    search_window = round(0.35 * fs); 
    
    for i = 1:num_peaks
        curr_p = peak_idx(i);
        
        % DYNAMIC SEARCH BOUNDARIES: COMPROBAR SI MIRO DELATE Y DETRÁS - HR
        % We look back 350ms, BUT we stop if we hit the previous peak.
        % This prevents "Cross-Beat Contamination".
        if i == 1
            search_start = max(1, curr_p - search_window);
        else
            search_start = max(peak_idx(i-1) + 1, curr_p - search_window);
        end
        
        % Find the local minimum (The Valley) in that window
        segment_to_search = sig(search_start : curr_p);
        [~, min_rel_idx] = min(segment_to_search); % we have flip the signal before -> min
        
        % Convert relative index back to absolute index
        valleys(i) = search_start + min_rel_idx - 1;
    end

    % Convert the indices (valleys) to real time (seconds)
    valley_times = timestamps(valleys);
    
    % 2. SEGMENTATION & DUAL NORMALIZATION 
    % Define beats as the interval between two consecutive Valleys (Full Cycle).
    num_beats = length(valleys) - 1;
    
    % TARGET SIZE: 200 samples.
    target_len = 200; 
    morphology_matrix = zeros(num_beats, target_len);
    
    valid_count = 0;
    
    for k = 1:num_beats
        idx_start = valleys(k);
        idx_end = valleys(k+1);
        
        raw_beat = sig(idx_start : idx_end);
        
        % ARTIFACT REJECTION (DURATION CHECK):
        % Reject if beat is < 0.25s (>240 BPM) or > 1.5s (<40 BPM).
        if length(raw_beat) < (0.25*fs) || length(raw_beat) > (1.5*fs)
            continue; 
        end
        
        % TEMPORAL NORMALIZATION (Time Warping)
        % Use 'pchip' interpolation to stretch signal to 200 points.
        x_old = linspace(0, 1, length(raw_beat));
        x_new = linspace(0, 1, target_len);
        norm_time_beat = interp1(x_old, raw_beat, x_new, 'pchip'); 
        
        % AMPLITUDE NORMALIZATION (Z-Score)
        % Formula: (Signal - Mean) / StdDev.
        if std(norm_time_beat) > 0.0001
            norm_amp_beat = (norm_time_beat - mean(norm_time_beat)) / std(norm_time_beat);
        else
            norm_amp_beat = norm_time_beat; % Handle flatline edge case
        end
        
        valid_count = valid_count + 1;
        morphology_matrix(valid_count, :) = norm_amp_beat;
    end
    
    % Remove empty rows
    morphology_matrix = morphology_matrix(1:valid_count, :);
    
    % 3. SQI CALCULATION (Template Correlation) 
    if valid_count > 1
        % Create a "Master Template" (Average of all valid beats)
        template = mean(morphology_matrix, 1); 
        corrs = zeros(valid_count, 1);
        
        for k = 1:valid_count
            % Correlation: 1.0 = Perfect Clone, 0.0 = Random Noise.
            r = corrcoef(morphology_matrix(k, :), template);
            corrs(k) = r(1, 2); 
        end
        
        sqi_score = mean(corrs); 
    else
        sqi_score = 0;
    end
end