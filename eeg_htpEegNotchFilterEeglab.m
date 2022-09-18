function [EEG,results] = eeg_htpEegNotchFilterEeglab(EEG,varargin)
% Description: Perform Notch filtering on data
% ShortTitle: Notch Filter EEG using EEGLAB
% Category: Preprocessing
% Tags: Filter
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegNotchFilterEeglab( EEG, varargin)
%
%% Required Inputs:
%     EEG [struct]         - EEGLAB Structure
%
%% Function Specific Inputs:
%   'method'  - Text representing method utilized for Filtering
%               default: 'highpass' e.g. {'highpass', 'lowpass', 'notch', 'cleanline'}
%
%   'notchfilt' - Array of two numbers utilized for generating the line noise
%             used in harmonics calculation for notch filtering
%             default: [55 65]
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

defaultNotch = [55 65];
defaultRevFilt=1;
defaultPlotFreqz   = 0;
defaultMinPhase    = false;
defaultFiltOrder = missing;
defaultDynamicFiltOrder = 0;
defaultSaveOutput = false;
   
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'notchfilt',defaultNotch,@isnumeric);
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
    harmonics = 3;
    linenoise = floor((ip.Results.notchfilt(1) + ip.Results.notchfilt(2)) / 2);
    if ~(ip.Results.dynamicfiltorder)
        if ismissing(ip.Results.filtorder)
            notchfiltorder = 3300;
        else
            notchfiltorder = ip.Results.filtorder;
        end
        if EEG.srate < 2000
            for i = 1 : harmonics
                EEG = pop_eegfiltnew(EEG, 'locutoff', (linenoise * i-(abs(ip.Results.notchfilt(1)-ip.Results.notchfilt(2))/2)), 'hicutoff', (linenoise * i+(abs(ip.Results.notchfilt(1)-ip.Results.notchfilt(2))/2)), 'filtorder',notchfiltorder,'revfilt', ip.Results.revfilt, 'plotfreqz',ip.Results.plotfreqz);
            end
        end
        EEG.vhtp.eeg_htpEegNotchFilterEeglab.filtorder    = notchfiltorder;
    else
        if EEG.srate < 2000
            for i = 1 : harmonics
                EEG = pop_eegfiltnew(EEG, 'locutoff', (linenoise * i-(abs(ip.Results.notchfilt(1)-ip.Results.notchfilt(2))/2)), 'hicutoff', (linenoise * i+(abs(ip.Results.notchfilt(1)-ip.Results.notchfilt(2))/2)), 'revfilt', ip.Results.revfilt, 'plotfreqz',ip.Results.plotfreqz);
            end
        end
        EEG.vhtp.eeg_htpEegNotchFilterEeglab.filtorder    = 'dynamic';
    end
    EEG.vhtp.eeg_htpEegNotchFilterEeglab.completed = 1;
    EEG.vhtp.eeg_htpEegNotchFilterEeglab.notchcutoff = ip.Results.notchfilt;
    EEG.vhtp.eeg_htpEegNotchFilterEeglab.revfilt     = ip.Results.revfilt;
    EEG.vhtp.eeg_htpEegNotchFilterEeglab.plotfreqz   = ip.Results.plotfreqz;
    EEG.vhtp.eeg_htpEegNotchFilterEeglab.minphase    = ip.Results.minphase;
catch e
    throw(e);
end

EEG = eeg_checkset(EEG);


if isfield(EEG,'vhtp') && isfield(EEG.vhtp,'inforow')
    EEG.vhtp.inforow.proc_filt_notch_lowcutoff = ip.Results.notchfilt(1);
    EEG.vhtp.inforow.proc_filt_notch_highcutoff = ip.Results.notchfilt(2);
end

qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegNotchFilterEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegNotchFilterEeglab.qi_table = [EEG.vhtp.eeg_htpEegNotchFilterEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegNotchFilterEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegNotchFilterEeglab;
end

