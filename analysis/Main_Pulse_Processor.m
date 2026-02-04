%% EARABLE PULSE PIPELINE (PHASES I & II)
%  -----------------------------------------------------------------
%  PURPOSE: Robust in-ear PPG analysis for Phase I & II validation.
%
%  CORE LOGIC (Based on Rosato et al. Methodology):
%  * Integrity: Mandatory chronological sorting and duplicate removal
%  * Filter: 0.5–7 Hz band-pass to isolate heartbeats from noise
%  * Normalization: Resamples beats to 200 points for shape analysis
%  * Quality: Rule-based exclusion of non-physiological artifacts
%  * Phases: Classifies steps as Systolic (0%) or Diastolic (45%)
%  * Hemodynamics: Detects bi-phasic waves and amplitude shifts
%
%  OUTPUTS:
%  * Visual Report: 6-panel verification of signal and morphology
%  * Global Table: CSV summary 

clear; clc; close all;

%% --- 1. USER CONFIGURATION --- ESPECIFICAR Q TIENE Q METER EL USAURIO
root_folder = '/Users/martaguzman/Master/KTH/PhDopp/Recordings';

fs_ppg = 84; % PPG sampling frequency
fs_imu = 50; % IMU sampling frequency

% Physiological Thresholds (Refractory Periods)
max_hr_bpm = 180;        % Prevents dicrotic notch false positives.
max_spm_walk = 140;  % Standard walking limit (SPM) -> steps per min

% Motion detection thresholds
acc_walkthreshold_g = 1.1;   % Gravity (1.0 G) + safety margin (0.1).
acc_cutoff_hz = 15;      % Biomechanical gait filter - standard for human gait biomechanics.

% Time window (100ms) to reject beats coinciding with steps
motion_artifact_window_s = 0.10;

summary_results = {};

%% --- 2. SESSION PROCESSING ---
dir_content = dir(root_folder);
folders = dir_content([dir_content.isdir] & ~startsWith({dir_content.name}, '.'));

for i = 1:length(folders)
    session_id = folders(i).name;
    session_path = fullfile(root_folder, session_id);
    
    ppg_files = dir(fullfile(session_path, '*_PHOTOPLETHYSMOGRAPHY.csv'));
    acc_files = dir(fullfile(session_path, '*_ACCELEROMETER.csv'));
    
    for k = 1:length(ppg_files)
        try
            % A. DETECT SIDE (L/R)
             % Explicitly detect side from filename
            if contains(ppg_files(k).name, '-L_')
                sensor_side = 'L';
            elseif contains(ppg_files(k).name, '-R_')
                sensor_side = 'R';
            else
                % This handles cases where the filename is not standard
                sensor_side = 'Side_Label_Missing_Check_Filename';
                warning('File %s does not contain -L_ or -R_ tags.', ppg_files(k).name);
            end  

            % B. DATA CLEANING
            [ppg_data, ppg_time] = load_and_clean_ppg(ppg_files(k), session_path); 
            [acc_raw, acc_filt, step_times] = load_and_clean_imu(acc_files, sensor_side, session_path, fs_imu,max_spm_walk, acc_walkthreshold_g, acc_cutoff_hz);

            % C. PULSE ANALYSIS (Phase 2.1)
            [filt_sig, cand_amps, cand_times, cand_idx] = preprocess_pulse(ppg_data.GREEN, fs_ppg, max_hr_bpm);
            
            % D. QUALITY VOTE (Artifact Rejection) 
            [v_amps, v_times, v_idx, n_amps, n_times] = validate_pulse_quality(filt_sig, cand_amps, cand_times, cand_idx, fs_ppg, step_times, motion_artifact_window_s);            % E. BIOMETRIC EXTRACTION
            [morphology_200pt, sqi_val, valley_times] = normalize_pulse_shape(filt_sig, v_idx, fs_ppg, ppg_time);        
            [hr_bpm, t_metric, pulse_auc] = extract_pulse_metrics(filt_sig, ppg_time, valley_times);    
           
            [f_ppg, pxx_ppg, s_hr_bpm] = calculate_pulse_spectrum(filt_sig, fs_ppg);
            [f_imu, pxx_imu, s_step_bpm] = calculate_pulse_spectrum(acc_filt, fs_imu);
           
            % F. EXPORT VISUAL DASHBOARD
            h_raw = plot_raw_data_exclusive(ppg_time, ppg_data.GREEN, sensor_side, session_id);
            
            % Definir nombre específico para el Raw
            raw_output_name = [session_id, '_', sensor_side, '_RAW_ONLY'];
            raw_export_path = fullfile(session_path, raw_output_name);
            
            % Guardar PNG y FIG del Raw
            saveas(h_raw, [raw_export_path, '.png']);
            savefig(h_raw, [raw_export_path, '.fig']);
            close(h_raw); % Cerramos para limpiar memoria
            
            fprintf('   Raw Inspection saved: %s.png\n', raw_output_name);
            
            % Generar Dashboard 
            h_fig = plot_research_dashboard(ppg_time, ppg_data.GREEN, filt_sig, v_times, v_amps, ...
            n_times, n_amps, morphology_200pt, hr_bpm, t_metric, pulse_auc, ...
            acc_raw, acc_filt, step_times, sensor_side, session_id, ...
            f_ppg, pxx_ppg, f_imu, pxx_imu);

            % Define the base filename and full storage path
            report_name = [session_id, '_', sensor_side, '_Analysis'];
            export_full_path = fullfile(session_path, report_name);
            
            % Save visual report (PNG) and MATLAB figure (FIG)
            saveas(h_fig, [export_full_path, '.png']);
            savefig(h_fig, [export_full_path, '.fig']);
            
            fprintf('PROCESSING COMPLETE: Session [%s] | Side [%s]\n', session_id, sensor_side);
            fprintf('   Generated File: %s.png\n', report_name);
            fprintf('   Destination: %s\n\n', session_path);
            
            close(h_fig);

            % Store results for Phase III
            summary_results(end+1, :) = {session_id, sensor_side, length(v_idx), mean(hr_bpm), s_hr_bpm, mean(pulse_auc), sqi_val, [report_name, '.png']};
            catch ME
            fprintf('Error in session %s: %s\n', session_id, ME.message);
        end
    end
end

% Export global summary CSV
if ~isempty(summary_results)
    csv_path = fullfile(root_folder, 'Global_Research_Summary.csv');
    % Header matches the 7 elements above
    header = {'SessionID', 'Side', 'Valid_Beats', 'Avg_HR_Peaks', 'HR_Spectral', 'Avg_AUC', 'SQI_Quality', 'Report_File'};    
    writetable(cell2table(summary_results, 'VariableNames', header), csv_path);
    fprintf('\nGlobal Summary saved: %s\n', csv_path);
end