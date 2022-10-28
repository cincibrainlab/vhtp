function [EEG, results] = eeg_htpEegRereferenceEeglab(EEG,varargin)
% Description: Rereference data to Average Reference.
% ShortTitle: Average reference EEG data
% Category: Preprocessing
% Tags: Channel
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegRereferenceEeglab( EEG, varargin )
%
%% Required Inputs:
%   EEG [struct]           - EEGLAB Structure
%
%% Function Specific Inputs:
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
defaultSaveOutput = false;
defaultOutputDir = '';

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);


parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    %EEG.data = bsxfun( @minus, EEG.data, sum( EEG.data, 1 ) / ( EEG.nbchan + 1 ) );
    EEG.nbchan = EEG.nbchan+1;
    if ndims(EEG.data) == 3
        trial_dim = size(EEG.data);
        EEG.data(end+1, :, :) = zeros([trial_dim(2:end)]);
    else 
        if ndims(EEG.data) == 2
                EEG.data(end+1,:) = zeros(1, EEG.pnts);
        end
    end
    EEG.chanlocs(1,EEG.nbchan).labels = 'initialReference';
    EEG = pop_reref(EEG, []);
    EEG = pop_select( EEG,'nochannel',{'initialReference'});
    EEG.vhtp.eeg_htpEegRereferenceEeglab.method = 'Average';
    EEG.vhtp.eeg_htpEegRereferenceEeglab.completed = 1;
    
catch e
    throw(e)
end
EEG=eeg_checkset(EEG);

if isfield(EEG,'vhtp') && isfield(EEG.vhtp,'inforow')
    EEG.vhtp.inforow.proc_rereference_ref = {'Average'};
end

qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegRereferenceEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegRereferenceEeglab.qi_table = [EEG.vhtp.eeg_htpEegRereferenceEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegRereferenceEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegRereferenceEeglab;

if ip.Results.saveoutput && ~isempty(ip.Results.outputdir)
    if isfield(EEG.vhtp, 'currentStep')
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,EEG.vhtp.currentStep);
    else
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,'rereference');
    end
    fprintf('Output was copied to %s\n\n',ip.Results.outputdir);
end

end

