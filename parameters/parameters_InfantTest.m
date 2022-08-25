function [PARAMS] = parameters_InfantTest()
clear PARAMS;
%FILTER HIGHPASS
PARAMS.filter_highpass.function = @eeg_htpEegFilterEeglab;
PARAMS.filter_highpass.method='highpass';
PARAMS.filter_highpass.highpassfilt = 0.3;
PARAMS.filter_highpass.filtorder = 13750;


%%FILTER NOTCH
PARAMS.filter_notch.function = @eeg_htpEegFilterEeglab;
PARAMS.filter_notch.method = 'notch';
PARAMS.filter_notch.notchfilt=[57 63];
% PARAMS.filter_notch.saveoutput = true;

%%FILTER LOWPASS
PARAMS.filter_lowpass.function = @eeg_htpEegFilterEeglab;
PARAMS.filter_lowpass.method = 'lowpass';
PARAMS.filter_lowpass.lowpassfilt=100;
%PARAMS.filter_lowpass.saveoutput = true;

% %% WAVELET DENOISING
 PARAMS.waveletdenoise.function = @eeg_htpEegWaveletDenoiseHappe;
 PARAMS.waveletdenoise.isErp = true;
 PARAMS.waveletdenoise.filtOn = true;
 PARAMS.waveletdenoise.saveoutput = true;

%%CHANNEL REMOVAL 
PARAMS.channel_removal.function=@eeg_htpEegRemoveChansEeglab;
PARAMS.channel_removal.threshold = 3;
PARAMS.channel_removal.removechannel = true;
PARAMS.channel_removal.saveoutput = true;
PARAMS.channel_removal.minimumduration = 0;
PARAMS.channel_removal.type = 'Event';
PARAMS.channel_removal.automark = true;


% 
% %% EPOCH AND BASELINE CORRECT
% PARAMS.create_epochs.function = @eeg_htpEegCreateErpEpochsEeglab;
% PARAMS.create_epochs.eventevent = 'vep+';
% PARAMS.create_epochs.epochlimits = [-.1 .45];
% PARAMS.create_epochs.rmbaseline = 1;
% PARAMS.create_epochs.baselinelimits = [-100 0];

% % 
% %%RESAMPLE
% PARAMS.resample.function = @eeg_htpEegResampleDataEeglab;
% PARAMS.resample.srate = 500;
 

% 
% %%CHANNEL INTERPOLATION
% PARAMS.channel_interpolation.function = @eeg_htpEegInterpolateChansEeglab;
% PARAMS.channel_interpolation.method = 'spherical';
% 
% %%SEGMENT REMOVAL
% PARAMS.segment_removal.function = @eeg_htpEegRemoveSegmentsEeglab;
% 
% %%ICA
% PARAMS.ica.function = @eeg_htpEegIcaEeglab;
% PARAMS.ica.method = 'binica';
% 
% %%REMOVE COMPONENTS
% PARAMS.component_removal.function=@eeg_htpEegRemoveCompsEeglab;
% PARAMS.component_removal.maxcomps = 24;
% 
% 
% %%Average Reference
% PARAMS.rereference.function = @eeg_htpEegRereferenceEeglab;
end



