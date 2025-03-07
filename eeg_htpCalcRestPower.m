function [EEG, results] = eeg_htpCalcRestPower(EEG, varargin)
    % Description: calculate spectral power on continuous data.
    % Category: Analysis
    % ShortTitle: Resting Spectral Power Analysis
    % Tags: Power
    %      Power is calculated using MATLAB pWelch function. Key parameter is
    %      window length with longer window providing increased frequency
    %      resolution. Overlap is set at default at 50%. A hanning window is
    %      also implemented. Speed is greatly increased by GPU.
    %
    % Usage:
    %    >> [ EEG, results ] = eeg_htpCalcRestPower( EEG, varargin )
    %
    % Require Inputs:
    %     EEG       - EEGLAB Structure
    % Function Specific Inputs:
    %     gpuon     - [logical] use gpuArray. default: false
    %     duration  - [integer] duration to calculate on. default: 80 seconds
    %                 if duration is greater sample, will default to max size.
    %     offset    - [integer] start time in seconds. default: 0
    %     outputdir - default, same as EEG path
    %.    useParquet - [logical] use Parquet format on save
    % Common Visual HTP Inputs:
    %     'bandDefs'   - cell-array describing frequency band definitions
    %     {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 'alpha2', 10.5, 12.5;
    %     'beta', 13, 30;'gamma1', 30, 55; 'gamma2', 65, 80; 'epsilon', 81, 120;}
    %     'outputdir' - path for saved output files (default: tempdir)
    %
    % Outputs:
    % Outputs:
    %     EEG       - EEGLAB Structure with modified .vhtp field
    %                 [table] summary_table: subject chan power_type_bandname
    %                 [table] spectro: channel average power for spectrogram
    %     results   - .vhtp structure
    %
    %  This file is part of the Cincinnati Visual High Throughput Pipeline,
    %  please see http://github.com/cincibrainlab
    %
    %  Contact: kyle.cullion@cchmc.org

    timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
    functionstamp = mfilename; % function name for logging/output

    [note] = htp_utilities();

    % Inputs: Function Specific
    defaultGpu = 0;
    defaultDuration = 60;
    defaultOffset = 0;
    defaultWindow = 2;
    defaultUseParquet = false;

    % Inputs: Common across Visual HTP functions
    defaultOutputDir = [];
    defaultBandDefs = {'delta', 2, 3.5; 'theta', 3.5, 7.5; 'alpha1', 8, 10;
                    'alpha2', 10.5, 12.5; 'beta', 13, 30; 'gamma1', 30, 55;
                    'gamma2', 65, 80; 'epsilon', 81, 120; };

    % MATLAB built-in input validation
    ip = inputParser();
    addRequired(ip, 'EEG', @isstruct);
    addParameter(ip, 'gpuOn', defaultGpu, @mustBeNumericOrLogical);
    addParameter(ip, 'duration', defaultDuration, @isnumeric);
    addParameter(ip, 'offset', defaultOffset, @isnumeric);
    addParameter(ip, 'window', defaultWindow, @isnumeric);
    addParameter(ip, 'outputdir', defaultOutputDir, @isfolder);
    addParameter(ip, 'bandDefs', defaultBandDefs, @iscell);
    addParameter(ip, 'useParquet', defaultUseParquet, @islogical);

    parse(ip, EEG, varargin{:});

    outputdir = ip.Results.outputdir;
    bandDefs = ip.Results.bandDefs;


    % File Management (create subfolder with function name)
    [~, basename, ~] = fileparts(EEG.filename);
    analysis_outputdir =  fullfile(outputdir, mfilename);
    if ~exist("analysis_outputdir", "dir")
        mkdir(analysis_outputdir);
    end
    pow_file   = fullfile(analysis_outputdir, [basename '_eeg_htpCalcRestPower_band.csv']);
    spectro_file   = fullfile(analysis_outputdir, [basename '_eeg_htpCalcRestPower_spectro.csv']);
    qi_file   = fullfile(analysis_outputdir, [basename '_eeg_htpCalcRestPower_qi.csv']);


    % START: Signal Processing

    % Key Parameters
    t = ip.Results.duration; % time in seconds
    fs = EEG.srate; % sampling rate
    win = ceil(ip.Results.window * fs); % window
    nfft = win; % FFT points--
    noverlap = .5 * win; % points overlap
    channo = EEG.nbchan;
    EEG.subject = EEG.setname;

    labels = bandDefs(:, 1);
    freq = cell2mat(bandDefs(:, 2:3));

    % dataset validation
    % is size sufficient for duration and offset?
    samples = t * fs; % if using time, number of samples
    start_sample = ip.Results.offset * fs; if start_sample == 0, start_sample = 1; end
    total_samples = EEG.pnts * EEG.trials;
    
    if samples >= total_samples - start_sample
        samples = total_samples;
        start_samples = 1; % in samples
        warning("Insufficient Data, using max samples.")
    end

    % calculate power from first and last frequency from banddefs
    if ndims(EEG.data) > 2 %#ok<ISMAT>
        %dat = permute(detrend3(permute(EEG.data, [2 3 1])), [3 1 2]);
        dat = EEG.data;
        cdat = reshape(dat, size(dat, 1), size(dat, 2) * size(dat, 3));
    else
        cdat = EEG.data;
    end

    % define final input data
    cdat = cdat(:, start_sample:end);

    % switch on gpu
    if ip.Results.gpuOn, cdat = gpuArray(cdat); end

    % power computation
    [pxx, f] = pwelch(cdat', hanning(win), noverlap, freq(1, 1):.5:freq(end, 2), fs); %#ok<*ASGLU>
    if size(pxx,1)==EEG.nbchan, pxx=pxx'; f=f'; end % added for single channel data (like mouse electrodes)
    if ip.Results.gpuOn, pxx = gather(pxx); f = gather(f); end

    % power derivations
    pow_abs = pxx(1:end, :); % absolute power (V^2/Hz)
    pow_db = 10 * log10(pow_abs); % absolute power dB/Hz

    pow_rel = NaN * ones(size(pow_abs)); % relative power (unitless)

    for chani = 1:size(pow_rel, 2)
        pow_rel(:, chani) = pow_abs(:, chani) ./ sum(pow_abs(:, chani));
    end

    % band averaged power
    pow_prealloc = zeros(length(freq), channo);
    pow_abs_band = pow_prealloc; pow_db_band = pow_prealloc; pow_rel_band = pow_prealloc;

    for bandi = 1:length(freq)
        current_band = freq(bandi, :);
        freqidx = [find(f == current_band(1)):find(f == current_band(2))];
        pow_abs_band(bandi, :) = squeeze(mean(pow_abs(freqidx, :), 1));
        pow_db_band(bandi, :) = squeeze(mean(pow_db(freqidx, :), 1));
        pow_rel_band(bandi, :) = squeeze(mean(pow_rel(freqidx, :), 1));
    end

    % create output table
    pow_abs_band = pow_abs_band';
    pow_db_band = pow_db_band';
    pow_rel_band = pow_rel_band';

    abs_labels = cellfun(@(x) sprintf('abs_%s', x), labels', 'uni', 0);
    db_labels = cellfun(@(x) sprintf('db_%s', x), labels', 'uni', 0);
    rel_labels = cellfun(@(x) sprintf('rel_%s', x), labels', 'uni', 0);

    allbandlabels = [abs_labels db_labels rel_labels];
    powertable = array2table([pow_abs_band pow_db_band pow_rel_band], 'VariableNames', allbandlabels);

    infocolumns = table(string(repmat(EEG.subject, channo, 1)), string(repmat(EEG.filename, channo, 1)), ...
        {EEG.chanlocs.labels}', 'VariableNames', {'eegid', 'filename', 'chan'});

    csvtable = [infocolumns, powertable];

    chan_names = {EEG.chanlocs.labels};
    slabel = @( measure_prefix ) cellfun(@(chan_name_cell) sprintf('%s_%s', ...
        measure_prefix, chan_name_cell), chan_names, 'uni',0);

    abs_labels = slabel('abspow');
    db_labels = slabel('dbpow');
    rel_labels = slabel('relpow');
    spectro_labels = [{'freq'} {abs_labels{:}} ...
         {db_labels{:}} {rel_labels{:}}];

    spectro_values = array2table([f pow_abs pow_db pow_rel ], ...
         'VariableNames', spectro_labels);
    spectro_info = table(repmat(EEG.subject, length(f), 1), ...
        repmat('spectrogram', length(f), 1), 'VariableNames', {'eegid', 'measure'});

    % deprecated: mean spectrogram across channels
%     spectro_values = array2table([f ...
%                                 mean(pow_abs, 2) mean(pow_db, 2) mean(pow_rel, 2)], ...
%         'VariableNames', {'freq', 'abspow', 'dbpow', 'relpow'});
% 
%     spectro_info = table(repmat(EEG.subject, length(f), 1), ...
%         repmat('mean', length(f), 1), 'VariableNames', {'eegid', 'chan'});

    % END: Signal Processing

    % QI Table
    qi_table = cell2table({EEG.setname, EEG.filename, functionstamp, timestamp, ...
        EEG.trials, EEG.pnts, EEG.srate, EEG.xmin, EEG.xmax}, ...
    'VariableNames', {'eegid', 'filename', 'scriptname', 'timestamp', ...
    'trials', 'points', 'srate', 'xmin', 'xmax'});

    % Outputs:
    EEG.vhtp.eeg_htpCalcRestPower.summary_table = csvtable;
    EEG.vhtp.eeg_htpCalcRestPower.pow.spectro = [spectro_info, spectro_values];
    EEG.vhtp.eeg_htpCalcRestPower.qi_table = qi_table;
    results = EEG.vhtp.eeg_htpCalcRestPower;

    % file management
    if ~isempty(ip.Results.outputdir)
        if ~ip.Results.useParquet
            writetable(results.summary_table, pow_file);
            writetable(results.pow.spectro, spectro_file);
            writetable(results.qi_table, qi_file);

        else
            parquetwrite(strrep(pow_file,'.csv','.parquet'),results.summary_table);
            parquetwrite(strrep(spectro_file,'.csv','.parquet'),results.pow.spectro);
            writetable(results.qi_table, qi_file);

        end
        note(sprintf('%s saved in %s.\n', EEG.setname, ip.Results.outputdir))
    else
        note('Specify output directory to save results.\n')
    end

    function note = htp_utilities()
            note        = @(msg) fprintf('%s: %s\n', mfilename, msg );
    end
    
end
