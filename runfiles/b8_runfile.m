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
mySourceOutput = '/srv/Analysis/cbl_analysis_gpu_student/B4_Baseline/source_datasets';
myCsvOuput = '/srv/Analysis/cbl_analysis_gpu_student/B4_Baseline/build';

% specify precomputed headmodel file
headmodelfile = '/srv/RESOURCES/headmodel_surf_openmeeg.mat';

% load a sample from our data
EEG = pop_loadset(mySetFile, [mySetPath]);

% run single source generation as test
EEG = eeg_htpCalcSource( EEG, 'nettype', 'EGI128', 'headmodelfile',  headmodelfile, ...
    'outputdir', mySourceOutput, 'resetprotocol', true);

% Paradigm #1: Resting EEG (Rest)
fl.rest      = util_htpDirListing(indir.rest,'ext','.set', 'subdirOn', false);

% Create output filenames
csv.basename = fullfile(myCsvOuput, 'B4_Baseline.csv');

csv.fl.rest = strrep(csv.basename,'.csv','_filelist_rest.csv');

csv.pow_rel = strrep(csv.basename,'.csv','_pow_rel.csv');
csv.pow_lap = strrep(csv.basename,'.csv','_pow_lap.csv');
csv.pow_mne = strrep(csv.basename,'.csv','_pow_mne.csv');
csv.aac_rel = strrep(csv.basename,'.csv','_aac_rel.csv');
csv.aac_lap = strrep(csv.basename,'.csv','_aac_lap.csv');
csv.aac_mne = strrep(csv.basename,'.csv','_aac_mne.csv');

writetable(fl.rest, csv.fl.rest);

% Summary functions
% File management functions
getFiles            = @( filelist_table ) filelist_table{:, 2};
getPaths            = @( filelist_table ) filelist_table{:, 1};

% load EEG functions
loadEeg             = @( filename, filepath ) pop_loadset(filename, filepath);
loadLaplacianEeg    = @( filename, filepath ) eeg_htpCalcLaplacian( loadEeg( filename, filepath ) );

loadSourceEeg       = @( filename, filepath ) eeg_htpCalcSource( loadEeg( filename, filepath ), 'nettype', 'EGI128', 'headmodelfile',  headmodelfile, ...
    'outputdir', mySourceOutput, 'resetprotocol', true);

loadSourceEeg2       = @( filename, filepath ) eeg_htpCalcSource( loadEeg( filename, filepath ), 'nettype', 'EGI128', 'headmodelfile',  headmodelfile, ...
    'outputdir', mySourceOutput, 'usepreexisting', true);

% calculate functions
runEegFun       = @( EegLoad, EegCalc, files, paths ) cellfun(@(fn,fl) EegCalc(EegLoad(fn, fl)), files, paths);

% summary functions
runRest             = @( EEG ) eeg_htpCalcRestPower( EEG , 'gpuOn', true);
runAac              = @( EEG ) eeg_htpCalcAacGlobal( EEG , 'gpuOn', true);
runAacSource        = @( EEG ) eeg_htpCalcAacGlobal( EEG , 'sourcemode', true, 'gpuOn', true);

% reporting function
summary2table = @( result_struct )  vertcat(result_struct(:).summary_table);
createResultsCsv = @(result_table, csvfile) writetable(vertcat(result_table), csvfile);

%%  Spectral Power
% Electrode Only (Mouse and Human)
res.rest.pow      = table();
[~, res.rest.pow] = runEegFun(loadEeg, runRest, getFiles(fl.rest), getPaths(fl.rest));
createResultsCsv( summary2table( res.rest.pow ), csv.pow_rel );

% Electrode, lapacian spatial filtered (Mouse + Human)
res.rest.lap      = table();
[~, res.rest.lap  ] = runEegFun(loadLaplacianEeg, runRest, getFiles(fl.rest), getPaths(fl.rest));
createResultsCsv( summary2table( res.rest.lap ), csv.pow_lap );

% Source Data (Human)
res.rest.source      = table();
[~, res.rest.source  ] = runEegFun(loadSourceEeg, runRest, getFiles(fl.rest), getPaths(fl.rest));
createResultsCsv( summary2table( res.rest.source ), csv.pow_mne );

%% AAC
% Eletode
[~, res.aac.pow] = runEegFun(loadEeg, runAac, getFiles(fl.rest), getPaths(fl.rest));
createResultsCsv( summary2table( res.aac.pow ), csv.aac_rel );

% Lapacian
[~, res.aac.lap] = runEegFun(loadLaplacianEeg, runAac, getFiles(fl.rest), getPaths(fl.rest));
createResultsCsv( summary2table( res.aac.lap ), csv.aac_lap );
% Source
[~, res.aac.mne] = runEegFun(loadSourceEeg2, runAacSource, getFiles(fl.rest), getPaths(fl.rest));
createResultsCsv( summary2table( res.aac.mne ), csv.aac_mne );