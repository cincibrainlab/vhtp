function [EEG, results] = eeg_htpEegResampleDataEeglab(EEG,srate)
% eeg_htpResampleDataEeglab() - Resample data to new specified sampling rate.
%
% Usage:
%    >> [ EEG, results ] = eeg_ResampleDataEeglab( EEG, srate )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%     srate         - Number specifying new sampling rate
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

% MATLAB built-in input validation
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addRequired(ip, 'srate',@isnumeric);

parse(ip,EEG,srate);

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    
    if EEG.srate > 2000
        EEG = pop_resample( EEG, 1000);
    end
    
    EEG = pop_resample( EEG, srate);
    
    EEG.vhtp.eeg_htpResampleDataEeglab.completed=1;
    EEG.vhtp.eeg_htpResampleDataEeglab.srate = srate;
catch e
    throw(e)
end

EEG = eeg_checkset( EEG );
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
EEG.vhtp.eeg_htpEegResampleDataEeglab.qi_table = qi_table;
results = EEG.vhtp.eeg_htpEegResampleDataEeglab;

end

