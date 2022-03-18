function [EEG] = eeg_htpEegInterpolateChansEeglab(EEG,varargin)
% eeg_htpEegInterpolateChansEeglab - Mark channels for rejection and
%                               interpolation
%
% Usage:
%    >> [ EEG ] = eeg_htpEegInterpolateChansEeglab( EEG )
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

EEG.vhtp.eeg_htpEegInterpolateChansEeglab.timestamp = datestr(now,'yymmddHHMMSS'); % timestamp
EEG.vhtp.eeg_htpEegInterpolateChansEeglab.functionStamp = mfilename; % function name for logging/output

try
    badchannels = EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans;

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
    EEG.vhtp.eeg_htpEegInterpolateChansEeglab.complete=1;

catch error
    throw(error);
end

EEG = eeg_checkset(EEG);

end

