% Parameter File: parameters_MEA_Connectivity.m
% Visual High Throughput Pipeline
% 2022-11-18 18:18:59
% http://github.com/cincibrainlab/vhtp


function [PARAMS] = parameters_MEA_Connectivity()
clear PARAMS


%% eeg_htpEegWaveletDenoiseHappe - Parameter Set
PARAMS.eeg_htpEegWaveletDenoiseHappe.function = @eeg_htpEegWaveletDenoiseHappe;
% PARAMS.eeg_htpEegWaveletDenoiseHappe.EEG = REQUIRED;
PARAMS.eeg_htpEegWaveletDenoiseHappe.outputdir = tempdir;
PARAMS.eeg_htpEegWaveletDenoiseHappe.isErp = tempdir;
PARAMS.eeg_htpEegWaveletDenoiseHappe.wavLvl = [];
PARAMS.eeg_htpEegWaveletDenoiseHappe.wavelet = 'coif4';
PARAMS.eeg_htpEegWaveletDenoiseHappe.DenoisingMethod = "Bayes";
PARAMS.eeg_htpEegWaveletDenoiseHappe.ThresholdRule = '';
PARAMS.eeg_htpEegWaveletDenoiseHappe.NoiseEstimate = 'LevelDependent';
PARAMS.eeg_htpEegWaveletDenoiseHappe.highpass = 30;
PARAMS.eeg_htpEegWaveletDenoiseHappe.lowpass = .5;
PARAMS.eeg_htpEegWaveletDenoiseHappe.filtOn = true;
PARAMS.eeg_htpEegWaveletDenoiseHappe.saveoutput = false;



end
