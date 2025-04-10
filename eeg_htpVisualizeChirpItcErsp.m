function [EEGcell, results] = eeg_htpVisualizeChirpItcErsp( EEGcell, varargin )
% Description: Creates ERP plots from eeg_htpCalcChirpItcErsp.
% ShortTitle: Visualize Chirp ERP analysis
% Category: Analysis
% Tags: ERP
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
defaultDiffColorLimits = [];
defaultChannel = missing;
EEGno =  numel(EEGcell);
defaultUseRawItc = false;

% MATLAB built-in input validation
ip = inputParser();
errorMsg = 'Group Id vector must be same length as input';
validGroupIds = @(x) assert(numel(x) == EEGno, errorMsg);

errorMsg2 = 'EEG input should be either a cell array or struct.';
validEegArray = @(x) assert(iscell(x) || isstruct(x), errorMsg2);

addRequired(ip, 'EEGcell', validEegArray);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder);
addParameter(ip,'groupids', defaultGroupIds, validGroupIds);
addParameter(ip,'groupmean', defaultGroupMean, @islogical);
addParameter(ip,'singleplot', defaultSingleplot, @islogical);
addParameter(ip, 'averageByRegion', defaultAverageByRegion, @islogical);
addParameter(ip,'contrasts', defaultContrasts, @iscell);
addParameter(ip,'diffColorLimits', defaultDiffColorLimits, @isvector);
addParameter(ip,'channel', defaultChannel, @ischar); % specific channel for plotting
addParameter(ip,'useRawItc', defaultUseRawItc, @logical); 

parse(ip,EEGcell,varargin{:});
outputdir = ip.Results.outputdir;
isDiff = false;

if isstruct(EEGcell)
    warning('Struct passed, converting to Cell.')
    EEGcell = num2cell(EEGcell);
end

if ip.Results.useRawItc

    for idx = 1:numel(EEGcell)
        if isfield(EEGcell{idx}, 'vhtp') && ...
           isfield(EEGcell{idx}.vhtp, 'eeg_htpCalcChirpItcErsp')
            EEGcell{idx}.vhtp.eeg_htpCalcChirpItcErsp.itc1 = ...
                EEGcell{idx}.vhtp.eeg_htpCalcChirpItcErsp.rawitc1;
        else
            warning('EEGCell{%d} is missing required fields.', idx);
        end
    end

end

% base output file can be modified with strrep()
outfileCell = cellfun( @(EEG) fullfile(outputdir, ...
    [functionstamp '_'  EEG.setname '_' timestamp '.mat']), ...
    EEGcell, 'uni',0);

% if averageByRegions is present will reduce dimensions of channel data by
% averaging into regions.
if ip.Results.averageByRegion
    for ei = 1 : numel(EEGcell)
        EEGcell{ei} = eeg_htpAverageStructByRegion( EEGcell{ei}, 'scriptname','eeg_htpVisualizeChirpItcErsp');
    end
end

