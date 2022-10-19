function [EEG, results] = eeg_htpEegCreateEpochsEeglab(EEG,varargin)
% Description: Perform epoch creation for Non-ERP datasets
% ShortTitle: Create Regular Epochs (EEGLAB)
% Category: Preprocessing
% Tags: Epoching
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegCreateEpochsEeglab( EEG, varargin )
%
%% Required Inputs:
%     EEG [struct]          - EEGLAB Structure
%
%% Function Specific Inputs:
%   'epochlength'  - Integer representing the recurrence interval in seconds of epochs
%               default: 2
%
%   'epochlimits' - array of two integers representing latencies interval in seconds relative to the time-locking events 
%               default: [0 epochlength]
%
%   'saveoutput' - Boolean representing if output should be saved when executing step while using VHTP preprocessing tool
%                  default: false
%   
%  'outputdir' - text representing the output directory for the function
%                 output to be saved to
%                 default: ''      
%
%% Outputs:
%     EEG [struct]         - Updated EEGLAB structure
%
%     results [struct]  - Updated function-specific structure containing qi table and input parameters used
%
%% Disclaimer:
%  This file is part of the Cincinnati Visual High Throughput Pipeline
%  
%  Please see http://github.com/cincibrainlab
%
%% Contact:
%   kyle.cullion@cchmc.org

defaultEpochLength = 2;
defaultEpochLimits = [0 defaultEpochLength];
defaultSaveOutput = false;
defaultOutputDir = '';

% MATLAB built-in input validation
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'epochlength',defaultEpochLength,@isnumeric);
addParameter(ip, 'epochlimits',defaultEpochLimits,@isnumeric);
addParameter(ip, 'saveoutput',defaultSaveOutput,@islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try 
    EEG = eeg_regepochs(EEG,'recurrence',ip.Results.epochlength,'limits',ip.Results.epochlimits,'extractepochs','on','rmbase',NaN);
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.proc_xmax_epoch = EEG.trials * abs(EEG.xmax-EEG.xmin);
    
    for i = 1:length(EEG.epoch); EEG.epoch(i).trialno = i; end
    
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.completed = 1;
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.epochlength = ip.Results.epochlength;
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.epochlimits = ip.Results.epochlimits;
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.trials = EEG.trials;
    
catch e
    throw(e)
end

EEG = eeg_checkset(EEG);

if isfield(EEG,'vhtp') && isfield(EEG.vhtp,'inforow')
    EEG.vhtp.inforow.proc_xmax_create_epochs = EEG.vhtp.eeg_htpEegCreateEpochsEeglab.proc_xmax_epoch;
    EEG.vhtp.inforow.proc_create_epochs_length = ip.Results.epochlength;
    EEG.vhtp.inforow.proc_create_epochs_limits = ip.Results.epochlimits;
    EEG.vhtp.inforow.proc_create_epochs_trials = EEG.trials;
end

qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegCreateEpochsEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.qi_table = [EEG.vhtp.eeg_htpEegCreateEpochsEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegCreateEpochsEeglab;

if ip.Results.saveoutput && ~isempty(ip.Results.outputdir)
    if isfield(EEG.vhtp, 'currentStep')
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,EEG.vhtp.currentStep);
    else
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,'epoch_creation');
    end
elseif ip.Results.saveoutput && isempty(ip.Results.outputdir)
    fprintf('File was NOT SAVED due to no output directory parameter specified\n\n');
else
    fprintf('File was NOT SAVED due to save out parameter being false\n\n');
end


end
