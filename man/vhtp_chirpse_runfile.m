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

%%
for fi = 1 : 1 %height(myFileListSource)
    %if fi == 1

    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    
    EEG = pop_select(EEG, 'time', [-500 0]); % extract baseline
    
    
    EEGSE = eeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput));
    %EEGPL = eeg_htpCalcPhaseLagFrontalTemporal(EEG, 'outputdir', fullfile(myDatasetOuput, "PL"));
    EEGSECell{fi} = EEGSE; %#ok<SAGROW> 
    %EEGPLCell{fi} = EEGPL;
    %end
end


%%

% Create and save results table
% eeg_htpCalcPhaseLagFrontalTemporal_summary_table = table();
eeg_htpCalcSpectralEvents_table = table();

for ti = 1 : numel(EEGSECell)
    %eeg_htpCalcRestPower_summary_table = vertcat(eeg_htpCalcRestPower_summary_table, EEGRestCell{ti}.vhtp.eeg_htpCalcRestPower.summary_table);
    %eeg_htpCalcPhaseLagFrontalTemporal_summary_table = vertcat(eeg_htpCalcPhaseLagFrontalTemporal_summary_table, EEGPLCell{ti}.vhtp.eeg_htpCalcPhaseLag.summary_table);
    %eeg_htpCalcAacGlobal_summary_table = vertcat(eeg_htpCalcAacGlobal_summary_table, EEGAacCell{ti}.vhtp.eeg_htpCalcAacGlobal.summary_table);
    eeg_htpCalcSpectralEvents_table = vertcat(eeg_htpCalcSpectralEvents_table, EEGSECell{ti}.vhtp.eeg_htpCalcSpectralEvents.summary_table); %#ok<*AGROW> 

        
end
writetable(eeg_htpCalcSpectralEvents_table, fullfile(myDatasetOuput, "eeg_htpCalcSpectralEvents_table.csv"));
% writetable(eeg_htpCalcPhaseLagFrontalTemporal_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcPhaseLagFrontalTemporal_Frontal_summary_table.csv"));






%% spec events during chirp 


for fi = 1 : height(myFileListSource)

    % indicate new file being loaded
    fprintf('\nNEW FILE fi=%d\n\n', fi)

    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    
  
    % pre stimulus
    %EEG = pop_select(EEG, 'time', [EEG.xmin, 0]);

    % entire chirp stimulus
    EEG = pop_select(EEG, 'time', [0, EEG.xmax]);

    % chirp onset
    %EEG = pop_select(EEG, 'time', [0.092, 0.308]); % time window too small
    % chirp 40Hz
    %EEG = pop_select(EEG, 'time', [0.676, 1.066]); % time window too small 
    % chirp 80Hz
    %EEG = pop_select(EEG, 'time', [?, ?]);
    % chirp offset
    %EEG = pop_select(EEG, 'time', [?, ?]);

    % event 3 regions RT LT RF LF RO LO
    EEGSE = eeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput), ... 
        'findMethod', int8(1), ...
        'selectRegions', {'RT', 'LT', 'RF', 'LF', 'RO', 'LO'}, ...
        'vis', false); 
        %'selectRegions', {'RT', 'LT', 'RF', 'LF', 'RO', 'LO'}, ...
        %'fVec', 3:3:80, ...
        %'selectBandList', {'alpha', 'gamma1', 'gamma2'}, ...



    % add to cell
    EEGSECell{fi} = EEGSE; %#ok<SAGROW> 

end

%generate and save table
eeg_htpCalcSpectralEvents_table = table();
for ti = 1 : numel(EEGSECell)
    eeg_htpCalcSpectralEvents_table = vertcat(eeg_htpCalcSpectralEvents_table, EEGSECell{ti}.vhtp.eeg_htpCalcSpectralEvents.summary_table); %#ok<*AGROW>    
end
writetable(eeg_htpCalcSpectralEvents_table, fullfile(myDatasetOuput, "eeg_htpCalcSpectralEvents_table_wholechirp_method1_complete.csv"));



%% comparing visualizations


for fi = 1 : 1 %height(myFileListSource)

    % indicate new file being loaded
    fprintf('\nNEW FILE fi=%d\n\n', fi)

    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    
    % pre stimulus
    EEG = pop_select(EEG, 'time', [EEG.xmin, 0]);

    % method 1
    EEGSE = eeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput), ... 
        'findMethod', int8(2), ...
        'selectRegions', {'LT'}, ...
        'vis', true); 

    % add to cell
    EEGSECell{fi} = EEGSE; %#ok<SAGROW> 

end

%generate and save table
eeg_htpCalcSpectralEvents_table = table();
for ti = 1 : numel(EEGSECell)
    eeg_htpCalcSpectralEvents_table = vertcat(eeg_htpCalcSpectralEvents_table, EEGSECell{ti}.vhtp.eeg_htpCalcSpectralEvents.summary_table); %#ok<*AGROW>    
end
writetable(eeg_htpCalcSpectralEvents_table, fullfile(myDatasetOuput, "eeg_htpCalcSpectralEvents_table_prestimulus_method3.csv"));


%% Pre stimulus power 

for fi = 1 : height(myFileListSource)


    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    
    EEG = pop_select(EEG, 'time', [EEG.xmin, 0]);
    
    
    EEGPow = eeg_htpCalcRestPower(EEG, 'outputdir', fullfile(myDatasetOuput, "pow"));
    EEGRestCell{fi} = EEGPow;
    
end


% Create and save results table
% eeg_htpCalcPhaseLagFrontalTemporal_summary_table = table();
eeg_htpCalcRestPower_summary_table = table();

for ti = 1 : numel(EEGRestCell)
    eeg_htpCalcRestPower_summary_table = vertcat(eeg_htpCalcRestPower_summary_table, EEGRestCell{ti}.vhtp.eeg_htpCalcRestPower.summary_table);
   
end
writetable(eeg_htpCalcRestPower_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcRestPower_summary_table.csv"));
% writetable(eeg_htpCalcPhaseLagFrontalTemporal_summary_table, fullfile(myDatasetOuput, "eeg_htpCalcPhaseLagFrontalTemporal_Frontal_summary_table.csv"));


