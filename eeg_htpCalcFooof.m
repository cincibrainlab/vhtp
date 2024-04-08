function [EEG, opts] = eeg_htpCalcFooof(EEG, varargin)
% eeg_htpCalcFooof - Function to calculate the FOOOF (Fitting Oscillations & One Over F) model on EEG data.
%                    Wrapper around Brainstorm implementation of MATLAB FOOOF
%
% Syntax:  [EEG, opts] = eeg_htpCalcFooof(EEG, varargin)
%
% Inputs:
%    EEG - EEGLAB data structure containing the EEG data
%    varargin - Optional parameters as key-value pairs:
%               'spectrogram_freqs' - Frequency range for the spectrogram (default: [1 55])
%               'use_components' - Boolean flag to indicate whether to use components in the calculation (default: false)
%               'save_to_csv' - Boolean flag to indicate whether to save the results to a CSV file (default: true)
            %    'ic_assessment' - Boolean flag to indicate whether to calculate only the aperiodic oscillation exponent (default: false)
            %    'freq_resolution' - Frequency resolution for the FOOOF model (default: 0.1)
            %    'save_fooof_img' - Boolean flag to indicate whether to save FOOOF model images (default: true)
            %    'parallel' - Boolean flag to indicate whether to run the calculations in parallel (default: false)
            %    'normalize_psd' - Boolean flag to indicate whether to normalize the power spectral density (default: false)
%
% Outputs:
%    EEG - EEGLAB data structure with added FOOOF results
%    opts - Options structure containing spectrogram_freqs, use_components, save_to_csv
%
% Example:
%    [EEG, opts] = eeg_htpCalcFooof(EEG, 'spectrogram_freqs', [1 45], 'use_components', true, 'save_to_csv', true);
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% Authors: Ernest Pedapati, Makoto Miyakoshi

p = inputParser;
addParameter(p, 'spect_freqs', [1 55], @isnumeric);
addParameter(p, 'use_components', false, @islogical);
addParameter(p, 'freq_resolution', .1, @isnumeric);
addParameter(p, 'save_to_csv', true, @islogical);
addParameter(p, 'ic_assessment', false, @islogical);
addParameter(p, 'save_fooof_img', true, @islogical);
addParameter(p, 'parallel', true, @islogical);
addParameter(p, 'normalize_psd', false, @islogical);


parse(p, varargin{:});

opts.spect_freqs = p.Results.spect_freqs;
opts.use_components = p.Results.use_components;
opts.freq_resolution = p.Results.freq_resolution;
opts.save_to_csv = p.Results.save_to_csv;
opts.aperiodic_oscillation_exponent = p.Results.ic_assessment;
opts.save_fooof_img = p.Results.save_fooof_img;
opts.parallel = p.Results.parallel;
opts.normalize_psd = p.Results.normalize_psd;

[EEG, opts] = check_requirements(EEG, opts);
[EEG, opts] = prepare_fooof_parameters(EEG, opts);


if opts.aperiodic_oscillation_exponent   % specifically for IC classification
    opts.use_components = true;
    opts.normalize_psd = true;    % specifically for IC classification
    opts.spect_freqs(1) = 2.5;
    opts.spect_freqs(2) = 55;
    [EEG, opts] = select_data(EEG, opts);
    [EEG, opts] = computeNumComponentsOrChannels(EEG, opts);
    [EEG, opts] = calc_psd(EEG, opts);
    [EEG, opts] = component_assessment(EEG, opts);
    [EEG, opts] = save_fooof_img( EEG, opts);
else
    [EEG, opts] = select_data(EEG, opts);
    [EEG, opts] = computeNumComponentsOrChannels(EEG, opts);
    [EEG, opts] = calc_psd(EEG, opts);
    [EEG, opts] = run_fooof(EEG, opts);
    [EEG, opts] = save_to_csv(EEG, opts);
    [EEG, opts] = save_fooof_img( EEG, opts);
