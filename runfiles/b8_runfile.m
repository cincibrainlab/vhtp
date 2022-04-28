% Project: B4Preterm
% Date: 4/26/2022

% add toolkit paths
vhtp_path = '/srv/vhtp';
eeglab_path = '/srv/TOOLKITS/eeglab-2022.0';
brainstorm_path = '/srv/TOOLKITS/brainstorm3';

restoredefaultpath;
addpath(genpath(vhtp_path));
addpath(eeglab_path);
addpath(brainstorm_path);

% run eeglab
eeglab nogui;

% run brainstorm
brainstorm;

% define our specific datasets
% load example EEG file
mySetPath = '/srv/RAWDATA/Grace_Projects/Proj_B4Preterm/B4_Baseline/';
mySetFile = 'D3244_rest_postcomp.set';

% output of source localized datsets
mySourceOutput = '/srv/BIGBUILD/Proj_B4Preterm/mySourceOutput/';
myCsvOuput = '/srv/BIGBUILD/Proj_B4Preterm/myCsvOutput/';


% specify precomputed headmodel file
headmodelfile = '/srv/RESOURCES/headmodel_surf_openmeeg.mat';

% load a sample from our data
EEG = pop_loadset(mySetFile, [mySetPath]);

% run single source generation as test
EEG = eeg_htpCalcSource( EEG, 'nettype', 'EGI128', 'headmodelfile',  headmodelfile, 'outputdir', mySourceOutput, 'resetprotocol', true);


% steps of the analysis
% 1. load electrode data (17 subjects) -> mySetPath
% 2. create source model from each electrode data (17 subject) ->
% mySourceOutput
% 3. perform calculations on electrode and source data (17 + 17)
%     a. mySetPath and mySourceOutput
% 4. combine each calculation into a single subject table (17 rows for each
% table)

% you making a series of loops are to process 1 file at a time


% you are generating spreadsheets


% you then combine the spreadsheets and share them
