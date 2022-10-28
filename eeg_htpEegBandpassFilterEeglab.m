function [EEG,results] = eeg_htpEegBandpassFilterEeglab(EEG,varargin)
% Description: Perform Bandpass filtering on data
% ShortTitle: Bandpass Filter EEG using EEGLAB
% Category: Preprocessing
% Tags: Filter
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegBandpassFilterEeglab( EEG, varargin)
%
%% Required Inputs:
%     EEG [struct]         - EEGLAB Structure
%
%% Function Specific Inputs:
%   'bandpassfilt' - Array of two numbers utilized for edges of bandpass filtering
%                    default: [55 65]
%
%   'revfilt' - logical boolean to invert filter from bandpass to notch
%               default: false e.g. {false -> bandpass, true -> notch}
%
%   'plotfreqz' - Numeric boolean to indicate whether to plot filter's frequency and phase response
%                 default: 0
%
%   'minphase' - Boolean for minimum-phase converted causal filter
%                default: false
%
%   'filtorder' - numeric override of default EEG filters
%                 default: 3300
%
%   'dynamicfiltorder' - numeric boolean indicating whether to use dynamic filtorder determined via EEGLAB filtering function
%                        default: 0
%   
%   'saveoutput' - Boolean representing if output should be saved when executing step from VHTP preprocessing tool
%                  default: false
%
%   'outputdir' - text representing the output directory for the function
%                 output to be saved to
%                 default: '' 
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

defaultBandpass = [55 65];
defaultRevFilt= false;
defaultPlotFreqz   = 0;
defaultMinPhase    = false;
defaultFiltOrder = 3300;
defaultDynamicFiltOrder = 0;
defaultSaveOutput = false;
defaultOutputDir = '';
   
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'bandpassfilt',defaultBandpass,@isnumeric);
addParameter(ip, 'revfilt',defaultRevFilt,@islogical);
addParameter(ip, 'plotfreqz',defaultPlotFreqz,@isnumeric);
addParameter(ip, 'minphase',defaultMinPhase,@islogical);
addParameter(ip, 'filtorder',defaultFiltOrder,@isnumeric);
addParameter(ip, 'dynamicfiltorder', defaultDynamicFiltOrder,@islogical);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    if ~(ip.Results.dynamicfiltorder)
        EEG = pop_eegfiltnew(EEG, 'locutoff', ip.Results.bandpassfilt(1), 'hicutoff', ip.Results.bandpassfilt(2), 'filtorder',ip.results.filtorder,'revfilt', ip.Results.revfilt, 'plotfreqz',ip.Results.plotfreqz,'minphase',ip.Results.minphase);
        EEG.vhtp.eeg_htpEegBandpassFilterEeglab.filtorder    = ip.Results.filtorder;
    else
        EEG = pop_eegfiltnew(EEG, 'locutoff', bandpassfilt(1), 'hicutoff', ip.Results.bandpassfilt(2),'revfilt', ip.Results.revfilt, 'plotfreqz',ip.Results.plotfreqz,'minphase',ip.Results.minphase);
        EEG.vhtp.eeg_htpEegBandpassFilterEeglab.filtorder    = 'dynamic';
    end
    EEG.vhtp.eeg_htpEegBandpassFilterEeglab.completed = 1;
    EEG.vhtp.eeg_htpEegBandpassFilterEeglab.bandpasscutoff = ip.Results.bandpassfilt;
    EEG.vhtp.eeg_htpEegBandpassFilterEeglab.revfilt     = ip.Results.revfilt;
    EEG.vhtp.eeg_htpEegBandpassFilterEeglab.plotfreqz   = ip.Results.plotfreqz;
    EEG.vhtp.eeg_htpEegBandpassFilterEeglab.minphase    = ip.Results.minphase;
catch e
    throw(e);
end

EEG = eeg_checkset(EEG);


if isfield(EEG,'vhtp') && isfield(EEG.vhtp,'inforow')
    EEG.vhtp.inforow.proc_filt_bandpass_lowcutoff = ip.Results.bandpassfilt(1);
    EEG.vhtp.inforow.proc_filt_bandpass_highcutoff = ip.Results.bandpassfilt(2);
end

qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegBandpassFilterEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegBandpassFilterEeglab.qi_table = [EEG.vhtp.eeg_htpEegBandpassFilterEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegBandpassFilterEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegBandpassFilterEeglab;

if ip.Results.saveoutput && ~isempty(ip.Results.outputdir)
    if isfield(EEG.vhtp, 'currentStep')
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,EEG.vhtp.currentStep);
    else
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,'filter_bandpass');
    end
    fprintf('Output was copied to %s\n\n',ip.Results.outputdir);
end

end



