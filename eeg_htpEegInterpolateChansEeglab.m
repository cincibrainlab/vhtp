function [EEG,results] = eeg_htpEegInterpolateChansEeglab(EEG,varargin)
% eeg_htpEegInterpolateChansEeglab - Mark channels for rejection and
%                               interpolation
%
% Usage:
%    >> [ EEG, results ] = eeg_htpEegInterpolateChansEeglab( EEG,varargin )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
% Function Specific Inputs:
%   'method'  - Text representing method utilized for interpolation 
%               of channels
%               e.g. {'invdist'/'v4', 'spherical', 'spacetime'}
%               default: 'spherical'
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
defaultMethod='spherical';
defaultChannels = [];
defaultSaveOutput = false;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'method', defaultMethod,@ischar);
addParameter(ip, 'channels', defaultChannels, @isnumeric);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical);

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    if isempty(ip.Results.channels)
        if isfield(EEG.vhtp,'eeg_htpEegRemoveChansEeglab')
            if ~isempty(EEG.vhtp.eeg_htpEegRemoveChansEeglab.('proc_badchans'))
                badchannels = EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans;            
            else
                badchannels = EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans;
            end
        else
            badchannels=[];
        end
    else
        badchannels = sort(unique(ip.Results.channels));
    end
    EEGtemp = EEG;  

    if length(badchannels) >= 1

        
        EEG = pop_interp(EEGtemp,badchannels,ip.Results.method);
        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.method = ip.Results.method;
        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.dataRank = size(double(EEG.data'),2) - length(badchannels);

        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.nbchan_post = EEG.vhtp.eeg_htpEegInterpolateChansEeglab.dataRank;
        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.proc_ipchans = badchannels;
    else

        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.dataRank = EEG.nbchan;
        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.nbchan_post = EEG.vhtp.eeg_htpEegInterpolateChansEeglab.dataRank;

    end
    EEG.vhtp.eeg_htpEegInterpolateChansEeglab.completed=1;

catch error
    throw(error);
end

EEG = eeg_checkset(EEG);
qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegInterpolateChansEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegInterpolateChansEeglab.qi_table = [EEG.vhtp.eeg_htpEegInterpolateChansEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegInterpolateChansEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegInterpolateChansEeglab;

end

