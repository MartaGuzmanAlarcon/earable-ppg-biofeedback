function [clean_data, time_vec] = load_and_clean_ppg(file_struct, session_path)
    % Description: Reads PPG CSV, sorts timestamps, and removes duplicates.
    % Inputs: 
    %   - file_struct: Directory structure from dir() command.
    %   - session_path: String path to the session folder.
    % Outputs:
    %   - clean_data: Table with sorted and unique PPG samples.
    %   - time_vec: Vector of time in seconds relative to the first sample.
    
    raw_table = readtable(fullfile(session_path, file_struct.name));
    raw_table = sortrows(raw_table, 'timestamp'); 
    [~, unique_idx] = unique(raw_table.timestamp, 'stable');
    clean_data = raw_table(unique_idx, :);
    time_vec = (clean_data.timestamp - clean_data.timestamp(1)) / 1e6;
end