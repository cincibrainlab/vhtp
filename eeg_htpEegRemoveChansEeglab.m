function [EEG, results] = eeg_htpEegRemoveChansEeglab(EEG,varargin)
% Description: Mark channels for rejection and interpolation
% ShortTitle: Reject Bad Channels
% Category: Preprocessing
% Tags: Channel
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegRemoveChansEeglab( EEG, varargin )
%
%% Required Inputs:
%     EEG [struct]           - EEGLAB Structure
%
%% Function Specific Inputs:
%   'trim'  - boolean to indicate whether to trim beginning and end of file for edge effects
%             default: false
%             
%             Removes first and last 10 secs of data
%
%   'minimumduration' - Number to indicate a minimum duration of data required for removal of channels and interpolation
%                       default: 100 secs
%
%   'threshold' - Number to utilize for threshold in automated detection/marking of bad channels via various measures (probability, kurtosis,and spectrum)
%                 default: 5
%
%   'removechannel' - true/false if channels should be removed after marking prior to next step.
%                      default: false
%    
%   'automark'      - turns on and off automatic detection 
%                      default: false
%
%   'saveoutput' - Boolean representing if output should be saved when executing step from VHTP preprocessing tool
%                  default: false
%
%% Outputs:
%    EEG [struct]         - Updated EEGLAB structure
%
%    results [struct]   - Updated function-specific structure containing qi table and input parameters used
%
%% Disclaimer:
%  This file is part of the Cincinnati Visual High Throughput Pipeline
%  
%  Please see http://github.com/cincibrainlab
%
%% Contact:
%   kyle.cullion@cchmc.org

defaultTrim = false;
defaultMinimumDuration = 60;
defaultThreshold = 5;
defaultRemoveChannel = true;
defaultAutoMark = false;
defaultSaveOutput = false;


ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'trim',defaultTrim,@islogical);
addParameter(ip, 'minimumduration',defaultMinimumDuration,@isnumeric);
addParameter(ip,'threshold',defaultThreshold,@isnumeric);
addParameter(ip,'removechannel', defaultRemoveChannel, @islogical);
addParameter(ip, 'automark', defaultAutoMark, @islogical);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical)

parse(ip,EEG,varargin{:});

