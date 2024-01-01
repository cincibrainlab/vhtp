classdef SpeedIC2 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        selectFolderPanel        matlab.ui.container.Panel
        fileBrowserLabel        matlab.ui.control.Label
        fileBrowserFolderBox    matlab.ui.control.EditField
        fileBrowserOpenButton   matlab.ui.control.Button
        fileBrowserTable        matlab.ui.control.Table
        fileBrowserSubfolderCheckbox matlab.ui.control.CheckBox
        img_open_layout         matlab.ui.container.GridLayout
        fileNameLabel           matlab.ui.control.Label
        fileStatusDropdown      matlab.ui.control.DropDown
        fileDetailsFlaggedCheckbox         matlab.ui.control.CheckBox
        commentsTextArea        matlab.ui.control.TextArea
        select_folder_layout    matlab.ui.container.GridLayout
        app_grid                matlab.ui.container.GridLayout
        details_file_layout     matlab.ui.container.GridLayout
        fileDetailsPanel        matlab.ui.container.Panel
        fileDetailsInfoLabel    matlab.ui.control.Label
        fileDetailsNameLabel    matlab.ui.control.Label
        fileDetailsTextArea     matlab.ui.control.TextArea
        fileDetailsSaveComments  matlab.ui.control.Hyperlink
        fileDetailsStatusDropdown matlab.ui.control.DropDown
        fileBrowserResetStatus  matlab.ui.control.CheckBox

        icViewPanel             matlab.ui.container.Panel
        icViewPanel_layout      matlab.ui.container.GridLayout
        icViewLabel            matlab.ui.control.Label

        toolboxPanel            matlab.ui.container.Panel

        icBrowserPanel           matlab.ui.container.Panel
        icDetailPanel          matlab.ui.container.Panel
        statusBarPanel          matlab.ui.container.Panel

        logTextArea            matlab.ui.control.HTML
        statusBarPanelLayout    matlab.ui.container.GridLayout
        fileDetailsMissingLabel matlab.ui.control.Label
        fileDetailsMissingButton matlab.ui.control.Hyperlink

        firstRun

        L % Logging Object
        appsettings

        currentSelectedFileBrowserDetail
    end

    events
        userSelectsFile     % User selects a row
        userModifiesFile     % User selects a row
    end


    properties (Access = private)
        ih % icHandlerClass
        % currentSelectedFileBrowserRow
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Log that currently this is unused
            %app.L.trace('Currently this is unused');

            fileBrowserSelectWorkingDirectory(app, '/Users/ernie/Documents/APDinASD');
        end

        function Controller(app, action, varargin)

            p = inputParser;
            % Allows for unmatched name-value pairs
            p.KeepUnmatched = true;
            p.addRequired('app', @isobject);
            p.addRequired('action', @ischar);

            switch action

                case 'preLaunchTasks'

                    app.L.info("Not used currently")

                case 'postStartupViewTasks'

                    %  application title
                    app.UIFigure.Name = sprintf('%s (%s)', app.ih.getAppConstants('APPTITLE'), app.ih.getAppConstants('APPVERSION'));

                    %  center application window
                    resolution = app.ih.getAppConstants('LAYOUT_RES');
                    screensize = get(0,'ScreenSize');
                    xpos = ceil((screensize(3)-resolution(1))/2); % center the figure in regards to width
                    ypos = ceil((screensize(4)-resolution(2))/2); % center the figure in regards to height
                    app.UIFigure.Position = [xpos ypos resolution(1) resolution(2)];

                    %                    app.currentSelectedFileBrowserRow = missing;
                    app.fileDetailsPanel.Visible = 'on';

                case 'setupFileBrowserView'
                    % setup File Browser Pane
                    % set up labels
                    app.fileBrowserLabel.Text               = 'File Browser';
                    app.fileBrowserFolderBox.Placeholder    = 'Set working folder.';
                    app.fileBrowserOpenButton.Text          = 'Open';

                    % set up callbacks
                    app.fileBrowserOpenButton.ButtonPushedFcn = @(btn,event) app.fileBrowserSelectWorkingDirectory();

                case 'updateFileBrowserTableView'

                    data = app.ih.Controller('getFileBrowserTableData');

                    fb_colnames = {'FULLFILE', 'FILENAME', 'FILESTATUSLABEL', 'FILEFLAG','FILEUUID'};
                    fb_table = table(data.FULLFILE, data.FILENAME, data.FILESTATUSLABEL, data.FILEFLAG, data.FILEUUID, ...
                        'VariableNames', fb_colnames);
                    fb_cell = table2cell(fb_table);

                    getColumnIndex = @(x) strcmp(fb_colnames, x);

                    FULLFILE_IDX = getColumnIndex('FULLFILE');

                    app.fileBrowserTable.Data = fb_cell; %table2cell(view_data);
                    app.fileBrowserTable.UserData.fb_colnames = fb_colnames;
                    app.fileBrowserTable.UserData.getColumnIndex = getColumnIndex;
                    app.fileBrowserTable.RowName = "";
                    app.fileBrowserTable.ColumnSortable = [false false true false false]; % Turn off sorting
                    app.fileBrowserTable.ColumnEditable = [false false true true false]; % Make only the 'Flag' column editable
                    app.fileBrowserTable.ColumnFormat = {[] [] app.ih.appsettings.ui.FileStatusLabels' [] []};
                    app.fileBrowserTable.ColumnWidth = {25,200,65,50, 0}; % Set the width of all columns to 'auto'
                    app.fileBrowserTable.BackgroundColor = [1 1 1; 0.94 0.94 0.94]; % Turn off uitable striping
                    app.fileBrowserTable.ColumnName = {'','File', 'Status', 'Flag',''}'; % Updated column names
                    app.fileBrowserTable.CellEditCallback = createCallbackFcn(app, @fileTableCellEditValueChanged, true);

                    % Iterate over each row and apply the color style to the first cell
                    for i = 1:size(data, 1)
                        colorRow = hex2rgb(data{i,'FILESTATUSCOLOR'});
                        colorStyle = colorRow;

                        % Create a uistyle object for this color
                        cellStyle = uistyle;
                        cellStyle.BackgroundColor =  colorStyle; % Set the background color

                        % Apply the style to the first cell of the row
                        addStyle(app.fileBrowserTable, cellStyle, 'cell', [i, 1]);

                        % Replace the cell contents with two spaces
                        app.fileBrowserTable.Data(i,FULLFILE_IDX) = {'  '};
                    end

                    app.updateFileBrowserDetailsByEventSelection(app);


                otherwise
                    error('Unhandled App action: %s', action);
            end

        end


        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            delete(app)

        end
    end

    % Component initialization
    methods (Access = private)
        function component = createUIComponent(app, componentType, parent, layout, properties)
            % Create UI component of the specified type
            component = feval(componentType, parent);

            % Set layout properties
            component.Layout.Row    = layout.row;
            component.Layout.Column = layout.column;

            % Set additional properties passed in the 'properties' struct
            fieldNames = fieldnames(properties);
            for i = 1:length(fieldNames)
                fieldName = fieldNames{i};
                component.(fieldName) = properties.(fieldName);
            end
        end

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off', 'Color', 'white');
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Assuming a layout of 4 rows and 3 columns
            app.app_grid = uigridlayout(app.UIFigure, [3, 3]);

            % Define the width of the columns and the height of the rows
            % The first column for the file browser, the second for the image, and the third for the component table
            app.app_grid.ColumnWidth                        = {'1.5x','2.5x','1.5x'};
            app.app_grid.RowHeight                          = {'.75x','2x','1.25x','1x'};
            app.app_grid.Padding                            = [2 2 2 2]; % [top right bottom left]
            app.app_grid.BackgroundColor                    = [1 1 1]; % white background color

            % Add a panel for the file browser in the first row and first column
            app.selectFolderPanel = uipanel('Parent', app.app_grid);
            app.selectFolderPanel.Layout.Row = [1 2];
            app.selectFolderPanel.Layout.Column = 1;
            app.selectFolderPanel.Tag = 'SelectFolderPanel';
            app.selectFolderPanel.BackgroundColor = [1 1 1]; % white background color

            app.select_folder_layout = uigridlayout(app.selectFolderPanel, [4, 3]);
            app.select_folder_layout.ColumnWidth            = {'2x','2x','1x'};
            app.select_folder_layout.RowHeight              = {'1x','1x','1x','15x'};
            app.select_folder_layout.Padding                = [2 2 2 2];

            app.fileBrowserLabel = createUIComponent(app, @uilabel, app.select_folder_layout, struct('row', 1, 'column', [1 3]), ...
                struct('Text', '', 'Tag','FileBrowserLabel', 'FontWeight', 'bold', 'FontSize', 16, 'FontColor', [0 0 0]));

            app.fileBrowserFolderBox = createUIComponent(app, @uieditfield, app.select_folder_layout, struct('row', 2, 'column', [1 2]), ...
                struct('Placeholder', 'Set working folder.', 'Tag','FileBrowserFolderBox'));

            app.fileBrowserOpenButton = createUIComponent(app, @uibutton, app.select_folder_layout, struct('row', 2, 'column', 3), ...
                struct('Text', 'Open', 'Tag','FileBrowserOpenButton'));

            app.fileBrowserSubfolderCheckbox =  createUIComponent(app, @uicheckbox, app.select_folder_layout, struct('row', 3, 'column', 1), ...
                struct('Text', 'Include Subfolders', 'Value', 1, 'Tag','FileBrowserSubfolderCheckbox'));
            app.fileBrowserSubfolderCheckbox.ValueChangedFcn = createCallbackFcn(app, @fileBrowserSubfolderCheckboxValueChanged, true);

            app.fileBrowserResetStatus =  createUIComponent(app, @uicheckbox, app.select_folder_layout, struct('row', 3, 'column', 2), ...
                struct('Text', 'Reset Status', 'Value', 0, 'Tag','fileBrowserResetStatus'));
            app.fileBrowserResetStatus.ValueChangedFcn = createCallbackFcn(app, @fileBrowserResetStatusValueChanged, true);

            app.fileBrowserTable = createUIComponent(app, @uitable, app.select_folder_layout, struct('row', 4, 'column', [1 3]), ...
                struct('Data', [], 'Tag','FileBrowserTable'));
            app.fileBrowserTable.CellSelectionCallback = createCallbackFcn(app, @updateFileBrowserDetailsByEventSelection, true);


            app.fileDetailsPanel = uipanel('Parent', app.app_grid);
            app.fileDetailsPanel.Layout.Row = 3;
            app.fileDetailsPanel.Layout.Column = 1;
            app.fileDetailsPanel.Tag = 'FileDetailsPanel';
            app.fileDetailsPanel.BackgroundColor = [1 1 1]; % white background color


            app.details_file_layout = uigridlayout(app.fileDetailsPanel, [7, 3]);
            app.details_file_layout.RowHeight              = {'1x','1x','1x','1x','1x','1x','1x'};
            app.details_file_layout.ColumnWidth            = {'1x','1x','1x'};

            app.fileDetailsNameLabel = createUIComponent(app, @uilabel, app.details_file_layout, struct('row', 1, 'column', [1 2]), ...
                struct('Text', '', 'Tag','FileDetailsLabel', 'FontWeight', 'bold', 'FontSize', 12));

            app.fileDetailsInfoLabel = createUIComponent(app, @uilabel, app.details_file_layout, struct('row', 2, 'column', [1 3]), ...
                struct('Text', '', 'Tag','fileDetailsInfoLabel', 'FontWeight', 'bold', 'FontSize', 12));

            app.fileDetailsFlaggedCheckbox = createUIComponent(app, @uicheckbox, app.details_file_layout, struct('row', 3, 'column', 1), ...
                struct('Text', 'Flagged', 'Tag','fileDetailsFlaggedCheckbox','Value', 1));
            app.fileDetailsFlaggedCheckbox.ValueChangedFcn = createCallbackFcn(app, @fileDetailsFlaggedCheckboxValueChanged, true);

            app.fileDetailsTextArea = createUIComponent(app, @uitextarea, app.details_file_layout, struct('row', [4 6], 'column', [1 3]), ...
                struct('Tag','fileDetailsTextArea'));

            app.fileDetailsSaveComments = createUIComponent(app, @uihyperlink, app.details_file_layout, struct('row', 3, 'column', 3), ...
                struct('Text','Save Comments', 'Tag','fileDetailsSaveComments', 'HorizontalAlignment', 'right'));
            app.fileDetailsSaveComments.HyperlinkClickedFcn = createCallbackFcn(app, @fileDetailsSaveCommentsHyperlinkClicked, true);

            app.fileDetailsStatusDropdown = createUIComponent(app, @uidropdown, app.details_file_layout, struct('row', 1, 'column', 3), ...
                struct('Items',{app.ih.appsettings.ui.FileStatusLabels}, 'ItemsData', {app.ih.appsettings.ui.FileStatusCodes} ,'Tag','fileDetailsStatusDropdown'));
            app.fileDetailsStatusDropdown.ValueChangedFcn = createCallbackFcn(app, @fileDetailsStatusDropdownValueChanged, true);

            app.fileDetailsMissingLabel = createUIComponent(app, @uilabel, app.details_file_layout, struct('row', 7, 'column', [1 2]), ...
                struct('Text', 'Missing', 'Tag','fileDetailsMissingLabel', 'FontWeight', 'bold', 'FontSize', 12));
            app.fileDetailsMissingButton = createUIComponent(app, @uihyperlink, app.details_file_layout, struct('row', 7, 'column', 3), ...
                struct('Text', 'Process', 'Tag','fileDetailsMissingButton', 'HorizontalAlignment', 'right'));
            app.fileDetailsMissingButton.HyperlinkClickedFcn = createCallbackFcn(app, @prepareEegSetFileForVisualizations, true);


            % Add a panel for the ICView in the first row and second column
            app.icViewPanel = uipanel('Parent', app.app_grid);
            app.icViewPanel.Layout.Row = [1 2];
            app.icViewPanel.Layout.Column = 2;
            app.icViewPanel.Tag = 'icViewPanel';

            app.icViewPanel_layout = uigridlayout(app.icViewPanel, [2, 1]);
            app.icViewPanel_layout.ColumnWidth            = {'1x'};
            app.icViewPanel_layout.RowHeight              = {'1x','15x'};
            app.icViewPanel_layout.Padding                = [2 2 2 2];

            app.icViewLabel = createUIComponent(app, @uilabel, app.icViewPanel_layout, struct('row', 1, 'column', 1), ...
                struct('Text', 'IC Properties', 'Tag','icViewLabel', 'FontWeight', 'bold', 'FontSize', 16, 'FontColor', [0 0 0]));

            % Add a panel for the Toolbox in the first row and second column
            app.toolboxPanel = uipanel('Parent', app.app_grid);
            app.toolboxPanel.Layout.Row = 3;
            app.toolboxPanel.Layout.Column = 2;
            app.toolboxPanel.Tag = 'toolboxPanel';
            app.toolboxPanel.BackgroundColor = [1 1 1]; % white background color

            % Add a panel for the ICSelect in the first row and second column
            app.icBrowserPanel = uipanel('Parent', app.app_grid);
            app.icBrowserPanel.Layout.Row = [1 2];
            app.icBrowserPanel.Layout.Column = 3;
            app.icBrowserPanel.Tag = 'icBrowserPanel';
            app.icBrowserPanel.BackgroundColor = [1 1 1]; % white background color

            % Add a panel for the ICDetail in the first row and second column
            app.icDetailPanel = uipanel('Parent', app.app_grid);
            app.icDetailPanel.Layout.Row = 3;
            app.icDetailPanel.Layout.Column = 3;
            app.icDetailPanel.Tag = 'icDetailPanel';
            app.icDetailPanel.BackgroundColor = [1 1 1]; % white background color

            % Add a panel for the statusBarPanel in the first row and second column
            app.statusBarPanel = uipanel('Parent', app.app_grid);
            app.statusBarPanel.Layout.Row = 4;
            app.statusBarPanel.Layout.Column = [1 3];
            app.statusBarPanel.Tag = 'statusBarPanel';
            app.statusBarPanel.BackgroundColor = [1 1 1]; % white background color

            app.statusBarPanelLayout = uigridlayout(app.statusBarPanel, [2, 1]);
            app.statusBarPanelLayout.ColumnWidth            = {'1x'};
            app.statusBarPanelLayout.RowHeight              = {'1x'};
            app.statusBarPanelLayout.Padding                = [2 2 2 2];
            app.statusBarPanelLayout.BackgroundColor        = [1 1 1]; % white background color


            % Add a HTML area for the log in the statusBarPanel
            app.logTextArea = createUIComponent(app, @uihtml, app.statusBarPanelLayout, ...
                struct('row', 1, 'column', 1), ...
                struct('Tag','logTextArea'));
                % Change the entire component background color to white


            % app.img_open_layout = uigridlayout(app.app_grid, [2, 4]);
            % app.img_open_layout.ColumnWidth = {'1x', '1x', '1x', '1x'};
            % app.img_open_layout.RowHeight = {'1x','1x'};
            % app.img_open_layout.Layout.Column = 2;
            % app.img_open_layout.Layout.Row = 2;
            %
            %
            % % Add an axes for displaying the image in the first row and second column
            % imgAxes = uiaxes(app.img_open_layout);
            % imgAxes.Layout.Row = [1 2];
            % imgAxes.Layout.Column = [1 4];
            %
            % % Add a panel for the buttons in the second row and second column
            % buttonPanel = uipanel(app.app_grid);
            % buttonPanel.Layout.Row = 3;
            % buttonPanel.Layout.Column = 2;
            %
            % % Inside the panel, you can add buttons for quick tagging
            % % Here's an example of adding a button
            % tagButton = uibutton(buttonPanel, 'Text', 'Quick Tag');
            % % You can set the button's position within the panel using its 'Position' property
            % tagButton.Position = [20 20 100 30]; % [left bottom width height]
            %
            % % Add a table for displaying the components in the first and second row of the third column
            % componentTable = uitable(app.app_grid);
            % componentTable.Layout.Row = [2, 3]; % Span both rows
            % componentTable.Layout.Column = 3;
            % % Define the Data property of the table to include fit quality and other associated values
            % componentTable.Data = { ...
            %     'IC01', 'Artifact', 'Rejected', false; ...
            %     'IC02', 'Brain', 'Accepted', true; ...
            %     'IC03', 'Muscle', 'Rejected', false; ...
            %     'IC04', 'Eye', 'Rejected', false; ...
            %     'IC05', 'Brain', 'Accepted', true; ...
            %     'IC06', 'Heart', 'Rejected', false; ...
            %     'IC07', 'Channel Noise', 'Rejected', false; ...
            %     'IC08', 'Brain', 'Accepted', true; ...
            %     'IC09', 'Artifact', 'Rejected', false; ...
            %     'IC10', 'Brain', 'Accepted', true ...
            % }; % Realistic example data with IC labels, status, and flags
            % componentTable.ColumnName = {'IC', 'Label', 'Status', 'Flag'}; % Updated column names
            % componentTable.RowName = "";

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end

        function prepareEegSetFileForVisualizations(app, source, event)
            app.ih.Controller('runVisualizationPrep');
        end
    end

    % App creation and deletion
    methods (Access = public)
        % Construct app
        function app = SpeedIC2

            app.firstRun = true;

            app.ih = icHandlerClass();
            app.L = app.ih.getLogger();



            % Create UIFigure and components
            createComponents(app)

            % Setup listener to log to show log messages to the new textbox
            addlistener(app.L, 'LogLineWritten', @(src, event) updateLogTextArea(app, app.L.getLastHtmlLogLine()));
            addlistener(app, 'userModifiesFile', @(src, event) userModifiesFileCallback(app,src,event));
            addlistener(app, 'userSelectsFile', @(src, event)  userSelectsFileCallback(app,src,event));

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            Controller(app, 'postStartupViewTasks');
            Controller(app, 'setupFileBrowserView');


            runStartupFcn(app, @startupFcn);



            if nargout == 0
                clear app
            end
        end
        function userModifiesFileCallback(app, src, event)
            disp('User Has Modified a File')
        end
        function userSelectsFileCallback(app, src, event)
            disp('User Has Selects a File')
        end

        % Method to update the text box with cumulating text like a log
        function updateLogTextArea(app, logString)
            % Add the new log string to the existing text in the log text area
            % The HTML text area requires the text to be formatted in HTML, so we use sprintf to add HTML tags
            % The 'Value' property is not recognized for the class 'matlab.ui.control.HTML', so it has been removed
            % The font is set to monospace for better readability, the font size is reduced, and line height is decreased for less spacing between lines
            % The background color is set to white
            % The pre settings are set only once with the log text injected inside not repeated over and over
            % The data field contains the loglines and the html source only adds format lines once
            app.logTextArea.Data = sprintf('%s%s', logString, app.logTextArea.Data);
            app.logTextArea.HTMLSource = sprintf('<div style="padding: 10px;"><pre style="font-family:sans-serif; font-size: 1em; line-height: 0.6em; background-color: white;">%s</pre></div>', app.logTextArea.Data);
        end
        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end

    end

    % Look Up functions
    methods (Access = private)
        function icFileObject = getEegSetFileObjectByUuid( app, selected_uuid )
            icFileObject = app.ih.Controller('getEegSetFileObjectByUuid', selected_uuid);
        end
        function uuid = getFileUuidByFbTableIndex(app, row_index)
            % Get the selected hash from the table
            fb_colnames = app.fileBrowserTable.UserData.fb_colnames;
            uuid = char(app.fileBrowserTable.Data(row_index, app.fileBrowserTable.UserData.getColumnIndex('FILEUUID')));
        end
    end


    % Callback / Data functions
    methods (Access = private)

        function updateEegSetFileStatus(app, selected_uuid, FILESTATUSCODE)
            icFileObject = getEegSetFileObjectByUuid( app, selected_uuid );
            icFileObject.setFileStatusProperties(FILESTATUSCODE);
        end

        function updateEegSetFileFlag(app, selected_uuid, FILEFLAG)
            icFileObject = getEegSetFileObjectByUuid( app, selected_uuid );
            icFileObject.setFileFlagProperties(FILEFLAG);
        end

        function updateEegSetFileComments(app, selected_uuid, FILECOMMENTS)
            icFileObject = getEegSetFileObjectByUuid( app, selected_uuid );
            icFileObject.setFileCommentsProperties(FILECOMMENTS);
        end

        function fileDetailsStatusDropdownValueChanged(app, event)
            FILESTATUSCODE = app.fileDetailsStatusDropdown.Value;
            FILEUUID = char(app.currentSelectedFileBrowserDetail.FILEUUID);
            updateEegSetFileStatus(app, FILEUUID, FILESTATUSCODE);
            cleanupFollowingDataModification(app, FILEUUID);
        end

        function fileDetailsFlaggedCheckboxValueChanged(app, event)
            FILEFLAG = app.fileDetailsFlaggedCheckbox.Value;
            FILEUUID = char(app.currentSelectedFileBrowserDetail.FILEUUID);
            updateEegSetFileFlag(app, FILEUUID, FILEFLAG);
            cleanupFollowingDataModification(app, FILEUUID);
        end

        function fileDetailsSaveCommentsHyperlinkClicked(app, event)
            comments = app.fileDetailsTextArea.Value;
            FILEUUID = char(app.currentSelectedFileBrowserDetail.FILEUUID);
            updateEegSetFileComments(app, FILEUUID, comments);
            cleanupFollowingDataModification(app, FILEUUID);
        end

        function fileTableCellEditValueChanged(app, event)
            column_index = event.Indices(2);
            column_name = app.fileBrowserTable.ColumnName{column_index};
            row_index = event.Indices(1);
            FILEUUID = app.getFileUuidByFbTableIndex(row_index);

            switch column_name
                case 'Status'
                    FILESTATUSLABEL = event.NewData;
                    FILESTATUSCODE = char(app.fileDetailsStatusDropdown.ItemsData(strcmp(app.fileDetailsStatusDropdown.Items, FILESTATUSLABEL)));
                    updateEegSetFileStatus(app, FILEUUID, FILESTATUSCODE);
                    app.Controller('updateFileBrowserTableView');
                    cleanupFollowingDataModification(app, FILEUUID);

                case 'Flag'
                    FILEFLAG = event.NewData;
                    updateEegSetFileFlag(app, FILEUUID, FILEFLAG);
                    app.Controller('updateFileBrowserTableView');
                    cleanupFollowingDataModification(app, FILEUUID);
                otherwise
                    return
            end

        end

        function updateFileBrowserDetailsByEventSelection(app, event)

            %Get the row and column indices of the cell that was clicked
            if ~isprop(event,'Indices') && ~isfield(event, 'Indices')
                row_index = 1;
                app.L.warn('This should only be called at the first run');
                selected_uuid = app.getFileUuidByFbTableIndex(row_index);
                updateFileBrowserDetailsByUuid(app, selected_uuid);
                return
            end
            if isprop(event,'Indices') || isfield(event, 'Indices')
                if isempty(event.Indices)
                    return
                else
                    row_index = event.Indices(1);
                    selected_uuid = app.getFileUuidByFbTableIndex(row_index);
                    updateFileBrowserDetailsByUuid(app, selected_uuid);
                end
            end

        end

        function updateFileBrowserDetailsByUuid(app, selected_uuid)

            app.fileDetailsPanel.Visible = 'on';


            icFileObject = getEegSetFileObjectByUuid( app, selected_uuid );

            fileBrowserDetailModel = icFileObject.Controller('getDetailedRow');

            app.fileDetailsNameLabel.Text = fileBrowserDetailModel.FILENAME;
            app.fileDetailsInfoLabel.Text = sprintf('FS: %d | PT: %d | T: %d | EP: %2.1fs | ICs: %d | EV: %d', ...
                fileBrowserDetailModel.SRATE{1}, ...
                fileBrowserDetailModel.NO_SAMPLES{1}, ...
                fileBrowserDetailModel.TRIALS{1}, ...
                fileBrowserDetailModel.EPOCH_DURATION{1}, ...
                fileBrowserDetailModel.NO_ICS{1}, ...
                fileBrowserDetailModel.NO_EVENTS);

            app.fileDetailsTextArea.Value = fileBrowserDetailModel.FILECOMMENTS;
            app.fileDetailsStatusDropdown.Value = fileBrowserDetailModel.FILESTATUSCODE;
            app.fileDetailsFlaggedCheckbox.Value = fileBrowserDetailModel.FILEFLAG;

            app.currentSelectedFileBrowserDetail = fileBrowserDetailModel;

            notify(app, 'userSelectsFile', icEventData(icFileObject));

        end

        function cleanupFollowingDataModification( app, selected_uuid )
            app.Controller('updateFileBrowserTableView');
            updateFileBrowserDetailsByUuid(app, selected_uuid);
            app.ih.updateDatabase();
            notify(app, 'userModifiesFile');
        end
    end

    % Working Folder Methods
    methods (Access = public)
        % Callback for fileBrowserSubfolderCheckbox
        function fileBrowserSubfolderCheckboxValueChanged(app, event)
            value = app.fileBrowserSubfolderCheckbox.Value;
            app.ih.AppFlagHandler('setIncludeSubfoldersCheckbox', value);
            app.L.debug(sprintf('fileBrowserSubfolderCheckbox value changed to: %s', mat2str(value)));
        end

        % Callback for fileBrowserResetStatus
        function fileBrowserResetStatusValueChanged(app, event)
            value = app.fileBrowserResetStatus.Value;
            app.ih.AppFlagHandler('setResetStatusCheckbox', value);
            app.L.debug(sprintf('fileBrowserResetStatus value changed to: %s', mat2str(value)));
        end

        function fileBrowserSelectWorkingDirectory(app, varargin)
            % Use input parser for best practices
            p = inputParser;
            addOptional(p, 'folderName', '', @ischar);
            parse(p, varargin{:});

            if isempty(p.Results.folderName)
                % This insanity is because matlab doesn't order window layers properly without tricks
                f = figure('Renderer', 'painters', 'Position', [-100 -100 0 0], 'CloseRequestFcn',''); %create a dummy figure so that uigetfile doesn't minimize our GUI
                folderName = uigetdir(); % Open dialog box for directory selection
                delete(f); %delete the dummy figure
                figure(app.UIFigure)
            else
                folderName = p.Results.folderName;
            end

            if folderName ~= 0
                app.fileBrowserFolderBox.Value = folderName; % Update the fileBrowserFolderBox with the selected directory
                app.ih.initialize(folderName);
                app.Controller('updateFileBrowserTableView');
            end
        end


    end
end