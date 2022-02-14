function [EEG] = util_htpResampleData(EEG,srate)
timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output


% defaultdryRun = true;

% MATLAB built-in input validation
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addRequired(ip, 'srate',@isnumeric);

parse(ip,EEG,srate);

EEG = pop_resample( EEG, srate);
EEG = eeg_checkset( EEG );
EEG.etc.resample = srate;

end

