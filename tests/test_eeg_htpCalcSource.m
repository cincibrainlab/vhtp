% test of eeg_htpCalcSource
restoredefaultpath;
addpath(genpath(fullfile('/srv/vhtp')));
addpath(fullfile('/srv/TOOLKITS/eeglab/'))
addpath(fullfile('/srv/TOOLKITS/brainstorm3/'));

% load toolkits
eeglab nogui;
brainstorm;

% test data
filepath = 'C:\srv\RAWDATA\P1_70FXS_71_TDC\S04_POSTCOMP\Group2';
filename = 'D0079_rest_postcomp.set';

% load data
EEG = pop_loadset('filename', filename, 'filepath', filepath);

%%
% Source localize
% output of source localized datsets
mySourceOutput = '/srv/Analysis/';

% run single source generation as test
sEEG = eeg_htpCalcSource( EEG, 'resetprotocol', true );

% generated head model
sEEG = eeg_htpCalcSource( EEG, 'resetprotocol', true, 'computeheadmodel', true );
