function [EEG, results] = eeg_htpGraphPhaseBcm(EEG, varargin)
% Description:  Conduct phase-based (DWPLI, IPSC, etc.) and amplitude-based (AEC) measures
% ShortTitle: Phase-based and amplitude connectivity analysis
% Category: Analysis
% Tags: Connectivity
%
% Michael X Cohen's PLI code from Chapter 26.
% AEC implementation added for amplitude envelope correlation
%
% Cohen, Mike X. Analyzing neural time series data: theory and practice.
% MIT Press 2014.

% Usage:
%    >> [ EEG, results ] = eeg_htpGraphPhaseBcm( EEG )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
% Function Specific Inputs:
%     'outputdir' - description
%     'threshold'   - thresholding type 'mediansd' implemented by default
%     for graph measures
%     'combos' - manually specify cell array of channel pairs to calculate
%     'calcGraphMeasures' - logical flag to enable/disable graph measures calculation (default: true)
% Outputs:
%     EEG       - EEGLAB Structure with modified .vhtp field
%     results   - .vhtp structure
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: ernest.pedapati@cchmc.org

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

[note] = htp_utilities();
note(sprintf('Initializing function %s', timestamp));
note(sprintf('Loading %s', EEG.filename));

% Inputs: Common across Visual HTP functions
defaultGpuOn = 0;
defaultThreshold = missing;
defaultCombos = missing;
defaultCalcGraphMeasures = false;  % Default to calculating graph measures
%defaultThreshold = 'mediansd';
defaultBandDefs = {
    'delta', 2 , 3.5;
    'theta', 3.5, 7.5;
    'alpha1', 8, 10;
    'alpha2', 10.5, 12.5;
    'beta', 13, 30;
    'gamma1', 30, 55;
    'gamma2', 65, 90;
    };

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'gpuon', defaultGpuOn, @mustBeNumericOrLogical);
addParameter(ip, 'threshold', defaultThreshold, @ischar);
addParameter(ip, 'combos', defaultCombos, @iscell);
addParameter(ip, 'bandDefs', defaultBandDefs, @iscell);
addParameter(ip, 'calcGraphMeasures', defaultCalcGraphMeasures, @mustBeNumericOrLogical);


% Confirm Dependencies for Graph Measures
% BRAPH
assert( exist('GraphWU', 'file') == 2, 'ERROR: Add Braph 1.0 Toolbox (https://github.com/softmatterlab/BRAPH) to MATLAB Path.');
% BCT
assert( exist('eigenvector_centrality_und', 'file') == 2, 'ERROR: Add Brain Connectivity Toolbox (https://github.com/brainlife/BCT) to MATLAB Path.');


% === EXPORT RESULT FILES ADDIN: 1/3 INITIALIZE  =================================

defaultUseParquet = true; defaultOutputDir = tempdir;
addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
addParameter(ip, 'useParquet', defaultUseParquet, @islogical);

% === EXPORT RESULT FILES ADDIN: 1/3 INITIALIZE  =================================


parse(ip, EEG, varargin{:});% specify some time-frequency parameters

note(sprintf('Output Dir: %s', ip.Results.outputdir));

