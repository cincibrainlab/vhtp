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

EEG.vhtp.ChannelInterpolation.timestamp = datestr(now,'yymmddHHMMSS'); % timestamp
EEG.vhtp.ChannelInterpolation.functionStamp = mfilename; % function name for logging/output

try
    badchannels = EEG.vhtp.ChannelRemoval.proc_badchans;

    EEGtemp = EEG;  

    if length(badchannels) >= 1

        
        EEG = pop_interp(EEGtemp,badchannels,ip.Results.method);
        EEG.vhtp.ChannelInterpolation.method = ip.Results.method;
        EEG.vhtp.ChannelInterpolation.dataRank = size(double(EEG.data'),2) - length(badchannels);

        EEG.vhtp.ChannelInterpolation.nbchan_post = EEG.vhtp.ChannelInterpolation.dataRank;
        EEG.vhtp.ChannelInterpolation.proc_ipchans = badchannels;
    else

        EEG.vhtp.ChannelInterpolation.dataRank = EEG.nbchan;
        EEG.vhtp.ChannelInterpolation.nbchan_post = EEG.vhtp.InterpolateChannels.dataRank;

    end
    EEG.vhtp.ChannelInterpolation.complete=1;

catch error
    throw(error);
end

EEG = eeg_checkset(EEG);

end