%EEG.vhtp.eeg_htpEegRemoveChansEeglab = struct();

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output
repeating = 1;
try
    if isfield(EEG.vhtp,'eeg_htpEegRemoveChansEeglab') && isfield(EEG.vhtp.eeg_htpEegRemoveChansEeglab,'failReason')
        EEG.vhtp.eeg_htpEegRemoveChansEeglab=rmfield(EEG.vhtp.eeg_htpEegRemoveChansEeglab,'failReason');
    end
    original = EEG;
    if EEG.xmax < ip.Results.minimumduration % 60 seconds
        proc_badchans = [];
        EEG.vhtp.eeg_htpEegRemoveChansEeglab.completed = 0;
        EEG.vhtp.eeg_htpEegRemoveChansEeglab.failReason = 'Data too short';
        
        f = errordlg(sprintf('\t\tYOUR DATA IS SHORTER THAN THE SET MINIMUM DURATION OF %d SECONDS\n\n\t\tYOUR FILE WILL NOT UNDERGO MARKING BAD CHANNELS.',ip.Results.minimumduration),'Recording Error');
        
        uiwait(f);
        repeating=0;

    end
    if ip.Results.trim
        if ~isfield(EEG.vhtp,'eeg_htpEegRemoveChansEeglab')
            EEG = trim_edges(EEG,10);
            if isfield(EEG.vhtp,'eeg_htpEegRemoveChansEeglab') && isfield(EEG.vhtp.eeg_htpEegRemoveChansEeglab,'failReason')
                f=errordlg(sprintf('\t\tYOUR DATA IS SHORTER THAN THE SET MINIMUM DURATION OF %d SECONDS\n\n\t\tYOUR FILE WILL NOT UNDERGO MARKING BAD CHANNELS.',ip.Results.minimumduration));
                uiwait(f);
                repeating = 0;
            end
        end
    end
    while repeating
        EEG = original;

        gui.position = [0.01 0.20 0.80 0.70];
        EEG=autobadchannel( EEG,ip.Results.threshold, ip.Results.automark );


        cdef = {'b','b'};
        carr = repmat(cdef,1, size(EEG.data,1));
        carr = carr(1:size(EEG.data, 1));
        carr(EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_autobadchannel) = {'r'};

        eegplot(EEG.data,'srate',EEG.srate,'winlength',10, ...
            'plottitle', [sprintf('Mark and Remove Bad Channels for Subject %s',regexprep(EEG.subject,'^*\.\w+$',''))], ...
            'events',EEG.event,'color',carr,'wincolor',[1 0.5 0.5], ...
            'eloc_file',EEG.chanlocs,  'butlabel', 'Close Window', 'submean', 'on', ...
            'command', 't = 1', 'position', [400 400 1024 768] ...
            );

        h = findobj('tag', 'eegplottitle');
        h.FontWeight = 'Bold'; h.FontSize = 16; h.Position = [0.5000 0.93 0];
        proc_badchans=[];
        chanlist = {EEG.chanlocs.labels};

        if ~isfield(EEG.vhtp.eeg_htpEegRemoveChansEeglab,'proc_badchans')
            EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans =  '';
        end

        handle = gcf;
        handle.Units = 'normalized';
        handle.Position = gui.position;


        popup = uicontrol(handle,'Tag', 'chanselect', 'Style', 'listbox', ...
            'max',EEG.nbchan,'min',1, ...
            'String', chanlist , 'Value', EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_autobadchannel,...
            'Units', 'normalized', ...
            'Position', [.05 0.15 0.035 .70], 'BackgroundColor', [0.94 0.94 0.94]);

        showBadDetail = uicontrol(handle,...
            'Tag', 'detailbutton', ...
            'Style', 'pushbutton', 'BackgroundColor', [0 1 1],...
            'Units', 'normalized', ...
            'Position', [0.7 0.08 0.10 0.05],...
            'String', 'Detail', 'Callback', @(src,event)showChanDetail(EEG));

        toggleBadChannels = uicontrol(handle,...
            'Tag', 'savebutton', ...
            'Style', 'togglebutton', 'BackgroundColor', [0 1 0],...
            'Units', 'normalized', ...
            'Position', [0.8 0.08 0.14 0.05],...
            'String', 'Save', 'Callback', @(src,event)selBadChan(EEG));

        textBadChannels = uicontrol(handle, 'Style', 'text', ...
            'String', 'Manual Bad Channel Rejection: no channels selected', 'Tag', 'badchantitle', ...
            'FontSize', 14,    'Units', 'normalized', 'Position', [0.1 0.89 0.3 0.03], 'HorizontalAlignment', 'left');


        waitfor(gcf);

        if length(proc_badchans) > ceil(EEG.nbchan*.05)
            f=warndlg('YOU HAVE REMOVED MORE THAN 5% OF THE TOTAL NUMBER OF CHANNELS');
            uiwait(f);
        end

        EEG.vhtp.eeg_htpEegRemoveChansEeglab.completed=1;
        if ~isempty(EEG.vhtp.eeg_htpEegRemoveChansEeglab.('proc_badchans'))
            EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans = sort(unique([EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans, proc_badchans]));
        else
            EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans = proc_badchans;
        end
        
        % display check for user
        channel_labels = {EEG.chanlocs.labels};
        nochannel_idx = channel_labels(proc_badchans);
        EEG_Temp = pop_select( EEG, 'nochannel',  nochannel_idx);

        eegplot(EEG_Temp.data,'srate',EEG.srate,'winlength',10, ...
            'plottitle', [sprintf('Review Channel Removal for for Subject %s',regexprep(EEG.subject,'^*\.\w+$',''))], ...
            'events',EEG.event,'color',carr,'wincolor',[1 0.5 0.5], ...
            'eloc_file',EEG_Temp.chanlocs,  'butlabel', 'Close Window', 'submean', 'on', ...
            'command', 't = 1', 'position', [400 400 1024 768] ...
            );

        h = findobj('tag', 'eegplottitle');
        h.FontWeight = 'Bold'; h.FontSize = 16; h.Position = [0.5000 0.93 0];

        handle = gcf;
        handle.Units = 'normalized';
        handle.Position = gui.position;

        waitfor(gcf);

        answer = questdlg(sprintf('Would you like to Re-do the Marking Bad Channel Process for Subject %s?',regexprep(EEG.subject,'^*\.\w+$','')),'Channel Removal Repeat','Repeat','Continue','Continue');
        
        if isempty(answer) || strcmp(answer, 'Repeat')
            repeating = 1;
        else
            repeating = 0;
        end
    end

catch e
    throw(e)
end

EEG=eeg_checkset(EEG);

% EP update 6/16/2022
% add option to remove channels without interpolation
% added to optimize inline ASR

