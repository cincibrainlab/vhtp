function [PARAMS] = parameters_analysis_resting()
clear PARAMS;

%%RESTING SPECTRAL POWER
PARAMS.eeg_htpCalcRestPower.function = @eeg_htpCalcRestPower;
PARAMS.eeg_htpCalcRestPower.useParquet = true;
PARAMS.eeg_htpCalcRestPower.gpuOn = true;

PARAMS.eeg_htpCalcAacGlobal.function = @eeg_htpCalcAacGlobal;
PARAMS.eeg_htpCalcAacGlobal.useParquet = true;
PARAMS.eeg_htpCalcAacGlobal.duration = 60;

PARAMS.htpCalcEulerPac.function = @htpCalcEulerPac;
PARAMS.htpCalcEulerPac.useParquet = true;
PARAMS.htpCalcEulerPac.duration = 60;

PARAMS.eeg_htpCalcLaplacian.function = @eeg_htpCalcLaplacian;
PARAMS.eeg_htpCalcLaplacian.useParquet = true;
PARAMS.eeg_htpCalcLaplacian.duration = 60;

end
