function [EEG, results] = eeg_htpCalcChirpItcErsp( EEG, varargin )
% eeg_htpCalcChirpItcErsp() - calculate ITC and single trial power (ERSP)
%      from epoched ERP data. Original code designed for auditory chirp
%      presentation. 
%      Note: newtimef() is a legacy EEGLAB function that is highly
%      dependent on EEGLAB timefreq.m which is frequently updated. Future
%      version of this code will embed relevant itc/ersp functions.
%
% Usage:
%    >> [ EEG ] = eeg_htpCalcChirpItcErsp( EEG )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
%
% Function Specific Inputs:
%     'option1' - description
%
% Common Visual HTP Inputs:
%     'bandDefs'   - cell-array describing frequency band definitions
%     {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 'alpha2', 10.5, 12.5;
%     'beta', 13, 30;'gamma1', 30, 55; 'gamma2', 65, 80; 'epsilon', 81, 120;}
%     'outputdir' - path for saved output files (default: tempdir)
%     
% Outputs:
%     EEG       - EEGLAB Structure with modified .etc.htp field
%     results   - etc.htp results structure or customized
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%    
%  Contact: kyle.cullion@cchmc.org

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

% Inputs: Function Specific
% publication parameters: Ethridge et al. 2019
defaultTLimits = [-500 2750];
defaultFLimits = [2 110];
defaultTimesOut = 250;
defaultCycles  = [1 30];
defaultWinSize = 100;
defaultNFreqs  = 109;
defaultSourceOn = false;
defaultEmptyEEG = true;
defaultAmpThreshold = 120;

% Inputs: Common across Visual HTP functions
defaultOutputDir = tempdir;
defaultBandDefs = {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 
                   'alpha2', 10.5, 12.5; 'beta', 13, 30;'gamma1', 30, 55; 
                   'gamma2', 65, 80; 'epsilon', 81, 120; };

% MATLAB built-in input validation
ip = inputParser();   
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'tlimits',defaultTLimits, @isvector);
addParameter(ip,'flimits',defaultFLimits, @isvector);
addParameter(ip,'cycles',defaultCycles, @isvector);
addParameter(ip,'timesout',defaultTimesOut, @isinteger);
addParameter(ip,'winsize',defaultWinSize, @isinteger);
addParameter(ip,'nfreqs',defaultNFreqs, @isinteger);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder);
addParameter(ip,'bandDefs', defaultBandDefs, @iscell);
addParameter(ip,'sourceOn', defaultSourceOn, @logical);
addParameter(ip, 'emptyEEG', defaultEmptyEEG, @logical)
addParameter(ip, 'ampThreshold', defaultAmpThreshold, @integer)

parse(ip,EEG,varargin{:});

outputdir = ip.Results.outputdir;

% base output file can be modified with strrep()
outputfile = fullfile(outputdir, [functionstamp '_'  EEG.setname '_' timestamp '.mat']); 

% START: Signal Processing

% create critical values correction
for i=1:400, rcrits(i,1)=sqrt(-(1/i)*log(.5)); end

if EEG.trials < 10, error("Low number of trials detected; check epoching."); end

% amplitude based artifact rejection
amp_threshold = ip.Results.ampThreshold;
bad_trial_idx = [];
bad_trial_count=0;
for i = 1 : EEG.trials

    trial_amplitude =abs( mean(EEG.data(:,:,i),3) );
    trial_index = i;

    if any(any(trial_amplitude > amp_threshold))
        bad_trial_count = bad_trial_count +1;
        bad_trial_idx(bad_trial_count) = trial_index;
        bad_trial_label=sprintf("%s epoch: %d", EEG.setname,trial_index);
    end
end
if ~isempty(bad_trial_idx)
    EEG = pop_select(EEG, 'notrial', bad_trial_idx);
    disp(['Removed: ' EEG.setname ' ' num2str(bad_trial_idx)])
end

% define ROI of auditory cortex projection
chirp_electrode_labels = {'E23','E18','E16','E10','E3',...
    'E28','E24','E19','E11','E4','E124','E117',...
    'E29','E20','E12','E5','E118','E111','E13','E6','E112',...
    'E7','E106'};

dksource_labels = {EEG.chanlocs.labels};
chirp_dksource_labels_idx =  contains(dksource_labels,'temporal');
chirp_dksource_labels = dksource_labels(chirp_dksource_labels_idx);

if ip.Results.sourceOn
    chirp_sensors = chirp_dksource_labels;
else
    if EEG.nbchan < 128, error('Insufficient # of Channels. Check if SourceOn = false.'); end
    chirp_sensors = chirp_electrode_labels; 
    chan_label = "Frontal";
end

sensoridx = cell2mat(cellfun(@(x) find(strcmpi(x,{EEG.chanlocs.labels})), ...
    chirp_sensors, 'uni',0));

