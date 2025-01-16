% test of test_eeg_htpGraphPhaseLag
% test will loop through data, source localize, and create graph tables

restoredefaultpath;

add_path_without_subfolders = @( filepath ) addpath(fullfile( filepath ));
add_path_with_subfolders = @( filepath ) addpath(fullfile( filepath ));

% VHTP
addpath(genpath(fullfile('/Users/ernie/Documents/GitHub/vhtp_og')));

% EEGLAB
addpath(fullfile('/Users/ernie/Documents/GitHub/vhtp_dependencies/eeglab/eeglab2022.1'))

% BS
addpath(fullfile('/Users/ernie/Documents/GitHub/brainstorm3_copy2'))
% VHTP EXTRAS
addpath(genpath(fullfile('/Users/ernie/Documents/GitHub/vhtp_dependencies/BCT')));

% FAST FILTER
%addpath(fullfile('/srv/TOOLKITS/FastFC/'))

% BRAPH GRAPH THEORY TOOLKIT
addpath(genpath(fullfile('/Users/ernie/Documents/GitHub/vhtp_dependencies/BRAPH')))

% load toolkits
eeglab nogui;
brainstorm nogui;
% input data
filepath = '/Users/ernie/Documents/GitHub/EegServer/autoclean/chirp_default/postcomps';
filepath = '/Users/ernie/Documents/GitHub/EegServer/autoclean/chirp_default/debug';
filepath = '/Users/ernie/Documents/GitHub/EegServer/results/chirp_default';
filepath = '/Users/ernie/Documents/GitHub/spg_analysis/cblprod_srv2/chirp'


% output directory for source files
sourcedatapath = '';
resultspath = '/Users/ernie/Documents/GitHub/EegServer/autoclean/chirp_default/debug';
resultspath = '/Users/ernie/Documents/GitHub/EegServer/results/tables';

resultspath_elec = '/Users/ernie/Documents/GitHub/EegServer/results/chirp_elec_calc/tables';
resultspath_mne = '/Users/ernie/Documents/GitHub/EegServer/results/chirp_mne_calc/tables';

% load filelist
filelist = util_htpDirListing(filepath, 'ext', '.set', 'subdirOn', true );
number_of_files = height(filelist);

figurepath = '/Users/ernie/Documents/GitHub/EegServer/results/figures';

chirp_mne_output = '/Users/ernie/Documents/GitHub/EegServer/results/chirp_mne_output';
chirp_mne_calc_output = '/Users/ernie/Documents/GitHub/EegServer/results/chirp_mne_calc';

chirp_elec_calc_output = '/Users/ernie/Documents/GitHub/EegServer/results/chirp_elec_calc';

%%

% workflow loop
result_array = {};
subj_percent = 0;
%waitbar_fig = waitbar(0,'Dataset');
%waitbar_msg = @(current_set) sprintf('Progress: %d of %d', current_set, number_of_files);
%1054 was long
%parfor

EEGCell = {};

summary_chirp_csv_elec = fullfile(resultspath_elec, 'summary_chirp_elec.csv');
fclose(fopen(summary_chirp_csv_elec, 'w'));
group_list_table = readtable("/Users/ernie/Documents/GitHub/spg_analysis/spg_group_list.csv");
group_list_elec = table2cell(group_list_table);

