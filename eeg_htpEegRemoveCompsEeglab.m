function [EEG] = eeg_htpEegRemoveCompsEeglab(EEG,varargin)
% eeg_htpEegRemoveCompsEeglab - Select and reject/keep components from data
%
% Usage:
%    >> [ EEG ] = eeg_htpEegRemoveCompsEeglab( EEG )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
% Function Specific Inputs:
%    'maxcomps'  - Number of maximum components to utilize
%                  in thresholding and plotting
%                  default: 24
%
% Outputs:
%     EEG         - Updated EEGLAB structure
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

defaultMaxComps = 24;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'maxcomps',defaultMaxComps,@isnumeric);

parse(ip,EEG,varargin{:});

EEG.vhtp.eeg_htpEegRemoveCompsEeglab.timestamp = datestr(now,'yymmddHHMMSS'); % timestamp
EEG.vhtp.eeg_htpEegRemoveCompsEeglab.functionStamp = mfilename; % function name for logging/output

try
    scsize=get(0,'ScreenSize');
    sc_height   = scsize(4);
    sc_width    = scsize(3);

    main_height = (sc_height / 3) / sc_height;
    user_height = (sc_height / 6) / sc_height ;

    main_width = (sc_width / 5) / sc_width;
    user_width = (sc_width / 6) / sc_width;

    maxcomps = ip.Results.maxcomps;
    
    % Open component topoplot, 20 components
    pop_selectcomps(EEG, 1:maxcomps);

    h.tp = gcf;
    h.tp.Units = 'norm';
    h.tp.Position = [sc_width/200/sc_width .5 main_width main_height];


    p = figure('Name','Component Selection Tool',...
        'Position',[800 300 400 200], ...
        'MenuBar', 'none');

    p.Units = 'norm';
    p.Position =  [sc_width/200/sc_width  0.3 user_width user_height];

    title = uicontrol(p,'Style','text',...
        'String', 'Component Removal',...
        'FontSize', 10,...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', [1 1 1], 'ForegroundColor', [0 0 0], ...
        'Position',[0.05 0.8 0.9 0.15]);

    b1 = uicontrol(p,'Style','pushbutton','String','Save Components',...
        'Units','normalized',...
        'UserData', EEG, ...
        'Callback',@b1_callback, ...
        'BackgroundColor', [0 1 0], ...
        'Position',[.6 0.05 .35 .25]);

    t1 = uicontrol(p,'Style','edit',...
        'tag', 'comp_entry', ...
        'String','',...
        'Max',1,'Min',0,...
        'Units', 'normalized', ...
        'Position',[0.6 0.34 0.35 .30]);

    b2 = uicontrol(p,'Style','pushbutton','String','C. Detail',...
        'Units','normalized',...
        'UserData', EEG, ...
        'Callback', @b2_callback, ...
        'Position',[.05 0.05 .20 .25]);
    %        delete(bguess)
    bguess = uicontrol(p,'Style','pushbutton','String','ICView Guess',...
        'Units','normalized',...
        'UserData', EEG, ...
        'Callback', @bguess_callback, ...
        'Position',[0.6 0.65 0.35 0.10]);


    %excludeStatus = s.get_exclude_switch;
    % global excludeButton;
%     excludeButton = uicontrol(p,'Style','pushbutton','String','Exclude Sub',...
%         'Units','normalized',...
%         'UserData', EEG, ...
%         'Tag', 'exbutton', ...
%         'Callback', @ex_callback, ...
%         'BackgroundColor', [0 1 0], ...
%         'Position',[.30 0.36 .25 .25]);

%     if excludeStatus == 1
%         excludeButton.Value = 1;
%         excludeButton.BackgroundColor = [1 0 0];
% 
%     else
%         excludeButton.Value = 0;
% 
%         excludeButton.BackgroundColor = [0 1 0];
%     end

