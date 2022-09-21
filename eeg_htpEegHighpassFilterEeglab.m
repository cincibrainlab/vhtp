function [EEG, results] = eeg_htpEegHighpassFilterEeglab(EEG,varargin)
% Description: Perform Highpass filtering on data
% ShortTitle: High Pass Filter EEG using EEGLAB
% Category: Preprocessing
% Tags: Filter
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegHighpassFilterEeglab( EEG, varargin)
%
%% Required Inputs:
%     EEG [struct]         - EEGLAB Structure
%
%% Function Specific Inputs:
%   'highpassfilt' - Number representing the lower edge frequency to use in 
%                  highpass bandpass filter 
%                  default: .5
%
%   'revfilt' - Numeric boolean to invert filter from bandpass to notch
%               default: 0 e.g. {0 -> bandpass, 1 -> notch}
%
%   'plotfreqz' - Numeric boolean to indicate whether to plot filter's frequency and phase response
%                 default: 0
%
%
%   'minphase' - Boolean for minimum-phase converted causal filter
%                default: false
%
%   'filtorder' - numeric override of default EEG filters
%                 default: missing
%
%   'dynamicfiltorder' - numeric boolean indicating whether to use dynamic filtorder determined via EEGLAB filtering function
%                        default: 0
%
%   'saveoutput' - Boolean representing if output should be saved when executing step from VHTP preprocessing tool
%                  default: false
%
%% Outputs:
%     EEG [struct]         - Updated EEGLAB structure
%
%     results [struct]   - Updated function-specific structure containing qi table and input parameters used
%
%% Disclaimer:
%  This file is part of the Cincinnati Visual High Throughput Pipeline
%  
%  Please see http://github.com/cincibrainlab
%
%% Contact:
%  kyle.cullion@cchmc.org

defaultLoCutoff = 1;
defaultRevFilt = 0;
defaultPlotFreqz   = 0;
defaultMinPhase    = false;
defaultFiltOrder = 6600;
defaultDynamicFiltOrder = 0;
defaultSaveOutput = false;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'highpassfilt',defaultLoCutoff,@isnumeric);
addParameter(ip, 'revfilt',defaultRevFilt,@islogical);
addParameter(ip, 'plotfreqz',defaultPlotFreqz,@isnumeric);
addParameter(ip, 'minphase',defaultMinPhase,@islogical);
addParameter(ip, 'filtorder',defaultFiltOrder,@isnumeric);
addParameter(ip, 'dynamicfiltorder', defaultDynamicFiltOrder,@islogical);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical)

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    if ~(ip.Results.dynamicfiltorder)
        if ismissing(ip.Results.filtorder)
            highpassfiltorder = 6600;
        else
            highpassfiltorder = ip.Results.filtorder;
        end
        EEG = pop_eegfiltnew(EEG,  'locutoff',ip.Results.highpassfilt, 'hicutoff', [],'filtorder',highpassfiltorder);
        EEG.vhtp.eeg_htpEegHighpassFilterEeglab.filtorder    = highpassfiltorder;
    else
        EEG = pop_eegfiltnew(EEG,  'locutoff',ip.Results.highpassfilt, 'hicutoff', []);
        EEG.vhtp.eeg_htpEegHighpassFilterEeglab.filtorder    = 'dynamic';
    end
    EEG.vhtp.eeg_htpEegHighpassFilterEeglab.completed = 1;
    EEG.vhtp.eeg_htpEegHighpassFilterEeglab.locutoff = ip.Results.highpassfilt;
    EEG.vhtp.eeg_htpEegHighpassFilterEeglab.revfilt     = ip.Results.revfilt;
    EEG.vhtp.eeg_htpEegHighpassFilterEeglab.plotfreqz   = ip.Results.plotfreqz;
    EEG.vhtp.eeg_htpEegHighpassFilterEeglab.minphase    = ip.Results.minphase;        
catch e
    throw(e);
end

EEG = eeg_checkset(EEG);

if isfield(EEG,'vhtp') && isfield(EEG.vhtp,'inforow')
    EEG.vhtp.inforow.proc_filt_lowcutoff = ip.Results.highpassfilt;
end

qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegHighpassFilterEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegHighpassFilterEeglab.qi_table = [EEG.vhtp.eeg_htpEegHighpassFilterEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegHighpassFilterEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegHighpassFilterEeglab;
end
