function export_table = eeg_htpDataFrame(EEG, output_dir)
% eeg_htpDataFrame - Convert an EEG SET structure to a long table of
% channel, sample, trial, and amplitude data, and export it to a Parquet
% file.
%
% Syntax:  long_table = eeg_htpDataFrame(EEG, output_dir)
%
% Inputs:
%    EEG - EEG SET structure with channel X sample X trial data
%    output_dir (optional) - directory where the Parquet file should be saved
%
% Outputs:
%    long_table - matrix with four columns: channel, sample, trial, and amplitude
%
% Example:
%    eeg_file = 'example.eeg';
%    EEG = pop_loadset(eeg_file);
%    output_dir = 'Analysis/';
%    long_table = eeg_htpDataFrame(EEG, output_dir);
%
% Other m-files required: None
% Subfunctions: None
% MAT-files required: None
%
% See also: parquetwrite, array2table

% Extract amplitudes from the EEG SET structure
amplitudes = EEG.data;

% Reshape the 3D array to a 2D matrix with channels and samples combined
% as the first dimension, and trials as the second dimension
combined = reshape(permute(amplitudes, [1 3 2]), [], size(amplitudes, 2));

% Get the indices for the long table
[num_channels, num_samples, num_trials] = size(amplitudes);
indices = reshape(repmat(1:num_samples, [num_channels*num_trials, 1]), [], 1);

% Create the long table as a matrix with four columns: channel, sample, trial, amplitude
long_table = [repmat((1:num_channels)', [num_samples*num_trials, 1]), ... % channel
              indices, ... % sample
              reshape(repmat(1:num_trials, [num_channels*num_samples, 1]), [], 1), ... % trial
              combined(:)]; % amplitude

% Convert the long table to a table with appropriate variable names
export_table = array2table(long_table, 'VariableNames', {'chan','sample','trial','amplitude'});

% Get the filename of the input EEG SET file
[~, filename, ~] = fileparts(EEG.filename);

% If the output directory is not specified, use the same directory as the input file
if nargin < 2
    output_dir = EEG.filepath;
end

% Export the table to a Parquet file in the output directory with the same filename as the input file
parquet_filename = fullfile(output_dir, [filename '.parquet']);
parquetwrite(parquet_filename, export_table);

end