%     excludeButton.Value = 0;
% 
%     excludeButton.BackgroundColor = [0 1 0];

    closebtn = findobj('tag', 'Set thresholds', 'parent', h.tp);

    UIButtonArr = findobj(h.tp, 'Type', 'UIControl');
    OriginalButtons = findobj(UIButtonArr, 'BackgroundColor', '[0.6600 0.7600 1]');
    for button_i = 1 : length(OriginalButtons), OriginalButtons(button_i).Visible = 'off'; end

    % loop with comp number

    for ri = 1 : maxcomps

        chbutton = findobj('tag', ['comp' num2str(ri)], 'Parent', h.tp);

        chbutton.UserData = {EEG, ri};
        chbutton.Callback = @prop_extended;

    end

    %  delete(t2)
    t2 = uicontrol(p,'Style','edit',...
        'tag', 'comp_entry2', ...
        'String','',...
        'Max',1,'Min',0,...
        'Units', 'normalized', ...
        'Position',[0.05 0.34 0.20 0.30]);

    b3 = uicontrol(p,'Style','pushbutton','String','ICLABEL',...
        'Units','normalized',...
        'UserData', EEG, ...
        'Callback', @b3_callback, ...
        'Position',[.35 0.05 .20 .25]);
    b4 = uicontrol('tag', 'qualitylabel', 'Style', 'text', ...
        'Units', 'norm', 'Position', [0.6 0.01 0.35 0.09]);
    x=5;
    box_title = 'Data Quality : Included';

    set(b4,'string', sprintf('%s', box_title));


    % Open component time series
    pop_eegplot( EEG, 0, 1, 1);
    h.ep = gcf;
    h.ep.Units = 'norm';

    h.ep.Position = [ main_width*1.05 .5 main_width main_height];


    g = h.ep.UserData;

    % adjust default spacing/zoom
    ESpacing = findobj('tag','ESpacing','parent', h.ep);
    ESpacing.String = 50;
    eegplot('draws',0);

    % adjust default number of epochs & components shown
    g.winlength = 10;
    g.dispchans = 10;

    if g.dispchans < 0 || g.dispchans > g.chans
        g.dispchans = g.chans;
    end

    set(h.ep, 'UserData', g);
    eegplot('updateslider', h.ep);
    eegplot('drawp',0);
    eegplot('scaleeye', [], h.ep);

    % draw amplitude time series

    cdef = {'g','b'};
    carr = repmat(cdef,1, size(EEG.data,1));
    carr = carr(1:size(EEG.data, 1));
    carr(EEG.vhtp.eeg_htpEegRemoveChansEeglab.proc_autobadchannel) = {'r'};

    eegplot(EEG.data,'srate',EEG.srate,'winlength',10, ...
        'plottitle', ['View Time Series: '], ...
        'events',EEG.event,'color',carr,'wincolor',[1 0.5 0.5], ...
        'eloc_file',EEG.chanlocs,  'butlabel', 'Close Window', 'submean', 'on', ...
        'command', 't = 1', 'position', [400 400 1024 768] ...
        );

    ts.ep = gcf;
    ts.ep.Units = 'norm';

    ts.ep.Position = h.ep.Position;
    ts.ep.Position(2) = ts.ep.Position(2) - 0.28;
    ts.ep.Position(3) = ts.ep.Position(3) - 0.02;
    ts.ep.Position(4) = ts.ep.Position(4) - 0.1;

    allui = {p, h.tp, h.ep, ts.ep};

    for mi = 1 : length(allui)
        allui{mi}.Position(2) = allui{mi}.Position(2) * 1.20;
        allui{mi}.Tag = 'selectcomps';
    end

    position_factor = [];

    uiwait(h.ep);

    EEG.vhtp.eeg_htpEegRemoveCompsEeglab.completed=1;

catch e
    throw(e)
end

function prop_extended( src, event)

    EEG = src.UserData{1};
    ri = src.UserData{2};
    pop_prop_extended( EEG, 0, ri,  NaN, {'freqrange', [0 55]});

 end

%Callback function for the exclusion button
function ex_callback(src, event)
    % get subject exclude status (default 0 = not excluded)
