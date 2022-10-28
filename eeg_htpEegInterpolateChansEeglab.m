function [EEG,results] = eeg_htpEegInterpolateChansEeglab(EEG,varargin)
% Description: Interpolate channels utilizing specified method 
% ShortTitle: Channel Interpolation
% Category: Preprocessing
% Tags: Channel
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegInterpolateChansEeglab( EEG,varargin )
%
%% Required Inputs:
%     EEG [struct]          - EEGLAB Structure
%
%% Function Specific Inputs:
%   'method'  - Text representing method utilized for interpolation of channels
%               default: 'spherical' e.g. {'invdist'/'v4', 'spherical', 'spacetime'}
%
%   'saveoutput' - Boolean representing if output should be saved when executing step from VHTP preprocessing tool
%                  default: false
%
%   'outputdir' - text representing the output directory for the function
%                 output to be saved to
%                 default: '' 
%
%% Outputs:
%     EEG [struct]        - Updated EEGLAB structure
%
%     results [struct]  - Updated function-specific structure containing qi table and input parameters used
%
%% Disclaimer:
%  This file is part of the Cincinnati Visual High Throughput Pipeline
%  
%  Please see http://github.com/cincibrainlab
%
%% Contact:
%  kyle.cullion@cchmc.org

defaultMethod='spherical';
defaultChannels = [];
defaultSaveOutput = false;
defaultOutputDir = '';

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'method', defaultMethod,@ischar);
addParameter(ip, 'channels', defaultChannels, @isnumeric);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    if isempty(ip.Results.channels)
        if isfield(EEG.vhtp,'eeg_htpEegRemoveChansEeglab')
            if ~isempty(EEG.vhtp.eeg_htpEegRemoveChansEeglab.('proc_badchans'))
                badchannels = EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans;            
            else
                badchannels = [];
            end
        else
            badchannels=[];
        end
    else
        badchannels = sort(unique(ip.Results.channels));
    end
    EEGtemp = EEG;  

    if length(badchannels) >= 1
        
        % EEG = pop_interp(EEGtemp,badchannels,ip.Results.method);
        EEG = pop_interp(EEGtemp, EEGtemp.urchanlocs,ip.Results.method);
        
        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.method = ip.Results.method;
        try
        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.dataRank = size(double(EEG.data'),2) - length(badchannels);
        catch
             EEG.vhtp.eeg_htpEegInterpolateChansEeglab.dataRank = numel(EEG.urchanlocs) - numel(badchannels);
        end
        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.nbchan_post = EEG.vhtp.eeg_htpEegInterpolateChansEeglab.dataRank;
        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.proc_ipchans = badchannels;
    else

        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.dataRank = EEG.nbchan;
        EEG.vhtp.eeg_htpEegInterpolateChansEeglab.nbchan_post = EEG.vhtp.eeg_htpEegInterpolateChansEeglab.dataRank;

    end
    EEG.vhtp.eeg_htpEegInterpolateChansEeglab.completed=1;

catch error
    throw(error);
end

EEG = eeg_checkset(EEG);

if isfield(EEG,'vhtp') && isfield(EEG.vhtp,'inforow')
    if isempty(badchannels)
        EEG.vhtp.inforow.proc_interpolate_chans_ipChans = 'none';
    else
        EEG.vhtp.inforow.proc_interpolate_chans_ipChans = badchannels;
    end
end

qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegInterpolateChansEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegInterpolateChansEeglab.qi_table = [EEG.vhtp.eeg_htpEegInterpolateChansEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegInterpolateChansEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegInterpolateChansEeglab;

if ip.Results.saveoutput && ~isempty(ip.Results.outputdir)
    if isfield(EEG.vhtp, 'currentStep')
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,EEG.vhtp.currentStep);
    else
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,'channel_interpolation');
    end
    fprintf('Output was copied to %s\n\n',ip.Results.outputdir);
end

end

