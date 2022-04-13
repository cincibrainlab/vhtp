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
%     'averageByRegion' - for source analysis if region_chanlocs,
%     region_itc1 and region_ersp1 is present it will created images
%     based on mean region. Code for DK atlas is present, but can be
%     modified.
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
defaultGroupIds = ones(1,length(EEGcell));
defaultGroupMean = 1;
defaultSingleplot = 1;
defaultAverageByRegion = false;
defaultContrasts = {};
EEGno =  numel(EEGcell);

% MATLAB built-in input validation
ip = inputParser();
errorMsg = 'Group Id vector must be same length as input';
validGroupIds = @(x) assert(numel(x) == EEGno, errorMsg);

errorMsg2 = 'EEG input should be either a cell array or struct.';
validEegArray = @(x) assert(iscell(x) || isstruct(x), errorMsg2);

addRequired(ip, 'EEGcell', validEegArray);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder)
addParameter(ip,'groupids', defaultGroupIds, validGroupIds)
addParameter(ip,'groupmean', defaultGroupMean, @islogical)
addParameter(ip,'singleplot', defaultSingleplot, @islogical)
addParameter(ip, 'averageByRegion', defaultAverageByRegion, @islogical)
addParameter(ip,'contrasts', defaultContrasts, @iscell)

parse(ip,EEGcell,varargin{:});
outputdir = ip.Results.outputdir;

if isstruct(EEGcell)
    warning('Struct passed, converting to Cell.')
    EEGcell = num2cell(EEGcell);
end

% base output file can be modified with strrep()
outfileCell = cellfun( @(EEG) fullfile(outputdir, ...
    [functionstamp '_'  EEG.setname '_' timestamp '.mat']), ...
    EEGcell, 'uni',0);

% if averageByRegions is present will reduce dimensions of channel data by
% averaging into regions.
if ip.Results.averageByRegion
    for ei = 1 : numel(EEGcell)
        EEGcell{ei} = eeg_htpAverageStructByRegion( EEGcell{ei}, 'eeg_htpVisualizeChirpItcErsp');
    end
end

% START: Start Visualization
chanItc = {};
chanErsp = {};
chanStp = {};
% check for multichannel data
if ndims(EEGcell{1}.vhtp.eeg_htpCalcChirpItcErsp.itc1) > 2
    isMultiChannel = true;
    chanlabels = {EEGcell{1}.chanlocs.labels};
    for ei = 1 : numel(EEGcell)
        chanItc{ei}  = EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.itc1;
        chanErsp{ei} = EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.ersp1;
        chanStp{ei}  = EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.stp1;
    end
else
    isMultiChannel = false;
    chanlabels = {'average'};
end