% Create channel combos
if all(all(ismissing(ip.Results.combos)))
    combos = nchoosek({EEG.chanlocs(:).labels}', 2); % channel pairs (unique) (30*29/2)
    ncombos = nchoosek(1:EEG.nbchan, 2); % channel pairs (numerical)
else
    combos = ip.Results.combos;
    ncombos = zeros(size(combos));
    for ci = 1 : size(combos,1)
        ncombos(ci,1) = find(strcmp(combos{ci,1}, {EEG.chanlocs(:).labels}'));
        ncombos(ci,2) = find(strcmp(combos{ci,2}, {EEG.chanlocs(:).labels}'));
    end
end
note(sprintf('%d channel combos created from %d channels', length(ncombos), EEG.nbchan));

if ip.Results.gpuon
    note('GPU Assist is ON.');
    EEG.data = gpuArray(EEG.data);
else
    note('GPU Assist is OFF.');
end

% confirm that data is epoched
assert(ndims(EEG.data) == 3, 'Data must be epoched prior to function run.')

combo_left = ncombos(:,1);
combo_right = ncombos(:,2);
combo_size = size(ncombos,1);

%% Define Band Ranges
bandDefs = ip.Results.bandDefs;

note(' = Band Definitions =');
bandDisplay = @(a,b,c) note(sprintf('%s: %1.1f-%1.1f', a,b,c));
cellfun(bandDisplay, bandDefs(:,1), bandDefs(:,2), bandDefs(:,3));

% defined frequency vector
nsteps = 30;
startf = 2;
endf = 80;
frex = logspace(log10(startf), log10(endf), nsteps);
nofreqs = length(frex);

note(sprintf('Frequencies(logspace): %d to %d Hz (%d steps)', startf, endf, nsteps));

res_dwpli = zeros(combo_size, nofreqs);
res_scoh = zeros(combo_size, nofreqs);
res_aec = zeros(combo_size, nofreqs);  % Add AEC results array

res_chan = zeros(combo_size,1);
res_chan2 = zeros(combo_size,1);

srate = EEG.srate;
pnts = EEG.pnts;
trials = EEG.trials;
labels = {EEG.chanlocs.labels};

note(sprintf('EEG: srate: %d, pnts: %d, trials %d', srate,pnts,trials))

freqs2use = frex;

tic;
HasParProgress = false;
note('Starting BCM calculations (including AEC)...');
% try ppm = ParforProgressbar(combo_size); HasParProgress = true; catch, warning('Missing ParFor Progressbar'); HasParProgress = false; end
% EEG.data = double(EEG.data .* 10e9);
parfor ci = 1 : combo_size
    fprintf('CI: %d\n', ci);
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
    scoh    = zeros(length(freqs2use),EEG.pnts);
    aec     = zeros(length(freqs2use),1);  % Initialize AEC
    aec_signed = zeros(length(freqs2use),1);  % Initialize signed AEC

    for fi=1:length(freqs2use)
        % fprintf('%d', fi);
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
        % A high csd value indicates the two time domain signals tend to have high power spectral density,
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

        % compute power and cross-spectral power
        spec1 = mean(sig1.*conj(sig1),2);
        spec2 = mean(sig2.*conj(sig2),2);
        specX = abs(mean(sig1.*conj(sig2),2)).^2;

        % alternative notation for the same procedure, using the Euler-like expression: Me^ik
        %spec1 = mean(abs(sig1).^2,2);
        %spec2 = mean(abs(sig2).^2,2);
        %specX = abs(mean( abs(sig1).*abs(sig2) .* exp(1i*(angle(sig1)-angle(sig2))) ,2)).^2;

        % compute spectral coherence, using only requested time points
        scoh(fi,:) = specX ./ (spec1 .* spec2);

        % === AEC CALCULATION ===
        % Extract amplitude envelopes
        amp1 = abs(sig1);  % Amplitude envelope of channel 1
        amp2 = abs(sig2);  % Amplitude envelope of channel 2
        
        % Concatenate trials for correlation
        amp1_concat = reshape(amp1, 1, []);
        amp2_concat = reshape(amp2, 1, []);
        
        % Calculate Pearson correlation between amplitude envelopes
        % Remove NaN values if any
        valid_idx = ~isnan(amp1_concat) & ~isnan(amp2_concat);
        if sum(valid_idx) > 1
            r = corr(amp1_concat(valid_idx)', amp2_concat(valid_idx)');
            % Store both signed and unsigned versions
            aec_signed(fi) = r;  % Keep for later analysis if needed
            % For graph analysis, use absolute value to capture coupling strength
            aec(fi) = abs(r);
        else
            aec(fi) = 0;
            aec_signed(fi) = 0;
        end
        % === END AEC CALCULATION ===

    end

    res_ispc(ci,:) = mean(ispc,2);
    res_wpli(ci,:) = mean(wpli,2);
    res_dwpli(ci, :) = mean(dwpli,2);
    res_scoh(ci, :) = mean(scoh,2);
    res_aec(ci, :) = aec';  % Store AEC results
    res_chan(ci,1) = channel1;
    res_chan2(ci,1) = channel2;

 %   if HasParProgress, ppm.increment(); end
end
toc;
if HasParProgress, ppm.close; end


% create graphs for each frequency and measure
for fi = 1 : numel(frex)
    [fispc(:,:,fi)] = create_bcm( res_chan, res_chan2, res_ispc(:,fi), labels);
    [fwpli(:,:,fi)] = create_bcm( res_chan, res_chan2, res_wpli(:,fi), labels);
    [fscoh(:,:,fi)] = create_bcm( res_chan, res_chan2, res_scoh(:,fi), labels);
    [faec(:,:,fi)] = create_bcm( res_chan, res_chan2, res_aec(:,fi), labels);  % Add AEC BCM
end

tic; % .06 seconds
fispc_table = util_htpBcm2Long( fispc, labels, frex ); fispc_table = renamevars(fispc_table, "bcm_long", "ispc");
fwpli_table = util_htpBcm2Long( fwpli, labels, frex ); fwpli_table = renamevars(fwpli_table, "bcm_long", "fwpli");
fscoh_table = util_htpBcm2Long( fscoh, labels, frex ); fscoh_table = renamevars(fscoh_table, "bcm_long", "fscoh");
faec_table = util_htpBcm2Long( faec, labels, frex ); faec_table = renamevars(faec_table, "bcm_long", "aec");  % Add AEC table

% Join all tables including AEC
bconn_table2 = horzcat( table(repmat(EEG.setname, [height(fispc_table) 1]), 'VariableNames',{'eegid'}), ...
    innerjoin(fispc_table, innerjoin(fwpli_table, innerjoin(fscoh_table, faec_table))));
toc;

% Thresholding and Graph Measures (Optional)
if ip.Results.calcGraphMeasures
    note('Graph measures calculation is ENABLED.');
    
    if ~ismissing(ip.Results.threshold)
        % based on cohen ANTS Chapter 31
        switch ip.Results.threshold % per frequency
            case 'mediansd'  % each frequency thresholded separately
                [t_fwpli, tvec1] = threshold_bcm_mediansd( fwpli );
                [t_fispc, tvec2] = threshold_bcm_mediansd( fispc );
                [t_fscoh, tvec3] = threshold_bcm_mediansd( fscoh );
                [t_faec, tvec4] = threshold_bcm_mediansd( faec );  % Add AEC thresholding
                note('Calculating thresholded graph measures ...');
                [~, wpli_graph] = eeg_htpGraphBraphWU(EEG, t_fwpli, labels, frex);
                [~, ispc_graph] = eeg_htpGraphBraphWU(EEG, t_fispc, labels, frex);
                [~, scoh_graph] = eeg_htpGraphBraphWU(EEG, t_fscoh, labels, frex);
                [~, aec_graph] = eeg_htpGraphBraphWU(EEG, t_faec, labels, frex);  % Add AEC graph
        end
    else
        threshold_vector = repmat(0,length(frex),1);
        note('Calculating graph measures ...');
        [~, wpli_graph] = eeg_htpGraphBraphWU(EEG, fwpli, labels, frex);
        [~, ispc_graph] = eeg_htpGraphBraphWU(EEG, fispc, labels, frex);
        [~, scoh_graph] = eeg_htpGraphBraphWU(EEG, fscoh, labels, frex);
        [~, aec_graph] = eeg_htpGraphBraphWU(EEG, faec, labels, frex);  % Add AEC graph
    end

    wpli_graph_table = wpli_graph.summary_table;
    ispc_graph_table = ispc_graph.summary_table;
    scoh_graph_table = scoh_graph.summary_table;
    aec_graph_table = aec_graph.summary_table;  % Add AEC graph table

    wpli_graph_table.Properties.VariableNames =strrep(wpli_graph_table.Properties.VariableNames, 'value', 'wpli');
    ispc_graph_table.Properties.VariableNames =strrep(ispc_graph_table.Properties.VariableNames, 'value', 'ispc');
    scoh_graph_table.Properties.VariableNames =strrep(scoh_graph_table.Properties.VariableNames, 'value', 'soch');
    aec_graph_table.Properties.VariableNames =strrep(aec_graph_table.Properties.VariableNames, 'value', 'aec');  % Add AEC rename

    graph_table_tmp1 = innerjoin(wpli_graph_table, ispc_graph_table);
    graph_table_tmp2 = innerjoin(graph_table_tmp1, scoh_graph_table);
    graph_table = innerjoin(graph_table_tmp2, aec_graph_table);  % Join all tables including AEC
else
    note('Graph measures calculation is DISABLED.');
    graph_table = table();  % Empty table when graph measures are disabled
end

% === EXPORT RESULT FILES ADDIN: 2/3 TARGET WRITE ================================
% Result File Management (create subfolder with function name)
% template: resultfile = EEG_to_resultfile(EEG, results_dir, file_extenstion);
try
    file_extension = target_resultfile( ip.Results.useParquet );

    % target files
    resultfile_bcm  = EEG_to_resultfile(EEG, ip.Results.outputdir, ['bcm.' file_extension]);

    % write BCM file (always created)
    writeresults( bconn_table2, resultfile_bcm, ip.Results.useParquet );
    note(sprintf('Tabulating brain connectivity matrix (BCM) calculations ...'));
    note(sprintf('Saved as %s.\n', resultfile_bcm));

    % write graph file only if graph measures were calculated
    if ip.Results.calcGraphMeasures && ~isempty(graph_table)
        resultfile_graph = EEG_to_resultfile(EEG, ip.Results.outputdir, ['graph.' file_extension]);
        writeresults( graph_table, resultfile_graph, ip.Results.useParquet );
        note(sprintf('Tabulating graph measures ...'));
        note(sprintf('Saved as %s.\n', resultfile_graph));
    end

catch
    error('Error creating output files.');
end
% === EXPORT RESULT FILES ADDIN: 2/3 TARGET WRITE ================================

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});

% Outputs:
note(sprintf('Completing function and assigning outputs.'));

EEG.vhtp.eeg_htpGraphPhaseBcm.summary_table =  bconn_table2;
EEG.vhtp.eeg_htpGraphPhaseBcm.graph_table =  graph_table;

EEG.vhtp.eeg_htpGraphPhaseBcm.qi_table = qi_table;
results = EEG.vhtp.eeg_htpGraphPhaseBcm;

if ip.Results.gpuon
    note('Reseting GPU');
    reset(gpuDevice);
end

    function [bcm, G]  = create_bcm( chan1_list, chan2_list, weights, chan_labels )
        % create brain connectivity matrix using matlab graph objects
        % input are two columns representing nodes pairs, weight column, and labels
        % output include a numerical matrix but also MATLAB graph object (G)
        G = graph( chan1_list, chan2_list, weights, chan_labels );
        bcm = full(adjacency(G, 'weighted'));
    end

    function [tbcm, tvec] = threshold_bcm_mediansd( bcm )
        for fi = 1 : size( bcm, 3 ) % Brain Connectivity Matrix, freq. dimension
            bcm_by_freq = bcm(:,:,fi);
            bcm_threshold =  std(reshape(bcm_by_freq,1,[])) + median(reshape(bcm_by_freq,1,[]));
            bcm_by_freq(bcm_by_freq < bcm_threshold) = 0;
            thres_bcm(:,:,fi) = bcm_by_freq;
            fprintf('BCM Median+SD %2.2f Hz Threshold: %2.2f\n', frex(fi), bcm_threshold);
            threshold_vector(fi) = bcm_threshold;
        end

        tbcm = thres_bcm;
        tvec = threshold_vector;
    end

% === EXPORT RESULT FILES ADDIN: 3/3 FUNCTIONS ===================================

    function resultfile = EEG_to_resultfile(EEG, results_dir, file_extention)

        file_name = EEG.filename;
        folder_name = fullfile(results_dir, mfilename);

        % check and create output directory
        if ~exist(folder_name, 'dir')
            mkdir(folder_name);
        end

        % get basename of file
        [~, basename, ~] = fileparts(file_name);

        % create result file by adding new extension to basename
        resultfile = fullfile(folder_name, [basename, '_', mfilename, '_', file_extention]);

    end

    function file_ext = target_resultfile( useParquet )
        if useParquet, file_ext = 'parquet';
        else, file_ext = 'csv'; end
    end

    function writeresults( result_table, result_file, useParquet )
        if useParquet
            parquetwrite(result_file, result_table);
        else
            writetable(result_table, result_file);
        end
    end

% === RESULT FILES ADDIN: 3/3 FUNCTIONS ===================================

% === UTILITIES ADDIN: 2/2 ================================================
    function note = htp_utilities()
        note        = @(msg) fprintf('%s: %s\n', mfilename, msg );
    end
% === UTILITIES ADDIN: 2/2 ================================================
end