end

    function [EEG, opts] = check_requirements(EEG, opts)

        if ndims(EEG.data) == 3
            logMessage('warning', 'EEG data is 3D. Making it continuous.');
            EEG = eeg_epoch2continuous(EEG);
        end

        if (~isfield(EEG, 'icaact') && opts.use_components) || (opts.aperiodic_oscillation_exponent)
            logMessage('warning', 'ICA activations not found or components are required. Calculating...');
            EEG.icaact = eeg_getica(EEG);
        end

    end

    function [EEG, opts] = select_data(EEG, opts)

        if opts.use_components
            data = EEG.icaact;
        else
            data = EEG.data;
        end
        opts.data = data;

    end

    function [EEG, opts] = calc_psd(EEG, opts)
        % calc_psd - Calculate the power spectral density (PSD) for EEG data

        % Initialize variables
        spect_freqs_start = opts.spect_freqs(1);
        spect_freqs_end = opts.spect_freqs(2);
        freqBins = spect_freqs_start:opts.freq_resolution:spect_freqs_end;
        psd = zeros(length(freqBins), floor(size(opts.data, 2) / 2), size(opts.data, 1));

        % Compute short-term Fourier Transform for 1-s window, 50% overlap, 1-55 Hz, 0.1 Hz bin.
        for idx = 1:size(opts.data, 1)

            if idx == 1
                [~, freqList, timeList, firstPSD] = spectrogram(opts.data(idx,:), EEG.srate, round(EEG.srate/2), freqBins, EEG.srate);
                psd = zeros(length(freqList), size(firstPSD,2), size(opts.data,1));
                psd(:,:,idx) = firstPSD;
            else
                [~, ~, ~, psd(:,:,idx)] = spectrogram(opts.data(idx,:), EEG.srate, round(EEG.srate/2), freqBins, EEG.srate);
            end

        end

        % Store PSD in EEG structure
        opts.psd = psd;
        opts.psdFreqs =  double(freqList);
        opts.freq_res  = mean(diff(opts.psdFreqs));
        opts.psdTimes = timeList;

        % Return updated EEG structure
        return;
    end

    function [EEG, opts] = computeNumComponentsOrChannels(EEG, opts)

        if opts.use_components
            logMessage('info', 'Computing component number.');
            opts.no_of_components = size(EEG.icawinv, 2);
        else
            logMessage('info', 'Computing channel number.');
            opts.no_of_components = size(EEG.data, 1);
        end

    end

    function [EEG, opts] = prepare_fooof_parameters(EEG, opts)
        % prepare_fooof_parameters - Prepares the parameters for FOOOF analysis

        % From original FOOOF documents.
        %
        %       Iteratively fit peaks to flattened spectrum.
        %
        %       Parameters
        %       ----------
        %       freqs : 1xn array
        %           Frequency values for the power spectrum, in linear scale.
        %       flat_iter : 1xn array
        %           Flattened (aperiodic removed) power spectrum.
        %       max_n_peaks : double
        %           Maximum number of gaussians to fit within the spectrum.
        %       peak_threshold : double
        %           Threshold (in standard deviations of noise floor) to detect a peak.
        %       min_peak_height : double
        %           Minimum height of a peak (in log10).
        %       gauss_std_limits : 1x2 double
        %           Limits to gaussian (cauchy) standard deviation (gamma) when detecting a peak.
        %       proxThresh : double
        %           Minimum distance between two peaks, in st. dev. (gamma) of peaks.
        %       peakType : {'gaussian', 'cauchy', 'both'}
        %           Which types of peaks are being fitted
        %       guess_weight : {'none', 'weak', 'strong'}
        %           Parameter to weigh initial estimates during optimization (None, Weak, or Strong)
        %       hOT : 0 or 1
        %           Defines whether to use constrained optimization, fmincon, or
        %           basic simplex, fminsearch.
        %
        %       Returns
        %       -------
        %       gaussian_params : mx3 array, where m = No. of peaks.
        %           Parameters that define the peak fit(s). Each row is a peak, as [mean, height, st. dev. (gamma)].

        % Freq are set individually for each function.
        fooof_params.freq_range          = missing;
        fooof_params.aperiodic_mode      = 'knee';  % aperiodic_mode : {'fixed', 'knee'} Defines absence or presence of knee in aperiodic component.

        %fooof_params.aperiodic_mode      = 'fixed';  % aperiodic_mode : {'fixed', 'knee'} Defines absence or presence of knee in aperiodic component.
        fooof_params.max_peaks           = 5;        % Maximum number of gaussians to fit within the spectrum.
        fooof_params.peak_threshold      = 1;        % 2 std dev: parameter for interface simplification
        fooof_params.min_peak_height     = 0;        % Minimum height of a peak (in log10).
        fooof_params.peak_width_limits   = [0.5 12]; % Values were taken from https://neuroimage.usc.edu/brainstorm/Tutorials/Fooof
        fooof_params.proximity_threshold = 0;        % Minimum distance between two peaks, in st. dev. (gamma) of peaks.
        fooof_params.peak_type           = 'best'; % {'gaussian', 'cauchy', 'best'}
        fooof_params.guess_weight        = 'weak';   % Parameter to weigh initial estimates during optimization (None, Weak, or Strong)
        fooof_params.hOT                 = 1;        % Defines whether to use constrained optimization, fmincon, or basic simplex, fminsearch.
        fooof_params.thresh_after        = true;     % Threshold after fitting always selected for Matlab (mirrors the Python FOOOF closest by removing peaks that do not satisfy a user's predetermined conditions)
        opts.fooof_params = fooof_params;

        return;
    end

    function [EEG,opts] = set_fooof_params_freqs(EEG, opts, freqs)
        % set_fooof_params_freqs - Sets the frequency range for FOOOF parameters
        % This function updates the 'freq_range' field in the FOOOF parameters
        % within the 'opts' structure with the provided frequency range.
        % Allows for custom use cases (i.e., component assessment).
        opts.fooof_params.freq_range = [freqs(1) freqs(end)];
    end

    function [EEG, opts] = run_fooof(EEG, opts)
        % run_fooof - Executes the FOOOF algorithm on EEG data
        % This function applies the FOOOF algorithm to the power spectral
        % density data contained within the EEG structure, using the parameters
        % specified in opts. Function extracted from Brainstorm.

        % Input:
        % TF   : Power spectral density (in microV^2, but could be in 10*log10 dB?)
        % Freqs: Frequency bins for TF. Must have the same length as TF.
        % opt  : Options. See below for a working example.
        % hOT  : [0|1] Defines whether to use constrained optimization, fmincon, or basic simplex, fminsearch.


        psd = squeeze(mean(opts.psd,2));
        [~,opts] = set_fooof_params_freqs(EEG, opts, [opts.psdFreqs(1) opts.psdFreqs(end)]);
        Freqs = double(opts.psdFreqs);
        hOT = opts.fooof_params.hOT;
        opt = opts.fooof_params;

        if size(Freqs,1)>size(Freqs,2)
            Freqs = Freqs';
        end

        opts.FOOOF_results = struct();
        opts.FOOOF_results.FOOOF_dimensions      = {'mean', 'height', 'std (gamma)'};

        for idx = 1:size(psd,2)

            % Extract current PSD slice.
            TF_raw = double(squeeze(psd(:,idx))); % TF MUST be a row vector.

            % Normalize PSD if required
            if opts.normalize_psd
                TF_z = zscore(TF_raw);
                TF = 10.^(TF_z/10);
            else
                TF = TF_raw;
            end
            

            if size(TF,1)>size(TF,2)
                TF = TF';
            end

            [fooofFreqs, fooof_slice] = matlab_FOOOF(TF, Freqs, opt, hOT);
            fooof_slice.raw_psd = TF_raw';
            fooof_slice.raw_psd_zmv = TF';
            % Store FOOOF results in EEG structure.
            fooof_slice.frequencies = fooofFreqs;
            
            fooof_fields = fieldnames(fooof_slice);
            
            for fn = 1 : numel(fooof_fields)
                opts.FOOOF_results.channel(idx).(fooof_fields{fn}) = fooof_slice.(fooof_fields{fn});
            end
        end

        % The following code block initializes an empty table to store FOOOF results for each channel.
        % This table will include the filename, channel number, frequencies, aperiodic fit, raw spectrum the FOOOFed spectrum, and peak fit.

        % The next code block constructs a summary table with rows for each channel and columns for various FOOOF metrics.
        % This includes aperiodic parameters, peak parameters, peak types, error, r-squared, the FOOOFed spectrum, peak fit, and aperiodic fit.

        % Initialize an empty table outside the loop
        fooof_table = table();

        % Loop through each channel
        for ch = 1:length(opts.FOOOF_results.channel)
            % Extract data from the current channel's fooof struct
            fooofData = opts.FOOOF_results.channel(ch);

            % Create a table for the current channel's data
            curr_table = table(repmat({EEG.filename}, numel(fooofData.frequencies), 1), ...
                repmat(ch, numel(fooofData.frequencies), 1), ...
                fooofData.frequencies', ...
                fooofData.ap_fit', ...
                fooofData.fooofed_spectrum', ...
                fooofData.peak_fit', ...
                'VariableNames', {'Filename', 'Channel', 'Frequencies', 'AP_Fit', 'Fooofed_Spectrum', 'Peak_Fit'});

            % Concatenate the current table with the accumulated table
            fooof_table = [fooof_table; curr_table];
        end

        opts.FOOOF_results.FOOOF_fit = fooof_table;

        % Loop through each channel
        new_rows = {};

        for ch = 1:length(opts.FOOOF_results.channel)
            % Extract data from the current channel's fooof struct
            fooofData = opts.FOOOF_results.channel(ch);

            summary_fields = {'aperiodic_params','peak_params','peak_types','error','r_squared', 'fooofed_spectrum', 'peak_fit', 'ap_fit'};


            for n_fields = 1 : numel(summary_fields)

                switch(summary_fields{n_fields})
                    case 'aperiodic_params'
                        dat = fooofData.('aperiodic_params');
                        for ni = 1 : numel(dat)
                            key = sprintf('aperiodic_params_%d', ni);
                            value = dat(ni);
                            row = {ch,key,value};
                            new_rows = [new_rows;row];
                        end
                    case 'peak_params'
                        dat = fooofData.('peak_params');
                        for ni = 1 : size(dat,1)
                            row_a = dat(ni,:);

                            key = sprintf('peak_params_%d_mean', ni);
                            value = row_a(1);
                            row1 = {ch,key,value};

                            key = sprintf('peak_params_%d_height', ni);
                            value = row_a(2);
                            row2 = {ch,key,value};

                            key = sprintf('peak_params_%d_std_gamma', ni);
                            value = row_a(3);
                            row3 = {ch,key,value};

                            row = [row1;row2;row3];
                            new_rows = [new_rows;row];

                        end

                    case 'peak_types'
                        dat = fooofData.('peak_types');
                        key  = 'peak_types';
                        value = dat;
                        row = {ch,key,value};
                        new_rows = [new_rows;row];

                    case 'error'
                        dat = fooofData.('error');
                        key  = 'error';
                        value = dat;
                        row = {ch,key,value};
                        new_rows = [new_rows;row];

                    case 'r_squared'
                        dat = fooofData.('r_squared');
                        key  = 'r_squared';
                        value = dat;
                        row = {ch,key,value};
                        new_rows = [new_rows;row];

                end

            end

        end

        summary_table_tmp = cell2table(new_rows, 'VariableNames', {'chan','key','value'});

        opts.FOOOF_results.summary_table = [table(repmat({EEG.filename}, height(summary_table_tmp), 1), 'VariableNames', {'filename'}) summary_table_tmp];

        % Add results to EEG structure
        EEG.etc.FOOOF_results = opts.FOOOF_results;
        % Return updated EEG structure
        return;
    end

    function [EEG, opts] = component_assessment(EEG, opts)
        % component_assessment - Assess the components of EEG data
        % This function performs an assessment of the EEG data components
        % based on the options provided in opts. Specifically for artifact removal.
        % Worked on in consultation with Makoto Miyakoshi.

        lower_freq_limit = opts.spect_freqs(1);
        upper_freq_limit = opts.spect_freqs(2);
        no_of_components = opts.no_of_components;

        [~,opts] = set_fooof_params_freqs(EEG, opts, [lower_freq_limit upper_freq_limit]);
 
        [EEG, opts] = run_fooof(EEG, opts);


        [maxProb, classIdx] = max(EEG.etc.ic_classification.ICLabel.classifications, [], 2);


        % Loop through each channel
        new_rows = {};
        
        summary_table = EEG.etc.FOOOF_results.summary_table;

        for ch = 1:no_of_components

            key = sprintf('iclabel_max');
            value = sprintf('%1.3f', maxProb(ch));
            key2 = sprintf('iclabel_class');
            value2 = sprintf('%d', classIdx(ch));
            key3 = sprintf('iclabel_label');
            value3 = sprintf('%s', EEG.etc.ic_classification.ICLabel.classes{classIdx(ch)});
            row = {EEG.filename, ch,key,value; ...
                EEG.filename, ch, key2, value2;
                EEG.filename, ch, key3, value3};
            new_rows = [new_rows;row];

        end

        EEG.etc.FOOOF_results.summary_table = [summary_table; 
            cell2table(new_rows, 'VariableNames', summary_table.Properties.VariableNames)];

    end


    function [EEG, opts] = save_fooof_img( EEG, opts)
    % save_fooof_img - Saves FOOOF images for EEG data components or channels
    % This function checks if the user has opted to save FOOOF images and
    % proceeds to save the images either in parallel or sequentially based on
    % the user's settings and system capabilities.
    
        fg = EEG.etc.FOOOF_results.channel;
        no_of_components = opts.no_of_components;

        handle_create_fooof_plot = @create_fooof_plot;
        
        if(opts.save_fooof_img)
            % Check if parallel computing toolbox is available and opts.parallel is true
            if license('test', 'Distrib_Computing_Toolbox') && opts.parallel
                logMessage('info', sprintf('Saving FOOOF image for IC in parallel'));
                fooof_images = cell(no_of_components, 1);
                parfor ic = 1 : no_of_components
                    fooof_images{ic} = feval(handle_create_fooof_plot, fg, ic); %#ok<FVAL>          
                end
                for ic = 1:no_of_components
                    EEG.etc.FOOOF_results.channel(ic).fooof_img = fooof_images{ic};
                end
            else
                logMessage('info', sprintf('Saving FOOOF image for IC sequentially'));
                for ic = 1 : no_of_components
                    EEG.etc.FOOOF_results.channel(ic).fooof_img = feval(handle_create_fooof_plot,fg, ic); %#ok<FVAL>
                end
            end
        else
            [fg(1:no_of_components).fooof_img] = deal(missing);
        end

    end
     
     function curfig_matrix = create_fooof_plot( fg, ic)
         % create_fooof_plot - Generates a FOOOF plot for a given independent component or channel.
         % This function creates a figure of the FOOOF model fit for the power
         % spectral density of a specified independent component or channel.

         logMessage('info', sprintf('Saving FOOOF image for IC %d', ic));
         % Set the size of the figure
         figWidth = 800; % Width in pixels
         figHeight = 700; % Height in pixels
         curfig = figure('visible', 'off', 'Position', [100, 100, figWidth, figHeight]);
%                 curfig = figure('visible', 'off');

         %curfig = figure('visible', 'on');
        set(gcf,'color', [0.9300 0.9600 1.0000]);

        lineHandle2 = plot(fg(ic).frequencies, 10*log10(fg(ic).fooofed_spectrum), 'linewidth', 2, 'color', [1 0 0 0.5]);  hold on;
        lineHandle3 = plot(fg(ic).frequencies, 10*log10(fg(ic).ap_fit),  'linewidth', 2, 'color', [1 0 0], 'LineStyle', '--');
        lineHandle1 = plot(fg(ic).frequencies, 10*log10(fg(ic).raw_psd_zmv),   'linewidth', 6, 'color', [0 0 0 0.5]);
        title(sprintf('IC %d: PSD and FOOOF Estimate', ic))
        xlabel('Frequency (Hz)', 'fontsize', 32, 'fontweight', 'normal');
        ylabel('Power 10*log_{10}(uV^2/Hz)', 'fontsize', 32, 'fontweight', 'normal');
        set(gca, 'fontsize', 32);
        axis on;
        box on;
        grid on;
        legend([lineHandle1 lineHandle2 lineHandle3], {'Raw' 'Modeled' 'Exponent'})

        % Set the figure resolution
        set(curfig, 'PaperPositionMode', 'auto');
        set(curfig, 'PaperUnits', 'inches');
        set(curfig, 'PaperPosition', [0, 0, figWidth/100, figHeight/100]); % Convert pixels to inches for PaperPosition

%        set(curfig, 'PaperPositionMode', 'auto');

        curfig_matrix = getframe(curfig);
        curfig_matrix = frame2im(curfig_matrix);
              
    end

    function [EEG, opts] = save_to_csv(EEG, opts)
        % save_to_csv - Saves FOOOF results and summary to CSV files.
        if opts.save_to_csv
            % Save FOOOF results to CSV file.
            subdir = fullfile(EEG.filepath, mfilename);
            if ~exist(subdir, 'dir')
                mkdir(subdir);
            end
            csv_filename = fullfile(subdir, [EEG.filename(1:end-4) '_fooof_fit.csv']);
            writetable(opts.FOOOF_results.FOOOF_fit, csv_filename);

            % Save FOOOF summary table to CSV file.
            csv_filename = fullfile(subdir, [EEG.filename(1:end-4) '_fooof_summary.csv']);
            writetable(opts.FOOOF_results.summary_table, csv_filename);
        end

        % Return updated EEG structure
        return;
    end
  
    function logMessage(type, message)
        switch type
            case 'info'
                fprintf('[INFO]: %s\n', message);
            case 'warning'
                fprintf('[WARNING]: %s\n', message);
            case 'error'
                error('[ERROR]: %s\n', message);
            otherwise
                fprintf('[UNKNOWN]: %s\n', message);
        end
    end


end



%% ===================================================================================
%  ===== MATLAB FOOOF ================================================================
%  ===================================================================================

%% ===== MATLAB STANDALONE FOOOF =====
%% Brainstorm coded by Luc Wilson and Francois Tadel.
%% Adapated for MATLAB by Ernest Pedapati and Makoto Miyakoshi.

% Input:
%        TF   : Power spectral density (in microV^2, but could be in 10*log10 dB?)
%        Freqs: Frequency bins for TF. Must have the same length as TF.
%        opt  : Options. See below for a working example.
%        hOT  : [0|1] Defines whether to use constrained optimization, fmincon, or basic simplex, fminsearch.
%
%           opt =
%
%           struct with fields:
%
%                      freq_range: [1 45]
%                  aperiodic_mode: 'fixed'
%                       max_peaks: 5
%                  peak_threshold: 2
%                 min_peak_height: 0
%               peak_width_limits: [0.5000 12]
%             proximity_threshold: 0
%                       peak_type: 'gaussian'
%                    guess_weight: 'weak'
%                    thresh_after: 1
%
%
%           The list below is stripped from original FOOOF, process_fooof() line 844 and slightly modified.
%
%           Parameters
%           ----------
%           freqs : 1xn array
%               Frequency values for the power spectrum, in linear scale.
%           flat_iter : 1xn array
%               Flattened (aperiodic removed) power spectrum.
%           max_n_peaks : double
%               Maximum number of gaussians to fit within the spectrum.
%           peak_threshold : double
%               Threshold (in standard deviations of noise floor) to detect a peak.
%           min_peak_height : double
%               Minimum height of a peak (in log10).
%           gauss_std_limits : 1x2 double
%               Limits to gaussian (cauchy) standard deviation (gamma) when detecting a peak.
%           proxThresh : double
%               Minimum distance between two peaks, in st. dev. (gamma) of peaks.
%           peakType : {'gaussian', 'cauchy', 'both'}
%               Which types of peaks are being fitted
%           guess_weight : {'none', 'weak', 'strong'}
%               Parameter to weigh initial estimates during optimization (None, Weak, or Strong)
%
% Output:
%         fs: Same as input Freqs.
%         fg: Contains the informaiton shown in the following example.
%
%             aperiodic_params: [-0.4315 1.5987]
%                  peak_params: [4×3 double]     % Each row is a peak, as [mean, height, st. dev. (gamma)].
%                   peak_types: 'gaussian'
%                       ap_fit: [1×441 double]   % FOOOF-fitted background slope.
%             fooofed_spectrum: [1×441 double]   % FOOOF-approximated PSD.
%                     peak_fit: [1×441 double]   % FOOOF-fitted peaks.
%                        error: 0.0042
%                    r_squared: 0.9907
%
%    REFERENCE: Please cite the original algorithm:
%    Donoghue T, Haller M, Peterson E, Varma P, Sebastian P, Gao R, Noto T,
%    Lara AH, Wallis JD, Knight RT, Shestyuk A, Voytek B. Parameterizing
%    neural power spectra into periodic and aperiodic components.
%    Nature Neuroscience (in press)


function [fs, fg] = matlab_FOOOF(TF, Freqs, opt, hOT)
% Find all frequency values within user limits
fMask = round(Freqs,1) >= opt.freq_range(1) & Freqs <= opt.freq_range(2);
fs = Freqs(fMask);
spec = log10(squeeze(TF(:,fMask))); % extract log spectra
nChan = size(TF,1);
%if nChan == 1, spec = spec'; end
% Initalize FOOOF structs
fg(nChan) = struct(...
    'aperiodic_params', [],...
    'peak_params',      [],...
    'peak_types',       '',...
    'ap_fit',           [],...
    'fooofed_spectrum', [],...
    'peak_fit',         [],...
    'error',            [],...
    'r_squared',        []);
% Iterate across channels
for chan = 1:nChan
    %bst_progress('set', bst_round(chan / nChan,2) * 100);
    % Fit aperiodic
    aperiodic_pars = robust_ap_fit(fs, spec(chan,:), opt.aperiodic_mode);
    % Remove aperiodic
    flat_spec = flatten_spectrum(fs, spec(chan,:), aperiodic_pars, opt.aperiodic_mode);
    % Fit peaks
    [peak_pars, peak_function] = fit_peaks(fs, flat_spec, opt.max_peaks, opt.peak_threshold, opt.min_peak_height, ...
        opt.peak_width_limits/2, opt.proximity_threshold, opt.peak_type, opt.guess_weight,hOT);
    if opt.thresh_after && ~hOT  % Check thresholding requirements are met for unbounded optimization
        peak_pars(peak_pars(:,2) < opt.min_peak_height,:)     = []; % remove peaks shorter than limit
        peak_pars(peak_pars(:,3) < opt.peak_width_limits(1)/2,:)  = []; % remove peaks narrower than limit
        peak_pars(peak_pars(:,3) > opt.peak_width_limits(2)/2,:)  = []; % remove peaks broader than limit
        peak_pars = drop_peak_cf(peak_pars, opt.proximity_threshold, opt.freq_range); % remove peaks outside frequency limits
        peak_pars(peak_pars(:,1) < 0,:) = []; % remove peaks with a centre frequency less than zero (bypass drop_peak_cf)
        peak_pars = drop_peak_overlap(peak_pars, opt.proximity_threshold); % remove smallest of two peaks fit too closely
    end
    % Refit aperiodic
    aperiodic = spec(chan,:);
    for peak = 1:size(peak_pars,1)
        aperiodic = aperiodic - peak_function(fs,peak_pars(peak,1), peak_pars(peak,2), peak_pars(peak,3));
    end
    aperiodic_pars = simple_ap_fit(fs, aperiodic, opt.aperiodic_mode);
    % Generate model fit
    ap_fit = gen_aperiodic(fs, aperiodic_pars, opt.aperiodic_mode);
    model_fit = ap_fit;
    for peak = 1:size(peak_pars,1)
        model_fit = model_fit + peak_function(fs,peak_pars(peak,1),...
            peak_pars(peak,2),peak_pars(peak,3));
    end
    % Calculate model error
    MSE = sum((spec(chan,:) - model_fit).^2)/length(model_fit);
    rsq_tmp = corrcoef(spec(chan,:),model_fit).^2;
    % Return FOOOF results
    aperiodic_pars(2) = abs(aperiodic_pars(2));
    fg(chan).aperiodic_params = aperiodic_pars;
    fg(chan).peak_params      = peak_pars;
    fg(chan).peak_types       = func2str(peak_function);
    fg(chan).ap_fit           = 10.^ap_fit;
    fg(chan).fooofed_spectrum = 10.^model_fit;
    fg(chan).peak_fit         = 10.^(model_fit-ap_fit);
    fg(chan).error            = MSE;
    fg(chan).r_squared        = rsq_tmp(2);
    % figure; plot(fs', [fg(chan).ap_fit', fg(chan).peak_fit', fg(chan).fooofed_spectrum'])
