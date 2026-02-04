function [filt, amps, times, idx] = preprocess_pulse(raw, fs, max_hr)
    % Description: Applies bandpass filtering and identifies peak candidates.
    % Inputs:
    %   - raw: Raw PPG signal vector (usually Green channel).
    %   - fs: Sampling frequency in Hz.
    % Outputs:
    %   - filt: Zero-phase filtered signal (0.5-7 Hz).
    %   - amps: Amplitude values of all potential systolic peaks.
    %   - times: Time vector in seconds.
    %   - idx: Indices of the detected peaks.
    
    [b, a] = butter(2, [0.5 7] / (fs/2), 'bandpass'); 
    filt = filtfilt(b, a, raw);

    filt = -filt;

    %Physiological refractory period logic
    min_dist_samples = (60 / max_hr) * fs;

    [amps, idx] = findpeaks(filt, 'MinPeakDistance', min_dist_samples);
    times = (idx-1)/fs; 
end
