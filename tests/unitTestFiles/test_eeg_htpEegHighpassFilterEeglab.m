function [EEG, results] = test_eeg_htpEegHighpassFilterEeglab(EEG)

[EEG, results] = eeg_htpEegHighpassFilterEeglab(EEG,'highpassfilt',.5,'revfilt',false,'plotfreqz',0,'minphase',false,'filtorder',6600,'dynamicfiltorder',true,'saveoutput',false,'outputdir','');

end
