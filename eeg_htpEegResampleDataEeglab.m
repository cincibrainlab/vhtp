function [EEG, results] = eeg_htpEegResampleDataEeglab(EEG,varargin)
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
defaultSrate=500;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'srate',defaultSrate,@isnumeric);

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
   
    orig_srate = EEG.srate;
    if EEG.srate > 2000
        EEG = pop_resample( EEG, 1000);
    end
    
    EEG = pop_resample( EEG, ip.Results.srate);
    
    EEG.vhtp.eeg_htpEegResampleDataEeglab.completed=1;
    EEG.vhtp.eeg_htpEegResampleDataEeglab.rawsrate = orig_srate;
    EEG.vhtp.eeg_htpEegResampleDataEeglab.srate = ip.Results.srate;
catch e
    throw(e)
end

EEG = eeg_checkset( EEG );
qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegResampleDataEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegResampleDataEeglab.qi_table = [EEG.vhtp.eeg_htpEegResampleDataEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegResampleDataEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegResampleDataEeglab;

end