end
end


%%
function varargout = process_fooof(varargin)
% PROCESS_FOOOF: Applies the "Fitting Oscillations and One Over F" algorithm on a Welch's PSD
%
% REFERENCE: Please cite the original algorithm:
%    Donoghue T, Haller M, Peterson E, Varma P, Sebastian P, Gao R, Noto T,
%    Lara AH, Wallis JD, Knight RT, Shestyuk A, Voytek B. Parameterizing
%    neural power spectra into periodic and aperiodic components.
%    Nature Neuroscience (in press)

% @=============================================================================
% This function is part of the Brainstorm software:
% https://urldefense.proofpoint.com/v2/url?u=https-3A__neuroimage.usc.edu_brainstorm&d=DwIGAg&c=-35OiAkTchMrZOngvJPOeA&r=pyiMpJA6aQ3IKcfd-jIW1kWlr8b1b2ssGmoavJHHJ7Q&m=qZvaYhmZTctdkdZJOkejKfqdE2SmYP5GTWXIMt6Ks6I&s=b0ZSIJQhPATmwH4HutwXwcmvOBtvFz7mNNYLhHYyZJs&e=
%
% Copyright (c)2000-2020 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at https://urldefense.proofpoint.com/v2/url?u=http-3A__www.gnu.org_copyleft_gpl.html&d=DwIGAg&c=-35OiAkTchMrZOngvJPOeA&r=pyiMpJA6aQ3IKcfd-jIW1kWlr8b1b2ssGmoavJHHJ7Q&m=qZvaYhmZTctdkdZJOkejKfqdE2SmYP5GTWXIMt6Ks6I&s=cD20JwGQ4YfIqMWT9Wi-KOCXKX7lKjvzJsALU7WupV4&e= .
%
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Luc Wilson, Francois Tadel, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
% Description the process
sProcess.Comment     = 'FOOOF: Fitting oscillations and 1/f';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = 'Frequency';
sProcess.Index       = 503;
sProcess.Description = 'https://urldefense.proofpoint.com/v2/url?u=https-3A__neuroimage.usc.edu_brainstorm_Tutorials_Fooof&d=DwIGAg&c=-35OiAkTchMrZOngvJPOeA&r=pyiMpJA6aQ3IKcfd-jIW1kWlr8b1b2ssGmoavJHHJ7Q&m=qZvaYhmZTctdkdZJOkejKfqdE2SmYP5GTWXIMt6Ks6I&s=4K92yk6_YzeCa1OXQTTf50nJsAySqNJfXg7lmq4jc0U&e= ';
% Definition of the input accepted by this process
sProcess.InputTypes  = {'timefreq'};
sProcess.OutputTypes = {'timefreq'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 1;
sProcess.isSeparator = 1;
% Definition of the options
% === FOOOF TYPE
sProcess.options.implementation.Comment = {'Matlab', 'Python 3 (3.7 recommended)', 'FOOOF implementation:'; 'matlab', 'python', ''};
sProcess.options.implementation.Type    = 'radio_linelabel';
sProcess.options.implementation.Value   = 'matlab';
sProcess.options.implementation.Controller.matlab = 'Matlab';
sProcess.options.implementation.Controller.python = 'Python';
% === FREQUENCY RANGE
sProcess.options.freqrange.Comment = 'Frequency range for analysis: ';
sProcess.options.freqrange.Type    = 'freqrange_static';   % 'freqrange'
sProcess.options.freqrange.Value   = {[1 40], 'Hz', 1};
% === PEAK TYPE
sProcess.options.peaktype.Comment = {'Gaussian', 'Cauchy*', 'Best of both* (* experimental)', 'Peak model:'; 'gaussian', 'cauchy', 'best', ''};
sProcess.options.peaktype.Type    = 'radio_linelabel';
sProcess.options.peaktype.Value   = 'gaussian';
sProcess.options.peaktype.Class   = 'Matlab';
% === PEAK WIDTH LIMITS
sProcess.options.peakwidth.Comment = 'Peak width limits (default=[0.5-12]): ';
sProcess.options.peakwidth.Type    = 'freqrange_static';
sProcess.options.peakwidth.Value   = {[0.5 12], 'Hz', 1};
% === MAX PEAKS
sProcess.options.maxpeaks.Comment = 'Maximum number of peaks (default=3): ';
sProcess.options.maxpeaks.Type    = 'value';
sProcess.options.maxpeaks.Value   = {3, '', 0};
% === MEAN PEAK HEIGHT
sProcess.options.minpeakheight.Comment = 'Minimum peak height (default=3): ';
sProcess.options.minpeakheight.Type    = 'value';
sProcess.options.minpeakheight.Value   = {3, 'dB', 1};
% === PROXIMITY THRESHOLD
sProcess.options.proxthresh.Comment = 'Proximity threshold (default=2): ';
sProcess.options.proxthresh.Type    = 'value';
sProcess.options.proxthresh.Value   = {2, 'stdev of peak model', 1};
sProcess.options.proxthresh.Class   = 'Matlab';
% === APERIODIC MODE
sProcess.options.apermode.Comment = {'Fixed', 'Knee', 'Aperiodic mode (default=fixed):'; 'fixed', 'knee', ''};
sProcess.options.apermode.Type    = 'radio_linelabel';
sProcess.options.apermode.Value   = 'fixed';
% === GUESS WEIGHT
sProcess.options.guessweight.Comment = {'None', 'Weak', 'Strong', 'Guess weight (default=none):'; 'none', 'weak', 'strong', ''};
sProcess.options.guessweight.Type    = 'radio_linelabel';
sProcess.options.guessweight.Value   = 'none';
sProcess.options.guessweight.Class   = 'Matlab';

% === SORT PEAKS TYPE
sProcess.options.sorttype.Comment = {'Peak parameters', 'Frequency bands', 'Sort peaks using:'; 'param', 'band', ''};
sProcess.options.sorttype.Type    = 'radio_linelabel';
sProcess.options.sorttype.Value   = 'param';
sProcess.options.sorttype.Controller.param = 'Param';
sProcess.options.sorttype.Controller.band = 'Band';
sProcess.options.sorttype.Group   = 'output';
% === SORT PEAKS PARAM
sProcess.options.sortparam.Comment = {'Frequency', 'Amplitude', 'Std dev.', 'Sort by peak...'; 'frequency', 'amplitude', 'std', ''};
sProcess.options.sortparam.Type    = 'radio_linelabel';
sProcess.options.sortparam.Value   = 'frequency';
sProcess.options.sortparam.Class   = 'Param';
sProcess.options.sortparam.Group   = 'output';
% === SORT FREQ BANDS
DefaultFreqBands = bst_get('DefaultFreqBands');
sProcess.options.sortbands.Comment = '';
sProcess.options.sortbands.Type    = 'groupbands';
sProcess.options.sortbands.Value   = DefaultFreqBands(:,1:2);
sProcess.options.sortbands.Class   = 'Band';
sProcess.options.sortbands.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInputs) %#ok<DEFNU>
% Initialize returned list of files
OutputFile = {};

