function [EEG, results] = eeg_htpEegCreateErpEpochsEeglab(EEG, varargin)
% Description: Perform epoch creation for ERP datasets
% Category: Preprocessing
% ShortTitle: Create ERP epoch (EEGLAB)
% Tags: Epoching
%
%% Syntax:
%    [ EEG, results ] = eeg_htpEegCreateErpEpochsEeglab( EEG, epochevent, varargin )
%
%% Required Inputs:
%     EEG [struct]           - EEGLAB Structure
%
%     epochevent    - string indicating event to time-lock epochs to when converting continuous dataset to epoched dataset.
%
%% Function Specific Inputs:
%   'epochlimits' - array of two integers representing interval in secs relative to the time-locking event 
%                   default: [-.5 2.750]
%
%   'rmbaseline' - Boolean indicating if baseline should be removed
%                  default: false
%
%   'baselinelimits' - Array of numbers indicating limits in secs to use for baseline removal process.
%                      default: [-.5 0]
%
%   'saveoutput' - Boolean representing if output should be saved when executing step from VHTP preprocessing tool
%                  default: false
%      
%% Output:
%     EEG [struct]        - Updated EEGLAB structure
%
%     results [struct]   - Updated function-specific structure containing qi table and input parameters used
%
%% Disclaimer:
%   Part of the Cincinnati Visual High Throughput EEG Pipeline
%   
%   Please see http://github.com/cincibrainlab
%
%% Contact:
%   kyle.cullion@cchmc.org
timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

defaultEpochEvent = missing;
defaultEpochLimits = [-.500 2.750];
defaultRmBaseline = false;
defaultBaselineLimits = [-.500 0];
defaultSaveOutput = false;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'epochevent', defaultEpochEvent, @ischar);
addParameter(ip,'epochlimits',defaultEpochLimits,@isnumeric);
addParameter(ip, 'rmbaseline', defaultRmBaseline, @islogical);
addParameter(ip, 'baselinelimits', defaultBaselineLimits, @isnumeric);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical);

parse(ip, EEG, varargin{:});

if ismissing(ip.Results.epochevent)
    disp("Missing Event Code to Epoch.")
    return;
else
    epochevent = ip.Results.epochevent;
end

try
   [~,filename,~] = fileparts(EEG.filename);
   originalfile = filename;
   EEG = pop_epoch(EEG, {epochevent}, ip.Results.epochlimits, 'epochinfo', 'yes', 'newname', fullfile(EEG.filepath,[filename '_' epochevent]));
   EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.erporiginalfile = originalfile;
   if ip.Results.rmbaseline
       EEG = pop_rmbase(EEG, ip.Results.baselinelimits*1000);
       EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.erprmbaseline = 1;
       EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.erpbaselinelimits = ip.Results.baselinelimits;
   end
   
   for i = 1:length(EEG.epoch); EEG.epoch(i).trialno = i; end
   
   EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.erpepochxmax = EEG.xmax;
   EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.erpepochevent = epochevent;
   EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.erpepochlimits = ip.Results.epochlimits;
   EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.erpepochtrials = EEG.trials;
   EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.completed=1;
catch e
    throw(e)
end

EEG = eeg_checkset(EEG);
qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.qi_table = [EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegCreateErpEpochsEeglab;
end

