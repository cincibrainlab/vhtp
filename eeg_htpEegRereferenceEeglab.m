function [EEG, results] = eeg_htpEegRereferenceEeglab(EEG,varargin)
% eeg_htpEegRereferenceEeglab() - Rereference data to Average Reference.
%
% Usage:
%    >> [ EEG, results ] = eeg_htpEegRereferenceEeglab( EEG, varargin )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
% Outputs:
%     EEG         - Updated EEGLAB structure
%
%     results   - Updated function-specific structure containing qi table
%                 and input parameters used
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    %EEG.data = bsxfun( @minus, EEG.data, sum( EEG.data, 1 ) / ( EEG.nbchan + 1 ) );
    EEG.nbchan = EEG.nbchan+1;
    EEG.data(end+1,:) = zeros(1, EEG.pnts);
    EEG.chanlocs(1,EEG.nbchan).labels = 'initialReference';
    EEG = pop_reref(EEG, []);
    EEG = pop_select( EEG,'nochannel',{'initialReference'});
    EEG.vhtp.eeg_htpEegRereferenceEeglab.method = 'Average';
    EEG.vhtp.eeg_htpEegRereferenceEeglab.completed = 1;
    
catch e
    throw(e)
end
EEG=eeg_checkset(EEG);
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
EEG.vhtp.eeg_htpEegRereferenceEeglab.qi_table = qi_table;
results = EEG.vhtp.eeg_htpEegRereferenceEeglab;
end