% Fetch user settings
implementation = sProcess.options.implementation.Value;
opt.freq_range          = sProcess.options.freqrange.Value{1};
opt.peak_width_limits   = sProcess.options.peakwidth.Value{1};
opt.max_peaks           = sProcess.options.maxpeaks.Value{1};
opt.min_peak_height     = sProcess.options.minpeakheight.Value{1} / 10; % convert from dB to B
opt.aperiodic_mode      = sProcess.options.apermode.Value;
opt.peak_threshold      = 2;   % 2 std dev: parameter for interface simplification
% Matlab-only options
opt.peak_type           = sProcess.options.peaktype.Value;
opt.proximity_threshold = sProcess.options.proxthresh.Value{1};
opt.guess_weight        = sProcess.options.guessweight.Value;
opt.thresh_after        = true;   % Threshold after fitting always selected for Matlab (mirrors the Python FOOOF closest by removing peaks that do not satisfy a user's predetermined conditions)
% Python-only options
opt.verbose    = false;
% Output options
opt.sort_type  = sProcess.options.sorttype.Value;
opt.sort_param = sProcess.options.sortparam.Value;
opt.sort_bands = sProcess.options.sortbands.Value;

% Check input frequency bounds
if (any(opt.freq_range < 0) || opt.freq_range(1) >= opt.freq_range(2))
    bst_report('error','Invalid Frequency range');
    return
end

hasOptimTools = 0;
if exist('fmincon') == 2 && strcmp(implementation,'matlab')
    hasOptimTools = 1;
    disp('Using constrained optimization, Guess Weight ignored.')
end

% Initialize returned list of files
OutputFile = {};
for iFile = 1:length(sInputs)
    bst_progress('text',['Standby: FOOOFing spectrum ' num2str(iFile) ' of ' num2str(length(sInputs))]);
    % Load input file
    PsdMat = in_bst_timefreq(sInputs(iFile).FileName);
    % Exclude 0Hz from the computation
    if (opt.freq_range(1) == 0) && (PsdMat.Freqs(1) == 0) && (length(PsdMat.Freqs) >= 2)
        opt.freq_range(1) = PsdMat.Freqs(2);
    end

    % === COMPUTE FOOOF MODEL ===
    % Switch between implementations
    switch (implementation)
        case 'matlab'   % Matlab standalone FOOOF
            [FOOOF_freqs, FOOOF_data] = matlab_FOOOF(PsdMat.TF, PsdMat.Freqs, opt, hasOptimTools);
        case 'python'
            opt.peak_type = 'gaussian';
            [FOOOF_freqs, FOOOF_data] = process_fooof_py('FOOOF_python', PsdMat.TF, PsdMat.Freqs, opt);
            % Remove unnecessary structure level, allowing easy concatenation across channels, e.g. for display.
            FOOOF_data = FOOOF_data.FOOOF;
        otherwise
            error('Invalid implentation.');
    end

    % === FOOOF ANALYSIS ===
    TFfooof = PsdMat.TF(:,1,ismember(PsdMat.Freqs,FOOOF_freqs));
    [ePeaks, eAperiodics, eStats] = FOOOF_analysis(FOOOF_data, PsdMat.RowNames, TFfooof, opt.max_peaks, opt.sort_type, opt.sort_param, opt.sort_bands);

    % === PREPARE OUTPUT STRUCTURE ===
    % Create file structure
    PsdMat.Options.FOOOF = struct(...
        'options',    opt, ...
        'freqs',      FOOOF_freqs, ...
        'data',       FOOOF_data, ...
        'peaks',      ePeaks, ...
        'aperiodics', eAperiodics, ...
        'stats',      eStats);
    % Comment: Add FOOOF
    if ~isempty(strfind(PsdMat.Comment, 'PSD:'))
        PsdMat.Comment = strrep(PsdMat.Comment, 'PSD:', 'FOOOF:');
    else
        PsdMat.Comment = strcat(PsdMat.Comment, ' | FOOOF');
    end
    % History: Computation
    PsdMat = bst_history('add', PsdMat, 'compute', 'FOOOF');

    % === SAVE FILE ===
    % Filename: add _fooof tag
    [fPath, fName, fExt] = bst_fileparts(file_fullpath(sInputs(iFile).FileName));
    NewFile = file_unique(bst_fullfile(fPath, [fName, '_fooof', fExt]));
    % Save file
    bst_save(NewFile, PsdMat, 'v6');
    % Add file to database structure
    db_add_data(sInputs(iFile).iStudy, NewFile, PsdMat);
    % Return new file
    OutputFile{end+1} = NewFile;
end
end


%% ===== GENERATE APERIODIC =====
function ap_vals = gen_aperiodic(freqs,aperiodic_params,aperiodic_mode)
%       Generate aperiodic values, from parameter definition.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%       	Frequency vector to create aperiodic component for.
%       aperiodic_params : 1x3 array
%           Parameters that define the aperiodic component.
%       aperiodic_mode : {'fixed', 'knee'}
%           Defines absence or presence of knee in aperiodic component.
%
%       Returns
%       -------
%       ap_vals : 1d array
%           Generated aperiodic values.

switch aperiodic_mode
    case 'fixed'  % no knee
        ap_vals = expo_nk_function(freqs,aperiodic_params);
    case 'knee'
        ap_vals = expo_function(freqs,aperiodic_params);
    case 'floor'
        ap_vals = expo_fl_function(freqs,aperiodic_params);
end
end


%% ===== CORE MODELS =====
function ys = gaussian(freqs, mu, hgt, sigma)
%       Gaussian function to use for fitting.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency vector to create gaussian fit for.
%       mu, hgt, sigma : doubles
%           Parameters that define gaussian function (centre frequency,
%           height, and standard deviation).
%
%       Returns
%       -------
%       ys :    1xn array
%       Output values for gaussian function.

ys = hgt*exp(-(((freqs-mu)./sigma).^2) /2);

end

function ys = cauchy(freqs, ctr, hgt, gam)
%       Cauchy function to use for fitting.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency vector to create cauchy fit for.
%       ctr, hgt, gam : doubles
%           Parameters that define cauchy function (centre frequency,
%           height, and "standard deviation" [gamma]).
%
%       Returns
%       -------
%       ys :    1xn array
%       Output values for cauchy function.

ys = hgt./(1+((freqs-ctr)/gam).^2);

end

function ys = expo_function(freqs,params)
%       Exponential function to use for fitting 1/f, with a 'knee' (maximum at low frequencies).
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Input x-axis values.
%       params : 1x3 array (offset, knee, exp)
%           Parameters (offset, knee, exp) that define Lorentzian function:
%           y = 10^offset * (1/(knee + x^exp))
%
%       Returns
%       -------
%       ys :    1xn array
%           Output values for exponential function.

ys = params(1) - log10(abs(params(2)) +freqs.^params(3));

end

function ys = expo_nk_function(freqs, params)
%       Exponential function to use for fitting 1/f, without a 'knee'.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Input x-axis values.
%       params : 1x2 array (offset, exp)
%           Parameters (offset, exp) that define Lorentzian function:
%           y = 10^offset * (1/(x^exp))
%
%       Returns
%       -------
%       ys :    1xn array
%           Output values for exponential (no-knee) function.

ys = params(1) - log10(freqs.^params(2));

end

function ys = expo_fl_function(freqs, params)

ys = log10(f.^(params(1)) * 10^(params(2)) + params(3));

end


%% ===== FITTING ALGORITHM =====
function aperiodic_params = simple_ap_fit(freqs, power_spectrum, aperiodic_mode)
%       Fit the aperiodic component of the power spectrum.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       power_spectrum : 1xn array
%           Power values, in log10 scale.
%       aperiodic_mode : {'fixed','knee'}
%           Defines absence or presence of knee in aperiodic component.
%
%       Returns
%       -------
%       aperiodic_params : 1xn array
%           Parameter estimates for aperiodic fit.

%       Set guess params for lorentzian aperiodic fit, guess params set at init
options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', 1e-6, ...
    'MaxFunEvals', 5000, 'MaxIter', 5000);

