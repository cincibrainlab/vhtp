function [EEG, results] = eeg_htpEegCreateHabEpochsEeglab(EEG,varargin)
% Description: Perform epoch creation for Non-ERP datasets
% ShortTitle: Create Habituation Epochs (EEGLAB)
% Category: Preprocessing
% Tags: Epoching
%
% Usage:
%    >> [ EEG ] = eeg_htpEegCreateEpochsEeglab( EEG )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
% Function Specific Inputs:
%   'targetdin'    - digital input marker (DIN) event code for epochs
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
defaultTargetDin = 'DIN8';
defaultEpochLimits = [0 defaultEpochLength];
defaultSaveOutput = false;

% MATLAB built-in input validation
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'epochlength',defaultEpochLength,@isnumeric);
addParameter(ip,'epochlimits',defaultEpochLimits,@isnumeric);
addParameter(ip, 'targetdin', defaultTargetDin, @ischar);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical)

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

target_din = ip.Results.targetdin;

try 
    target_events = zeros(numel(EEG.event),1);
    counter = 1;
    first_target_din_found = false;
    for ei = 1:numel(EEG.event)
        current_din = EEG.event(ei).type;
        current_latency = EEG.event(ei).latency;
        if strcmp(current_din, target_din) 
            if counter == 1
                first_target_din_found = true;
                first_target_latency = current_latency;
                previous_latency = current_latency;
                target_events(ei) = 1;
                counter = counter + 1;
            else
                check_latency = current_latency - previous_latency;
                fprintf("%s #%d to previous DIN Latency: %s ms\n", target_din, ei, num2str(check_latency));
                if counter == 4
                    fprintf("Fourth DIN of series\n");
                    fprintf("First to First Latency: %s ms\n", num2str(first_target_latency-current_latency));
                counter = 1;
                else
                    counter = counter + 1;
                end
                previous_latency = current_latency;
            end
        end
    end
 
    EEG = pop_epoch( EEG, {target_din}, [-0.5 2.75],...
        'eventindices', find(target_events),  ...
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

