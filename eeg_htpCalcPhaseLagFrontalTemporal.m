function [EEG, results] = eeg_htpCalcPhaseLag(EEG, varargin)
% eeg_htpCalcPli() - calculates phase lag index on EEG set. Implementation
% of Michael X Cohen's PLI code from Chapter 26. Further customized to over time
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
defaultGpu = 0;
defaultDuration = 60;

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'outputdir', defaultOutputDir, @isfolder);
addParameter(ip, 'gpuon', defaultGpu, @islogical);
addParameter(ip, 'duration', defaultDuration);

parse(ip, EEG, varargin{:});% specify some time-frequency parameters

c = containers.Map;
c('LT') = {'banksstsL' 'entorhinalL' 'fusiformL' 'inferiortemporalL' ...
    'insulaL' 'middletemporalL' 'parahippocampalL' 'superiortemporalL' ...
    'temporalpoleL' 'transversetemporalL'}; % 10
c('RT') = {'banksstsR' 'entorhinalR' 'fusiformR' 'inferiortemporalR' ...
    'insulaR' 'middletemporalR' 'parahippocampalR' 'superiortemporalR' ...
    'temporalpoleR' 'transversetemporalR'};
c('LL') = {'caudalanteriorcingulateL' 'isthmuscingulateL' ...
    'posteriorcingulateL' 'rostralanteriorcingulateL'}; % 4
c('RL') = {'caudalanteriorcingulateR' 'isthmuscingulateR' ...
    'posteriorcingulateR' 'rostralanteriorcingulateR'};
c('LF') = {'caudalmiddlefrontalL' 'parsopercularisL' 'parstriangularisL' ...
    'rostralmiddlefrontalL' 'superiorfrontalL'}; % 5
c('RF') = {'caudalmiddlefrontalR' 'parsopercularisR' 'parstriangularisR' ...
    'rostralmiddlefrontalR' 'superiorfrontalR'};
c('LO') = {'cuneusL' 'lateraloccipitalL' 'lingualL' 'pericalcarineL'}; % 4
c('RO') = {'cuneusR' 'lateraloccipitalR' 'lingualR' 'pericalcarineR'};
c('LPF') = {'frontalpoleL' 'lateralorbitofrontalL' ...
    'medialorbitofrontalL' 'parsorbitalisL'}; % 4
c('RPF') = {'frontalpoleR' 'lateralorbitofrontalR' ...
    'medialorbitofrontalR' 'parsorbitalisR'};
c('LP') = {'inferiorparietalL' 'precuneusL' 'superiorparietalL' 'supramarginalL'}; % 4
c('RP') = {'inferiorparietalR' 'precuneusR' 'superiorparietalR' 'supramarginalR'};
c('LC') = {'paracentralL' 'postcentralL' 'precentralL'}; % 3
c('RC') = {'paracentralR' 'postcentralR' 'precentralR'};

tic;
combos = combnk([c('LF') c('RF') c('LPF') c('RPF') c('LT') c('RT')]', 2); % 703x2
%combos = combnk([c('LT') c('RT')]', 2); % 703x2

% combos = combnk({EEG.chanlocs(:).labels}', 2); % channel pairs (unique)
% 2278x2

if ip.Results.gpuon
    warning('GPU Arrays Enabled.')
    EEG.data = gpuArray(EEG.data);
end

combo_left = combos(:,1);
combo_right = combos(:,2);
combo_size = size(combos,1);

%% Define Band Ranges
bandDefs = {
    'delta', 2 , 3.5;
    'theta', 3.5, 7.5;
    'alpha1', 8, 10;
    'alpha2', 10.5, 12.5; % edit for whole numbers
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

% Consistent Duration
t = ip.Results.duration; % time in seconds
fs = EEG.srate; % sampling rate
samples = t * fs; % if using time, number of samples
start_sample = 0 * fs; if start_sample == 0, start_sample = 1; end
total_samples = EEG.pnts * EEG.trials;

if samples >= total_samples - start_sample
    samples = total_samples;
    start_samples = 1; % in samples
    warning("Insufficient Data, using max samples.")
else
    EEG = pop_select(EEG, 'trial', [1 : t / (EEG.pnts/ fs)]); % extract baseline
end

% EEG = pop_resample( EEG, 500 );
srate = EEG.srate;
pnts = EEG.pnts;
trials = EEG.trials;
labels = {EEG.chanlocs.labels};

% EEG.data = gpuArray(double(EEG.data));

% dataset validation
% is size sufficient for duration and offset?
% Key Parameters


for ci = 1 : combo_size % parfor

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
    ispc    = zeros(length(freqs2use),EEG.trials);
    pli     = zeros(length(freqs2use),EEG.trials);
    wpli    = zeros(length(freqs2use),EEG.trials);
    dwpli   = zeros(length(freqs2use),EEG.trials);

    parfor fi=1:length(freqs2use)

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
        cdd = sig1 .* conj(sig2); % 500pnts x 138trial

        % ISPC
        ispc(fi,:) = abs( mean( exp(1i*angle(cdd)) ) ); % note: equivalent to ispc(fi,:) = abs(mean(exp(1i*(angle(sig1)-angle(sig2))),2));
        
        % take imaginary part of signal only
        cdi = imag(cdd); % 500 x 149

        % phase-lag index
        pli(fi,:)  = abs(mean(sign(cdi)));

        % weighted phase-lag index (eq. 8 in Vink et al. NeuroImage 2011)
        wpli(fi,:) = abs( mean( abs(cdi).*sign(cdi) ) )./mean(abs(cdi));

        % debiased weighted phase-lag index (shortcut, as implemented in fieldtrip)
        imagsum      = sum(cdi);
        imagsumW     = sum(abs(cdi));
        debiasfactor = sum(cdi.^2);
        dwpli(fi,:)  = (imagsum.^2 - debiasfactor)./(imagsumW.^2 - debiasfactor);


    end

    res_dwpli(ci, :) = mean(dwpli,2);
    res_chan{ci,1} = channel1;
    res_chan2{ci,1} = channel2;
end
freq_labels = arrayfun(@(x) ['F',strrep(num2str(x),'.','_')], freqs2use, 'uni',0);
% freq_labels = arrayfun(@(x) ['F',num2str(x)], 1:numel(freqs2use), 'uni',0);
% freq_labels = arrayfun(@(x) sprintf('F%d',x*10), freqs2use, 'uni',0); % sprintf('F%1.1f',x)
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