switch (aperiodic_mode)
    case 'fixed'  % no knee
        guess_vec = [power_spectrum(1), 2];
        aperiodic_params = fminsearch(@error_expo_nk_function, guess_vec, options, freqs, power_spectrum);
    case 'knee'
        guess_vec = [power_spectrum(1),0, 2];
        aperiodic_params = fminsearch(@error_expo_function, guess_vec, options, freqs, power_spectrum);
end

end

function aperiodic_params = robust_ap_fit(freqs, power_spectrum, aperiodic_mode)
%       Fit the aperiodic component of the power spectrum robustly, ignoring outliers.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       power_spectrum : 1xn array
%           Power values, in log10 scale.
%       aperiodic_mode : {'fixed','knee'}
%           Defines absence or presence of knee in aperiodic component.
%
%       Returns
%       -------
%       aperiodic_params : 1xn array
%           Parameter estimates for aperiodic fit.

% Do a quick, initial aperiodic fit
popt = simple_ap_fit(freqs, power_spectrum, aperiodic_mode);
initial_fit = gen_aperiodic(freqs, popt, aperiodic_mode);

% Flatten power_spectrum based on initial aperiodic fit
flatspec = power_spectrum - initial_fit;

% Flatten outliers - any points that drop below 0
flatspec(flatspec(:) < 0) = 0;

