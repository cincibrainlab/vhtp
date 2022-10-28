function [EEG, results] = eeg_htpEegResampleDataEeglab(EEG,varargin)
% Description: Resamples data to newly specified sampling rate
% ShortTitle: Resample EEG data
% Category: Preprocessing
% Tags: Resample
%
%% Syntax:
%   [ EEG, results ] = eeg_ResampleDataEeglab( EEG, srate )
%
%% Required Inputs:
%   EEG [struct]           - EEGLAB Structure
% 
%% Function Specific Inputs
%   'srate'         - Number specifying new sampling rate
%                     default: 500
%
%   'saveoutput' - Boolean representing if output should be saved when executing step from VHTP preprocessing tool
%                  default: false
%
%   'outputdir' - text representing the output directory for the function
%                 output to be saved to
%                 default: ''
%
%% Outputs:
%   EEG [struct] - output structure with updated dataset
%
%   results [struct]   - Updated function-specific structure containing qi table and input parameters used
%
%% Disclaimer:
%   Part of the Cincinnati Visual High Throughput EEG Pipeline
%   
%   Please see http://github.com/cincibrainlab
%
%% Contact:
%   kyle.cullion@cchmc.org

% MATLAB built-in input validation
defaultSrate=500;
defaultSaveOutput = false;
defaultOutputDir = '';

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'srate',defaultSrate,@isnumeric);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);


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

if isfield(EEG,'vhtp') && isfield(EEG.vhtp,'inforow')
    EEG.vhtp.inforow.proc_resample_srate = ip.Results.srate;
end

qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegResampleDataEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegResampleDataEeglab.qi_table = [EEG.vhtp.eeg_htpEegResampleDataEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegResampleDataEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegResampleDataEeglab;

if ip.Results.saveoutput && ~isempty(ip.Results.outputdir)
    if isfield(EEG.vhtp, 'currentStep')
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,EEG.vhtp.currentStep);
    else
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,'resample');
    end
    fprintf('Output was copied to %s\n\n',ip.Results.outputdir);
end

end

