function [EEGcell, results] = eeg_htpVisualizeHabErp( EEGcell, varargin )
% eeg_htpVisualizeHabErp() - Creates ERP plots from eeg_htpCalcHabErp.
%
% Usage:
%    >> [ EEGcell, results ] = eeg_htpVisualizeHabErp( EEGcell )
%
% Require Inputs:
%     EEGcell       - cell array of EEGLAB Structures
% Function Specific Inputs:
%     'outputdir' - output directory for save files
%     'groupIds'  - vector length of EEGcell with integers representing
%                   groups
%     'groupmean' - (true/false) average across groups
%     'singleplot'- (true/false) One plot for group and individual (multiline)
%
% Common Visual HTP Inputs:
%     'bandDefs'   - cell array describing frequency band definitions
%     {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 'alpha2', 10.5, 12.5;
%     'beta', 13, 30;'gamma1', 30, 55; 'gamma2', 65, 80; 'epsilon', 81, 120;}
%     'outputdir' - path for saved output files (default: tempdir)
%     
% Outputs:
%     EEGcell       - cell array of EEGLAB Structure with modified .etc.htp field
%     results   - etc.htp results structure or customized
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%    
%  Contact: kyle.cullion@cchmc.org

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

% Inputs: Function Specific

% Inputs: Common across Visual HTP functions
defaultOutputDir = tempdir;
defaultBandDefs = {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 
                   'alpha2', 10, 12; 'beta', 13, 30;'gamma1', 30, 55; 
                   'gamma2', 65, 80; 'epsilon', 81, 120; };
defaultGroupIds = ones(1,length(EEGcell));
defaultGroupMean = 1;
defaultSingleplot = 1;


% MATLAB built-in input validation
ip = inputParser();   
addRequired(ip, 'EEGcell', @iscell);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder)
addParameter(ip,'bandDefs', defaultBandDefs, @iscell)
addParameter(ip,'groupids', defaultGroupIds, @isvector)
addParameter(ip,'groupmean', defaultGroupMean, @islogical)
addParameter(ip,'singleplot', defaultSingleplot, @islogical)

parse(ip,EEGcell,varargin{:});

outputdir = ip.Results.outputdir;
bandDefs = ip.Results.bandDefs;

% base output file can be modified with strrep()
outfileCell = cellfun( @(EEG) fullfile(outputdir, ...
    [functionstamp '_'  EEG.setname '_' timestamp '.mat']), EEGcell, 'uni',0);

% START: Start Visualization

% get groups
groups = unique(ip.Results.groupids);
group_no = numel(groups);

% consistent indexes regardless of group or inidividual ERP
t = EEGcell{1}.etc.htp.hab.times;
n1idx = EEGcell{1}.etc.htp.hab.n1idx; % get window size
p2idx = EEGcell{1}.etc.htp.hab.p2idx;

% calculate ERP mean, individual ERPs, or single plot ERPs
plot_title = [];
if ip.Results.groupmean  % single mean across groups
    plot_title = 'ERP average waveform by Group';
    plot_filename = fullfile(outputdir,['hab_erp_by_group_' timestamp '.png']);
    for ei = 1 : length(EEGcell) % all ERPs in single array
        erpArr(ei,:) = EEGcell{ei}.etc.htp.hab.erp;
    end

    for gi = 1 : group_no % mean each by group id
        cur_group_idx(gi,:) = find(ip.Results.groupids(ip.Results.groupids == groups(gi)));
        erp(gi,:) = mean(erpArr(cur_group_idx(gi,:),:),1);
    end