for ci = 1 : numel(chanlabels)
    channame = chanlabels{ci};
    if isMultiChannel
        for ei = 1 : length(EEGcell)
            chanItcNow = chanItc{ei};
            chanErspNow = chanErsp{ei};
            chanStpNow = chanStp{ei};
            EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.itc1 = chanItcNow(:,:,ci);
            EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.ersp1 = chanErspNow(:,:,ci);
            EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.stp1 = chanStpNow(:,:,ci);
        end
    end

    % get groups
    groups = double(unique(ip.Results.groupids));
    group_no = numel(groups);

    % consistent indexes regardless of group or inidividual ERP
    t = EEGcell{1}.vhtp.eeg_htpCalcChirpItcErsp.t_s;
    f = EEGcell{1}.vhtp.eeg_htpCalcChirpItcErsp.f_s;

    % calculate ERP mean, individual ERPs, or single plot ERPs
    plot_title = [];
    if ip.Results.groupmean  % single mean across groups
        plot_title = ['PLACEHOLDER by Group (' channame ')'];
        for ei = 1 : length(EEGcell) % all ERPs in single array
            itcArr(:,:,ei) = EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.itc1;
            erspArr(:,:,ei) = EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.ersp1;
            stpArr(:,:,ei) = EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.stp1;
        end

        for gi = 1 : group_no % mean each by group id
            cur_group_idx = find(ip.Results.groupids == groups(gi));
            plot_title_cell{gi} = sprintf('PLACEHOLDER for group %d (%s)', gi, channame);
            plot_filename_cell{gi} = fullfile(outputdir, ...
                ['chirp_itcersp_by_group_' channame '_' num2str(gi) '_' timestamp '.png']);
            itc(:,:,gi) = mean(itcArr(:,:,cur_group_idx),3);
            ersp(:,:,gi) = mean(erspArr(:,:,cur_group_idx),3);
            stp(:,:,gi) = mean(stpArr(:,:,cur_group_idx),3);

        end
        % Perform contrasts and add as additional groups
        if ~isempty(ip.Results.contrasts)
            contrasts = ip.Results.contrasts;
            for contrast_i = 1 : numel(contrasts)
                select_contrast = contrasts{contrast_i};
                group_no = group_no + 1;

                itc(:,:,group_no) = itc(:,:,select_contrast(1)) - itc(:,:,select_contrast(2));
                ersp(:,:,group_no) = ersp(:,:,select_contrast(1)) - ersp(:,:,select_contrast(2));
                stp(:,:,group_no) = stp(:,:,select_contrast(1)) - stp(:,:,select_contrast(2));

                plot_title_cell{group_no} = sprintf('PLACEHOLDER for group diff %d_%d (%s)', select_contrast(1), select_contrast(2), channame);
                plot_filename_cell{group_no} = fullfile(outputdir, ...
                    ['chirp_itcersp_by_groupdiff_' channame '_' sprintf('%d_%d', select_contrast(1), select_contrast(2)) '_' timestamp '.png']);

            end

        
        end

    else  % individual results
        for ei = 1 : length(EEGcell)
            if ip.Results.singleplot && ei == 1 && ~ip.Results.groupmean
                plot_title = 'PLACEHOLDER by Recording';
                plot_filename = fullfile(outputdir,['chirp_itcersp_by_recording_' channame '_' timestamp '.png']);
                plot_title_cell{ei} = sprintf('PLACEHOLDER for %s (%s)', EEGcell{ei}.setname, channame);
                plot_filename_cell{ei} = fullfile(outputdir, ...
                    ['chirp_itcersp_' channame '_' matlab.lang.makeValidName(EEGcell{ei}.setname) '.png']);

            else
                plot_title_cell{ei} = sprintf('PLACEHOLDER for %s (%s)', EEGcell{ei}.setname, channame);
                plot_filename_cell{ei} = fullfile(outputdir, ...
                    ['chirp_itcersp_' channame '_' matlab.lang.makeValidName(EEGcell{ei}.setname) '.png']);
            end
            itc(:,:,ei) = EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.itc1;
            ersp(:,:,ei) = EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.ersp1;
            stp(:,:,ei) = EEGcell{ei}.vhtp.eeg_htpCalcChirpItcErsp.stp1;
        end
        
    end

    if ip.Results.singleplot
        for gi = 1 : group_no
            figure('Position', [600 600 1200 700]);
            subplot(1,3,1)
            createPlot_chirpItc(t, f, itc(:,:,gi), ...
                strrep(plot_title_cell{gi},'PLACEHOLDER','ITC'));
            subplot(1,3,2)
            createPlot_chirpStp(t, f, stp(:,:,gi), ...
                strrep(plot_title_cell{gi},'PLACEHOLDER','ERSP'));
            subplot(1,3,3)
            createPlot_chirpErsp(t, f, ersp(:,:,gi), ...
                strrep(plot_title_cell{gi},'PLACEHOLDER','ERSP'));
            sgtitle(strrep(plot_title_cell{gi},'PLACEHOLDER','Chirp Plots'));
            saveas(gcf, plot_filename_cell{gi});
            close all;
        end
    else
        for si = 1 : size(itc,3)
            figure('Position', [600 600 1200 700]);
            subplot(1,3,1)
            createPlot_chirpItc(t, f, itc(:,:,si), ...
                'ITC');
            subplot(1,3,2)
            createPlot_chirpStp(t, f, stp(:,:,si), ...
                'STP');
            subplot(1,3,3)
            createPlot_chirpErsp(t, f, ersp(:,:,si), ...
                'ERSP');
            sgtitle(strrep(plot_title_cell{si},'PLACEHOLDER','Chirp Plots'));
            saveas(gcf, plot_filename_cell{si});
            close all;
        end
    end
end

% END: End Visualization

% QI Table
qi_table = cellfun( @(EEG) ...
    cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'}), ...
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
%ylim(h,[0 .2]);
if contains(plot_title, 'diff')
    caxis([-.03 .03]); % important
else
    max_itc = .2;
    if max(max(itc)) > max_itc
        % axis([0 1]); % important
        plot_title = [plot_title ' (EXCEEDS UPPER LIMIT ' num2str(max_itc) ')' ];
    else
        caxis([0 .2]); % important
    end
end
pbaspect([1 1 1]);
title(plot_title);

end

function fig = createPlot_chirpStp(t, f, stp,plot_title)

set(0,'defaultTextInterpreter','none');
colormap jet;
imagesc(t,f,stp); axis xy;
xlabel('Time (ms)'); ylabel('Frequency (Hz)');
h = colorbar;
ylabel(h,'Power (dB/Hz) ');
%ylim(h,[0 45]);
if contains(plot_title, 'diff')
    caxis([-5 5]); % important
else
    max_stp = -190;
    if max(max(stp)) > max_stp
        % axis([0 1]); % important
        plot_title = [plot_title ' (EXCEEDS UPPER LIMIT ' num2str(max_stp) ')' ];
    else
        caxis([-215 -190]); % important
    end
 %   caxis([-215 -190]);
end

pbaspect([1 1 1]);
title(plot_title);

end

function fig = createPlot_chirpErsp(t, f, ersp,plot_title)

set(0,'defaultTextInterpreter','none');
colormap jet;
imagesc(t,f,ersp); axis xy;
xlabel('Time (ms)'); ylabel('Frequency (Hz)');
h = colorbar;
ylabel(h,'Power (dB/Hz) Change from Baseline');
%ylim(h,[0 45]);
if contains(plot_title, 'diff')
    caxis([-5 5]); % important
else
    
%    caxis([-215 -190]);
end

pbaspect([1 1 1]);
title(plot_title);

end
