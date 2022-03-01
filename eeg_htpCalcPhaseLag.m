function [EEG, results] = eeg_htpCalcPhaseLag(EEG, varargin)
% eeg_htpCalcPli() - calculates phase lag index on EEG set. Implementation
% of Michael X Cohen's PLI code from Chapter 26.
%
% Cohen, Mike X. Analyzing neural time series data: theory and practice.
% MIT Press 2014.

% Usage:
%    >> [ EEG, results ] = eeg_htpFunctionTemplate( EEG )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
% Function Specific Inputs:
%     'outputdir' - description
%
% Outputs:
%     EEG       - EEGLAB Structure with modified .vhtp field
%     results   - .vhtp structure
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

% Inputs: Function Specific

% Inputs: Common across Visual HTP functions
defaultOutputDir = tempdir;

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
parse(ip, EEG, varargin{:});% specify some time-frequency parameters
tic;
combos = combnk({EEG.chanlocs(:).labels}', 2); % channel pairs (unique)

EEG.data = gpuArray(EEG.data);

combo_left = combos(:,1);
combo_right = combos(:,2);
combo_size = size(combos,1);

%% Define Band Ranges
bandDefs = {
    'delta', 2 , 3.5;
    'theta', 3.5, 7.5;
    'alpha1', 8, 10;
    'alpha2', 10.5, 12.5;
    'beta', 13, 30;
    'gamma1', 30, 55;
    'gamma2', 65, 90;
    'epsilon', 81, 120;
    };

f_theta = [bandDefs{2,2}:1:bandDefs{2,3}];
f_alpha1 = [bandDefs{3,2}:1:bandDefs{3,3}];
f_alpha2 = [bandDefs{4,2}:1:bandDefs{4,3}];
f_gamma1 =[bandDefs{6,2}:5:bandDefs{6,3}];
f_gamma2 = [bandDefs{7,2}:5:bandDefs{7,3}];

freqs2use = [f_theta f_alpha1 f_alpha2 f_gamma1 f_gamma2];
nofreqs = length(freqs2use);
res_dwpli = zeros(combo_size, nofreqs);
res_chan = cell(combo_size,1);
res_chan2 = cell(combo_size,1);

srate = EEG.srate;
pnts = EEG.pnts;
trials = EEG.trials;
labels = {EEG.chanlocs.labels};

parfor ci = 1 : combo_size

    channel1 = combo_left{ci};
    channel2 = combo_right{ci};

    % wavelet and FFT parameters
    time          = -1:1/srate:1;
    half_wavelet  = (length(time)-1)/2;
    num_cycles = logspace(log10(3),log10(8),length(freqs2use)); % ANTS 26.3
    n_wavelet     = length(time);
    n_data        = pnts*trials;
    n_convolution = n_wavelet+n_data-1;

    % select channels
    chanidx = zeros(1,2); % always initialize!
    chanidx(1) = find(strcmpi(channel1,labels));
    chanidx(2) = find(strcmpi(channel2,labels));

    % data FFTs
    data_fft1 = fft(reshape(EEG.data(chanidx(1),:,:),1,n_data),n_convolution);
    data_fft2 = fft(reshape(EEG.data(chanidx(2),:,:),1,n_data),n_convolution);

    % initialize
    ispc    = zeros(length(freqs2use),EEG.pnts);
    pli     = zeros(length(freqs2use),EEG.pnts);
    wpli    = zeros(length(freqs2use),EEG.pnts);
    dwpli   = zeros(length(freqs2use),EEG.pnts);

    for fi=1:length(freqs2use)

        % create wavelet and take FFT
        s = num_cycles(fi)/(2*pi*freqs2use(fi));
        wavelet_fft = fft( exp(2*1i*pi*freqs2use(fi).*time) .* exp(-time.^2./(2*(s^2))) ,n_convolution);

        % phase angles from channel 1 via convolution
        convolution_result_fft = ifft(wavelet_fft.*data_fft1,n_convolution);
        convolution_result_fft = convolution_result_fft(half_wavelet+1:end-half_wavelet);
        sig1 = reshape(convolution_result_fft,EEG.pnts,EEG.trials);

        % phase angles from channel 2 via convolution
        convolution_result_fft = ifft(wavelet_fft.*data_fft2,n_convolution);
        convolution_result_fft = convolution_result_fft(half_wavelet+1:end-half_wavelet);
        sig2 = reshape(convolution_result_fft,EEG.pnts,EEG.trials);

        % cross-spectral density
        cdd = sig1 .* conj(sig2);

        % ISPC
        ispc(fi,:) = abs(mean(exp(1i*angle(cdd)),2)); % note: equivalent to ispc(fi,:) = abs(mean(exp(1i*(angle(sig1)-angle(sig2))),2));

        % take imaginary part of signal only
        cdi = imag(cdd);

        % phase-lag index
        pli(fi,:)  = abs(mean(sign(imag(cdd)),2));

        % weighted phase-lag index (eq. 8 in Vink et al. NeuroImage 2011)
        wpli(fi,:) = abs( mean( abs(cdi).*sign(cdi) ,2) )./mean(abs(cdi),2);

        % debiased weighted phase-lag index (shortcut, as implemented in fieldtrip)
        imagsum      = sum(cdi,2);
        imagsumW     = sum(abs(cdi),2);
        debiasfactor = sum(cdi.^2,2);
        dwpli(fi,:)  = (imagsum.^2 - debiasfactor)./(imagsumW.^2 - debiasfactor);


    end

    res_dwpli(ci, :) = mean(dwpli,2);
    res_chan{ci,1} = channel1;
    res_chan2{ci,1} = channel2;
end

freq_labels = arrayfun(@(x) sprintf('F%1.1f',x), freqs2use, 'uni',0);

summary_table = [table(string(repmat(EEG.setname, combo_size,1)), res_chan, res_chan2, 'VariableNames',{'eegid','chan1','chan2'}) ...
    array2table(res_dwpli,'VariableNames',freq_labels)];

toc;

% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});

% Outputs:
EEG.vhtp.eeg_htpCalcPhaseLag.summary_table =  summary_table;
EEG.vhtp.eeg_htpCalcPhaseLag.qi_table = qi_table;

results = EEG.vhtp.eeg_htpCalcPhaseLag;

end

