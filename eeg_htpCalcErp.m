function [EEG, results] = eeg_htpCalcErp( EEG, varargin )
% eeg_htpCalcErp() - Amplitude, latency, and percent change 
% general ERP function
%
% Usage:
%    >> [ EEG ] = eeg_htpCalcErp( EEG, varargin )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
% Function Specific Inputs:
%     EEG       - EEGLAB Structure
%     plotsOn   - ERP plot with extraction ROI bars
%     baseline  - Baseline latency range in milliseconds [start end]
%     filtOn    - 40 Hz high cutoff filter (default: true)
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
%  Contact: lauren.ethridge@ou.edu (Original algorithm)
%           ernest.pedapati@cchmc.org (EEGLAB function adaption)
%

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

% Inputs: Function Specific
defaultPlotsOn = 0;
defaultBaseline = [-500 0];
defaultFiltOn = 1;
defaultAmpThreshold = 120;
defaultTimeFreq = false;


% Inputs: Common across Visual HTP functions
defaultOutputDir = tempdir;
defaultBandDefs = {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 
                   'alpha2', 10.5, 12.5; 'beta', 13, 30;'gamma1', 30, 55; 
                   'gamma2', 65, 80; 'epsilon', 81, 120; };

% MATLAB built-in input validation
ip = inputParser();   
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'plotsOn', defaultPlotsOn);
addParameter(ip,'baseline', defaultBaseline);
addParameter(ip, 'filtOn', defaultFiltOn,@islogical);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder);
addParameter(ip,'bandDefs', defaultBandDefs, @iscell);
addParameter(ip, 'ampThreshold', defaultAmpThreshold, @isnumeric)
addParameter(ip, 'timefreq', defaultTimeFreq, @islogical);

parse(ip,EEG,varargin{:});

outputdir = ip.Results.outputdir;
bandDefs = ip.Results.bandDefs;

% base output file can be modified with strrep()
outputfile = fullfile(outputdir, [functionstamp '_'  EEG.setname '_' timestamp '.mat']); 

% START: Signal Processing
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

% remove baseline
EEG_og = EEG;
EEG = pop_rmbase(EEG, ip.Results.baseline);
if ip.Results.filtOn, EEG = pop_eegfiltnew(EEG, 'hicutoff', 30); end

% define ROI of auditory cortex projection
chirp_sensor_labels = {'E23','E18','E16','E10','E3',...
    'E28','E24','E19','E11','E4','E124','E117',...
    'E29','E20','E12','E5','E118','E111','E13','E6','E112',...
    'E7','E106'};

% find sensor indexes
sensoridx = cell2mat(cellfun(@(x) find(strcmpi(x,{EEG.chanlocs.labels})), ...
    chirp_sensor_labels, 'uni',0));

% define analysis parameters
data               = squeeze(mean(EEG.data(sensoridx,:,:)));
data_og            = squeeze(mean(EEG_og.data(sensoridx,:,:)));
erp                = mean(data,2);
t                  = EEG.times;
Fs                 = EEG.srate;
trials             = EEG.trials;

if ip.Results.timefreq 
% specifically for ITC/ERSP
tlimits = [-500 2750];
cycles = [1 30];
winsize = 100;
nfreqs = 109;
flimits = [1 120];
baselinew = -500;
timesout = 250;

% optional ITC and ERSP
     [ersp1, itc, ~, t_s, f_s] = newtimef(double(data_og), ...
        EEG.pnts, ... % frames
        tlimits, ... %tlimits
        Fs, ... %Fs
        cycles, ... % varwin (cycles)
        'winsize', winsize, ...
        'nfreqs', nfreqs, ...
        'freqs', flimits, ...
        'plotersp', 'on', ...
        'plotitc', 'on', ...
        'verbose', 'on', ...
        'baseline', [-500 0], ...
        'timesout', timesout);
end


if ip.Results.plotsOn
    set(0,'defaultTextInterpreter','tex');
    roi_strip = nan(1,length(erp));
    roi_strip([n1a_idx n1b_idx n1c_idx n1d_idx]) = -.5;
    roi_strip([p2a_idx p2b_idx p2c_idx p2d_idx]) =  .5;
    figure;
    plot(t,erp); xlabel('Time (ms)'); ylabel('Amplitude (microvolts)');
    hold on;
    plot(t,roi_strip,'k.')
    title(sprintf('ERP average waveforms for %s', EEG.setname));
    xline(0);
    xline(500);
    xline(1000);
    xline(1500);
    for i = 1 : length(N1Latency)
        xline(N1Latency(i),'b:');
    end
    for i = 1 : length(P2Latency)
        xline(N1Latency(i),'r:');
    end
    %xlim([500 1000])
end

inforow = cell2table({EEG.setname EEG.trials numel(bad_trial_idx)}, ...
    'VariableNames', {'eegid','trials', 'rejtrials'});
resultsrow = array2table([N1 P2 N1PC P2PC N1Latency P2Latency], ...
    'VariableNames', {'N1R1','N1R2',...
    'N1R3', 'N1R4', 'P2R1', 'P2R2', 'P2R3', 'P2R4', ...
    'N1PerR2', 'N1PerR3', 'N1PerR4', 'P2PerR2', 'P2PerR3', 'P2PerR4', ...
    'N1R1_lat', 'N1R2_lat', 'N1R3_lat', 'N1R4_lat',...
    'P2R1_lat', 'P2R2_lat', 'P2R3_lat', 'P2R4_lat'});

% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});

% Outputs: 
EEG.vhtp.eeg_htpCalcHabErp.erp = erp';
EEG.vhtp.eeg_htpCalcHabErp.times = t;
EEG.vhtp.eeg_htpCalcHabErp.n1idx = [n1a_idx n1b_idx n1c_idx n1d_idx];
EEG.vhtp.eeg_htpCalcHabErp.p2idx = [p2a_idx p2b_idx p2c_idx p2d_idx];
EEG.vhtp.eeg_htpCalcHabErp.N1Lat = N1Latency;
EEG.vhtp.eeg_htpCalcHabErp.P2Lat = P2Latency;
EEG.vhtp.eeg_htpCalcHabErp.trials = EEG.trials;
EEG.vhtp.eeg_htpCalcHabErp.amp_rej_trials = num2str(bad_trial_idx);
EEG.vhtp.eeg_htpCalcHabErp.amp_threshold = amp_threshold;
EEG.vhtp.eeg_htpCalcHabErp.summary_table = [inforow resultsrow];
EEG.etc.htc.hab.qi_table = qi_table;
results = EEG.vhtp.eeg_htpCalcHabErp;

end