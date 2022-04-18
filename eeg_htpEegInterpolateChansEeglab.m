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

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'method', defaultMethod,@ischar)
parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    try
    badchannels = EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans;
    catch
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
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
EEG.vhtp.eeg_htpEegInterpolateChansEeglab.qi_table = qi_table;
results = EEG.vhtp.eeg_htpEegInterpolateChansEeglab;

end