for i = 1 : number_of_files % 37 files

    disp(i);

    % Load File
    current_set = filelist{i,2}{1};
    current_subfolder = filelist{i,1}{1};
    EEG = pop_loadset('filename', current_set, 'filepath', current_subfolder);
    EEG = eeg_checkset(EEG);
    fprintf("Loading %s\n", current_set);

    % Event Handling
    event_types = {EEG.event.type};
    non_di64_indices = find(~strcmp(event_types, 'DI64'));
    for j = non_di64_indices
        EEG.event(j).type = 'boundary';
    end
    EEG = eeg_checkset(EEG, 'eventconsistency');

    EEG = pop_reref(EEG, []);
    EEG = pop_select( EEG,'nochannel',{'E129'});


    SEEG = eeg_htpCalcSource( EEG );

    EEG_EPO = pop_epoch( EEG, {  'DI64'  }, [-0.5        2.75], 'epochinfo', 'yes');
    SEEG_EPO = pop_epoch( SEEG, {  'DI64'  }, [-0.5        2.75], 'epochinfo', 'yes');

    [EEG_EPO, results_elec] = eeg_htpCalcChirpItcErsp(EEG_EPO, 'outputdir', figurepath, 'sourceOn', false, 'byChannel', false, 'baselinew', [-500 0], 'ampThreshold', 350);
    group_list_elec{i,6} = EEG_EPO;
    csv_file_elec = summary_chirp_csv_elec;

    % Check if the file already exists (to avoid rewriting the headers)
    if exist(csv_file_elec, 'file') == 2
        % Append to existing file
        writetable(results_elec.summary_table, csv_file_elec, 'WriteMode', 'append');
    else
        % Write new file with headers
        writetable(results_elec.summary_table, csv_file_elec);
    end


    pop_saveset(EEG_EPO, 'filename', EEG_EPO.filename, 'filepath', chirp_elec_calc_output)
    pop_saveset(SEEG_EPO, 'filename', SEEG_EPO.filename, 'filepath', chirp_mne_output)

end

%% Calculate Source

% load filelist
mne_filelist = util_htpDirListing(chirp_mne_output, 'ext', '.set', 'subdirOn', true );
number_of_files = height(mne_filelist);

csv_file_mne = fullfile(resultspath_mne, 'summary_chirp_mne.csv');
fclose(fopen(csv_file_mne, 'w'));
mne_group_list_table = readtable("/Users/ernie/Documents/GitHub/spg_analysis/spg_group_list.csv");
mne_group_list_mne = table2cell(mne_group_list_table);

parfor i = 1 : number_of_files % 37 files

    disp(i);

    % Load File
    current_set = mne_filelist{i,2}{1};
    current_subfolder = mne_filelist{i,1}{1};
    SEEG_EPO = pop_loadset('filename', current_set, 'filepath', current_subfolder);
    SEEG_EPO = eeg_checkset(SEEG_EPO);
    fprintf("Loading %s\n", current_set);

    [SEEG_EPO_CALC, results_mne] = eeg_htpCalcChirpItcErsp(SEEG_EPO, 'outputdir', figurepath, 'sourceOn', true, 'byChannel', true, 'baselinew', [-500 0], 'ampThreshold', 350);

    mne_group_list_mne{i,6} = SEEG_EPO_CALC;

    pop_saveset(SEEG_EPO_CALC, 'filename', SEEG_EPO_CALC.filename, 'filepath', chirp_mne_calc_output);

    % Check if the file already exists (to avoid rewriting the headers)
    if exist(csv_file_mne, 'file') == 2
        % Append to existing file
        writetable(results_mne.summary_table, csv_file_mne, 'WriteMode', 'append');
    else
        % Write new file with headers
        writetable(results_mne.summary_table, csv_file_mne);
    end

end

%%
% Load filelist
mne_filelist = util_htpDirListing(chirp_mne_output, 'ext', '.set', 'subdirOn', true);
number_of_files = height(mne_filelist);

% Prepare CSV file for writing
summary_chirp_csv_mne = fullfile(resultspath_mne, 'summary_chirp_mne.csv');
fclose(fopen(summary_chirp_csv_mne, 'w'));

% Load group list table
mne_group_list_table = readtable("/Users/ernie/Documents/GitHub/spg_analysis/spg_group_list.csv");
mne_group_list_mne = table2cell(mne_group_list_table);

% Preallocate temporary cell for results
temp_mne_group_list = cell(number_of_files, 6);
temp_results_mne = cell(number_of_files, 1);

% Use parfor for parallel processing
for i = 1:number_of_files
    disp(i);

    % Call the modular function for processing each file
    [SEEG_EPO, results_mne_table] = processMneFile(mne_filelist{i, :}, figurepath, chirp_mne_calc_output);

    % Save results temporarily
    temp_mne_group_list{i, 6} = SEEG_EPO;
    temp_results_mne{i} = results_mne_table;
end

% Combine and write summary tables to the CSV
combined_results = vertcat(temp_results_mne{:});
writetable(combined_results, summary_chirp_csv_mne);

% Update the group list table
mne_group_list_mne(:, 6) = temp_mne_group_list;

disp('Processing completed.');


