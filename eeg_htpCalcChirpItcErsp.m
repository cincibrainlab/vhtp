function [EEG, results] = eeg_htpCalcChirpItcErsp(EEG, varargin)
% Description: calculate ITC and single trial power (ERSP)
% ShortTitle: Auditory Chirp Analysis
% Category: Analysis
% Tags: ERP
%      Original code designed for auditory chirp presentation.
%      Note: newtimef() is a legacy EEGLAB function that is highly
%      dependent on EEGLAB timefreq.m which is frequently updated. Future
%      version of this code will embed relevant itc/ersp functions.
%
% Usage:
%    >> [ EEG ] = eeg_htpCalcChirpItcErsp( EEG, varargin )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
%
% Function Specific Inputs:
%     'option1' - description
%
% Outputs:
%     EEG       - EEGLAB Structure with modified .etc.htp field
%     results   - etc.htp results structure or customized
%     baselinew - if 'baselinew' vector is specified ersp will be
%     calculated and added to the result spreadsheet.
%
% Example: with baseline ERSP
%  eeg_htpCalcChirpItcErsp(EEG, 'sourceOn', true, 'byChannel', true, 'baselinew', [-500 0]);
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: ernest.pedapati@cchmc.org

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

% Inputs: Function Specific
% publication parameters: Ethridge et al. 2019
defaultTLimits = [-500 2750];
defaultBaselineW = [-500 0];
defaultFLimits = [2 110];
defaultTimesOut = 250;
defaultCycles = [1 30];
defaultWinSize = 100;
defaultNFreqs = 109;
defaultSourceOn = false;
defaultEmptyEEG = true;
defaultAmpThreshold = 120;
defaultByChannel = false;
defaultOutputDir = tempdir;
defaultRoi = {'E23', 'E18', 'E16', 'E10', 'E3', ...
    'E28', 'E24', 'E19', 'E11', 'E4', 'E124', 'E117', ...
    'E29', 'E20', 'E12', 'E5', 'E118', 'E111', 'E13', 'E6', 'E112', ...
    'E7', 'E106'};
defaultRoiLabel = "Average";
defaultPlotRoi = true;
defaultIsSteadyState = false;

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'tlimits', defaultTLimits, @isvector);
addParameter(ip, 'flimits', defaultFLimits, @isvector);
addParameter(ip, 'cycles', defaultCycles, @isvector);
addParameter(ip, 'timesout', defaultTimesOut, @isinteger);
addParameter(ip, 'winsize', defaultWinSize, @isinteger);
addParameter(ip, 'nfreqs', defaultNFreqs, @isinteger);
addParameter(ip, 'outputdir', defaultOutputDir, @isfolder);
addParameter(ip, 'sourceOn', defaultSourceOn, @islogical);
addParameter(ip, 'emptyEEG', defaultEmptyEEG, @islogical)
addParameter(ip, 'ampThreshold', defaultAmpThreshold, @isnumeric)
addParameter(ip, 'byChannel', defaultByChannel, @islogical)
addParameter(ip, 'baselinew', defaultBaselineW, @isvector);
addParameter(ip, 'isMouseMea', defaultSourceOn, @islogical);
addParameter(ip, 'roi', defaultRoi, @iscell);
addParameter(ip, 'roiLabel', defaultRoiLabel, @ischar);
addParameter(ip, 'plotRoi', defaultPlotRoi, @islogical);
addParameter(ip, 'isSteadyState', defaultIsSteadyState, @islogical);

parse(ip, EEG, varargin{:});

outputdir = ip.Results.outputdir;

% base output file can be modified with strrep()
outputfile = fullfile(outputdir, [functionstamp '_' EEG.setname '_' timestamp '.mat']);

% START: Signal Processing

% Flag to control whether to use actual critical values or zeros
useCritValues = ~ip.Results.isMouseMea;  % Set to true to use original calculation, false for zeros

if useCritValues
    % Original critical values correction
    for i = 1:400, rcrits(i, 1) = sqrt(- (1 / i) * log(.5)); end
else
    % All zeros version
    rcrits = zeros(400, 1);
end

if EEG.trials < 10, error("Low number of trials detected; check epoching."); end

% define ROI of auditory cortex projection
chirp_electrode_labels = ip.Results.roi;


