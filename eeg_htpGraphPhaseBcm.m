function [EEG, results] = eeg_htpGraphPhaseBcm(EEG, varargin)
% eeg_htpGraphPhaseBcm: Phase brain connectivity matrix Implementation
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
note = @(msg) fprintf('%s: %s\n', mfilename, msg );
note(sprintf('Initializing function %s', timestamp));
note(sprintf('Loading %s', EEG.filename));

% Inputs: Common across Visual HTP functions
defaultOutputDir = pwd;
defaultGpuOn = 1;
defaultForceCsv = false;

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
addParameter(ip, 'gpuon', defaultGpuOn, @islogical);
addParameter(ip, 'forcecsv', defaultForceCsv, @islogical);
parse(ip, EEG, varargin{:});% specify some time-frequency parameters

note(sprintf('Output Dir: %s', ip.Results.outputdir));
note(sprintf('CSV Output: %s', mat2str(ip.Results.forcecsv)));

% Create channel combos
combos = combnk({EEG.chanlocs(:).labels}', 2); % channel pairs (unique)
ncombos = combnk(1:EEG.nbchan, 2); % channel pairs (numerical)
note(sprintf('%d channel combos created from %d channels', length(ncombos), EEG.nbchan));


% File Management
[~, basename, ~] = fileparts(EEG.filename);
bcm_file   = fullfile(ip.Results.outputdir, [basename '_bcm.parquet']);
graph_file = fullfile(ip.Results.outputdir, [basename '_graph.parquet']);

if ip.Results.gpuon
    note('GPU Arrays ON');
    EEG.data = gpuArray(EEG.data);
end

combo_left = ncombos(:,1);
combo_right = ncombos(:,2);
combo_size = size(ncombos,1);

%% Define Band Ranges
bandDefs = {
    'delta', 2 , 3.5;
    'theta', 3.5, 7.5;
    'alpha1', 8, 10;
    'alpha2', 10.5, 12.5;
    'beta', 13, 30;
    'gamma1', 30, 55;
    'gamma2', 65, 90;
    };

% defined frequency vector
nsteps = 30;
startf = 2;
endf = 80;
frex = logspace(log10(startf), log10(endf), nsteps);
nofreqs = length(frex);

note(sprintf('Frequencies(logspace): %d to %d Hz (%d steps)', startf, endf, nsteps));

res_dwpli = zeros(combo_size, nofreqs);
res_chan = zeros(combo_size,1);
res_chan2 = zeros(combo_size,1);

srate = EEG.srate;
pnts = EEG.pnts;
trials = EEG.trials;
labels = {EEG.chanlocs.labels};

note(sprintf('EEG: srate: %d, pnts: %d, trials %d', srate,pnts,trials))

freqs2use = frex;

tic;
note('Starting BCM calculations ...');

ppm = ParforProgressbar(combo_size);

parfor ci = 1 : combo_size

    channel1 = combo_left(ci);
    channel2 = combo_right(ci);

    % wavelet and FFT parameters
    time          = -1:1/srate:1;
    half_wavelet  = (length(time)-1)/2;
    num_cycles    = logspace(log10(3),log10(8),length(freqs2use)); % ANTS 26.3
    n_wavelet     = length(time);
    n_data        = pnts*trials;
    n_convolution = n_wavelet+n_data-1;

    % data FFTs
    data_fft1 = fft(reshape(EEG.data(channel1,:,:),1,n_data),n_convolution);
    data_fft2 = fft(reshape(EEG.data(channel2,:,:),1,n_data),n_convolution);

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
       
    res_ispc(ci,:) = mean(ispc,2);
    res_wpli(ci,:) = mean(wpli,2);
    res_dwpli(ci, :) = mean(dwpli,2);
    res_chan(ci,1) = channel1;
    res_chan2(ci,1) = channel2;
    
    ppm.increment();
end
toc;

% create graphs for each frequency and measure
note(sprintf('Tabulating BCM calculations into %s...', bcm_file));
for fi = 1 : numel(frex)
    [fispc(:,:,fi)] = create_bcm( res_chan, res_chan2, res_ispc(:,fi), labels);
    [fwpli(:,:,fi)] = create_bcm( res_chan, res_chan2, res_wpli(:,fi), labels);
    %[fdwpli(:,:,fi) = create_bcm( res_chan, res_chan2, res_dwpli(:,fi), labels);
end

bconn_table = {};
count = 1;
% sample long table
% eegid chan1 chan2 freq wpli ispc
for fi = 1 : size(fispc,3)
    current_ispc = fispc(:,:,fi);
    current_wpli = fwpli(:,:,fi);
    for ci = 1 : size(current_wpli,1)
        ispc_row = current_ispc(ci,:);
        wpli_row = current_wpli(ci,:);
        for ci2 = 1 : size(current_wpli,2)
            bconn_table{count,1} = EEG.filename;
            bconn_table{count,2} = labels(ci);
            bconn_table{count,3} = labels(ci2);
            bconn_table{count,4} = frex(fi);
            bconn_table{count,5} = current_wpli(ci2);
            bconn_table{count,6} = current_ispc(ci2);
            count = count + 1;
        end
    end
end

bconn_table2 = cell2table(bconn_table, ...
    'VariableNames', {'eegid','chan1','chan2','freq','wpli','ispc'});

note('Calculating graph measures ...');
[~, wpli_graph] = eeg_htpGraphBraphWU(EEG, fwpli, labels, frex);
[~, ispc_graph] = eeg_htpGraphBraphWU(EEG, fispc, labels, frex);

wpli_graph_table = wpli_graph.summary_table;
ispc_graph_table = ispc_graph.summary_table;

note(sprintf('Tabulating graph measures into %s...', graph_file));
wpli_graph_table.Properties.VariableNames =strrep(wpli_graph_table.Properties.VariableNames, 'value', 'wpli');
ispc_graph_table.Properties.VariableNames =strrep(ispc_graph_table.Properties.VariableNames, 'value', 'ispc');
graph_table = innerjoin(wpli_graph_table, ispc_graph_table);

% File management
note(sprintf('Writing files to disk.'));
if ip.Results.forcecsv
    writetable(bconn_table2, strrep(bcm_file,'parquet','csv'));
    writetable(graph_table, strrep(graph_file,'parquet','csv'));
else
    parquetwrite(bcm_file, bconn_table2);
    parquetwrite(graph_file, graph_table);
end

freq_labels = arrayfun(@(x) sprintf('F%1.1f',x), freqs2use, 'uni',0);
summary_table = [table(string(repmat(EEG.setname, combo_size,1)), ...
    res_chan, res_chan2, 'VariableNames',{'eegid','chan1','chan2'}) ...
    array2table(res_dwpli,'VariableNames',freq_labels)];

% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});

% Outputs:
note(sprintf('Completing function and assigning outputs.'));

EEG.vhtp.eeg_htpCalcPhaseLag.summary_table =  summary_table;
EEG.vhtp.eeg_htpCalcPhaseLag.qi_table = qi_table;
results = EEG.vhtp.eeg_htpCalcPhaseLag;

    function [bcm, G]  = create_bcm( chan1_list, chan2_list, weights, chan_labels )
        % create brain connectivity matrix using matlab graph objects
        % input are two columns representing nodes pairs, weight column, and labels
        % output include a numerical matrix but also MATLAB graph object (G)
        G = graph( chan1_list, chan2_list, weights, chan_labels );
        bcm = full(adjacency(G, 'weighted'));
    end
end




