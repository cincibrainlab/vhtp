function [EEG, results] = eeg_htpCalcHabErp( EEG, varargin )
% eeg_htpCalcHabErp() - Amplitude, latency, and percent change 
% (habituation) in N1 and P2 event-related potential (ERP) components 
% calculated from habituation task (Ethridge 2019).
%
% Usage:
%    >> [ EEG ] = eeg_htpCalcHabErp( EEG, varargin )
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
addParameter(ip, 'ampThreshold', defaultAmpThreshold, @integer)

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
EEG = pop_rmbase(EEG, ip.Results.baseline);
if ip.Results.filtOn, EEG = pop_eegfiltnew(EEG, 'hicutoff', 40); end

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
erp                = mean(data,2);
t                  = EEG.times;
Fs                 = EEG.srate;
trials             = EEG.trials;

% define ROI indexes
tidx = @(idx) find(t >= idx(1) & t <= idx(2));

% define ROIs in miliseconds
stimulus_times = [0 500 1000 1500];

n1_min_roi_delay = 50; % miliseconds following stimulus
p2_min_roi_delay = 130; % miliseconds following stimulus
roi_change = 1.2;  % proportion increase on original delay
roi_duration     = 125;

% define search windows for amplitude/latency
% n1_roi_start = n1_min_roi_delay * [1 1.2 1.3 1.4] + stimulus_times; % delay for each repetition
% p2_roi_start = p2_min_roi_delay * [1 1.2 1.3 1.4] + stimulus_times; % delay for each repetition
% n1_roi = [n1_roi_start; n1_roi_start + roi_duration]';
% p2_roi = [p2_roi_start; p2_roi_start + roi_duration]';

% revised 1/28/22 following timing testing
n1_roi_start = [76 594 1110 1628];
n1_roi = [n1_roi_start; n1_roi_start + [100 100 100 100]]';
p2_roi_start = [126 644 1160 1678];
p2_roi = [p2_roi_start; p2_roi_start + [100 100 100 100]]';


% % OG N1
% n1a_idx = tidx([50 130]); % original index: 276:316
% n1b_idx = tidx([562 642]); % original index 532:572;
% n1c_idx = tidx([1076 1156]); % original index t(789:829);
% n1d_idx = tidx([1596 1676]); % original index t(1049:1089);
% 
% % OG P2
% p2a_idx = tidx([130 210]); %t(316:356);
% p2b_idx = tidx([648 728]); %t(575:615);
% p2c_idx = tidx([1168 1248]); %t(835:875);
% p2d_idx = tidx([1684 1764]); %t(1093:1133);

% N1 Algorithmic Defined Indexes
n1a_idx = tidx(n1_roi(1,:));
n1b_idx = tidx(n1_roi(2,:));
n1c_idx = tidx(n1_roi(3,:));
n1d_idx = tidx(n1_roi(4,:));

% P2 Algorithmic Defined Indexes
p2a_idx = tidx(p2_roi(1,:));
p2b_idx = tidx(p2_roi(2,:));
p2c_idx = tidx(p2_roi(3,:));
p2d_idx = tidx(p2_roi(4,:));

[N1, N1idx] = cellfun( @(idx) min(erp(idx)), {n1a_idx, n1b_idx, n1c_idx, n1d_idx});
[P2, P2idx] = cellfun( @(idx) max(erp(idx)), {p2a_idx, p2b_idx, p2c_idx, p2d_idx});

N1PC = (N1(1) - N1(2:4)) / N1(1);
P2PC = (P2(1) - P2(2:4)) / P2(1);

N1Latency = [t(n1a_idx(N1idx(1))) t(n1b_idx(N1idx(2))) ...
    t(n1c_idx(N1idx(3))) t(n1d_idx(N1idx(4)))];
P2Latency = [t(p2a_idx(P2idx(1))) t(p2b_idx(P2idx(2))) ...
    t(p2c_idx(P2idx(3))) t(p2d_idx(P2idx(4)))];

if ip.Results.plotsOn
    set(0,'defaultTextInterpreter','none');
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
    'VariableNames', {'eegid','function','timestamp'});

% Outputs: 
EEG.etc.htp.hab.erp = erp';
EEG.etc.htp.hab.times = t;
EEG.etc.htp.hab.n1idx = [n1a_idx n1b_idx n1c_idx n1d_idx];
EEG.etc.htp.hab.p2idx = [p2a_idx p2b_idx p2c_idx p2d_idx];
EEG.etc.htp.hab.N1Lat = N1Latency;
EEG.etc.htp.hab.P2Lat = P2Latency;
EEG.etc.htp.hab.trials = EEG.trials;
EEG.etc.htp.hab.amp_rej_trials = num2str(bad_trial_idx);
EEG.etc.htp.hab.amp_threshold = amp_threshold;
EEG.etc.htp.hab.summary_table = [inforow resultsrow];
EEG.etc.htc.hab.qi_table = qi_table;
results = EEG.etc.htp.hab;

end