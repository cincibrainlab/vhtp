% vHtp Runfile
% Chirp Spectral Events Runfile
% Computing SE variations on Chirp Source data

% add toolkit paths
vhtp_path = '/srv/vhtp';
eeglab_path = '/srv/TOOLKITS/eeglab2021.1';
brainstorm_path = '/srv/TOOLKITS/brainstorm3';
restoredefaultpath;
addpath(genpath(vhtp_path));
addpath(eeglab_path);
addpath(brainstorm_path);

% run eeglab
eeglab nogui;
% run brainstorm
%brainstorm;

% load example EEG file
% Pre source conversion
mySetFile = 'D0179_chirp-ST_postcomp.set';
mySetPath = '/srv/RAWDATA/Grace_Projects/Proj_FxsChirp';

% post source conversion (for SE)
mySourceOutput = '/srv/RAWDATA/Grace_Projects/Proj_FxsChirpSource/';
myDatasetOuput = '/srv/BIGBUILD/Proj_FxsChirpSe/';

% Spectral Events
addpath("/srv/TOOLKITS/SpectralEvents");

% Get new file lists of source files
myFileListSource    = util_htpDirListing(mySourceOutput,'ext','.set', 'subdirOn', false);



%% spec events during chirp 

for fi = 1 : height(myFileListSource)

    % print new file being loaded
    fprintf('\nNEW FILE fi=%d\n\n', fi)

    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    
    % pre stimulus
    %EEG = pop_select(EEG, 'time', [EEG.xmin, 0]);
    % entire chirp stimulus
    EEG = pop_select(EEG, 'time', [0, EEG.xmax]);

    % event 3 regions RT LT RF LF RO LO
    EEGSE = eeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput), ... 
        'findMethod', int8(1), ...  % method 1 (overlapping events)
        'selectRegions', {'RT', 'LT', 'RF', 'LF', 'RO', 'LO'}, ...  % ROI
        'vis', false, ...   % no figures
        'bandDefs', {   % only theta, alpha, beta, gamma1, gamma2
                'theta', 3.5, 7.5;
                'alpha', 8, 13;
                'beta', 13, 30;
                'gamma1', 30, 55;
                'gamma2', 65, 80;
            }, ...
        'writeCsvFile', false, ...
        'duration', (EEG.pnts/EEG.srate)*EEG.trials); % total duration

    % add to cell
    EEGSECell{fi} = EEGSE; %#ok<SAGROW> 

end

% generate and save table
eeg_htpCalcSpectralEvents_table = table();
for ti = 1 : numel(EEGSECell)
    eeg_htpCalcSpectralEvents_table = vertcat(eeg_htpCalcSpectralEvents_table, EEGSECell{ti}.vhtp.eeg_htpCalcSpectralEvents.summary_table); %#ok<*AGROW>    
end
writetable(eeg_htpCalcSpectralEvents_table, fullfile(myDatasetOuput, "eeg_htpCalcSpectralEvents_table_prestimulus_method1_FINAL.csv"));




%%
%% itc40, itc80

for fi = 1 : height(myFileListSource)

    % indicate new file being loaded
    fprintf('\nNEW FILE fi=%d\n\n', fi)

    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    
    % select whole chirp stimulus, pick events after
    EEG = pop_select(EEG, 'time', [0, EEG.xmax]);
    
    % chirp 80Hz
    %EEG = pop_select(EEG, 'time', [1.390, 1.930]);


    % tlim - only select events within tlim range
    % 0 to 600 for 1250 - 650, within the selected time range
    % could maybe try not using pop_select and only using tlim 
    EEGSE = eeg_htpCalcSpectralEvents_NEWARG(EEG, 'outputdir', fullfile(myDatasetOuput), ... 
        'findMethod', int8(1), ...
        'selectRegions', {'RT', 'LT', 'RF', 'LF'}, ...
        'bandDefs', {'alpha', 8, 13; ...
                     'gamma1', 30, 55; ...
                     'gamma2', 65, 80;}, ...
        'vis', false, ...
        'tlim', [2.038 2.254]); %itc40 = 650 ms to 1250 ms


    % add to cell
    EEGSECell{fi} = EEGSE; %#ok<SAGROW> 

end

%generate and save table
eeg_htpCalcSpectralEvents_table = table();
for ti = 1 : numel(EEGSECell)
    eeg_htpCalcSpectralEvents_table = vertcat(eeg_htpCalcSpectralEvents_table, EEGSECell{ti}.vhtp.eeg_htpCalcSpectralEvents.summary_table); %#ok<*AGROW>    
end
writetable(eeg_htpCalcSpectralEvents_table, fullficurrowle(myDatasetOuput, "eeg_htpCalcSpectralEvents_table_itcoffset.csv"));