% Use percential threshold, in terms of # of points, to extract and re-fit
perc_thresh = prctile(flatspec, 2.5);
perc_mask = flatspec <= perc_thresh;
freqs_ignore = freqs(perc_mask);
spectrum_ignore = power_spectrum(perc_mask);

% Second aperiodic fit - using results of first fit as guess parameters

options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', 1e-6, ...
    'MaxFunEvals', 5000, 'MaxIter', 5000);
guess_vec = popt;

switch (aperiodic_mode)
    case 'fixed'  % no knee
        aperiodic_params = fminsearch(@error_expo_nk_function, guess_vec, options, freqs_ignore, spectrum_ignore);
    case 'knee'
        aperiodic_params = fminsearch(@error_expo_function, guess_vec, options, freqs, power_spectrum);
end
end

function spectrum_flat = flatten_spectrum(freqs, power_spectrum, robust_aperiodic_params, aperiodic_mode)
%       Flatten the power spectrum by removing the aperiodic component.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       power_spectrum : 1xn array
%           Power values, in log10 scale.
%       robust_aperiodic_params : 1x2 or 1x3 array (see aperiodic_mode)
%           Parameter estimates for aperiodic fit.
%       aperiodic_mode : 1 or 2
%           Defines absence or presence of knee in aperiodic component.
%
%       Returns
%       -------
%       spectrum_flat : 1xn array
%           Flattened (aperiodic removed) power spectrum.


spectrum_flat = power_spectrum - gen_aperiodic(freqs,robust_aperiodic_params,aperiodic_mode);

end

