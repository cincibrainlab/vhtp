% vHtp Runfile
% Getting Started Tutorial
% Wavelet Thresholding

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

% load example EEG file
mySetFile = 'D0004_rest_postcomp.set';
mySetPath = 'E:\data\SAT\';
mySourceOutput = 'E:\data\SATSource\';
myDatasetOuput = 'C:\Users\ernie\Dropbox\RESEARCH_FOCUS\MAIN_SAT\EEG Paper\satbuild';

EEG = pop_loadset(mySetFile, [mySetPath 'Group1-ASD/']);

% specify precomputed headmodel file
headmodelfile = 'C:\Users\ernie\Dropbox\RESEARCH_FOCUS\COMMON_RESOURCES\headmodel_surf_openmeeg_EGI32.mat';

% Wavelet Thresholding
EEG2 = eeg_htpEegWaveletDenoiseHappe( EEG );
EEG2.srate =1000;
eeg_htpEegAssessPipelineHAPPE(EEG, EEG2);

test = doChannelVariance(EEG, 0)

 means = assessPipelineStep('test', EEG.data, EEG2.data, [], EEG.srate, [1:5])


% Perform batch processing: Generate source SET files
myFileList    = util_htpDirListing(mySetPath,'ext','.set', 'subdirOn', true);

for fi = 1 : height(myFileList)

    EEG = pop_loadset(myFileList.filename{fi}, myFileList.filepath{fi});

    EEG2 = eeg_htpCalcSource( EEG, 'nettype', 'EGI32', 'headmodelfile',  headmodelfile, 'outputdir', mySourceOutput);

    EEG2 = [];

end