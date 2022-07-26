
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
tic;
[fEEG] = eeg_htpEegFilterFastFc( EEG, 'lowpass', 30 );
toc;

[fEEG] = eeg_htpEegFilterFastFc( EEG, 'highpass', 2 );
[fEEG] = eeg_htpEegFilterFastFc( EEG, 'notch', [47 53] );
[fEEG] = eeg_htpEegFilterFastFc( EEG, 'bandpass', [5 7] );

% plot results
pop_eegplot(fEEG)
pop_spectopo(fEEG);

% return data matrix only in samples X channel
x = eeg_htpCalcReturnColumnMatrix(fEEG);

tic;[plv,pval_plv,pli]=fastfc_ps(x,n_samples*.1,1);t_ps1=toc;
tic;[wpli,imc]=fastfc_wpli(x);t_ps2=toc;

% load eeglab data and convert to fieldtrip

cfg = []; 
cfg.dataset = 'C:\srv\RAWDATA\P1_70FXS_71_TDC\S04_POSTCOMP\Group2\D0079_rest_postcomp.set'; 
ft_data1 = ft_preprocessing(cfg);

%% compute the power spectrum
cfg              = [];
cfg.output       = 'pow';
cfg.method       = 'mtmfft';
cfg.taper        = 'dpss';
cfg.tapsmofrq    = 1;
cfg.keeptrials   = 'no';
datapow_planar   = ft_freqanalysis(cfg, ft_data1);

%% plot the topography and the spectrum
figure;

cfg        = [];
cfg.layout = 'CTF275_helmet.mat';
cfg.xlim   = [5 7];
subplot(2,2,1); ft_topoplotER(cfg, datapow_planar);
subplot(2,2,2); ft_topoplotER(cfg, ft_combineplanar([], datapow_planar));

cfg         = [];
cfg.channel = {'MRO22', 'MRO32', 'MRO33'};
subplot(2,2,3); ft_singleplotER(cfg, datapow_planar);

%% compute connectivity
cfg         = [];
cfg.method  ='coh';
cfg.complex = 'absimag';
source_conn = ft_connectivityanalysis(cfg, ft_data1);
