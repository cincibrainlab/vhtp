function [PARAMS] = parameters_resting_source()
clear PARAMS;

%% Wavelet Thresholding
PARAMS.eeg_htpEegWaveletDenoiseHappe.function = @eeg_htpEegWaveletDenoiseHappe;
PARAMS.eeg_htpEegWaveletDenoiseHappe.isErp = false;


%% RESTING SPECTRAL POWER
PARAMS.eeg_htpCalcRestPower.function = @eeg_htpCalcRestPower;
PARAMS.eeg_htpCalcRestPower.useParquet = true;
PARAMS.eeg_htpCalcRestPower.gpuOn = true;
% PARAMS.eeg_htpCalcRestPower.outputdir = results_dir;

%% GLOBAL COUPLING
PARAMS.eeg_htpGraphPhaseBcm.function = @eeg_htpCalcAacGlobal;
PARAMS.eeg_htpGraphPhaseBcm.useParquet = true;
PARAMS.eeg_htpGraphPhaseBcm.gpuOn = true;
% PARAMS.eeg_htpGraphPhaseBcm.outputdir = results_dir;


end
