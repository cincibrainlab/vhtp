function [PARAMS] = parameters_Template()
%% THIS IS A TEMPLATE FOR A PARAMETERS FILE
% PLEASE COPY THIS FILE AND TAILOR IT TO YOUR PREPROCESSING NEEDS
% EACH STEP HAS A 'saveoutput' FIELD THAT NEEDS TO BE SET TO TRUE TO SAVE
% OUTPUT FOR THAT STEP
%
% IF YOU HAVE A SINGLE STEP PLEASE MAKE SURE TO SET THE 'saveoutput' FIELD
% TO TRUE TO ACTUALLY SAVE OUTPUT
%
% ALSO, ENSURE THAT THE LAST STEP IN A LIST OF MULTIPLE STEPS HAS THE
% 'saveoutput' FIELD SET TO TRUE TO SAVE FINAL FILES

clear PARAMS;

%%FILTER HIGHPASS
PARAMS.filter_highpass.function = @eeg_htpEegFilterEeglab;
PARAMS.filter_highpass.method='highpass';
PARAMS.filter_highpass.highpassfilt = 1;

%%FILTER LOWPASS
PARAMS.filter_lowpass.function = @eeg_htpEegFilterEeglab;
PARAMS.filter_lowpass.method = 'lowpass';
PARAMS.filter_lowpass.lowpassfilt=80;

%%FILTER NOTCH
PARAMS.filter_notch.function = @eeg_htpEegFilterEeglab;
PARAMS.filter_notch.method = 'notch';
PARAMS.filter_notch.notchfilt=[57 63];
PARAMS.filter_notch.saveoutput = true;

%%RESAMPLE
PARAMS.resample.function = @eeg_htpEegResampleDataEeglab;
PARAMS.resample.srate = 250;

%%Rereference
PARAMS.rereference.function = @eeg_htpEegRereferenceEeglab;

%%CHANNEL REMOVAL 
PARAMS.channel_removal.function=@eeg_htpEegRemoveChansEeglab;
PARAMS.channel_removal.threshold = 3;
PARAMS.channel_removal.saveoutput = true;

%%CHANNEL INTERPOLATION
PARAMS.channel_interpolation.function = @eeg_htpEegInterpolateChansEeglab;
PARAMS.channel_interpolation.method = 'spherical';

%%SEGMENT REMOVAL
PARAMS.segment_removal.function = @eeg_htpEegRemoveSegmentsEeglab;
PARAMS.serment_removal.saveoutput = true;

%%EPOCH CREATION
PARAMS.epoch_creation.function = @eeg_htpEegCreateEpochsEeglab;
PARAMS.epoch_creation.epochlength = 2;
PARAMS.epoch_creation.epochlimits=[-1 1];

%%EPOCH REMOVAL
PARAMS.epoch_removal.function = @eeg_htpEegRemoveEpochsEeglab;

%%ICA
PARAMS.ica.function = @eeg_htpEegIcaEeglab;
PARAMS.ica.method = 'binica';
PARAMS.ica.saveoutput = true;

%%REMOVE COMPONENTS
PARAMS.component_removal.function=@eeg_htpEegRemoveCompsEeglab;
PARAMS.component_removal.maxcomps = 24;
PARAMS.component_removal.saveoutput = true;
end

