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
    fprintf('\nNEW FILE fi=%d\n', fi)

    EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
    
   
    % entire chirp stimulus
    % don't need to select roi?
    EEG = pop_select(EEG, 'time', [EEG.xmin*1000, EEG.xmax*1000]);

    % only temporal/frontal/occipital, chirp onset
    %EEG = pop_select(EEG, 'time', [92, 308], 'channel', roi);
    % only temporal/frontal/occipital, chirp 40Hz
    %EEG = pop_select(EEG, 'time', [676, 1066], 'channel', roi);
    % only temporal/frontal/occipital, chirp 80Hz
    %EEG = pop_select(EEG, 'time', [?, ?], 'channel', roi);
    % only temporal/frontal/occipital, chirp offset
    %EEG = pop_select(EEG, 'time', [?, ?], 'channel', roi);

    % method 1
    EEGSE = eeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput), ... 
        'findMethod', int8(1), ...
        'selectRegions', {'RT', 'LT', 'RF', 'LF', 'RO', 'LO'});

    % add to cell
    EEGSECell{fi} = EEGSE; %#ok<SAGROW> 

end

%generate and save table
eeg_htpCalcSpectralEvents_table = table();
for ti = 1 : numel(EEGSECell)
    eeg_htpCalcSpectralEvents_table = vertcat(eeg_htpCalcSpectralEvents_table, EEGSECell{ti}.vhtp.eeg_htpCalcSpectralEvents.summary_table); %#ok<*AGROW>    
end
writetable(eeg_htpCalcSpectralEvents_table, fullfile(myDatasetOuput, "eeg_htpCalcSpectralEvents_table_chirp_allregions_method1.csv"));



%% comparing methods spec events pre-stimulus

roi = {'banksstsL' 'entorhinalL' 'fusiformL' 'inferiortemporalL' ...
    'insulaL' 'middletemporalL' 'parahippocampalL' 'superiortemporalL' ...
    'temporalpoleL' 'transversetemporalL' ...   % LT
    'banksstsR' 'entorhinalR' 'fusiformR' 'inferiortemporalR' ...
    'insulaR' 'middletemporalR' 'parahippocampalR' 'superiortemporalR' ...
    'temporalpoleR' 'transversetemporalR' ...   % RT
    'caudalmiddlefrontalL' 'parsopercularisL' 'parstriangularisL' ...
    'rostralmiddlefrontalL' 'superiorfrontalL' ...  % LF
    'caudalmiddlefrontalR' 'parsopercularisR' 'parstriangularisR' ...
    'rostralmiddlefrontalR' 'superiorfrontalR' ...  % RF
    'cuneusL' 'lateraloccipitalL' 'lingualL' 'pericalcarineL' ... % LO
    'cuneusR' 'lateraloccipitalR' 'lingualR' 'pericalcarineR'}; % RO

for methodNum = 1 : 3 
    fprintf('\nNEW METHOD method=%d\n\n', methodNum)

    for fi = 1 : 25 %height(myFileListSource)

        % indicate new file being loaded
        fprintf('\nNEW FILE fi=%d\n\n', fi)
    
        EEG = pop_loadset(myFileListSource.filename{fi}, myFileListSource.filepath{fi});
        
        % pre-stimulus
        EEG = pop_select(EEG, 'time', [-500, 0]);
    
        % Temporal, Frontal, Occipital
        EEGSE = eeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput), ... 
            'findMethod', int8(methodNum), ...
            'selectRegions', {'RT', 'LT', 'RF', 'LF'}); % {'RT', 'LT', 'RF', 'LF', 'RO', 'LO'});

        % add to celleeg_htpCalcSpectralEvents(EEG, 'outputdir', fullfile(myDatasetOuput), 'findMethod', int8(3));
        EEGSECell{fi} = EEGSE; %#ok<SAGROW> 

    
    
    end
    
    %generate and save table
    eeg_htpCalcSpectralEvents_table = table();

    for ti = 1 : numel(EEGSECell)
        eeg_htpCalcSpectralEvents_table = vertcat(eeg_htpCalcSpectralEvents_table, EEGSECell{ti}.vhtp.eeg_htpCalcSpectralEvents.summary_table); %#ok<*AGROW>    
    end
    writetable(eeg_htpCalcSpectralEvents_table, fullfile(myDatasetOuput, strcat("eeg_htpCalcSpectralEvents_table_prestimulus_method", string(methodNum), ".csv")));

end


