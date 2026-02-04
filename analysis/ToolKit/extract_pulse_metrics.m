function [heart_rate_bpm, metric_timestamps, perfusion_auc] = extract_pulse_metrics(ppg_signal, time_vector, beat_times)
    %
    %   Derives Heart Rate (HR) and Perfusion Index proxy (AUC).
    %
    % INPUTS:
    %   - ppg_signal:  Filtered PPG time series (amplitude).
    %   - time_vector: Time array corresponding to the signal (seconds).
    %   - beat_times:  Timestamps of beat boundaries (Valleys).
    %
    % OUTPUTS:
    %   - heart_rate_bpm:    Instantaneous Heart Rate (Beats Per Minute).
    %   - metric_timestamps: Time axis for the metrics (aligned to the end of intervals).
    %   - perfusion_auc:     Area Under the Curve (Proxy for relative blood volume change).
    
    % 1. INSTANTANEOUS HEART RATE CALCULATION 
    % Calculate the time difference between consecutive beats
    inter_beat_intervals = diff(beat_times);
    
    % Convert intervals (seconds) to frequency (Beats Per Minute)
    heart_rate_bpm = 60 ./ inter_beat_intervals;
    
    % Align the time axis: The rate applies to the interval ending at the second beat
    metric_timestamps = beat_times(2:end);
    
    %  2. PULSE AREA (AUC) CALCULATION
    
    num_intervals = length(beat_times) - 1;
    perfusion_auc = zeros(num_intervals, 1);
    
    for k = 1:num_intervals
        
        % Define the time window for the current beat (Valley A to Valley B)
        t_start = beat_times(k);
        t_end   = beat_times(k+1);
        
        % Extract the signal segment for this specific interval
        time_mask = (time_vector >= t_start) & (time_vector <= t_end);
        
        current_beat_sig  = ppg_signal(time_mask);
        current_beat_time = time_vector(time_mask);
        
        % BASELINE CORRECTION (Grounding)
        % Subtract the local minimum of *this specific beat*.
        if ~isempty(current_beat_sig)
            grounded_beat = current_beat_sig - min(current_beat_sig);
            
            % Integration (Trapezoidal Rule)
            perfusion_auc(k) = trapz(current_beat_time, grounded_beat);
        else
            perfusion_auc(k) = 0; 
        end
    end
end