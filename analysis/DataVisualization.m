clear; clc; close all;

% directory where recordings are stored
rootFolder = '/Users/martaguzman/Master/KTH/PhDopp/Recordings'; 

% Get all folders with Recordings
allContent = dir(rootFolder);
% Filter out non-directories and hidden Mac files
myFolders = allContent([allContent.isdir] & ~startsWith({allContent.name}, '.'));

fprintf('Found %d recording folders.\n', length(myFolders));

% Iterate through each session folder to analyze Left (L) and Right (R) ear data 
for i = 1:length(myFolders)
    currentFolderPath = fullfile(rootFolder, myFolders(i).name);
    
    % Identify sensor files (IMU/PPG...)
    ppgFiles = dir(fullfile(currentFolderPath, '*_PHOTOPLETHYSMOGRAPHY.csv'));
    accFiles = dir(fullfile(currentFolderPath, '*_ACCELEROMETER.csv'));
    gyroFiles = dir(fullfile(currentFolderPath, '*_GYROSCOPE.csv'));

    if isempty(ppgFiles) || isempty(accFiles), continue; end

    % Process each PPG file found (Left or Right)
    for k = 1:length(ppgFiles)
        try
            % LOAD PPG DATA 
            T_ppg = readtable(fullfile(currentFolderPath, ppgFiles(k).name));
            t_ppg = (T_ppg.timestamp - T_ppg.timestamp(1)) / 1e6; % Convert microsec to sec
            greenSignal = T_ppg.GREEN; % Heart rate is usually clearest in GREEN

            % Determine side (Left vs Right) to match with IMU
            side = 'L'; 
            if contains(ppgFiles(k).name, '-R_'), side = 'R'; end
            
            % --- B. LOAD & MATCH ACCELEROMETER ---
            idxAcc = find(contains({accFiles.name}, ['-' side '_']), 1);
            if isempty(idxAcc), continue; end
            
            T_acc = readtable(fullfile(currentFolderPath, accFiles(idxAcc).name));
            t_acc = (T_acc.timestamp - T_acc.timestamp(1)) / 1e6;
            
            % Resultant Acceleration Magnitude (Includes Gravity)
            % Formula: sqrt(X^2 + Y^2 + Z^2)
            accMag = sqrt(T_acc.X.^2 + T_acc.Y.^2 + T_acc.Z.^2);

            % LOAD & MATCH GYROSCOPE 
            idxGyro = find(contains({gyroFiles.name}, ['-' side '_']), 1);
            if ~isempty(idxGyro)
                T_gyro = readtable(fullfile(currentFolderPath, gyroFiles(idxGyro).name));
                t_gyro = (T_gyro.timestamp - T_gyro.timestamp(1)) / 1e6;
                gyroMag = sqrt(T_gyro.X.^2 + T_gyro.Y.^2 + T_gyro.Z.^2);
            end

            % MULTI-MODAL VISUALIZATION (RAW DATA) 
            figName = sprintf('Session: %s | Side: %s', myFolders(i).name, side);
            f = figure('Name', figName, 'Color', 'w', 'Units', 'normalized', 'Position', [0.1 0.1 0.8 0.8]);
            
            % Subplot 1: Acceleration (Steps/Impacts)
            subplot(3,1,1);
            plot(t_acc, accMag, 'k');
            title(['ACCELEROMETER - Total Magnitude (Step Impacts) - ', side]);
            ylabel('m/s^2'); grid on;
            legend('Acceleration Magnitude', 'Location', 'northeast'); 

            % Subplot 2: Gyroscope (Head Rotation/Gait Rhythm)
            subplot(3,1,2);
            if ~isempty(idxGyro)
                plot(t_gyro, gyroMag, 'm');
                title('GYROSCOPE - Rotation Magnitude (Gait Sway)');
                ylabel('rad/s'); grid on;
                legend('Gyroscope Magnitude', 'Location', 'northeast'); 
            end

            % Subplot 3: PPG (Heart Rate Raw Signal)
            subplot(3,1,3);
            plot(t_ppg, greenSignal, 'g');
            title('PPG - Raw Green Channel (Heart Rate)');
            ylabel('Amplitude'); xlabel('Time (seconds)'); grid on;
            legend('Green Channel Raw', 'Location', 'northeast'); 

            % Sync X-axes for precise comparison of step vs. pulse
            linkaxes(findall(gcf, 'type', 'axes'), 'x');

            % Save figures 
            saveName = fullfile(currentFolderPath, ['Report_' side]);
            saveas(f, [saveName '.png']); % Imagen para ver rápido
            saveas(f, [saveName '.fig']); % Archivo para abrir en MATLAB
            close(f); % Cierra para no saturar la pantalla

            fprintf(' -> Saved: %s Ear in %s\n', side, myFolders(i).name);

        catch ME
            fprintf('Error processing file %s: %s\n', ppgFiles(k).name, ME.message);
        end
    end
end
disp('Analysis Complete');