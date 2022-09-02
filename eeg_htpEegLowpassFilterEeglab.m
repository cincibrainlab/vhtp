function [EEG,results] = eeg_htpEegLowpassFilterEeglab(EEG,varargin)
% Description: Perform Lowpass filtering on data
% ShortTitle: Filter EEG using EEGLAB
% Category: Preprocessing
% Tags: Filter
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegLowpassFilterEeglab( EEG, varargin)
%
%% Required Inputs:
%     EEG [struct]         - EEGLAB Structure
%
%% Function Specific Inputs:
%
%   'lowpassfilt' - Number representing the higher edge frequency to use in 
%                   lowpass bandpass filter 
%                   default: 80
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

defaultHiCutoff = 80;
defaultRevFilt=0;
defaultPlotFreqz   = 0;
defaultMinPhase    = false;
defaultFiltOrder = missing;
defaultDynamicFiltOrder = 0;
defaultSaveOutput = false;
    
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'lowpassfilt',defaultHiCutoff,@isnumeric);
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
            lowpassfiltorder = 3300;
        else
            lowpassfiltorder = ip.Results.filtorder;
        end
        EEG = pop_eegfiltnew(EEG,  ...
            'locutoff', [],  'hicutoff', ip.Results.lowpassfilt,'filtorder',lowpassfiltorder);
        EEG.vhtp.eeg_htpEegLowpassFilterEeglab.lowpassfiltorder    = lowpassfiltorder;
    else
        EEG = pop_eegfiltnew(EEG,  ...
            'locutoff', [],  'hicutoff', ip.Results.lowpassfilt);
        EEG.vhtp.eeg_htpEegLowpassFilterEeglab.lowpassfiltorder    = 'dynamic';
    end
    EEG.vhtp.eeg_htpEegLowpassFilterEeglab.completed = 1;
    EEG.vhtp.eeg_htpEegLowpassFilterEeglab.hicutoff    = ip.Results.lowpassfilt;
    EEG.vhtp.eeg_htpEegLowpassFilterEeglab.revfilt     = ip.Results.revfilt;
    EEG.vhtp.eeg_htpEegLowpassFilterEeglab.plotfreqz   = ip.Results.plotfreqz;
    EEG.vhtp.eeg_htpEegLowpassFilterEeglab.minphase    = ip.Results.minphase;
        
catch e
    throw(e);
end

EEG = eeg_checkset(EEG);
qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegLowpassFilterEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegLowpassFilterEeglab.qi_table = [EEG.vhtp.eeg_htpEegLowpassFilterEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegLowpassFilterEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegLowpassFilterEeglab;
end

