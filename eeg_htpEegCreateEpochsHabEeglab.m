function [EEG, results] = eeg_htpEegCreateHabEpochsEeglab(EEG,varargin)
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

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try 
    target_events = zeros(numel(EEG.event),1);
    counter = 1;
    for ei = 1:numel(EEG.event)
        if ei == 1
            target_events(ei) = 1;
        else
            counter = counter + 1;
            if counter == 5
                check_latency = EEG.event(ei).latency - EEG.event(ei-1).latency;
                %assert(check_latency > 60, 'Event code latency discrepency');
                disp(ei);
                target_events(ei) = 1;
                counter = 1;
            end
        end
    end
    EEG = pop_epoch( EEG,  {'DIN8'}, [-0.5 2.75], 'eventindices', find(target_events), ...
        'newname', EEG.setname, 'epochinfo', 'yes');
    
    EEG.vhtp.eeg_htpEegCreateEpochsEeglab.proc_xmax_epoch = EEG.trials * abs(EEG.xmax-EEG.xmin);
    
    %for i = 1:length(EEG.epoch); EEG.epoch(i).trialno = i; end
    
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

