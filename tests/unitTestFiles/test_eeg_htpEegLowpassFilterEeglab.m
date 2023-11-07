function [EEG, results] = test_eeg_htpEegLowpassFilterEeglab(EEG)

[EEG, results] = eeg_htpEegLowpassFilterEeglab(EEG,'lowpassfilt',80,'revfilt',false,'plotfreqz',0,'minphase',false,'filtorder',6600,'dynamicfiltorder',true,'saveoutput',false,'outputdir','');

end

