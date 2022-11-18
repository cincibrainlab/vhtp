% Parameter File: parameters_MEA_Connectivity.m
% Visual High Throughput Pipeline
% 2022-11-18 17:21:58
% http://github.com/cincibrainlab/vhtp


function [PARAMS] = parameters_MEA_Connectivity()
clear PARAMS


%% eeg_htpGraphPhaseBcm - Parameter Set
PARAMS.eeg_htpGraphPhaseBcm.function = @eeg_htpGraphPhaseBcm;
% PARAMS.eeg_htpGraphPhaseBcm.EEG = REQUIRED;
PARAMS.eeg_htpGraphPhaseBcm.gpuon = 1;
PARAMS.eeg_htpGraphPhaseBcm.threshold = missing;
% PARAMS.eeg_htpGraphPhaseBcm.outputdir = REQUIRED;
% PARAMS.eeg_htpGraphPhaseBcm.useParquet = REQUIRED;



end
