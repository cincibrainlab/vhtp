# Getting Started with Cincinnati Visual High Throughput Pipeline
## Start analyzing EEG data with vHTP: learn how to calculate resting power with htpCalc functions.
### This tutorial is part of the "Introduction to analysis vHtp" tutorial series.

Note that you can find the code for this repository here:
https://github.com/vhtp/man/vhtp_tutorial1

The core vHtp distribution includes scripts for preprocessing and analyzing EEG data. The eeg_htpCalc series of functions are used to take EEGLAB SET files, perform an analysis, and output CSV-style tables for use in statistical software. The eeg_htpVisualize functions can be used to further visualize these results.

Remember that these packages are essentially a set of tools for easily working with EEG data at different stages. If you would like to know more, check out our tutorial list.

### Overview
The basic process of an eeg_htpCalc function is to:
1. load SET file(s)
2. perform computation
3. return a summary results and quality assurance table

### Prerequistes
First off, you should download a distribution of the vHtp scripts:
`git clone https://github.com/cincibrainlab/vhtp.git`
and obtain a copy of EEGLAB which implements backend SET functions:
`git clone https://github.com/sccn/eeglab.git`

I prefer to place these scripts in a separate toolkit directory which can be updated periodically. 

### Create your first RUNFILE
When you start a new vhtp process, create a "runfile" script to keep track of each step and distribute with your final results. We can create template runfiles for different preprocessing and analysis purposes.

Create a blank MATLAB script and save it as vhtp_tutorial1_runfile.m.

```octave
% vHtp Runfile
% Getting Started Tutorial

% add toolkit paths
vhtp_path = '/srv/vhtp';
eeglab_path = '/srv/TOOLKITS/eeglab2021.1';
restoredefaultpath;
addpath(vhtp_path);
addpath(eeglab_path);
```
Verify the paths by either running eeglab and/or a vhtp function like eeg_htpCalcRestPower.

Let's first work with an individual SET file:
```octave
% load example EEG file
mySetFile = '128_Rest_EyesOpen_D1004.set';
mySetPath = '/srv/RAWDATA/exampledata/';
EEG = pop_loadset(mySetFile, mySetPath);  % eeglab function
```
Next, let's use the vhtp function eeg_htpCalcRestPower to calculate spectral band power and arrange the results in summary table.

```octave
% compute resting spectral band power
EEG = eeg_htpCalcRestPower( EEG );        % vhtp function

% view summary table
EEG.vhtp.eeg_htpCalcRestPower.summary_table
```

The results table dimensions including channel by band power for absolute power, dB normalized, and relative power. The code contains the algorithms used to obtain the final results.

### Multiple files
vhtp functions were designed to perform an operation on a single SET file (and output a SET file). Running multiple SET files in batch, however, is trivial with built in MATLAB function tools.

Here we have directory of three similar resting data files. By similar, we assume they have the same channel number and the same paradigm as they will be combined in a single table.
```octave
D0079_rest_postcomp.fdt  D0079_rest_postcomp.set  D0099_rest_postcomp.fdt  D0099_rest_postcomp.set  D0101_rest_postcomp.fdt  D0101_rest_postcomp.set
```

First, let's obtain a selected list of files we want to process using the `util_htpDirListing` function. Notice the two options we have specified:
1. 'ext' file extention must be a "set"
2. 'subDirOn' do not search subdirectories

```octave
%% Input and Output Base Directories
myRestPath   = '/srv/RAWDATA/exampleBatchData';

% Paradigm #1: 128-channel Resting EEG
myFileList    = util_htpDirListing(myRestPath,'ext','.set', 'subdirOn', false);

```
The output of the util_htpDirListing is a convenient filelist table variable with two columns, the filepath and the filenames. At this point, we can either do our subsequent processing in a for-loop or use MATLAB batch function tools like cellfun. 

### A traditional loop workflow.
This has the advantage of having more control over what is loaded in memory and is extremely readable for sharing or debugging.
Notice, we are also adding a 'gpuOn' flag to speed up calculations using a gpuArray. If your machine does not have a GPU you can omit this parameter.

```octave
batch_result_table = table()
for fi = 1 : height(myFileList)

    EEG = pop_loadset(myFileList.filename{fi}, myFileList.filepath{fi});

    [EEG, results] = eeg_htpCalcRestPower( EEG, 'gpuOn', true );

    batch_result_table = [batch_result_table; results.summary_table];

    EEG = [];

end
writetable(batch_result_table, fullfile(myRestPath, 'resting_power_summary.csv'));
```
The last line uses the MATLAB command `writetable` to save the results to a spreadsheet (CSV). The `fullfile` functions combines a pathname and a filename to create a valid filepath.
