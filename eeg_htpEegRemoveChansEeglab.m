function [EEG, results] = eeg_htpEegRemoveChansEeglab(EEG,varargin)
% eeg_htpEegRemoveChansEeglab - Mark channels for rejection and
%                               interpolation
%
% Usage:
%    >> [ EEG, results ] = eeg_htpEegRemoveChansEeglab( EEG, varargin )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
%     results   - Updated function-specific structure containing qi table
%                 and input parameters used
%
% Function Specific Inputs:
%   'type'  - Text for type of data to work with for use in trimming edge effects
%             e.g. {'Resting, Event'}
%             default: 'Resting'
%
%   'minimumduration' - Number to indicate a minimum duration of data
%                       required for removal of channels and interpolation
%                       default: 100
%
%   'threshold' - Number to utilize for threshold in automated detection/marking
%                 of bad channels via various measures (probability, kurtosis,and spectrum) 
%                 default: 5
%   
% Outputs:
%     EEG         - Updated EEGLAB structure
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

defaultType = 'Resting';
defaultMinimumDuration = 100;
defaultThreshold = 5;

validateType = @( type ) ischar( type ) && ismember(type, {'Resting', 'Event'});


ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'type',defaultType,validateType);
addParameter(ip, 'minimumduration',defaultMinimumDuration,@isnumeric);
addParameter(ip,'threshold',defaultThreshold,@isnumeric);

parse(ip,EEG,varargin{:});

%EEG.vhtp.eeg_htpEegRemoveChansEeglab = struct();

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
   if EEG.xmax < ip.Results.minimumduration
       EEG.vhtp.eeg_htpEegRemoveChansEeglab.completed = 0;
       EEG.vhtp.eeg_htpEegRemoveChansEeglab.failReason = 'Data too short';
       return;
   else
       if strcmp(ip.Results.type,'Resting')
           EEG = trim_edges(EEG,10);
           if isfield(EEG.vhtp.eeg_htpEegRemoveChansEeglab,'failReason')
               return;
           end
       end
       
       gui.position = [0.01 0.20 0.80 0.70];
       EEG=autobadchannel( EEG,ip.Results.threshold );
       
       
       cdef = {'b','b'};
       carr = repmat(cdef,1, size(EEG.data,1));
       carr = carr(1:size(EEG.data, 1));
       carr(EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_autobadchannel) = {'r'};

       eegplot(EEG.data,'srate',EEG.srate,'winlength',10, ...
            'plottitle', ['Mark and Remove Bad Channels '], ...
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
            'max',10,'min',1, ...
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
           EEG.vhtp.eeg_htpEegRemoveChansEeglab.completed=0;
           EEG.vhtp.eeg_htpEegRemoveChansEeglab.failReason = 'Max Reject Threshold Exceeded';
           return
       end
       
       EEG.vhtp.eeg_htpEegRemoveChansEeglab.completed=1;
       if ~isempty(getfield(EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans))
           EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans = sort(unique([EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans, proc_badchans]));
       else 
           EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans = proc_badchans;
       end
   end
   
   
catch e
    throw(e)
end



EEG=eeg_checkset(EEG);

qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
EEG.vhtp.eeg_htpEegRemoveChansEeglab.qi_table = qi_table;
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

function EEG = autobadchannel( EEG, threshold )

    maxchannels = floor(size(EEG.data, 1) * 0.10);

    measure = {'prob','kurt','spec'}; % 'spec'
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
    EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_autobadchannel = unique( badchans, 'stable' );
    %EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_badchans = unique( badchans, 'stable' );

end

 function index = find_zeroed_chans( dat )
            
    chans_median = zeros( size( dat, 1 ),1 );

    for i = 1 : size( dat, 1 )

        chans_median(i) = median( dat(i, :));

    end

    allchannels = round(chans_median(:),8);
    index =  find(allchannels == 0);

end


