function [EEG] = eeg_htpFiltLowPass(EEG,lowpassFilt,varargin)
%EEG_HTPFILTLOWPASS Summary of this function goes here
%   Detailed explanation goes here
timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output
    

defaultHiCutoff = 80;
defaultFiltOrder   = 3300;
defaultRevFilt     = 0;
defaultPlotFreqz   = 0;
defaultMinPhase    = false;
    
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addOptional(ip, 'lowpassFilt',defaultHiCutoff,@isnumeric);
addParameter(ip, 'filtOrder',defaultFiltOrder,@isnumeric);
addParameter(ip, 'revFilt',defaultRevFilt,@isnumeric);
addParameter(ip, 'plotFreqz',defaultPlotFreqz,@isnumeric);
addParameter(ip, 'minPhase',defaultMinPhase,@islogical);

parse(ip,EEG,lowpassFilt,varargin{:});

try
    EEG = pop_eegfiltnew(EEG,  'locutoff', [],  'hicutoff', lowpassFilt, 'filtorder', ip.Results.filtOrder);
catch e
    throw(e);
end

EEG.etc.filter.lowpass = struct('cutoff',ip.Results.lowpassFilt,'filter_order',ip.Results.filtOrder,'reverse_filter',ip.Results.revFilt,'plot_frequencies',ip.Results.plotFreqz,'minimum_phase_converted_causal_filter',ip.Results.minPhase);
EEG = eeg_checkset( EEG );

end

