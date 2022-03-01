function [EEG] = eeg_htpEegRereferenceEeglab(EEG,varargin)
%EEG_HTPEEGREREFERENCEEEGLAB Summary of this function goes here
%   Detailed explanation goes here

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);

parse(ip,EEG,varargin{:});

EEG.vhtp.Rereference.timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
EEG.vhtp.Rereference.functionstamp = mfilename; % function name for logging/output

try
    %EEG.data = bsxfun( @minus, EEG.data, sum( EEG.data, 1 ) / ( EEG.nbchan + 1 ) );
    EEG.nbchan = EEG.nbchan+1;
    EEG.data(end+1,:) = zeros(1, EEG.pnts);
    EEG.chanlocs(1,EEG.nbchan).labels = 'initialReference';
    EEG = pop_reref(EEG, []);
    EEG = pop_select( EEG,'nochannel',{'initialReference'});
    EEG.vhtp.Rereference.method = 'Average';
    EEG.vhtp.Rereference.completed = 1;
    
catch e
    throw(e)
end
EEG=eeg_checkset(EEG);
end