else  % individual results
    for ei = 1 : length(EEGcell)
        if ip.Results.singleplot && ei == 1 && ~ip.Results.groupmean
            plot_title = 'ERP average waveform by Recording';
            plot_filename = fullfile(outputdir,['hab_erp_by_recording_' timestamp '.png']);
        else
            plot_title_cell{ei} = sprintf('Average ERP for %s (Trials: Ret: %s, Rej: %s)', ...
                EEGcell{ei}.setname, num2str(EEGcell{ei}.etc.htp.hab.trials), EEGcell{ei}.etc.htp.hab.amp_rej_trials);
            plot_filename_cell{ei} = fullfile(outputdir, ...
                ['hab_erp_' matlab.lang.makeValidName(EEGcell{ei}.setname) '.png']);
        end
           erp(ei,:) = EEGcell{ei}.etc.htp.hab.erp;
    end
end

if ip.Results.singleplot % all single plot group or multi individual
    [N1,P2,N1Lat, P2Lat, n1_roi, p2_roi] = calcErpFeatures(erp, t, EEGcell{1}.srate);
    createPlot_habERP(t, erp, n1idx,p2idx,N1Lat, P2Lat, plot_title);
    saveas(gcf, plot_filename);
    %close gcf;
else
    for si = 1 : size(erp,1)
        [N1,P2,N1Lat, P2Lat, n1_roi, p2_roi] = calcErpFeatures(erp(si,:), t, EEGcell{si}.srate);
        createPlot_habERP(t, erp(si,:), n1idx,p2idx,N1Lat, P2Lat, plot_title_cell{si});
        saveas(gcf, plot_filename_cell{si});
        close gcf;
    end
end

% END: End Visualization

% QI Table
qi_table = cellfun( @(EEG) ...
    cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','function','timestamp'}), EEGcell, 'uni',0);

% Outputs:
results = [];
end

function createPlot_habERP(t, erp, n1idx,p2idx, N1Lat, P2Lat, plot_title)

stimoffsets = [0 500 1000 1500];
stimoffsets_actual = [25 545 1061 1579];

figure('Position', [600 300 1200 900]);
set(0,'defaultTextInterpreter','none');
roi_strip = nan(1,length(erp));
roi_strip2 = roi_strip;
roi_strip([n1idx]) = -.5;
roi_strip2([p2idx]) =  .5;
plot(t,roi_strip,'b.'); hold on;
plot(t,roi_strip2,'r.');
xline(stimoffsets,'-',{'DIN1','DIN2','DIN3','DIN4'},'LabelHorizontalAlignment','center','LabelVerticalAlignment','middle'  );
xline(stimoffsets_actual,':',{'S1','R1','R2','R3'} ,'LabelHorizontalAlignment','center','LabelVerticalAlignment','bottom' );

    for i = 1 : length(N1Lat)
        xline(N1Lat(i),'b:',{['N1:' num2str(N1Lat(i)-stimoffsets_actual(i))]});
    end
    for i = 1 : length(P2Lat)
        xline(P2Lat(i),'r:',{['P2: ' num2str(P2Lat(i)-stimoffsets_actual(i))]});
    end
% hold on;
plot(t,erp); xlabel('Time (ms)'); ylabel('Amplitude (microvolts)');
ylim([-10 10])
title(plot_title);
end


function [N1,P2,N1Lat, P2Lat, n1_roi, p2_roi] = calcErpFeatures(erp, t, Fs)

% define ROI indexes
tidx = @(idx) find(t >= idx(1) & t <= idx(2));

% define ROIs in miliseconds
stimulus_times = [0 500 1000 1500];

% define search windows for amplitude/latency
% revised 1/28/22 following timing testing
n1_roi_start = [76 594 1110 1628];
n1_roi = [n1_roi_start; n1_roi_start + [100 100 100 100]]';
p2_roi_start = [126 644 1160 1678];
p2_roi = [p2_roi_start; p2_roi_start + [100 100 100 100]]';

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

N1Lat = [t(n1a_idx(N1idx(1))) t(n1b_idx(N1idx(2))) ...
    t(n1c_idx(N1idx(3))) t(n1d_idx(N1idx(4)))];
P2Lat = [t(p2a_idx(P2idx(1))) t(p2b_idx(P2idx(2))) ...
    t(p2c_idx(P2idx(3))) t(p2d_idx(P2idx(4)))];

end
