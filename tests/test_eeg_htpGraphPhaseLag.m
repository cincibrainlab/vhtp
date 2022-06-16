% test of test_eeg_htpGraphPhaseLag
% test will loop through data, source localize, and create graph tables

restoredefaultpath;
addpath(genpath(fullfile('/srv/vhtp')));
addpath(fullfile('/srv/TOOLKITS/eeglab/'))
addpath(fullfile('/srv/TOOLKITS/brainstorm3/'));
addpath(fullfile('/srv/TOOLKITS/FastFC/'))
addpath(genpath(fullfile('/srv/TOOLKITS/BRAPH/')))

% load toolkits
eeglab nogui;
brainstorm;

% input data
filepath = 'C:\srv\RAWDATA\Proj_Eden';

% output directory for source files
sourcedatapath = 'C:\srv\BIGBUILD\Proj_Eden\source_datasets';
resultspath = 'C:\srv\BIGBUILD\Proj_Eden\results';

% load filelist
filelist = util_htpDirListing(filepath, 'ext', '.set');

%%
% workflow loop
result_array = {};
number_of_files = height(filelist);
subj_percent = 0;
 f = waitbar(0,'Dataset');

for i = 1 : number_of_files
    
    waitbar(subj_percent, f, sprintf('Dataset: %1.0f of %1.0f', i,number_of_files ));

    current_set = filelist{i,2}{1};
    current_subfolder = filelist{i,1}{1};

    EEG = pop_loadset('filename', current_set, ... % load data
        'filepath', current_subfolder);

    SEEG = eeg_htpCalcSource( EEG ); % generate source timeseries

    [SEEG, results] = eeg_htpGraphPhaseLag( SEEG );

    result_array{i} = results;

    subj_percent = i / number_of_files;

end

% phaselag

SEEG3 = eeg_htpGraphDwpli( SEEG )