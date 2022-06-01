
% add toolkit paths
vhtp_path = '/srv/vhtp';
eeglab_path = '/srv/TOOLKITS/eeglab';
brainstorm_path = '/srv/TOOLKITS/brainstorm3';

restoredefaultpath;
addpath(genpath(vhtp_path));
addpath(eeglab_path);
addpath(brainstorm_path);

eeglab nogui;       % load eeglab functions


% load sample data (simulated or empirical data)
[EEG] = eeg_htpEegSimulateEeg( 'showplot', false );
[EEG] = pop_loadset( 'filename', 'D0079_rest_postcomp.set', 'filepath', 'C:\srv\RAWDATA\P1_70FXS_71_TDC\S04_POSTCOMP\Group2' );

% test filter functions
[fEEG] = eeg_htpEegFilterFastFc( EEG, 'lowpass', 30 );
[fEEG] = eeg_htpEegFilterFastFc( EEG, 'highpass', 2 );
[fEEG] = eeg_htpEegFilterFastFc( EEG, 'notch', [47 53] );
[fEEG] = eeg_htpEegFilterFastFc( EEG, 'bandpass', [5 7] );

% plot results
pop_eegplot(fEEG)
pop_spectopo(fEEG);

% return data matrix only in samples X channel
x = eeg_htpCalcReturnColumnMatrix(fEEG);


