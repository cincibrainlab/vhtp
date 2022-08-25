function [PARAMS] = parameters_VD()
clear PARAMS;

%%FILTER HIGHPASS
PARAMS.filter_highpass.function = @eeg_htpEegFilterEeglab;
PARAMS.filter_highpass.method='highpass';
PARAMS.filter_highpass.highpassfilt = 0.5;

%%FILTER LOWPASS
PARAMS.filter_lowpass.function = @eeg_htpEegFilterEeglab;
PARAMS.filter_lowpass.method = 'lowpass';
PARAMS.filter_lowpass.lowpassfilt=80;

%%FILTER NOTCH
PARAMS.filter_notch.function = @eeg_htpEegFilterEeglab;
PARAMS.filter_notch.method = 'notch';
PARAMS.filter_notch.notchfilt=[57 63];

%%RESAMPLE
PARAMS.resample.function = @eeg_htpEegResampleDataEeglab;
PARAMS.resample.srate = 500;

%%CHANNEL REMOVAL 
PARAMS.channel_removal.function=@eeg_htpEegRemoveChansEeglab;
PARAMS.channel_removal.threshold = 3;

%%CHANNEL INTERPOLATION
PARAMS.channel_interpolation.function = @eeg_htpEegInterpolateChansEeglab;
PARAMS.channel_interpolation.method = 'spherical';

%%SEGMENT REMOVAL
PARAMS.segment_removal.function = @eeg_htpEegRemoveSegmentsEeglab;

%%ICA
PARAMS.ica.function = @eeg_htpEegIcaEeglab;
PARAMS.ica.method = 'binica';

%%REMOVE COMPONENTS
PARAMS.component_removal.function=@eeg_htpEegRemoveCompsEeglab;
PARAMS.component_removal.maxcomps = 24;


%%Average Reference
PARAMS.rereference.function = @eeg_htpEegRereferenceEeglab;
end