%         EEG = src.UserData;
%         %exstatus = get_exclude_switch;
%         exstatus=1;
%         comps = src;
%         % change button based on exstatus
%         switch exstatus
%             case 0
%                 %s.exclude_subject( 'yes' );
%                 set(comps, 'String', 'Include Subject')
%                 comps.BackgroundColor = [1 0 0];
%                 list = obj.xml_exclude;
%                 [indx,tf] = listdlg('ListString',list);
%                 %s.exclude_category = list(indx)';
%                 str = [list(indx)'];
%             case 1
%                 %s.exclude_subject('no');
%                 set(comps, 'String', 'Exclude Subject')
%                 comps.BackgroundColor = [0 1 0];
%                 %s.exclude_category = [];
%                 str = 'Quality Sufficient';
%         end
%         
%         b4  = findobj('tag', 'qualitylabel');
%         b4.String  = str;


end

%% bguess_callback
%Callback function for generated component topographical plot window
function bguess_callback(src, event)


    threshold = 0.75;
    range = 1:24;

    get_ic = @(x) get_icview_comps(x, threshold, range,src.UserData);

    comps_artifact = [get_ic('Eye') get_ic('Heart') get_ic('Muscle') get_ic('Line Noise') get_ic('Channel Noise')];

    try
        h_comp_entry = findobj(p, 'Type', 'UIControl', 'tag', 'comp_entry');

        h_comp_entry.String = num2str(comps_artifact);

    catch

    end


end

%% b2_callback
%Callback function for detail button to get component specific
%information such as power spectrum, EVP, diploe location, etc.
function b2_callback(src, event)

    comps = findobj('tag', 'comp_entry2');

    EEG = src.UserData;


    pop_prop_extended( EEG, 0, str2num(comps.String), NaN, {'freqrange', [0 55]});



end

%% b3_callback
% Callback function to handle the ICLABEL button which allows the view
% of many components and channels as well as set the spectral options of
% the component topographical plots
function b3_callback(src, event)

    comps = findobj('tag', 'comp_entry2');

    EEG = src.UserData;

    EEG = pop_iclabel(EEG);

    pop_viewprops( EEG, 0 );

    src.UserData.EEG = EEG;



end

%% b1_callback
% Callback function for save component button
% which allows the user to save their selected components for further
% analysis in the post processing stages
function b1_callback(src, event)

    comps = findobj('tag', 'comp_entry');

    src.UserData.proc_removeComps = str2num(comps.String);
    EEG.vhtp.eeg_htpEegRemoveCompsEeglab.proc_removeComps = str2num(comps.String);
    try
        EEG.etc.clean_channel_mask = true(1,EEG.nbchan);
        EEG.etc.clean_sample_mask = true(1,EEG.pnts * EEG.trials);
    catch

    end

    EEGTMP = EEG;

    % remove components
    EEG=compRemove(EEG);

    % replot components
    vis_artifacts( EEG, EEGTMP);
    vis_h = gcf;
    vis_h.Units = 'norm';
    vis_h.Position(1) = 0.05;
    vis_h.Position(2) = 0.5;

    vis_h.Units = 'pixels';
    vis_h.Position(3) = 1000;
    vis_h.Position(4) = 500;




    uiwait(vis_h);
    EEGTMP = [];
    

    h = findobj('Tag', 'selectcomps');

    for mi = 1 : length( h )
        close( h(mi) );
    end


end

EEG = eeg_checkset(EEG);

qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
EEG.vhtp.eeg_htpEegRemoveCompsEeglab.qi_table = qi_table;
results = EEG.vhtp.htpEegRemoveCompsEeglab;
end

function comps_artifact = get_icview_comps(var, threshold, range,EEG)
    if isfield(EEG.etc, 'ic_classification')
            
    else
        EEG = iclabel(EEG);
    end

    getCompIdx = @(x) find(strcmpi( x, EEG.etc.ic_classification.ICLabel.classes));
    getComps = @(x, y) find(EEG.etc.ic_classification.ICLabel.classifications(range, getCompIdx(x)) > y)';
    

    comps_artifact = getComps(var, threshold);
end

function EEG = compRemove(EEG,varargin)
            

    try
        EEG = eeg_checkset( EEG );

        try
            EEG.etc.clean_channel_mask = true(1,EEG.nbchan);
            EEG.etc.clean_sample_mask = true(1,EEG.pnts * EEG.trials);
        catch

        end

        if nargin > 1

            compIdx = varargin{1};
        else
            compIdx = EEG.vhtp.eeg_htpEegRemoveCompsEeglab.proc_removeComps;
        end
      
        try
            
            EEG=pop_subcomp(EEG,compIdx, 0);
        catch
            
        end

        try
            EEG=iclabel(EEG);
        catch

        end


        EEG.icaact = eeg_getdatact(EEG, 'component', [1:size(EEG.icaweights,1)]);


    catch


    end

    EEG = eeg_checkset( EEG );

end

function exclude_subject( EEG, toggle )
            
            switch toggle
                case 'yes'
                    EEG.exclude_switch = true;
                case 'no'
                    EEG.exclude_switch = false;
            end
end