% define analysis parameters
data               = mean(EEG.data(sensoridx,:,:));
tlimits            = ip.Results.tlimits;
flimits            = ip.Results.flimits; % changed from 120 to 110 - LAD 1/19/22
timesout           = ip.Results.timesout;
cycles             = ip.Results.cycles;
winsize            = ip.Results.winsize;
nfreqs             = ip.Results.nfreqs; % changed from 119 to 109 - LAD 1/19/22

Fs                 = EEG.srate;
trials             = EEG.trials;
EEG.subject        = EEG.setname;

% newtimef() - Return estimates and plots of mean event-related (log) spectral
% perturbation (ERSP) and inter-trial coherence (ITC) events across
% event-related trials (epochs) of a single input channel time series.

[ersp1,itc,~,t_s,f_s] = newtimef(double(data), ...
    EEG.pnts, ...  % frames
    tlimits, ... %tlimits
    Fs, ... %Fs
    cycles,... % varwin (cycles)
    'winsize', winsize, ...
    'nfreqs', nfreqs, ...
    'freqs', flimits, ...
    'plotersp','off',...
    'plotitc','off',...
    'verbose','off',...
    'baseline',NaN,...
    'timesout', timesout);

corrected_itc = (abs(itc))-rcrits(trials);

% results table
findHz = @(hz1,hz2) find(f_s >= hz1 & f_s <= hz2);
findTimes = @(t1,t2) find(t_s >= t1 & t_s <= t2);

%% Identify ROIs: Units are Hz for Frequencies and milliseconds for Times
roi.ERSP_gamma_hz  = {findHz(30,71)}; % edited to LE's final analyzed frequences for gamma - LAD 1/19/22
roi.ERSP_gamma1_hz = {findHz(30,60)};
roi.ERSP_gamma2_hz = {findHz(60,100)};
roi.ERSP_alpha_hz  = {findHz(8,12)};

roi.ErpOnset_hz    = {findHz(2,13)}; % LE's final freq range for onset was 6-13hz - should check with her about this
roi.ErpOnset_ms    = {findTimes(92,308)};
roi.ErpOffset_hz   = {findHz(2,13)};
roi.ErpOffset_ms   = {findTimes(2038,2254)};

roi.ITC40_hz_og    = {findHz(31,42); findHz(43,46); findHz(47,57)};
roi.ITC40_ms_og    = {findTimes(676,784); findTimes(796,980); findTimes(990,1066)};

roi.ITC40_hz = {findHz(30,35); findHz(35,40); findHz(40,45); findHz(45,50); findHz(50,55)};
roi.ITC40_ms = {findTimes(650,850); findTimes(750,950); findTimes(850,1050); ...
    findTimes(950,1150); findTimes(1050,1250)};

roi.ITC80_hz = {find(f_s >= 70 & f_s <=100)};
roi.ITC80_ms = {find(t_s >= 1390 & t_s <= 1930)};

% Summary Functions
computeMeanERSP = @(roi_hz) sum(cellfun(@(hz) mean2(ersp1(hz, :)), ...
    roi_hz)) / numel(roi_hz);

computeMeanITC = @(roi_hz, roi_ms) sum(cellfun(@(hz, ms) mean2(corrected_itc(hz, ms)), ...
    roi_hz, roi_ms)) / numel(roi_hz);

csvRow = { ...
    EEG.subject ...
    EEG.trials ...
    numel(bad_trial_idx) ...
    computeMeanERSP(roi.ERSP_gamma_hz) ...
    computeMeanERSP(roi.ERSP_gamma1_hz) ...
    computeMeanERSP(roi.ERSP_gamma2_hz) ...
    computeMeanERSP(roi.ERSP_alpha_hz) ...
    computeMeanITC(roi.ITC40_hz_og, roi.ITC40_ms_og) ...
    computeMeanITC(roi.ITC40_hz, roi.ITC40_ms) ...
    computeMeanITC(roi.ITC80_hz, roi.ITC80_ms) ...
    computeMeanITC(roi.ErpOnset_hz, roi.ErpOnset_ms) ...
    computeMeanITC(roi.ErpOffset_hz, roi.ErpOffset_ms) ...
    };

if ip.Results.emptyEEG, EEG.data = []; end

csvTable = cell2table(csvRow, "VariableNames", {'eegid','trials','rejtrials','ersp_gamma','ersp_gamma1',...
    'ersp_gamma2', ...
    'ersp_alpha', 'itc40_og', 'itc40', 'itc80', 'erponset', 'erpoffset'});

% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, 'VariableNames', {'eegid','function','timestamp'});

% Outputs: 
EEG.etc.htp.chirp.itc1  = corrected_itc;
EEG.etc.htp.chirp.ersp1 = ersp1;
EEG.etc.htp.chirp.t_s   = t_s;
EEG.etc.htp.chirp.f_s   = f_s;
EEG.etc.htp.chirp.summary_table = csvTable;
EEG.etc.htp.chirp.qi_table = qi_table;
EEG.etc.htp.chirp.trials = EEG.trials;
EEG.etc.htp.chirp.amp_rej_trials = num2str(bad_trial_idx);
EEG.etc.htp.chirp.amp_threshold = amp_threshold;
results = EEG.etc.htp.chirp;

end