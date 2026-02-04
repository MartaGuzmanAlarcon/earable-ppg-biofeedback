function [freq_vec, pxx, dominant_bpm] = calculate_pulse_spectrum(sig, fs)
    % Computes PSD using Periodogram for HR/Motion analysis.
    %
    % INPUTS:
    %   - sig: Time series vector (PPG or Accelerometer magnitude).
    %   - fs:  Sampling frequency (Hz).
    %
    % OUTPUTS:
    %   - freq_vec: Frequency axis in Hz.
    %   - pxx:      Power Spectral Density (Normalized).
    %   - dominant_bpm: The frequency of the highest peak converted to BPM.
    
    % Removes the DC offset (0 Hz component) and linear trend.
    % Without this, the 0 Hz peak is so huge it hides the heart rate.
    sig = detrend(sig, 'constant'); 
    
    % COMPUTE PERIODOGRAM (Standard for HR Estimation)
    % We use the entire signal length to maximize spectral resolution.
    % nfft: Next power of 2 from signal length (for FFT speed)
    nfft = max(512, 2^nextpow2(length(sig))); 
    
    % Use Hamming window to reduce spectral leakage (side lobes)
    [pxx, freq_vec] = periodogram(sig, hamming(length(sig)), nfft, fs);
    
    % PHYSIOLOGICAL BAND LIMIT (0.5 Hz - 4.0 Hz)
    % 0.5 Hz = 30 BPM (Extreme Bradycardia)
    % 4.0 Hz = 240 BPM (Extreme Tachycardia / Running)
    % We only look for peaks inside this "Human" window.
    valid_mask = freq_vec >= 0.5 & freq_vec <= 4.0;
    
    f_valid = freq_vec(valid_mask);
    p_valid = pxx(valid_mask);
    
    % 4. FIND DOMINANT PEAK
    if ~isempty(p_valid)
        [max_val, max_idx] = max(p_valid);
        dominant_freq = f_valid(max_idx);
        dominant_bpm = dominant_freq * 60;
    else
        dominant_bpm = 0;
    end
    
    % Normalize PXX for easier visual comparison between PPG and IMU
    % This makes the max peak always 1.0.
    if max(pxx) > 0
        pxx = pxx / max(pxx);
    end
end