function [model_params,peak_function] = fit_peaks(freqs, flat_iter, max_n_peaks, peak_threshold, min_peak_height, gauss_std_limits, proxThresh, peakType, guess_weight,hOT)
%       Iteratively fit peaks to flattened spectrum.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       flat_iter : 1xn array
%           Flattened (aperiodic removed) power spectrum.
%       max_n_peaks : double
%           Maximum number of gaussians to fit within the spectrum.
%       peak_threshold : double
%           Threshold (in standard deviations of noise floor) to detect a peak.
%       min_peak_height : double
%           Minimum height of a peak (in log10).
%       gauss_std_limits : 1x2 double
%           Limits to gaussian (cauchy) standard deviation (gamma) when detecting a peak.
%       proxThresh : double
%           Minimum distance between two peaks, in st. dev. (gamma) of peaks.
%       peakType : {'gaussian', 'cauchy', 'both'}
%           Which types of peaks are being fitted
%       guess_weight : {'none', 'weak', 'strong'}
%           Parameter to weigh initial estimates during optimization (None, Weak, or Strong)
%       hOT : 0 or 1
%           Defines whether to use constrained optimization, fmincon, or
%           basic simplex, fminsearch.
%
%       Returns
%       -------
%       gaussian_params : mx3 array, where m = No. of peaks.
%           Parameters that define the peak fit(s). Each row is a peak, as [mean, height, st. dev. (gamma)].
switch peakType
    case 'gaussian' % gaussian only
        peak_function = @gaussian; % Identify peaks as gaussian
        % Initialize matrix of guess parameters for gaussian fitting.
        guess_params = zeros(max_n_peaks, 3);
        % Save intact flat_spectrum
        flat_spec = flat_iter;
        % Find peak: Loop through, finding a candidate peak, and fitting with a guess gaussian.
        % Stopping procedure based on either the limit on # of peaks,
        % or the relative or absolute height thresholds.
        for guess = 1:max_n_peaks
            % Find candidate peak - the maximum point of the flattened spectrum.
            max_ind = find(flat_iter == max(flat_iter));
            max_height = flat_iter(max_ind);

            % Stop searching for peaks once max_height drops below height threshold.
            if max_height <= peak_threshold * std(flat_iter)
                break
            end

            % Set the guess parameters for gaussian fitting - mean and height.
            guess_freq = freqs(max_ind);
            guess_height = max_height;

            % Halt fitting process if candidate peak drops below minimum height.
            if guess_height <= min_peak_height
                break
            end

            % Data-driven first guess at standard deviation
            % Find half height index on each side of the center frequency.
            half_height = 0.5 * max_height;

            le_ind = sum(flat_iter(1:max_ind) <= half_height);
            ri_ind = length(flat_iter) - sum(flat_iter(max_ind:end) <= half_height);

            % Keep bandwidth estimation from the shortest side.
            % We grab shortest to avoid estimating very large std from overalapping peaks.
            % Grab the shortest side, ignoring a side if the half max was not found.
            % Note: will fail if both le & ri ind's end up as None (probably shouldn't happen).
            short_side = min(abs([le_ind,ri_ind]-max_ind));

            % Estimate std from FWHM. Calculate FWHM, converting to Hz, get guess std from FWHM
            fwhm = short_side * 2 * (freqs(2)-freqs(1));
            guess_std = fwhm / (2 * sqrt(2 * log(2)));

            % Check that guess std isn't outside preset std limits; restrict if so.
            % Note: without this, curve_fitting fails if given guess > or < bounds.
            if guess_std < gauss_std_limits(1)
                guess_std = gauss_std_limits(1);
            end
            if guess_std > gauss_std_limits(2)
                guess_std = gauss_std_limits(2);
            end

            % Collect guess parameters.
            guess_params(guess,:) = [guess_freq, guess_height, guess_std];

            % Subtract best-guess gaussian.
            peak_gauss = gaussian(freqs, guess_freq, guess_height, guess_std);
            flat_iter = flat_iter - peak_gauss;

        end
        % Remove unused guesses
        guess_params(guess_params(:,1) == 0,:) = [];

        % Check peaks based on edges, and on overlap
        % Drop any that violate requirements.
        guess_params = drop_peak_cf(guess_params, proxThresh, [min(freqs) max(freqs)]);
        guess_params = drop_peak_overlap(guess_params, proxThresh);

        % If there are peak guesses, fit the peaks, and sort results.
        if ~isempty(guess_params)
            model_params = fit_peak_guess(guess_params, freqs, flat_spec, 1, guess_weight, gauss_std_limits,hOT);
        else
            model_params = zeros(1, 3);
        end

    case 'cauchy' % cauchy only
        peak_function = @cauchy; % Identify peaks as cauchy
        guess_params = zeros(max_n_peaks, 3);
        flat_spec = flat_iter;
        for guess = 1:max_n_peaks
            max_ind = find(flat_iter == max(flat_iter));
            max_height = flat_iter(max_ind);
            if max_height <= peak_threshold * std(flat_iter)
                break
            end
            guess_freq = freqs(max_ind);
            guess_height = max_height;
            if guess_height <= min_peak_height
                break
            end
            half_height = 0.5 * max_height;
            le_ind = sum(flat_iter(1:max_ind) <= half_height);
            ri_ind = length(flat_iter) - sum(flat_iter(max_ind:end) <= half_height);
            short_side = min(abs([le_ind,ri_ind]-max_ind));

            % Estimate gamma from FWHM. Calculate FWHM, converting to Hz, get guess gamma from FWHM
            fwhm = short_side * 2 * (freqs(2)-freqs(1));
            guess_gamma = fwhm/2;
            % Check that guess gamma isn't outside preset limits; restrict if so.
            % Note: without this, curve_fitting fails if given guess > or < bounds.
            if guess_gamma < gauss_std_limits(1)
                guess_gamma = gauss_std_limits(1);
            end
            if guess_gamma > gauss_std_limits(2)
                guess_gamma = gauss_std_limits(2);
            end

            % Collect guess parameters.
            guess_params(guess,:) = [guess_freq(1), guess_height, guess_gamma];

            % Subtract best-guess cauchy.
            peak_cauchy = cauchy(freqs, guess_freq(1), guess_height, guess_gamma);
            flat_iter = flat_iter - peak_cauchy;

        end
        guess_params(guess_params(:,1) == 0,:) = [];
        guess_params = drop_peak_cf(guess_params, proxThresh, [min(freqs) max(freqs)]);
        guess_params = drop_peak_overlap(guess_params, proxThresh);

        % If there are peak guesses, fit the peaks, and sort results.
        if ~isempty(guess_params)
            model_params = fit_peak_guess(guess_params, freqs, flat_spec, 2, guess_weight, gauss_std_limits,hOT);
        else
            model_params = zeros(1, 3);
        end
    case 'best' % best of both: model both fits and compare error, save best
        % Gaussian Fit
        guess_params = zeros(max_n_peaks, 3);
        flat_spec = flat_iter;
        for guess = 1:max_n_peaks
            max_ind = find(flat_iter == max(flat_iter));
            max_height = flat_iter(max_ind);
            if max_height <= peak_threshold * std(flat_iter)
                break
            end
            guess_freq = freqs(max_ind);
            guess_height = max_height;
            if guess_height <= min_peak_height
                break
            end
            half_height = 0.5 * max_height;
            le_ind = sum(flat_iter(1:max_ind) <= half_height);
            ri_ind = length(flat_iter) - sum(flat_iter(max_ind:end) <= half_height);
            short_side = min(abs([le_ind,ri_ind]-max_ind));
            fwhm = short_side * 2 * (freqs(2)-freqs(1));
            guess_std = fwhm / (2 * sqrt(2 * log(2)));
            if guess_std < gauss_std_limits(1)
                guess_std = gauss_std_limits(1);
            end
            if guess_std > gauss_std_limits(2)
                guess_std = gauss_std_limits(2);
            end
            guess_params(guess,:) = [guess_freq, guess_height, guess_std];
            peak_gauss = gaussian(freqs, guess_freq, guess_height, guess_std);
            flat_iter = flat_iter - peak_gauss;
        end
        guess_params(guess_params(:,1) == 0,:) = [];
        guess_params = drop_peak_cf(guess_params, proxThresh, [min(freqs) max(freqs)]);
        guess_params = drop_peak_overlap(guess_params, proxThresh);
        if ~isempty(guess_params)
            gauss_params = fit_peak_guess(guess_params, freqs, flat_spec, 1, guess_weight, gauss_std_limits,hOT);
            flat_gauss = zeros(size(freqs));
            for peak = 1:size(gauss_params,1)
                flat_gauss =  flat_gauss + gaussian(freqs,gauss_params(peak,1),...
                    gauss_params(peak,2),gauss_params(peak,3));
            end
            error_gauss = sum((flat_gauss-flat_spec).^2);
        else
            gauss_params = zeros(1, 3); error_gauss = 1E10;
        end

        % Cauchy Fit
        guess_params = zeros(max_n_peaks, 3);
        flat_iter = flat_spec;
        for guess = 1:max_n_peaks
            max_ind = find(flat_iter == max(flat_iter));
            max_height = flat_iter(max_ind);
            if max_height <= peak_threshold * std(flat_iter)
                break
            end
            guess_freq = freqs(max_ind);
            guess_height = max_height;
            if guess_height <= min_peak_height
                break
            end
            half_height = 0.5 * max_height;
            le_ind = sum(flat_iter(1:max_ind) <= half_height);
            ri_ind = length(flat_iter) - sum(flat_iter(max_ind:end) <= half_height);
            short_side = min(abs([le_ind,ri_ind]-max_ind));
            fwhm = short_side * 2 * (freqs(2)-freqs(1));
            guess_gamma = fwhm/2;
            if guess_gamma < gauss_std_limits(1)
                guess_gamma = gauss_std_limits(1);
            end
            if guess_gamma > gauss_std_limits(2)
                guess_gamma = gauss_std_limits(2);
            end
            guess_params(guess,:) = [guess_freq(1), guess_height, guess_gamma];
            peak_cauchy = cauchy(freqs, guess_freq(1), guess_height, guess_gamma);
            flat_iter = flat_iter - peak_cauchy;
        end
        guess_params(guess_params(:,1) == 0,:) = [];
        guess_params = drop_peak_cf(guess_params, proxThresh, [min(freqs) max(freqs)]);
        guess_params = drop_peak_overlap(guess_params, proxThresh);
        if ~isempty(guess_params)
            cauchy_params = fit_peak_guess(guess_params, freqs, flat_spec, 2, guess_weight, gauss_std_limits,hOT);
            flat_cauchy = zeros(size(freqs));
            for peak = 1:size(cauchy_params,1)
                flat_cauchy =  flat_cauchy + cauchy(freqs,cauchy_params(peak,1),...
                    cauchy_params(peak,2),cauchy_params(peak,3));
            end
            error_cauchy = sum((flat_cauchy-flat_spec).^2);
        else
            cauchy_params = zeros(1, 3); error_cauchy = 1E10;
        end
        % Save least-error model
        if min([error_gauss,error_cauchy]) == error_gauss
            model_params = gauss_params;
            peak_function = @gaussian;
        else
            model_params = cauchy_params;
            peak_function = @cauchy;
        end
end

end

function guess = drop_peak_cf(guess, bw_std_edge, freq_range)
%       Check whether to drop peaks based on center's proximity to the edge of the spectrum.
%
%       Parameters
%       ----------
%       guess : mx3 array, where m = No. of peaks.
%           Guess parameters for peak fits.
%
%       Returns
%       -------
%       guess : qx3 where q <= m No. of peaks.
%           Guess parameters for peak fits.

cf_params = guess(:,1)';
bw_params = guess(:,3)' * bw_std_edge;

% Check if peaks within drop threshold from the edge of the frequency range.

keep_peak = abs(cf_params-freq_range(1)) > bw_params & ...
    abs(cf_params-freq_range(2)) > bw_params;

% Drop peaks that fail the center frequency edge criterion
guess = guess(keep_peak,:);

end

function guess = drop_peak_overlap(guess, proxThresh)
%       Checks whether to drop gaussians based on amount of overlap.
%
%       Parameters
%       ----------
%       guess : mx3 array, where m = No. of peaks.
%           Guess parameters for peak fits.
%       proxThresh: double
%           Proximity threshold (in st. dev. or gamma) between two peaks.
%
%       Returns
%       -------
%       guess : qx3 where q <= m No. of peaks.
%           Guess parameters for peak fits.
%
%       Note
%       -----
%       For any gaussians with an overlap that crosses the threshold,
%       the lowest height guess guassian is dropped.

% Sort the peak guesses, so can check overlap of adjacent peaks
guess = sortrows(guess);

% Calculate standard deviation bounds for checking amount of overlap

bounds = [guess(:,1) - guess(:,3) * proxThresh, ...
    guess(:,1), guess(:,1) + guess(:,3) * proxThresh];

% Loop through peak bounds, comparing current bound to that of next peak
drop_inds =  [];

