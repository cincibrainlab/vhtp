function [EEG] = eeg_htpEegResampleDataEeglab(EEG,srate)
% eeg_htpResampleDataEeglab() - Resample data to new specified sampling rate.
%
% Usage:
%    >> [ EEG ] = eeg_ResampleDataEeglab( EEG, srate )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%     srate         - Number specifying new sampling rate
%
% Outputs:
%     EEG         - Updated EEGLAB structure
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

% MATLAB built-in input validation
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addRequired(ip, 'srate',@isnumeric);

parse(ip,EEG,srate);

EEG.vhtp.Resample.timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
EEG.vhtp.Resample.functionstamp = mfilename; % function name for logging/output

try
    
    if EEG.srate > 2000
        EEG = pop_resample( EEG, 1000);
    end
    
    EEG = pop_resample( EEG, srate);
    
    EEG.vhtp.Resample.complete=1;
    EEG.vhtp.Resample.newSrate = srate;
catch e
    throw(e)
end

EEG = eeg_checkset( EEG );

end

