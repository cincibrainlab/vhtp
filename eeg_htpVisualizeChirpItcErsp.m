function [EEGcell, results] = eeg_htpVisualizeChirpItcErsp( EEGcell, varargin )
% eeg_htpVisualizeChirpItcErsp() - Creates ERP plots from eeg_htpCalcChirpItcErsp.
%
% Usage:
%    >> [ EEGcell, results ] = eeg_htpVisualizeChirpItcErsp( EEGcell )
%
% Require Inputs:
%     EEGcell       - cell array of EEGLAB Structures
% Function Specific Inputs:
%     'outputdir' - output directory for save files
%     'groupIds'  - vector length of EEGcell with integers representing
%                   groups
%     'groupmean' - (true/false) average across groups
%     'singleplot'- (true/false) One plot for group and individual (multiline)
%     'contrasts' - cell array of contrast pairs with group indexes {{1,2}}
%     = group 1- group 2
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

EEGno =  numel(EEGcell);

% MATLAB built-in input validation
ip = inputParser();   
errorMsg = 'Group Id vector must be same length as input'; 
validGroupIds = @(x) assert(numel(x) == EEGno, errorMsg);

addRequired(ip, 'EEGcell', @iscell);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder)
addParameter(ip,'bandDefs', defaultBandDefs, @iscell)
addParameter(ip,'groupids', defaultGroupIds, validGroupIds)
addParameter(ip,'groupmean', defaultGroupMean, @islogical)
addParameter(ip,'singleplot', defaultSingleplot, @islogical)

parse(ip,EEGcell,varargin{:});
outputdir = ip.Results.outputdir;
bandDefs = ip.Results.bandDefs;

% base output file can be modified with strrep()
outfileCell = cellfun( @(EEG) fullfile(outputdir, ...
    [functionstamp '_'  EEG.setname '_' timestamp '.mat']), ...
    EEGcell, 'uni',0);

% START: Start Visualization

% get groups
groups = double(unique(ip.Results.groupids));
group_no = numel(groups);

% consistent indexes regardless of group or inidividual ERP
t = EEGcell{1}.etc.htp.chirp.t_s;
f = EEGcell{1}.etc.htp.chirp.f_s;

% calculate ERP mean, individual ERPs, or single plot ERPs
plot_title = [];
if ip.Results.groupmean  % single mean across groups
    plot_title = 'PLACEHOLDER by Group';
    for ei = 1 : length(EEGcell) % all ERPs in single array
        itcArr(:,:,ei) = EEGcell{ei}.etc.htp.chirp.itc1;
        erspArr(:,:,ei) = EEGcell{ei}.etc.htp.chirp.ersp1;
    end
    
    for gi = 1 : group_no % mean each by group id
        cur_group_idx = find(ip.Results.groupids == groups(gi));
        plot_title_cell{gi} = sprintf('PLACEHOLDER for group %d', gi);
        plot_filename_cell{gi} = fullfile(outputdir, ...
            ['chirp_itcersp_by_group' num2str(gi) '_' timestamp '.png']);
        itc(:,:,gi) = mean(itcArr(:,:,cur_group_idx),3);
        ersp(:,:,gi) = mean(erspArr(:,:,cur_group_idx),3);
    end
else  % individual results
    for ei = 1 : length(EEGcell)
        if ip.Results.singleplot && ei == 1 && ~ip.Results.groupmean
            plot_title = 'PLACEHOLDER by Recording';
            plot_filename = fullfile(outputdir,['chirp_itcersp_by_recording_' timestamp '.png']);
        else
            plot_title_cell{ei} = sprintf('PLACEHOLDER for %s', EEGcell{ei}.setname);
            plot_filename_cell{ei} = fullfile(outputdir, ...
                ['chirp_itcersp_' matlab.lang.makeValidName(EEGcell{ei}.setname) '.png']);
        end
           itc(:,:,ei) = EEGcell{ei}.etc.htp.chirp.itc1;
           ersp(:,:,ei) = EEGcell{ei}.etc.htp.chirp.ersp1;
    end
end

if ip.Results.singleplot 
    for gi = 1 : group_no
        figure('Position', [600 600 1200 700]);
        subplot(1,2,1)
        createPlot_chirpItc(t, f, itc(:,:,gi), ...
            strrep(plot_title_cell{gi},'PLACEHOLDER','ITC'));
        subplot(1,2,2)
        createPlot_chirpErsp(t, f, ersp(:,:,gi), ...
            strrep(plot_title_cell{gi},'PLACEHOLDER','ERSP'));
        sgtitle(strrep(plot_title_cell{gi},'PLACEHOLDER','Chirp Plots'));
        saveas(gcf, plot_filename_cell{gi});
        close all;
    end
else
    for si = 1 : size(itc,3)
        figure('Position', [600 600 1200 700]);
        subplot(1,2,1)
        createPlot_chirpItc(t, f, itc(:,:,si), ...
            strrep(plot_title_cell{si},'PLACEHOLDER','ITC'));
        subplot(1,2,2)
        createPlot_chirpErsp(t, f, ersp(:,:,si), ...
            strrep(plot_title_cell{si},'PLACEHOLDER','ERSP'));
        sgtitle(strrep(plot_title_cell{si},'PLACEHOLDER','Chirp Plots'));
        saveas(gcf, plot_filename_cell{si});
        close all;
    end
end

% END: End Visualization

% QI Table
qi_table = cellfun( @(EEG) ...
    cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','function','timestamp'}), ...
    EEGcell, 'uni',0);

% Outputs:
results = [];
end

function fig = createPlot_chirpItc(t, f, itc, plot_title)

set(0,'defaultTextInterpreter','none');
colormap jet;
imagesc(t,f,itc); axis xy;
xlabel('Time (ms)'); ylabel('Frequency (Hz)');
h = colorbar;
ylabel(h,'Intertrial Coherence (ITC)');
ylim(h,[0 .2]);
pbaspect([1 1 1]);
title(plot_title);

end

function fig = createPlot_chirpErsp(t, f, ersp,plot_title)

set(0,'defaultTextInterpreter','none');
colormap jet;
imagesc(t,f,ersp); axis xy;
xlabel('Time (ms)'); ylabel('Frequency (Hz)');
h = colorbar;
ylabel(h,'Power (microvolts) ');
ylim(h,[0 45]);
pbaspect([1 1 1]);
title(plot_title);

end
