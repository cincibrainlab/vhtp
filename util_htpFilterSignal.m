function [EEG] = util_htpFilterSignal(EEG,method,varargin)
% Inputs: Common across Visual HTP functions

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output


% defaultdryRun = true;
defaultLowCutoff = [];
defaultHighCutoff = [];
defaultNotch = [];
defaultCleanline = [];

% MATLAB built-in input validation
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addRequired(ip, 'method',@ischar);
addOptional(ip, 'lowCutoff',defaultLowCutoff,@isnumeric);
addOptional(ip, 'highCutoff',defaultHighCutoff,@isnumeric);
addOptional(ip, 'notchCutoff',defaultNotch,@isnumeric);
addOptional(ip, 'cleanlineFilt', defaultCleanline, @islogical);


parse(ip,EEG,method,varargin{:});

switch method
    case 'lowpass'

        EEG=eeg_htpFiltLowPass(EEG,ip.Results.highCutoff);
    case 'highpass'

        EEG=eeg_htpFiltHighPass(EEG,ip.Results.lowCutoff);
    case 'notch'

        EEG=eeg_htpFiltNotch(EEG,ip.Results.notchCutoff);
    case 'cleanline'
        EEG=eeg_htpFiltCleanline(EEG);
    otherwise
        print('No Filter Performed')
end

EEG=eeg_checkset(EEG);
end

