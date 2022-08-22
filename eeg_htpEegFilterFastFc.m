function [fEEG, results] = eeg_htpEegFilterFastFc(EEG, filttype, filtfreq, varargin)
% Description: Perform various filtering methods using fast_fc toolbox
% ShortTitle: Filter EEG using FastFC
% Category: Preprocessing
% Tags: Filter
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
%
%       order       force filter order
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

validateFiltType =  @( filttype ) ischar( filttype ) & ismember(filttype, {'highpass', 'lowpass', 'notch', 'bandpass'});

defaultOrder = missing;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addRequired(ip, 'filttype', validateFiltType);
addRequired(ip, 'filtfreq', @isnumeric);
addParameter(ip, 'order', defaultOrder, @isnumeric);

parse(ip,EEG, filttype, filtfreq, varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

Fs = EEG.srate;     % sample rate
Fn = Fs / 2;        % nyquist

% check if FastFc toolbox is present
if exist('fastfc_filt','file')
    useFastFc = true;
    disp('Using FastFc Toolbox (http://juangpc.github.io/FastFC/).')
else
    useFastFc = false;
    disp('Missing FastFc Toolbox (http://juangpc.github.io/FastFC/). Using MATLAB filtfilt.')
end

% filter order override
if ~ismissing(ip.Results.order)
    n = ip.Results.order;
else
    switch filttype
        case 'lowpass'
            n = 3300;
        case 'highpass'
            n = 6600;
        case 'notch'
            n = 3300;
        case 'bandpass'
            n = 3300;
    end
end

switch filttype
    case 'lowpass'
        b = fir1(n, max(filtfreq)/Fn,"low");
    case 'highpass'
        b = fir1(n, max(filtfreq)/Fn,"high");
    case 'notch'
        b = fir1(n, [min(filtfreq)/Fn max(filtfreq)/Fn], 'stop');
    case 'bandpass'
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

if useFastFc
    Fd = fastfc_filt(b,dat,1)';
else
    Fd = filtfilt(b, a, dat)';
end

fEEG = EEG;
fEEG.data = Fd;

end



