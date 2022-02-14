function [EEG] = eeg_htpFiltNotch(EEG,notch,varargin)
%EEG_HTPFILTBANPASS Summary of this function goes here
%   Detailed explanation goes here

defaultNotch = [55 65];
defaultFiltOrder   = 3300;
defaultRevFilt     = 1;
defaultPlotFreqz   = 0;
defaultMinPhase    = false;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addOptional(ip, 'notch',defaultNotch,@isnumeric);
addParameter(ip, 'filtOrder',defaultFiltOrder,@isnumeric);
addParameter(ip, 'revFilt',defaultRevFilt,@isnumeric);
addParameter(ip, 'plotFreqz',defaultPlotFreqz,@isnumeric);
addParameter(ip, 'minPhase',defaultMinPhase,@islogical);

parse(ip,EEG,notch,varargin{:});

try
    linenoise = floor((notch(1) + notch(2)) / 2);
    harmonics = floor((EEG.srate/2) / linenoise);
    if EEG.srate < 2000
        for i = 1 : harmonics
            EEG = pop_eegfiltnew(EEG, 'locutoff', (linenoise * i)-2, 'hicutoff', (linenoise * i)+2, 'filtorder', ip.Results.filtOrder, 'revfilt', ip.Results.revFilt, 'plotfreqz',ip.Results.plotFreqz);
        end
    end

catch e
    throw(e);
end

EEG.etc.filter.notch = struct('cutoff',ip.Results.notch,'filter_order',ip.Results.filtOrder,'reverse_filter',ip.Results.revFilt,'plot_frequencies',ip.Results.plotFreqz,'minimum_phase_converted_causal_filter',ip.Results.minPhase);
EEG = eeg_checkset( EEG );

end