if ip.Results.removechannel
    fprintf('eeg_htpEegRemoveChannelsEeglab: Remove Channels ON \n');
    channel_labels = {EEG.chanlocs.labels};
    nochannel_idx = channel_labels(proc_badchans);
    EEG = pop_select( EEG, 'nochannel',  nochannel_idx);
else
    fprintf('eeg_htpEegRemoveChannelsEeglab: Mark Channels Only \n')
end
%
if isfield(EEG,'vhtp') && isfield(EEG.vhtp,'inforow')
    if isempty(EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans)
        EEG.vhtp.inforow.proc_removal_chans_badChans = 'none';
        EEG.vhtp.inforow.proc_removal_chans_nbchan = EEG.nbchan;
    else
        EEG.vhtp.inforow.proc_removal_chans_badChans = EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans;
        EEG.vhtp.inforow.proc_removal_chans_nbchan = EEG.vhtp.inforow.raw_nbchan - length(EEG.vhtp.inforow.proc_removal_chans_badChans);
    end
end
qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegRemoveChansEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegRemoveChansEeglab.qi_table = [EEG.vhtp.eeg_htpEegRemoveChansEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegRemoveChansEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegRemoveChansEeglab;

    function  EEG=showChanDetail(EEG)

    ui_main = findobj(gcf,'Tag', 'EEGPLOT');
    h = findobj(gcf,'Style','togglebutton');
    hlist = findobj(gcf,'Style','listbox');
    htext = findobj(gcf,'Tag','badchantitle');

    ui_list = h.Value;
    ui_selection = hlist.Value;

    if ~isempty(ui_selection)
        pop_prop( EEG, 1, ui_selection, NaN, {'freqrange' [0.5 55] });
    end

    end

    function EEG=selBadChan(EEG)


    ui_main = findobj(gcf,'Tag', 'EEGPLOT');
    h = findobj(gcf,'Style','togglebutton');
    hlist = findobj(gcf,'Style','listbox');
    htext = findobj(gcf,'Tag','badchantitle');

    ui_list = h.Value;
    ui_selection = hlist.Value;

    if ui_list == 1
        ui_main.UserData.delchans = ui_selection;
        htext.String = 'Manual Bad Channel Rejection: ';
        htext.String = [htext.String num2str(ui_selection)];
        %fprintf(htext.String);
        htext.BackgroundColor = [0 1 0];
        proc_badchans=ui_selection;
    else
        ui_main.UserData.delchans = '';
        htext.String = 'Manual Bad Channel Rejection: no channels selected';
        htext.BackgroundColor = [0.93 0.93 0.93];
        proc_badchans=[];
    end

    end

end


function EEG = trim_edges( EEG, time )
if isempty(EEG)

else
    EEGTMP = EEG;
    if time * 6 > EEG.xmax
        validtime = 0;
        EEGTMP.vhtp.eeg_htpEegRemoveChansEeglab.completed=0;
        EEGTMP.vhtp.eeg_htpEegRemoveChansEeglab.failReason = 'Data too short';
    else
        cut1 = [0 time];
        EEGTMP = eeg_checkset(pop_select(EEGTMP, 'notime', cut1));
        cut2 = [(EEGTMP.xmax - time) EEGTMP.xmax];
        EEGTMP = eeg_checkset(pop_select(EEGTMP, 'notime', cut2));
    end

    EEG = EEGTMP;
end

end

function EEG = autobadchannel( EEG, threshold, automark_true )

if automark_true % added 6/17/22 default turned off (saves time)

    maxchannels = floor(size(EEG.data, 1) * 0.10);

    measure = {'prob','kurt'}; % 'spec'
    indelec = cell(1,length(measure));
    com = cell(1,length(measure));


    for i = 1 : length(measure)
        try
            [OUTEEG, indelec{i}, measure_name{i}, com{i}] = pop_rejchan(EEG, 'elec',[1:EEG.nbchan]...
                ,'threshold',threshold,'norm','on','measure',measure{i} );
        catch error
            throw(error)
        end
    end
    zerochan = find_zeroed_chans( EEG.data ); if ~isempty( zerochan ), indelec{end+1} = zerochan'; end
    badchans = cell2mat(indelec(1:length(indelec)));
else
    badchans = [];
end
EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_autobadchannel = unique( badchans, 'stable' );
end

function index = find_zeroed_chans( dat )

chans_median = zeros( size( dat, 1 ),1 );

for i = 1 : size( dat, 1 )

    chans_median(i) = median( dat(i, :));

end

allchannels = round(chans_median(:),8);
index =  find(allchannels == 0);

end


