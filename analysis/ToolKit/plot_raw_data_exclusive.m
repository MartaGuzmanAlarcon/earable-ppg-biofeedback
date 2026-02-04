function f_raw = plot_raw_data_exclusive(t_ppg, raw_ppg, side, name)
    % Create clean figure
    f_raw = figure('Color','w','Name','Raw Signal Inspection','Visible','on');
    
    % Ensure data is double for math operations
    t = double(t_ppg);
    raw = double(raw_ppg);
    
    % Sync lengths
    L = min(length(t), length(raw));
    t = t(1:L);
    original = raw(1:L);
    
    % Inversion logic (Mirror across the mean)
    inverted = -original + (2 * mean(original));
    
    % Plotting
    plot(t, inverted, 'k', 'LineWidth', 1, 'DisplayName', 'Inverted'); 
    hold on;
    plot(t, original, 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5, 'DisplayName', 'Original');
    
    % Clean formatting
    grid on;
    xlabel('Time (s)');
    ylabel('Amplitude (Counts)');
    title(sprintf('Raw PPG | Side: %s | ID: %s', side, name), 'Interpreter', 'none');
    legend('Location', 'northeast');
    
    % Tighten axis
    xlim([t(1) t(end)]);
end