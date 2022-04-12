function [EEG, results] = eeg_htpEegCreateEpochsEeglab(EEG,varargin)
% eeg_htpEegCreateEpochs - Perform epoch creation for Non-ERP datasets
%
% Usage:
%    >> [ EEG ] = eeg_htpEegCreateEpochsEeglab( EEG )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
% Function Specific Inputs:
%   'epochlength'  - Integer representing the recurrence interval in seconds of epochs
%               default: 2
%
%   'epochlimits' - array of two integers representing latencies interval in seconds 
%                   relative to the time-locking events 
%               default: [0 epochlength]
%
%           
% Outputs:
%     EEG         - Updated EEGLAB structure
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

defaultEpochLength = 2;
defaultEpochLimits = [0 defaultEpochLength];

% MATLAB built-in input validation
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'epochlength',defaultEpochLength,@isnumeric);
addParameter(ip,'epochlimits',defaultEpochLimits,@isnumeric);

parse(ip,EEG,varargin{:});

EEG.vhtp.eeg_htpEegCreateEpochsEeglab.timestamp = datestr(now,'yymmddHHMMSS'); % timestamp
EEG.vhtp.eeg_htpEegCreateEpochsEeglab.functionStamp = mfilename; % function name for logging/output

try 
    EEG = eeg_regepochs(EEG,'recurrence',ip.Results.epochlength,'limits',ip.Results.epochlimits,'extractepochs','on','rmbase',NaN);
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.proc_xmax_epoch = EEG.trials * abs(EEG.xmax-EEG.xmin);
    
    for i = 1:length(EEG.epoch); EEG.epoch(i).trialno = i; end
    
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.epochlength = ip.Results.epochlength;
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.epochlimits = ip.Results.epochlimits;
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.trials = EEG.trials;
    
catch e
    throw(e)
end

EEG = eeg_checkset(EEG);
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
EEG.vhtp.eeg_htpEegCreateEpochsEeglab.qi_table = qi_table;
results = EEG.vhtp.eeg_htpEegCreateEpochsEeglab;
end