function [SEEG_EPO, results_mne_table] = processMneFile(file_info, figurepath, chirp_mne_calc_output)
    % Extract file information
    current_set = file_info{2};
    current_subfolder = file_info{1};

    % Load the SEEG data
    SEEG_EPO = pop_loadset('filename', current_set, 'filepath', current_subfolder);

    % Process the data
    [SEEG_EPO, results_mne] = eeg_htpCalcChirpItcErsp(SEEG_EPO, ...
        'outputdir', figurepath, ...
        'sourceOn', true, ...
        'byChannel', true, ...
        'baselinew', [-500 0], ...
        'ampThreshold', 350);

    % Save the processed SEEG data
    pop_saveset(SEEG_EPO, 'filename', SEEG_EPO.filename, 'filepath', chirp_mne_calc_output);

    % Return the summary table
    results_mne_table = results_mne.summary_table;
end

%%

contrast_pairs = {{2,1}, {4,3}, {6,5}, {8,7}, {10,9}, {12,11}, {14,13}, {16,15}, {18,17}, {20,19}};
    [EEGchirp2, results] = eeg_htpVisualizeChirpItcErsp( group_list(:,6), 'groupIds', ... 
        cell2mat(group_list(:,5)'), 'contrasts', contrast_pairs, 'outputdir', resultspath, 'groupmean', true, 'singleplot', false);




%%

for i = 1 :  number_of_files

    % ==================
    % LOAD DATA
    % ==================
    current_set = filelist{i,2}{1};
    current_subfolder = filelist{i,1}{1};
    EEG = pop_loadset('filename', current_set, ... % load data
        'filepath', current_subfolder);
    EEG = eeg_checkset(EEG);

    % ==================
    % REMOVE BOUNDARIES
    % ==================
    % Get all event types
    event_types = {EEG.event.type};
    % Find indices of non-'DI64' events
    non_di64_indices = find(~strcmp(event_types, 'DI64'));
    % Convert these events to 'boundary'
    for j = non_di64_indices
        EEG.event(j).type = 'boundary';
    end
    % Check and update the EEG structure
    EEG = eeg_checkset(EEG, 'eventconsistency');

    % ==================
    % EPOCH DATA
    % ==================
    EEG = pop_epoch( EEG, {  'DI64'  }, [-0.5        2.75], 'epochinfo', 'yes');
    event_types = {EEG.event.type};

    % SEEG = eeg_htpCalcSource( EEG );
    [EEG, results_itc] = eeg_htpCalcChirpItcErsp(EEG, 'sourceOn', false, 'byChannel', false, 'baselinew', [-500 0], 'ampThreshold', 350);

    % Check if the file already exists (to avoid rewriting the headers)
    if exist(csv_file, 'file') == 2
        % Append to existing file
        writetable(results_itc.summary_table, csv_file, 'WriteMode', 'append');
    else
        % Write new file with headers
        writetable(results_itc.summary_table, csv_file);
    end


    EEGCell{1}= EEG;
    [EEGchirp2, results] = eeg_htpVisualizeChirpItcErsp( EEGCell, 'outputdir', resultspath, 'groupmean', false, 'singleplot', true);



    %EEG = eeg_htpCalcLaplacian(EEG);

    % SEEG = eeg_htpCalcSource( EEG ); % generate source timeseries
    %EEG = eeg_htpEegWaveletDenoiseHappe(EEG);
    %EEG = eeg_htpCalcFooof(EEG);
    %[EEG2, results] = eeg_htpCalcChirpItcErsp(EEG, 'sourceOn', false, 'byChannel', false, 'baselinew', [-500 0], 'ampThreshold', 200);

    %EEGCell{1}= EEG2;
    %[EEGchirp2, results] = eeg_htpVisualizeChirpItcErsp( EEGCell, 'outputdir', resultspath, 'groupmean', false, 'singleplot', true);

    %EEG = eeg_htpCalcRestPower( EEG, 'outputdir', resultspath );


    %    [SEEG, results] = eeg_htpGraphPhaseBcm( EEG, 'outputdir', resultspath );

    % result_array{i} = results;

    subj_percent = i / number_of_files;

    waitbar( i / number_of_files, waitbar_fig, sprintf('Progress: %1.0f of %1.0f', i,number_of_files ));
    % end
end

close (waitbar_fig)% waitbar


