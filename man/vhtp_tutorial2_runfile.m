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
    [EEG2, results] = eeg_htpCalcChirpItcErsp(EEG, 'sourceOn', true, 'byChannel', true, 'baselinew', [-500 0]);

    EEGCell{fi} = EEG2;
  
    %end
end

% get correct order of eegids for groups
for i = 1 : numel(EEGCell)
    EEG_tmp = EEGCell{i};
    sorted_eegids{i} = EEG_tmp.subject;
end
group_assigments = readtable(fullfile(mySourceOutput, "chirpsource_grouplist.csv"));
sorted_eegid_table = cell2table(sorted_eegids', 'VariableNames',{'eegid'});
sorted_eegidgroup_table = innerjoin(sorted_eegid_table, group_assigments, "LeftKeys","eegid","RightKeys","eegid_og");
sorted_eegidgroup_table.subgroup = categorical(sorted_eegidgroup_table.subgroup);
sorted_eegidgroup_table.group = categorical(sorted_eegidgroup_table.group);
sorted_eegidgroup_table.subgroup = categorical(sorted_eegidgroup_table.subgroup);
sorted_eegidgroup_table.sex = categorical(sorted_eegidgroup_table.sex);
sorted_eegidgroup_table.subgroupid = grp2idx(sorted_eegidgroup_table.subgroup);
sorted_eegidgroup_table.groupid = grp2idx(sorted_eegidgroup_table.group );

categories(sorted_eegidgroup_table.subgroup)
categories(sorted_eegidgroup_table.group)

[EEGchirp2, results] = eeg_htpVisualizeChirpItcErsp( EEGCell, 'groupmean', true, 'singleplot', true, ...
    'groupIds', sorted_eegidgroup_table.subgroupid,'outputdir',fullfile(myDatasetOuput, 'sourcetracings'));

[EEGchirp2, results] = eeg_htpVisualizeChirpItcErsp( EEGCell, 'groupmean', true, 'singleplot', true, ...
    'groupIds', sorted_eegidgroup_table.subgroupid,'outputdir',fullfile(myDatasetOuput, 'sourcetracings_region_sex'), ...
    'averageByRegion', true, 'contrasts', {[1 3],[2 4]});

[EEGchirp2, results] = eeg_htpVisualizeChirpItcErsp( EEGCell, 'groupmean', true, 'singleplot', true, ...
    'groupIds', sorted_eegidgroup_table.groupid,'outputdir',fullfile(myDatasetOuput, 'sourcetracings_region_group'), ...
    'averageByRegion', true, 'contrasts', {[1 2]});


% Create and save results table
eeg_htpCalcChirpItcErsp_summary_table = table();
for ti = 1 : numel(EEGCell)
    eeg_htpCalcChirpItcErsp_summary_table = vertcat(eeg_htpCalcChirpItcErsp_summary_table, EEGCell{ti}.vhtp.eeg_htpCalcChirpItcErsp.summary_table);
end
writetable(eeg_htpCalcChirpItcErsp_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcChirpItcErsp_summary_table.csv"));

% Spectral Events
addpath("/srv/TOOLKITS/SpectralEvents");
% Calculate chirp ITC
%EEGSECell = {};
%EEGPLCell = {};
%%
for fi = 1 : height(myFileListSource)
    %if fi == 1

    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    EEG = pop_select(EEG, 'time', [-500 0]); % extract baseline
    %EEGSE = eeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput, "SE"));
    EEGPL = eeg_htpCalcPhaseLagFrontalTemporal(EEG, 'outputdir', fullfile(myDatasetOuput, "PL"));
    % EEGSECell{fi} = EEGSE; %#ok<SAGROW> 
    EEGPLCell{fi} = EEGPL;
    %end
end
%%

% Create and save results table
eeg_htpCalcRestPower_summary_table = table();
eeg_htpCalcPhaseLagFrontalTemporal_summary_table = table();
eeg_htpCalcAacGlobal_summary_table = table();
eeg_htpCalcSpectralEvents_table = table();

for ti = 1 : numel(EEGSECell)
    %eeg_htpCalcRestPower_summary_table = vertcat(eeg_htpCalcRestPower_summary_table, EEGRestCell{ti}.vhtp.eeg_htpCalcRestPower.summary_table);
    eeg_htpCalcPhaseLagFrontalTemporal_summary_table = vertcat(eeg_htpCalcPhaseLagFrontalTemporal_summary_table, EEGPLCell{ti}.vhtp.eeg_htpCalcPhaseLag.summary_table);
    %eeg_htpCalcAacGlobal_summary_table = vertcat(eeg_htpCalcAacGlobal_summary_table, EEGAacCell{ti}.vhtp.eeg_htpCalcAacGlobal.summary_table);
    eeg_htpCalcSpectralEvents_table = vertcat(eeg_htpCalcSpectralEvents_table, EEGSECell{ti}.vhtp.eeg_htpCalcSpectralEvents.summary_table); %#ok<*AGROW> 

        
end
writetable(eeg_htpCalcSpectralEvents_table, fullfile(myDatasetOuput, "eeg_htpCalcSpectralEvents_table.csv"));
writetable(eeg_htpCalcPhaseLagFrontalTemporal_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcPhaseLagFrontalTemporal_Frontal_summary_table.csv"));


writetable(eeg_htpCalcRestPower_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcRestPower_summary_table.csv"));
writetable(eeg_htpCalcAacGlobal_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcAacGlobal_summary_table.csv"));

