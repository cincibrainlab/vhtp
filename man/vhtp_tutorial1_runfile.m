% vHtp Runfile
% Getting Started Tutorial

% add toolkit paths
vhtp_path = '/srv/vhtp';
eeglab_path = '/srv/TOOLKITS/eeglab-2022.0';
restoredefaultpath;
addpath(vhtp_path);
addpath(eeglab_path);

eeglab nogui;

% load example EEG file
mySetFile = '128_Rest_EyesOpen_D1004.set';
mySetPath = '/srv/RAWDATA/exampledata/';
EEG = pop_loadset(mySetFile, mySetPath);

% compute resting spectral band power
EEG = eeg_htpCalcRestPower( EEG );

% view summary table
EEG.vhtp.eeg_htpCalcRestPower.summary_table

%% Input and Output Base Directories
myRestPath   = '/srv/RAWDATA/exampleBatchData';

% Paradigm #1: 128-channel Resting EEG
myFileList    = util_htpDirListing(myRestPath,'ext','.set', 'subdirOn' false);

batch_result_table = table()
for fi = 1 : height(myFileList)

    EEG = pop_loadset(myFileList.filename{fi}, myFileList.filepath{fi});

    [EEG, results] = eeg_htpCalcRestPower( EEG, 'gpuOn', true );

    batch_result_table = [batch_result_table; results.summary_table];

    EEG = [];
end
writetable(batch_result_table, fullfile(myRestPath, 'resting_power_summary.csv'));

% Alternative MATLAB non-loop version (function handles and cellfun)

% File management functions
getFiles            = @( filelist_table ) filelist_table{:, 2};
getPaths            = @( filelist_table ) filelist_table{:, 1};

% Useful vhtp anonymous function handles (shortcuts)
loadEeg     = @(filename, filepath) pop_loadset(filename, filepath);
calcRest    = @( EEG ) eeg_htpCalcRestPower( EEG , 'gpuOn', true);

% general calculate functions
runEegFun       = @( EegLoad, EegCalc, files, paths ) cellfun(@(fn,fl) EegCalc(EegLoad(fn, fl)), files, paths);

% reporting function
summary2table = @( result_struct )  vertcat(result_struct(:).summary_table);
createResultsCsv = @(result_table, csvfile) writetable(vertcat(result_table), csvfile);

%%  Spectral Power
batch_result_table     = table();
[~, results] = runEegFun(loadEeg, calcRest, getFiles(myFileList), getPaths(myFileList));
createResultsCsv( summary2table( results ),  fullfile(myRestPath, 'resting_power_summary_nonloop.csv'));