if ip.Results.sourceOn

    dksource_labels = {EEG.chanlocs.labels};


    try
        atlasTable = readtable(websave([tempname, '.csv'], ...
            'https://raw.githubusercontent.com/cincibrainlab/vhtp/refs/heads/main/chanfiles/DK_atlas-68_dict.csv'));
        chirp_sensors = dksource_labels;
        chirp_sensors_table = table(chirp_sensors', 'VariableNames', {'labelclean'});
        chirp_sensors_table = innerjoin(chirp_sensors_table, atlasTable);
        chirp_sensors_table = chirp_sensors_table(:, {'labelclean', 'lobe'});
        chirp_dksource_labels_idx = ismember(chirp_sensors_table.lobe, {'Temporal', 'Frontal'});
        chirp_sensors = {EEG.chanlocs(chirp_dksource_labels_idx).labels};
        EEG = pop_select(EEG, 'channel', find(chirp_dksource_labels_idx));
        dksource_labels = chirp_sensors;


    catch ME
        chirp_dksource_labels_idx = contains(dksource_labels, 'temporal');
        chirp_dksource_labels = dksource_labels(chirp_dksource_labels_idx);
        chirp_sensors = chirp_dksource_labels;
        warning(ME.identifier, 'Web atlas could not be loaded. Processing Temporal ROIs instead. Error: %s', ME.message);
    end

else

    if ip.Results.isMouseMea

        chirp_sensors = {EEG.chanlocs.labels};
        dksource_labels = chirp_sensors;
    else
        %if EEG.nbchan < 128, error('Insufficient # of Channels. Check if SourceOn = false.'); end
        chirp_sensors = chirp_electrode_labels;
    end
end

if ip.Results.sourceOn || ip.Results.isMouseMea
    warning('Processing source data: using 3 SD ROI threshold, not global.');

    bad_trial_count = 0;
    bad_trial_idx = [];
    bad_trial_sd = [];

    channel_means = mean(EEG.data, [2, 3]);
    channel_stds = std(EEG.data, 0, [2, 3]);
    channel_thresholds = channel_means + 3 * channel_stds;
    amp_threshold = mean(channel_thresholds);

    for i = 1:EEG.trials
        trial_amplitude = mean(abs(EEG.data(:, :, i)), 2);
        exceed_sd = (trial_amplitude - channel_means) ./ channel_stds;
        
        if any(trial_amplitude > channel_thresholds)
            bad_trial_count = bad_trial_count + 1;
            bad_trial_idx(bad_trial_count) = i;
            bad_trial_sd(bad_trial_count) = max(exceed_sd);
            fprintf('Bad trial detected: %s\n', sprintf("%s epoch: %d exceeded by %.2f SD", EEG.setname, i, max(exceed_sd)));
        end
    end

    if ~isempty(bad_trial_idx)
        EEG.data(:, :, bad_trial_idx) = [];
        EEG.trials = size(EEG.data, 3);
        fprintf('%d bad trials removed.\n', length(bad_trial_idx));
        for idx = 1:length(bad_trial_idx)
            fprintf('Trial %d was %.2f SD from the mean.\n', bad_trial_idx(idx), bad_trial_sd(idx));
        end
    else
        fprintf('No bad trials detected.\n');
    end

else
    amp_threshold = ip.Results.ampThreshold;
    bad_trial_idx = zeros(1, EEG.trials);  % Pre-allocate for efficiency
    bad_trial_count = 0;

    for i = 1:EEG.trials
        trial_amplitude = abs(mean(EEG.data(:, :, i), 2));  % Fixed dimension
        trial_index = i;

        if any(trial_amplitude > amp_threshold)
            bad_trial_count = bad_trial_count + 1;
            bad_trial_idx(bad_trial_count) = trial_index;
            fprintf('Bad trial detected: %s\n', sprintf("%s epoch: %d", EEG.setname, trial_index));
        end
    end

    if ~isempty(bad_trial_idx)
        % Only keep non-zero indices
        bad_trial_idx = bad_trial_idx(1:bad_trial_count);
        EEG = pop_select(EEG, 'notrial', bad_trial_idx);
        disp(['Removed: ' EEG.setname ' ' num2str(bad_trial_idx)])
    end
end


sensoridx = cell2mat(cellfun(@(x) find(strcmpi(x, {EEG.chanlocs.labels})), ...
    chirp_sensors, 'uni', 0));

tlimits = ip.Results.tlimits;
flimits = ip.Results.flimits; % changed from 120 to 110 - LAD 1/19/22
timesout = ip.Results.timesout;
cycles = ip.Results.cycles;
winsize = ip.Results.winsize;
nfreqs = ip.Results.nfreqs; % changed from 119 to 109 - LAD 1/19/22

Fs = EEG.srate;
trials = EEG.trials;
EEG.subject = EEG.setname;

% newtimef() - Return estimates and plots of mean event-related (log) spectral
% perturbation (ERSP) and inter-trial coherence (ITC) events across
% event-related trials (epochs) of a single input channel time series.

% define analysis parameters
if ip.Results.byChannel
    data = EEG.data;
else
    data = mean(EEG.data(sensoridx, :, :));
end

for ci = 1 : size(data,1)
    datax = squeeze(data(ci,:,:));
    if ip.Results.byChannel
        if ip.Results.sourceOn
            channame = dksource_labels{ci};
        end
        if ip.Results.isMouseMea
            channame = dksource_labels{ci};
        end
    else
        channame = ip.Results.roiLabel;
    end

    [stp1, itc, ~, t_s, f_s] = newtimef(double(datax), ...
        EEG.pnts, ... % frames
        tlimits, ... %tlimits
        Fs, ... %Fs
        cycles, ... % varwin (cycles)
        'winsize', winsize, ...
        'nfreqs', nfreqs, ...
        'freqs', flimits, ...
        'plotersp', 'off', ...
        'plotitc', 'off', ...
        'verbose', 'off', ...
        'baseline', NaN, ...
        'timesout', timesout);

    % Single trial power with baseline correction (ERSP)
    if ~isnan(ip.Results.baselinew)
        [ersp1, itc, ~, t_s, f_s] = newtimef(double(datax), ...
            EEG.pnts, ... % frames
            tlimits, ... %tlimits
            Fs, ... %Fs
            cycles, ... % varwin (cycles)
            'winsize', winsize, ...
            'nfreqs', nfreqs, ...
            'freqs', flimits, ...
            'plotersp', 'off', ...
            'plotitc', 'off', ...
            'verbose', 'off', ...
            'baseline', ip.Results.baselinew, ...
            'timesout', timesout);
    else
        ersp1 = nan(size(stp1));
    end

    corrected_itc = (abs(itc)) - rcrits(trials);
    uncorrected_itc = (abs(itc));

    % results table
    findHz = @(hz1, hz2) find(f_s >= hz1 & f_s <= hz2);
    findTimes = @(t1, t2) find(t_s >= t1 & t_s <= t2);

    %% Identify ROIs: Units are Hz for Frequencies and milliseconds for Times
    roi.ERSP_gamma_hz = {findHz(30, 71)}; % edited to LE's final analyzed frequences for gamma - LAD 1/19/22
    roi.ERSP_gamma1_hz = {findHz(30, 60)};
    roi.ERSP_gamma2_hz = {findHz(60, 100)};
    roi.ERSP_alpha_hz = {findHz(8, 12)};

    roi.ItcOnset_hz = {findHz(2, 13)}; % LE's final freq range for onset was 6-13hz - should check with her about this
    roi.ItcOnset_ms = {findTimes(92, 308)};
    roi.ItcOffset_hz = {findHz(2, 13)};
    roi.ItcOffset_ms = {findTimes(2038, 2254)};



    if ip.Results.isSteadyState
        fprintf("Steady State Analysis");

        roi.ITC40_hz_og = {findHz(30, 50)};
        roi.ITC40_ms_og = {findTimes(0, 3000)};

        roi.ITC40_hz = {findHz(35, 45)};
        roi.ITC40_ms = {findTimes(0, 3000)};

        roi.ITC80_hz = {findHz(75, 85)};
        roi.ITC80_ms = {findTimes(0, 3000)};
    else
        fprintf("Chirp Analysis");

        roi.ITC40_hz_og = {findHz(31, 42); findHz(43, 46); findHz(47, 57)};
        roi.ITC40_ms_og = {findTimes(676, 785); findTimes(796, 981); findTimes(988, 1066)};

        roi.ITC40_hz = {findHz(30, 35); findHz(35, 40); findHz(40, 45); findHz(45, 50); findHz(50, 55)};
        roi.ITC40_ms = {findTimes(650, 850); findTimes(750, 950); findTimes(850, 1050); ...
            findTimes(950, 1150); findTimes(1050, 1250)};

        roi.ITC80_hz = {find(f_s >= 70 & f_s <= 100)};
        roi.ITC80_ms = {find(t_s >= 1390 & t_s <= 1930)};

    end

    % Summary Functions
    computeMeanSTP = @(roi_hz) sum(cellfun(@(hz) mean2(stp1(hz, :)), ...
        roi_hz)) / numel(roi_hz);

    computeMeanERSP = @(roi_hz) sum(cellfun(@(hz) mean2(ersp1(hz, :)), ...
        roi_hz)) / numel(roi_hz);

    computeMeanITC = @(roi_hz, roi_ms) sum(cellfun(@(hz, ms) mean2(corrected_itc(hz, ms)), ...
        roi_hz, roi_ms)) / numel(roi_hz);

    computeMeanRawITC = @(roi_hz, roi_ms) sum(cellfun(@(hz, ms) mean2(uncorrected_itc(hz, ms)), ...
        roi_hz, roi_ms)) / numel(roi_hz);

    plotroi = ip.Results.plotRoi;

    if plotroi

        [~,basename,~] = fileparts(EEG.filename);
        basename = char(sprintf("%s_%s", basename, channame));

        % Plot the uncorrected ITC using imagesc
        fig = figure('Visible','off');
        itc = corrected_itc;
        imagesc(t_s, f_s, itc);
        axis xy;  % Ensures that the Y-axis is not flipped
        xlabel('Time (ms)');
        ylabel('Frequency (Hz)');
        title(sprintf('ITC Heatmap %s %2.4f (max: %2.4f)', basename, computeMeanITC(roi.ITC40_hz, roi.ITC40_ms), max(max(itc))), 'Interpreter', 'none');
        colorbar;

        max_itc = .25;
        if max(max(itc)) > max_itc
            % axis([0 1]); % important
            % plot_title = [plot_title ' (EXCEEDS UPPER LIMIT ' num2str(max_itc) ')' ];
            caxis([0 .25]); % important

        else
            %caxis([0 .25]); % important
            caxis([0 .5]); % important

        end



        saveas(fig, fullfile(outputdir, [basename '.png']))
        close(fig);  % Close the figure window


    end

    csvRow = { ...
        EEG.subject ...
        EEG.trials ...
        channame ...
        numel(bad_trial_idx) ...
        computeMeanSTP(roi.ERSP_gamma_hz) ...
        computeMeanSTP(roi.ERSP_gamma1_hz) ...
        computeMeanSTP(roi.ERSP_gamma2_hz) ...
        computeMeanSTP(roi.ERSP_alpha_hz) ...
        computeMeanERSP(roi.ERSP_gamma_hz) ...
        computeMeanERSP(roi.ERSP_gamma1_hz) ...
        computeMeanERSP(roi.ERSP_gamma2_hz) ...
        computeMeanERSP(roi.ERSP_alpha_hz) ...
        computeMeanITC(roi.ITC40_hz_og, roi.ITC40_ms_og) ...
        computeMeanITC(roi.ITC40_hz, roi.ITC40_ms) ...
        computeMeanITC(roi.ITC80_hz, roi.ITC80_ms) ...
        computeMeanITC(roi.ItcOnset_hz, roi.ItcOnset_ms) ...
        computeMeanITC(roi.ItcOffset_hz, roi.ItcOffset_ms) ...
        computeMeanRawITC(roi.ITC40_hz_og, roi.ITC40_ms_og) ...
        computeMeanRawITC(roi.ITC40_hz, roi.ITC40_ms) ...
        computeMeanRawITC(roi.ITC80_hz, roi.ITC80_ms) ...
        computeMeanRawITC(roi.ItcOnset_hz, roi.ItcOnset_ms) ...
        computeMeanRawITC(roi.ItcOffset_hz, roi.ItcOffset_ms) ...
        };

    chanCsvRows{ci} = csvRow;
    chanItc{ci} = corrected_itc;
    chanRawItc{ci} = uncorrected_itc;
    chanErsp{ci} = ersp1;
    chanStp{ci} = stp1;
    disp(channame);
end

csvRow = vertcat(chanCsvRows{:});

if ip.Results.emptyEEG, EEG.data = []; end

csvTable = cell2table(csvRow, "VariableNames", {'eegid', 'trials', 'chan', 'rejtrials', ...
    'stp_gamma', 'stp_gamma1', 'stp_gamma2', 'stp_alpha', ...
    'ersp_gamma', 'ersp_gamma1', 'ersp_gamma2', 'ersp_alpha', ...
    'itc40_og', 'itc40', 'itc80', 'itconset', 'itcoffset', ...
    'raw_itc40_og', 'raw_itc40', 'raw_itc80', 'raw_itconset', 'raw_itcoffset',});

% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, 'VariableNames', {'eegid', 'scriptname', 'timestamp'});

% Outputs:
EEG.vhtp.eeg_htpCalcChirpItcErsp.itc1 = cat(3,chanItc{:});
EEG.vhtp.eeg_htpCalcChirpItcErsp.rawitc1 = cat(3,chanRawItc{:});
EEG.vhtp.eeg_htpCalcChirpItcErsp.ersp1 = cat(3,chanErsp{:});
EEG.vhtp.eeg_htpCalcChirpItcErsp.stp1 = cat(3,chanStp{:});
EEG.vhtp.eeg_htpCalcChirpItcErsp.t_s = t_s;
EEG.vhtp.eeg_htpCalcChirpItcErsp.f_s = f_s;
EEG.vhtp.eeg_htpCalcChirpItcErsp.summary_table = csvTable;
EEG.vhtp.eeg_htpCalcChirpItcErsp.qi_table = qi_table;
EEG.vhtp.eeg_htpCalcChirpItcErsp.trials = EEG.trials;
EEG.vhtp.eeg_htpCalcChirpItcErsp.amp_rej_trials = num2str(bad_trial_idx);
EEG.vhtp.eeg_htpCalcChirpItcErsp.amp_threshold = amp_threshold;
results =  EEG.vhtp.eeg_htpCalcChirpItcErsp;

end

