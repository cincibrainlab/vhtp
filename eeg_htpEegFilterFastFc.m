function [fEEG, results] = eeg_htpEegFilterFastFc(EEG, filttype, filtfreq)
% eeg_htpEegFilterFastFc - Perform various filtering methods
%                          using fast_fc toolbox
%
% Usage:
%    >> [ EEG, results ] = eeg_htpEegFilterEeglab( EEG, method, varargin)
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
%    method  - Text representing method utilized for Filtering
%
% Function Specific Inputs:
%   'lowpassfilt' - Number representing the higher edge frequency to use in
%                   lowpass bandpass filter
%                   default: 80
%
%   'hipassfilt' - Number representing the lower edge frequency to use in
%                  highpass bandpass filter
%                  default: .5
%
%   'notchfilt' - Array of two numbers utilized for generating the line noise
%             used in harmonics calculation for notch filtering
%             default: [55 65]
%
%
%   'revfilt' - Numeric boolean to invert filter from bandpass to notch
%               {0 -> bandpass, 1 -> notch}
%               default: 0
%
%   'plotfreqz' - Numeric boolean to indicate whether to plot filter's frequency and
%                 phase response
%                 default: 0
%
%   'minphase' - Boolean for minimum-phase converted causal filter
%                default: false
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



% where
%   dat        data matrix (Nchans X Ntime)
%   Fsample    sampling frequency in Hz
%   Flp        filter frequency
%   N          optional filter order, default is 6 (but) or 25 (fir)
%   type       optional filter type, can be
%                'but' Butterworth IIR filter (default)
%                'fir' FIR filter using MATLAB fir1 function
%   dir        optional filter direction, can be
%                'onepass'         forward filter only
%                'onepass-reverse' reverse filter only, i.e. backward in time
%                'twopass'         zero-phase forward and reverse filter (default)

validateFiltType =  @( filttype ) ischar( filttype ) & ismember(filttype, {'highpass', 'lowpass', 'notch', 'bandpass'});

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addRequired(ip, 'filttype', validateFiltType);
addRequired(ip, 'filtfreq', @isnumeric);

parse(ip,EEG, filttype, filtfreq);

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

Fs = EEG.srate;     % sample rate
Fn = Fs / 2;        % nyquist

switch filttype
    case 'lowpass'
        n = 3300;
        b = fir1(n, max(filtfreq)/Fn,"low");
    case 'highpass'
        n = 6600;
        b = fir1(n, max(filtfreq)/Fn,"high");
    case 'notch'
        n = 3300;
        b = fir1(n, [min(filtfreq)/Fn max(filtfreq)/Fn], 'stop');
    case 'bandpass'
        n = 3300;
        b = fir1(n, [min(filtfreq)/Fn max(filtfreq)/Fn], 'bandpass');
end

% filter data
a = 1;

% Wrangle data for filter function
if ndims(EEG.data) < 3 %#ok<ISMAT>
    dat = double(EEG.data');
else
    EEG = eeg_htpEegEpoch2Cont(EEG);
    dat = double(EEG.data');
end

Fd = filtfilt(b, a, dat)';

fEEG = EEG;
fEEG.data = Fd;

end



