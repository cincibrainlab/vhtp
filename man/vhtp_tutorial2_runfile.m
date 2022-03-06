% vHtp Runfile
% Getting Started Tutorial
% Computing an MNE model for event related data

% add toolkit paths
vhtp_path = '/srv/vhtp';
eeglab_path = '/srv/TOOLKITS/eeglab2021.1';
brainstorm_path = '/srv/TOOLKITS/brainstorm3';
restoredefaultpath;
addpath(genpath(vhtp_path));
addpath(eeglab_path);
addpath(brainstorm_path);

% run eeglab
eeglab
% run brainstorm
brainstorm;

% load example EEG file
mySetFile = 'D0179_chirp-ST_postcomp.set';
mySetPath = '/srv/RAWDATA/Grace_Projects/Proj_FxsChirp';
mySourceOutput = '/srv/RAWDATA/Grace_Projects/Proj_FxsChirpSource/';
myDatasetOuput = '/srv/BIGBUILD/Proj_FxsChirpSource/';

EEG = pop_loadset(mySetFile, mySetPath);

% specify precomputed headmodel file
headmodelfile = '/srv/RESOURCES/headmodel_surf_openmeeg.mat';

% run single source generation as test
EEG = eeg_htpCalcSource( EEG, 'headmodelfile',  headmodelfile, 'outputdir', mySourceOutput, 'resetprotocol', true);

% Perform batch processing: Generate source SET files
myFileList    = util_htpDirListing(mySetPath,'ext','.set', 'subdirOn', false);

for fi = 1 : height(myFileList)

    EEG = pop_loadset(myFileList.filename{fi}, myFileList.filepath{fi});

    EEG2 = eeg_htpCalcSource( EEG, 'headmodelfile',  headmodelfile, 'outputdir', mySourceOutput);

    EEG2 = [];

end

% Get new file lists of source files
myFileListSource    = util_htpDirListing(mySourceOutput,'ext','.set', 'subdirOn', false);

% Calculate chirp ITC
EEGCell = {};
for fi = 1 : height(myFileListSource)
    %if fi == 1

    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    [EEG2, results] = eeg_htpCalcChirpItcErsp(EEG, 'sourceOn', true, 'byChannel', true);

    EEGCell{fi} = EEG2;
  
    %end
end

% Create and save results table
eeg_htpCalcChirpItcErsp_summary_table = table();
for ti = 1 : numel(EEGCell)
    eeg_htpCalcChirpItcErsp_summary_table = vertcat(eeg_htpCalcChirpItcErsp_summary_table, EEGCell{ti}.vhtp.eeg_htpCalcChirpItcErsp.summary_table);
end
writetable(eeg_htpCalcChirpItcErsp_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcChirpItcErsp_summary_table.csv"));

% Spectral Events
addpath("/srv/TOOLKITS/SpectralEvents");
% Calculate chirp ITC
EEGSECell = {};
EEGPLCell = {};
for fi = 1 : height(myFileListSource)
    %if fi == 1

    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    EEG = pop_select(EEG, 'time', [-500 0]); % extract baseline
    EEGSE = eeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput, "SE"));
    EEGPL = eeg_htpCalcPhaseLagFrontalTemporal(EEG, 'outputdir', fullfile(myDatasetOuput, "PL"));
    EEGSECell{fi} = EEGSE; %#ok<SAGROW> 
    EEGPLCell{fi} = EEGPL;
    %end
end


  [EEGcell, results] = eeg_htpVisualizeChirpItcErsp( {EEG2,EEG2, EEG2}, 'singleplotOn')
  [EEGcell, results] = eeg_htpVisualizeChirpItcErsp( {EEG2,EEG2, EEG2}, 'singleplot', true, 'groupmean', false)