% % filter for specific channel if needed
% chanOfInterest = ip.Results.channel;
% if ~ismissing(chanOfInterest)
% fprintf("Single Channel Mode: %s\n", chanOfInterest);
% if any(strcmp(chanOfInterest, {EEGcell{1}.chanlocs.labels}))
%     for i = 1 : numel(EEGcell)
%         chanIdx = find(strcmp(chanOfInterest, {EEGcell{i}.chanlocs.labels}));
%         EEGcell{i}.chanlocs = EEGcell{i}.chanlocs{chanIdx};
%     end
% else
%     fprintf("%s channel not found, check input.\n", chanOfInterest);
% end
% end

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
    if iscell(ip.Results.groupids) || iscategorical(ip.Results.groupids)
        groups = unique(categorical(ip.Results.groupids));
        group_list = ip.Results.groupids;
    else
        groups = double(unique(ip.Results.groupids));
        group_list = categorical(ip.Results.groupids);
    end
    group_no = numel(unique(groups));

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
            group_names{gi} =  num2str(groups(gi));
            plot_title_cell{gi} = sprintf('PLACEHOLDER for group %s (%s)',  char(groups(gi)), channame);
            plot_filename_cell{gi} = fullfile(outputdir, ...
                ['chirp_itcersp_by_group_' channame '_' num2str(groups(gi)) '_' timestamp '.png']);
            itc(:,:,gi) = mean(itcArr(:,:,cur_group_idx),3, "omitnan");
            ersp(:,:,gi) = mean(erspArr(:,:,cur_group_idx),3, "omitnan");
            stp(:,:,gi) = mean(stpArr(:,:,cur_group_idx),3, "omitnan");

        end
        % Perform contrasts and add as additional groups
        get_id = @(x) find(strcmp(group_names, x));

        if ~isempty(ip.Results.contrasts)
            contrasts = ip.Results.contrasts;
            isDiff = true;
            for contrast_i = 1 : numel(contrasts)
                select_contrast = contrasts{contrast_i};
                group_no = group_no + 1;

                %id1 = get_id(select_contrast(1));
                %id2 = get_id(select_contrast(2));

                id1 = select_contrast{1};
                id2 = select_contrast{2};

                itc(:,:,group_no) = itc(:,:,id1) - itc(:,:,id2);
                ersp(:,:,group_no) = ersp(:,:,id1) - ersp(:,:,id2);
                stp(:,:,group_no) = stp(:,:,id1) - stp(:,:,id2);

                plot_title_cell{group_no} = sprintf('PLACEHOLDER for group diff\n%s_%s (%s)',select_contrast{1}, select_contrast{2}, channame);
                plot_filename_cell{group_no} = fullfile(outputdir, ...
                    ['chirp_itcersp_by_groupdiff_' channame '_' sprintf('%s_%s',num2str(select_contrast{1}), num2str(select_contrast{2})) '_' timestamp '.png']);
            end
        else
            ifDiff = false;
        end

    else  % individual results
        for ei = 1 : length(EEGcell)
            if ip.Results.singleplot && ei == 1 && ~ip.Results.groupmean
                plot_title = 'PLACEHOLDER by Recording';
                plot_filename = fullfile(outputdir,['chirp_itcersp_by_recording_' channame '_' timestamp '.png']);
                [~, temp_plot_name, ~] = fileparts(EEGcell{ei}.filename);
                plot_title_cell{ei} = sprintf('PLACEHOLDER for %s (%s)', temp_plot_name, channame);
                plot_filename_cell{ei} = fullfile(outputdir, ...
                    [temp_plot_name 'chirp_itc' channame '.png']);

            else
                [~, temp_plot_name, ~] = fileparts(EEGcell{ei}.filename);
                plot_title_cell{ei} = sprintf('PLACEHOLDER for %s (%s)', temp_plot_name, channame);
                plot_filename_cell{ei} = fullfile(outputdir, ...
                    [temp_plot_name 'chirp_itc' channame '.png']);
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
                strrep(plot_title_cell{gi},'PLACEHOLDER','STP'));
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
            if isDiff && si > numel(unique(groups))
                addtitle = plot_title_cell{si};
            else
                addtitle = '';
            end
            createPlot_chirpItc(t, f, itc(:,:,si), ...
                ['ITC ' addtitle]);
            subplot(1,3,2)
            createPlot_chirpStp(t, f, stp(:,:,si), ...
                ['STP ' addtitle]);
            subplot(1,3,3)
            createPlot_chirpErsp(t, f, ersp(:,:,si), ...
                ['ERSP ' addtitle]);
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
        caxis([-.1 .1]); % important
else
    max_itc = .2;
    if max(max(itc)) > max_itc
        % axis([0 1]); % important
        plot_title = [plot_title ' (EXCEEDS UPPER LIMIT ' num2str(max_itc) ')' ];
    else
        caxis([0 .1]); % important
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
    caxis([-3 3]); % important
else
    max_stp = -190;
    if max(max(stp)) > max_stp
        caxis([0 50]); % important
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
    caxis([-1 1]); % important
else
    caxis([-2 2]); % important
%    caxis([-215 -190]);
end

pbaspect([1 1 1]);
title(plot_title);

end
