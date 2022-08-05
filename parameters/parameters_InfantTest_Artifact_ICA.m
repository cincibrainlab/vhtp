function [PARAMS] = parameters_InfantTest_Artifact()
clear PARAMS;

%%ICA
PARAMS.ica.function = @eeg_htpEegIcaEeglab;
PARAMS.ica.method = 'cudaica';

%%REMOVE COMPONENTS
PARAMS.component_removal.function=@eeg_htpEegRemoveCompsEeglab;
PARAMS.component_removal.maxcomps = 24;


%% EPOCH AND BASELINE CORRECT
PARAMS.create_epochs.function = @eeg_htpEegCreateErpEpochsEeglab;
PARAMS.create_epochs.epochevent = 'vep+';
PARAMS.create_epochs.epochlimits = [-.1 .45];
PARAMS.create_epochs.rmbaseline = 1;
PARAMS.create_epochs.baselinelimits = [-100 0];

% %%SEGMENT REMOVAL
PARAMS.segment_removal.function = @eeg_htpEegRemoveSegmentsEeglab;

% %%CHANNEL INTERPOLATION
PARAMS.channel_interpolation.function = @eeg_htpEegInterpolateChansEeglab;
PARAMS.channel_interpolation.method = 'spherical';

% %%Average Reference
PARAMS.rereference.function = @eeg_htpEegRereferenceEeglab;
PARAMS.rereference.saveoutput = true;

% % 
% %%RESAMPLE
% PARAMS.resample.function = @eeg_htpEegResampleDataEeglab;
% PARAMS.resample.srate = 500;
% 

% 
% 

end



