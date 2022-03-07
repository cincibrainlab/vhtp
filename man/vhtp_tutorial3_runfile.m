% vHtp Runfile
% Getting Started Tutorial
% Computing MNE for Low Density EEG

% add toolkit paths
vhtp_path = 'C:\Users\ernie\Dropbox\RESEARCH_FOCUS\MAIN_SAT\EEG Paper\vhtp';
eeglab_path = 'C:\Users\ernie\Dropbox\RESEARCH_FOCUS\MAIN_SAT\EEG Paper\eeglab';
brainstorm_path = 'E:\Research Software\brainstorm3';
restoredefaultpath;
addpath(genpath(vhtp_path));
addpath(eeglab_path);
addpath(brainstorm_path);

% run eeglab
eeglab
% run brainstorm
brainstorm;

% load example EEG file
mySetFile = 'D0004_rest_postcomp.set';
mySetPath = 'E:\data\SAT\';
mySourceOutput = 'E:\data\SATSource\';
myDatasetOuput = 'C:\Users\ernie\Dropbox\RESEARCH_FOCUS\MAIN_SAT\EEG Paper\satbuild';

EEG = pop_loadset(mySetFile, [mySetPath 'Group1-ASD/']);

% specify precomputed headmodel file
headmodelfile = 'C:\Users\ernie\Dropbox\RESEARCH_FOCUS\COMMON_RESOURCES\headmodel_surf_openmeeg_EGI32.mat';

% run single source generation as test
EEG = eeg_htpCalcSource( EEG, 'nettype', 'EGI32', 'headmodelfile',  headmodelfile, 'outputdir', mySourceOutput, 'resetprotocol', true);

% Perform batch processing: Generate source SET files
myFileList    = util_htpDirListing(mySetPath,'ext','.set', 'subdirOn', true);

for fi = 1 : height(myFileList)

    EEG = pop_loadset(myFileList.filename{fi}, myFileList.filepath{fi});

    EEG2 = eeg_htpCalcSource( EEG, 'nettype', 'EGI32', 'headmodelfile',  headmodelfile, 'outputdir', mySourceOutput);

    EEG2 = [];

end

% Get new file lists of source files
myFileListSource    = util_htpDirListing('E:\data\SATSource\MN_EEG_Constr_2018\' ,'ext','.set', 'subdirOn', false);

%%
% Spectral Events
addpath("C:\Users\ernie\Dropbox\RESEARCH_FOCUS\MAIN_SAT\EEG Paper\SpectralEvents");
EEGSECell = {};

for fi = 1 : height(myFileListSource)
   fi
   EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
   EEGSE = eeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput, "SE"));
   EEGSECell{fi} = EEGSE; %#ok<SAGROW> 
end

%%
% Calculate chirp ITC
EEGSECell = {};
EEGPLCell = {};
EEGRestCell = {};
EEGAacCell = {};
for fi = 1 : height(myFileListSource)
    %if fi == 1
fi
    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    % EEG = pop_select(EEG, 'time', [-500 0]); % extract baseline
    EEGRest = eeg_htpCalcRestPower(EEG, 'gpuOn', true); 
   % EEGSE = eeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput, "SE"));
    EEGPL = eeg_htpCalcPhaseLagFrontalTemporal(EEG, 'outputdir', fullfile(myDatasetOuput, "PL"), 'gpuOn', false);
    EEGAAC = eeg_htpCalcAacGlobal( EEG, 'sourcemode', true, 'gpuOn', true );
    
    EEGRest.data = [];
    EEGAAC.data = [];
    EEGPL.data = [];
    EEGAAC.data = [];
    
    EEGRestCell{fi} = EEGRest;
   
    EEGPLCell{fi} = EEGPL;
    EEGAacCell{fi} = EEGAAC;
    %end
end


% Create and save results table
eeg_htpCalcRestPower_summary_table = table();
eeg_htpCalcPhaseLagFrontalTemporal_summary_table = table();
eeg_htpCalcAacGlobal_summary_table = table();

for ti = 1 : numel(EEGRestCell)
    eeg_htpCalcRestPower_summary_table = vertcat(eeg_htpCalcRestPower_summary_table, EEGRestCell{ti}.vhtp.eeg_htpCalcRestPower.summary_table);
    eeg_htpCalcPhaseLagFrontalTemporal_summary_table = vertcat(eeg_htpCalcPhaseLagFrontalTemporal_summary_table, EEGPLCell{ti}.vhtp.eeg_htpCalcPhaseLag.summary_table);
    eeg_htpCalcAacGlobal_summary_table = vertcat(eeg_htpCalcAacGlobal_summary_table, EEGAacCell{ti}.vhtp.eeg_htpCalcAacGlobal.summary_table);

        
end
writetable(eeg_htpCalcRestPower_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcRestPower_summary_table.csv"));
writetable(eeg_htpCalcPhaseLagFrontalTemporal_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcPhaseLagFrontalTemporal_summary_table.csv"));
writetable(eeg_htpCalcAacGlobal_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcAacGlobal_summary_table.csv"));
