function f = plot_research_dashboard(t_ppg, raw_ppg, filt_ppg, vt, va, nt, na, morph, hr, tm, auc, acc_raw, acc_filt, step_ts, side, name, f_ppg, pxx_ppg, f_imu, pxx_imu)
    
    f = figure('Color','w','Units','normalized','Position',[0.05 0.05 0.9 0.9], 'Visible','on');
    
    % Vector de tiempo para el IMU (para cuadrar ejes)
    t_imu = linspace(t_ppg(1), t_ppg(end), length(acc_raw));
    
    %% PANEL 1: RAW MOTION (Visual Context)
    ax1 = subplot(2,3,1); 
    if ~isempty(acc_raw)
        plot(t_imu, acc_raw, 'Color', [0.7 0.7 0.7]); 
    end
    title('1. Raw IMU Magnitude (G)'); ylabel('Raw G'); grid on; xlim([t_ppg(1) t_ppg(end)]);
    
    %% PANEL 2: FILTERED MOTION & STEPS (Algorithm Truth)
    ax2 = subplot(2,3,2); 
    if ~isempty(acc_filt)
        plot(t_imu, acc_filt, 'k', 'LineWidth', 1.2); hold on;
        % Dibuja triángulos rojos flotando un 10% por encima del pico máximo
        % Esto es VISUALIZACIÓN, no invención de datos.
        if ~isempty(step_ts)
            plot(step_ts, ones(size(step_ts)) * max(acc_filt)*1.1, 'rv', 'MarkerFaceColor', 'r', 'MarkerSize', 5);
        end
    end
    title('2. Step Detection Validation'); ylabel('Filt G'); grid on; xlim([t_ppg(1) t_ppg(end)]);
    
    %% PANEL 3: PPG SIGNAL QUALITY (The Core)
    ax3 = subplot(2,3,3); 
    plot(t_ppg, filt_ppg, 'Color', [0.2 0.2 0.2]); hold on; 
    if ~isempty(vt), plot(vt, va, 'g.', 'MarkerSize', 15); end % Valles Validados
    if ~isempty(nt), plot(nt, na, 'rx', 'MarkerSize', 8); end  % Ruido detectado
    title('3. PPG Quality Gating (Valleys)'); ylabel('mV'); grid on; xlim([t_ppg(1) t_ppg(end)]);
    
    %% PANEL 4: SPECTRAL COMPARISON (Frequency Lock Check)
    subplot(2,3,4);
    
    % 1. Pintar Pasos (IMU) como Área Gris de fondo
    if ~isempty(pxx_imu)
        % Normalizamos para comparar frecuencias, no amplitudes
        p_imu_norm = pxx_imu / max(pxx_imu); 
        area(f_imu, p_imu_norm, 'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
        hold on;
    end
    
    % 2. Pintar Corazón (PPG) como Línea Naranja encima
    if ~isempty(pxx_ppg)
        p_ppg_norm = pxx_ppg / max(pxx_ppg);
        plot(f_ppg, p_ppg_norm, 'Color', [0.85 0.33 0.10], 'LineWidth', 2); 
    end
    
    % Eje Primario (Hz)
    grid on; xlim([0.5 3.5]); ylim([0 1.1]);
    xlabel('Frequency (Hz)'); ylabel('Norm. Power');
    title('4. Spectral Check: Heart (Line) vs Steps (Area)');
    legend({'Motion/Steps', 'Heart Rate'}, 'Location', 'NorthEast', 'FontSize', 8);
    
    % Eje Secundario (BPM) - Para lectura médica rápida
    ax_curr = gca;
    ax_top = axes('Position', ax_curr.Position, 'XAxisLocation', 'top', 'YAxisLocation', 'right', 'Color', 'none');
    ax_top.XLim = ax_curr.XLim * 60; % Conversión Hz -> BPM
    ax_top.YTick = [];
    xlabel(ax_top, 'BPM Equivalent');
    
    %% PANEL 5: MORPHOLOGY (Pulse Shape)
    subplot(2,3,5); hold on;
    if ~isempty(morph)
        plot(linspace(0,100,200), morph', 'Color',[.8 .8 .8 .3], 'HandleVisibility', 'off'); 
        plot(linspace(0,100,200), mean(morph, 1), 'r', 'LineWidth', 2.5);
    end
    title('5. Avg Pulse Morphology'); xlabel('% Cycle'); grid on; xlim([0 100]);
    
    %% PANEL 6: HEMODYNAMICS (The Final Result)
    ax6 = subplot(2,3,6); 
    yyaxis left; plot(tm, hr, 'b.-'); ylabel('HR (BPM)'); ylim([40 180]);
    yyaxis right; stem(tm, auc, 'Color', [0.8 0 0], 'Marker', 'none', 'LineWidth', 1.5); ylabel('Pulse Volume (AUC)');
    title('6. HR & Perfusion Trends'); xlabel('Time (s)'); grid on; xlim([t_ppg(1) t_ppg(end)]);
    
    % Sincronizar zoom temporal en paneles de serie temporal
    linkaxes([ax1, ax2, ax3, ax6], 'x'); 
    
    sgtitle(['ANALYSIS REPORT | Session: ', name, ' | Sensor: ', side], 'Interpreter', 'none', 'FontWeight', 'bold');
end