for ind = 1:size(bounds,1)-1

    b_0 = bounds(ind,:);
    b_1 = bounds(ind + 1,:);

    % Check if bound of current peak extends into next peak
    if b_0(2) > b_1(1)
        % If so, get the index of the gaussian with the lowest height (to drop)
        drop_inds = [drop_inds (ind - 1 + find(guess(ind:ind+1,2) == ...
            min(guess(ind,2),guess(ind+1,2))))];
    end
end
% Drop any peaks guesses that overlap too much, based on threshold.
guess(drop_inds,:) = [];
end

function peak_params = fit_peak_guess(guess, freqs, flat_spec, peak_type, guess_weight, std_limits, hOT)
%     Fits a group of peak guesses with a fit function.
%
%     Parameters
%     ----------
%       guess : mx3 array, where m = No. of peaks.
%           Guess parameters for peak fits.
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       flat_iter : 1xn array
%           Flattened (aperiodic removed) power spectrum.
%       peakType : {'gaussian', 'cauchy', 'best'}
%           Which types of peaks are being fitted.
%       guess_weight : 'none', 'weak', 'strong'
%           Parameter to weigh initial estimates during optimization.
%       std_limits: 1x2 array
%           Minimum and maximum standard deviations for distribution.
%       hOT : 0 or 1
%           Defines whether to use constrained optimization, fmincon, or
%           basic simplex, fminsearch.
%
%       Returns
%       -------
%       peak_params : mx3, where m =  No. of peaks.
%           Peak parameters post-optimization.


if hOT % Use OptimToolbox for fmincon
    options = optimset('Display', 'off', 'TolX', 1e-3, 'TolFun', 1e-5, ...
        'MaxFunEvals', 3000, 'MaxIter', 3000); % Tuned options
    lb = [guess(:,1)-guess(:,3)*2,zeros(size(guess(:,2))),ones(size(guess(:,3)))*std_limits(1)];
    ub = [guess(:,1)+guess(:,3)*2,inf(size(guess(:,2))),ones(size(guess(:,3)))*std_limits(2)];
    peak_params = fmincon(@error_model_constr,guess,[],[],[],[], ...
        lb,ub,[],options,freqs,flat_spec, peak_type);
else % Use basic simplex approach, fminsearch, with guess_weight
    options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', 1e-5, ...
        'MaxFunEvals', 5000, 'MaxIter', 5000);
    peak_params = fminsearch(@error_model,...
        guess, options, freqs, flat_spec, peak_type, guess, guess_weight);
end
end


%% ===== ERROR FUNCTIONS =====
function err = error_expo_nk_function(params,xs,ys)
ym = -log10(xs.^params(2)) + params(1);
err = sum((ys - ym).^2);
end

function err = error_expo_function(params,xs,ys)
ym = expo_function(xs,params);
err = sum((ys - ym).^2);
end

function err = error_model(params, xVals, yVals, peak_type, guess, guess_weight)
fitted_vals = 0;
weak = 1E2;
strong = 1E7;
for set = 1:size(params,1)
    switch (peak_type)
        case 1 % Gaussian
            fitted_vals = fitted_vals + gaussian(xVals, params(set,1), params(set,2), params(set,3));
        case 2 % Cauchy
            fitted_vals = fitted_vals + cauchy(xVals, params(set,1), params(set,2), params(set,3));
    end
end
switch guess_weight
    case 'none'
        err = sum((yVals - fitted_vals).^2);
    case 'weak' % Add small weight to deviations from guess m and amp
        err = sum((yVals - fitted_vals).^2) + ...
            weak*sum((params(:,1)-guess(:,1)).^2) + ...
            weak*sum((params(:,2)-guess(:,2)).^2);
    case 'strong' % Add large weight to deviations from guess m and amp
        err = sum((yVals - fitted_vals).^2) + ...
            strong*sum((params(:,1)-guess(:,1)).^2) + ...
            strong*sum((params(:,2)-guess(:,2)).^2);
end
end

function err = error_model_constr(params, xVals, yVals, peak_type)
fitted_vals = 0;
for set = 1:size(params,1)
    switch (peak_type)
        case 1 % Gaussian
            fitted_vals = fitted_vals + gaussian(xVals, params(set,1), params(set,2), params(set,3));
        case 2 % Cauchy
            fitted_vals = fitted_vals + cauchy(xVals, params(set,1), params(set,2), params(set,3));
    end
end
err = sum((yVals - fitted_vals).^2);
end



%% ===================================================================================
%  ===== FOOOF STATS =================================================================
%  ===================================================================================
function [ePeaks, eAper, eStats] = FOOOF_analysis(FOOOF_data, ChanNames, TF, max_peaks, sort_type, sort_param, sort_bands)
% ===== EXTRACT PEAKS =====
% Organize/extract peak components from FOOOF models
nChan = numel(ChanNames);
maxEnt = nChan * max_peaks;
switch sort_type
    case 'param'
        % Initialize output struct
        ePeaks = struct('channel', [], 'center_frequency', [],...
            'amplitude', [], 'std_dev', []);
        % Collect data from all peaks
        i = 0;
        for chan = 1:nChan
            if ~isempty(FOOOF_data(chan).peak_params)
                for p = 1:size(FOOOF_data(chan).peak_params,1)
                    i = i +1;
                    ePeaks(i).channel = ChanNames(chan);
                    ePeaks(i).center_frequency = FOOOF_data(chan).peak_params(p,1);
                    ePeaks(i).amplitude = FOOOF_data(chan).peak_params(p,2);
                    ePeaks(i).std_dev = FOOOF_data(chan).peak_params(p,3);
                end
            end
        end
        % Apply specified sort
        switch sort_param
            case 'frequency'
                [tmp,iSort] = sort([ePeaks.center_frequency]);
                ePeaks = ePeaks(iSort);
            case 'amplitude'
                [tmp,iSort] = sort([ePeaks.amplitude]);
                ePeaks = ePeaks(iSort(end:-1:1));
            case 'std'
                [tmp,iSort] = sort([ePeaks.std_dev]);
                ePeaks = ePeaks(iSort);
        end
    case 'band'
        % Initialize output struct
        ePeaks = struct('channel', [], 'center_frequency', [],...
            'amplitude', [], 'std_dev', [], 'band', []);
        % Generate bands from input
        bands = process_tf_bands('Eval', sort_bands);
        % Collect data from all peaks
        i = 0;
        for chan = 1:nChan
            if ~isempty(FOOOF_data(chan).peak_params)
                for p = 1:size(FOOOF_data(chan).peak_params,1)
                    i = i +1;
                    ePeaks(i).channel = ChanNames(chan);
                    ePeaks(i).center_frequency = FOOOF_data(chan).peak_params(p,1);
                    ePeaks(i).amplitude = FOOOF_data(chan).peak_params(p,2);
                    ePeaks(i).std_dev = FOOOF_data(chan).peak_params(p,3);
                    % Find name of frequency band from user definitions
                    bandRanges = cell2mat(bands(:,2));
                    iBand = find(ePeaks(i).center_frequency >= bandRanges(:,1) & ePeaks(i).center_frequency <= bandRanges(:,2));
                    if ~isempty(iBand)
                        ePeaks(i).band = bands{iBand,1};
                    else
                        ePeaks(i).band = 'None';
                    end
                end
            end
        end
end

% ===== EXTRACT APERIODIC =====
% Organize/extract aperiodic components from FOOOF models
hasKnee = length(FOOOF_data(1).aperiodic_params) - 2;
% Initialize output struct
eAper = struct('channel', [], 'offset', [], 'exponent', []);
for chan = 1:nChan
    eAper(chan).channel = ChanNames(chan);
    eAper(chan).offset = FOOOF_data(chan).aperiodic_params(1);
    if hasKnee % Legacy FOOOF alters order of parameters
        eAper(chan).exponent = FOOOF_data(chan).aperiodic_params(3);
        eAper(chan).knee_frequency = FOOOF_data(chan).aperiodic_params(2);
    else
        eAper(chan).exponent = FOOOF_data(chan).aperiodic_params(2);
    end
end

% ===== EXTRACT STAT =====
% Organize/extract stats from FOOOF models
% Initialize output struct
eStats = struct('channel', ChanNames);
for chan = 1:nChan
    eStats(chan).MSE = FOOOF_data(chan).error;
    eStats(chan).r_squared = FOOOF_data(chan).r_squared;
    spec = squeeze(log10(TF(chan,:,:)));
    fspec = squeeze(log10(FOOOF_data(chan).fooofed_spectrum))';
    eStats(chan).frequency_wise_error = abs(spec-fspec);
end
end

