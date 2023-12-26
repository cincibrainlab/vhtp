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

        L % Logging Object
        appsettings
        
        currentSelectedFileBrowserDetail
    end

    
    properties (Access = private)
        ih % icHandlerClass

        currentSelectedFileBrowserRow

    end
    
    properties (Access = public)
        Property2 % Description
    end
    
    methods (Access = private)
        
        function results = func(app)
            
        end
    end
    
    methods (Access = public)
        
        function results = func2(app)
            
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            
            % Log that currently this is unused
            app.L.trace('Currently this is unused');



        end

        function Controller(app, action, varargin)
            
            p = inputParser;
            % Allows for unmatched name-value pairs
            p.KeepUnmatched = true;
            p.addRequired('app', @isobject);
            p.addRequired('action', @ischar);

            switch action
                case 'loadAppSettings'
                    % Setup input parser with optional
                    p.addOptional('SETTINGS_FILE', '', @ischar);
                    p.parse(app, action, varargin{:});
                    SETTINGS_FILE = p.Results.SETTINGS_FILE;
                    app.L.trace('Loading external app settings ... ');
                    try 
                        app.appsettings = yaml.loadFile(SETTINGS_FILE);
                        numKeys = length(fieldnames(app.appsettings));
                        app.L.trace(sprintf('YAML file loaded: %s', SETTINGS_FILE));
                        app.L.trace(sprintf('Number of keys loaded from app settings: %d', numKeys));
                        app.validateAppSettings();
                    catch ME
                        app.L.error(sprintf('Error loading or validating settings: %s', ME.message));
                    end

                    app.appsettings.ui.FileStatusLabels = cellfun(@(x) char(app.appsettings.file_statuses.(x).label), fieldnames(app.appsettings.file_statuses), 'UniformOutput', false);
                    app.appsettings.ui.IcStatusLabels = cellfun(@(x) char(app.appsettings.ic_statuses.(x).label), fieldnames(app.appsettings.ic_statuses), 'UniformOutput', false);

                
                case 'preLaunchTasks'

                    app.checkIfEegLabAvailable();
                    app.checkMatlabVersion();

                case 'postStartupViewTasks'
                    
                %  application title
                    app.UIFigure.Name = sprintf('%s (%s)', app.ih.getAppConstants('APPTITLE'), app.ih.getAppConstants('APPVERSION'));
                
                %  center application window
                    resolution = app.ih.getAppConstants('LAYOUT_RES');
                    screensize = get(0,'ScreenSize');
                    xpos = ceil((screensize(3)-resolution(1))/2); % center the figure in regards to width
                    ypos = ceil((screensize(4)-resolution(2))/2); % center the figure in regards to height
                    app.UIFigure.Position = [xpos ypos resolution(1) resolution(2)];

                    app.currentSelectedFileBrowserRow = missing;
                    app.fileDetailsPanel.Visible = 'off';
        
                case 'setupFileBrowserView'
                % setup File Browser Pane
                    % set up labels
                    app.fileBrowserLabel.Text               = 'File Browser';
                    app.fileBrowserFolderBox.Placeholder    = 'Set working folder.';
                    app.fileBrowserOpenButton.Text          = 'Open';

                    % set up table
                    app.fileBrowserTable.ColumnName = {'','File', 'Status', 'Flag',''}; % Updated column names
                    app.fileBrowserTable.RowName = "";
                    app.fileBrowserTable.ColumnEditable = [false false false true false]; % Make only the 'Flag' column editable
                    app.fileBrowserTable.ColumnWidth = {'fit','auto', 'fit', 'fit', 0}; % Set the width of all columns to 'auto'
                    app.fileBrowserTable.BackgroundColor = [1 1 1; 0.94 0.94 0.94]; % Turn off uitable striping

                    % set up callbacks
                    app.fileBrowserOpenButton.ButtonPushedFcn = @(btn,event) app.selectDirectory();
                
                case 'updateFileBrowserTableView'
                    % get data
                    data = app.ih.Controller('getFileBrowserTableData');
                    % update table
                    % Set the data for the table
                    app.fileBrowserTable.Data = data;
                    
                    % Iterate over each row and apply the color style to the first cell
                    for i = 1:size(data, 1)
                        colorStr = data{i, 'Color'}{1}; % Extract the color string
                        colorRGB = eval(colorStr); % Convert string to RGB value using eval

                        % Create a uistyle object for this color
                        cellStyle = uistyle;
                        cellStyle.BackgroundColor = colorRGB; % Set the background color

                        % Apply the style to the first cell of the row
                        addStyle(app.fileBrowserTable, cellStyle, 'cell', [i, 1]);

                        % Replace the cell contents with two spaces
                        app.fileBrowserTable.Data{i, 'Color'} = {'  '};
                    end
            
                    app.updateFileBrowserDetailsByRowSelection(app);
                    

                otherwise
                    error('Unhandled App action: %s', action);
            end

        end
        function result = checkIfEegLabAvailable( app )
            result = ~isempty(which('eeglab'));
            if ~result
                app.L.critical('EEGLAB is not available. Please add EEGLAB to the path and try again.');
            else
                app.L.trace('EEGLAB is available. Attempting to start without GUI...');
                system('eeglab(''nogui'') &');
                app.L.trace(sprintf('EEGLAB started without GUI as a background process. EEGLAB path: %s', which('eeglab')));
            end
        end

        function result = checkMatlabVersion( app )
            result = verLessThan('matlab', '9.7');
            if result
                app.L.error('MATLAB version 9.7 (R2019b) or higher is required. Please upgrade MATLAB and try again.');
            else
                app.L.info('MATLAB version is 9.7 (R2019b) or higher.');
            end
        end

        function validateAppSettings(app)
            % Check if the required fields exist in the appsettings
            requiredFields = {'application_settings', 'paths', 'default_output_folders', 'file_statuses','ic_statuses'};
            for i = 1:length(requiredFields)
                if ~isfield(app.appsettings, requiredFields{i})
                    error('App settings YAML file is missing the required field: %s', requiredFields{i});
                end
            end
        end

        function selectDirectory(app)
            %app.UIFigure.Visible = 'off'; % Hide the main window to prevent the dialog box from going behind it
            f = figure('Renderer', 'painters', 'Position', [-100 -100 0 0], 'CloseRequestFcn',''); %create a dummy figure so that uigetfile doesn't minimize our GUI
            folderName = uigetdir(); % Open dialog box for directory selection
            delete(f); %delete the dummy figure
            figure(app.UIFigure)
            if folderName ~= 0
                app.fileBrowserFolderBox.Value = folderName; % Update the fileBrowserFolderBox with the selected directory
                app.ih.Controller('setWorkingDirectory', folderName);
                app.Controller('updateFileBrowserTableView');
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
            app.app_grid.ColumnWidth                        = {'1.5x','3x','1x'};
            app.app_grid.RowHeight                          = {'.75x','2x','1x'};
            app.app_grid.Padding                            = [2 2 2 2]; % [top right bottom left]
            app.app_grid.BackgroundColor                    = [1 1 1]; % white background color

            % Add a panel for the file browser in the first row and first column
            app.selectFolderPanel = uipanel('Parent', app.app_grid);
            app.selectFolderPanel.Layout.Row = [1 2];
            app.selectFolderPanel.Layout.Column = 1;
            app.selectFolderPanel.Tag = 'SelectFolderPanel';  

            app.select_folder_layout = uigridlayout(app.selectFolderPanel, [4, 3]);
            app.select_folder_layout.ColumnWidth            = {'2x','2x','1x'};
            app.select_folder_layout.RowHeight              = {'1x','1x','1x','15x'};
            app.select_folder_layout.Padding                = [2 2 2 2];

            app.fileBrowserLabel = createUIComponent(app, @uilabel, app.select_folder_layout, struct('row', 1, 'column', [1 3]), ...
                struct('Text', '', 'Tag','FileBrowserLabel', 'FontWeight', 'bold', 'FontSize', 16, 'FontColor', [0 0 1]));

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
            app.fileBrowserTable.CellSelectionCallback = createCallbackFcn(app, @updateFileBrowserDetailsByRowSelection, true);


            app.fileDetailsPanel = uipanel('Parent', app.app_grid);
            app.fileDetailsPanel.Layout.Row = 3;
            app.fileDetailsPanel.Layout.Column = 1;
            app.fileDetailsPanel.Tag = 'FileDetailsPanel'; 


            app.details_file_layout = uigridlayout(app.fileDetailsPanel, [6, 3]);
            app.details_file_layout.RowHeight              = {'1x','1x','1x','1x','1x','1x'};
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
                struct('Items',{app.appsettings.ui.FileStatusLabels}, 'Tag','fileDetailsStatusDropdown'));
            app.fileDetailsStatusDropdown.ValueChangedFcn = createCallbackFcn(app, @fileDetailsStatusDropdownValueChanged, true);

    
            % Add a dropdown box for file status
            % app.fileStatusDropdown = uidropdown(glPanel);
            % app.fileStatusDropdown.Layout.Row = 2;
            % app.fileStatusDropdown.Layout.Column = 1;
            % app.fileStatusDropdown.Items = {'New', 'Draft', 'Final', 'Redo', 'Exclude'};
            % 
            %newPanel = uipanel(app.app_grid);
            % newPanel.Layout.Row = 4;
            % newPanel.Layout.Column = 1;

            % Add a grid layout manager within the panel
            % % Assuming a layout of 4 rows and 1 column
            % glPanel = uigridlayout(app.app_grid, [4, 1]);
            % glPanel.RowHeight = {'1x', '1x', '1x', '2x'};
            % glPanel.Padding = [2 2 2 2]; % [top right bottom left]
            % 
            % fileLabelAndFlaggedLayout = uigridlayout(glPanel, [1, 2]);
            % fileLabelAndFlaggedLayout.ColumnWidth = {'1x', '1x'};
            % fileLabelAndFlaggedLayout.RowHeight = {'1x'};
            % fileLabelAndFlaggedLayout.Layout.Row = 1;
            % fileLabelAndFlaggedLayout.Layout.Column = 1;
            % 
            % app.fileNameLabel = uilabel(fileLabelAndFlaggedLayout);
            % app.fileNameLabel.Layout.Row = 1;
            % app.fileNameLabel.Layout.Column = 1;
            % app.fileNameLabel.Text = 'File Name';
            % 
            % % Add a checkbox for flagged
            % app.flaggedCheckbox = uicheckbox(fileLabelAndFlaggedLayout, 'Text', 'Flagged');
            % app.flaggedCheckbox.Layout.Row = 1;
            % app.flaggedCheckbox.Layout.Column = 2;
            % 

            % % Add a dropdown box for file status
            % app.fileStatusDropdown = uidropdown(glPanel);
            % app.fileStatusDropdown.Layout.Row = 2;
            % app.fileStatusDropdown.Layout.Column = 1;
            % app.fileStatusDropdown.Items = {'New', 'Draft', 'Final', 'Redo', 'Exclude'};
            % 
            % % Add a text area box for comments
            % app.commentsTextArea = uitextarea(glPanel);
            % app.commentsTextArea.Layout.Row = 4;
            % app.commentsTextArea.Layout.Column = 1;
            % app.commentsTextArea.Value = 'Enter comments here...';
            % 
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
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = SpeedIC2

            SETTINGS_FILE = 'SpeedIC2.yaml';
            LOGGING_LEVEL = 'trace';
            MAT_FILE = 'speedic_database.mat';

            % Setup logging
            app.L = log4vhtp(LOGGING_LEVEL);

            % Load external app settings from YAML file
            Controller(app,'loadAppSettings', SETTINGS_FILE);

            % Check requirements
            Controller(app, 'preLaunchTasks');

            % Start background task
            app.ih = icHandlerClass(app.L,app.appsettings);

            % Create UIFigure and components
            createComponents(app)

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

        function updateFileDetails(app, uuid, field, value)
            % Get the file object using the UUID
            icFileObject = app.ih.Controller('getEegSetFileObjectByUuid', uuid);
    
            % Update the field with the new value
            icFileObject.manageSpeedic('update', field, value);
    
            % Resave the file
            icFileObject.Controller('resaveEegSetFile');
        end

        function fileDetailsFlaggedCheckboxValueChanged(app, event)
            value = app.fileDetailsFlaggedCheckbox.Value;
            selectedUuid = app.currentSelectedFileBrowserDetail.UUID;
            app.updateFileDetails(selectedUuid, 'flag', value);
        end
    
        function fileDetailsSaveCommentsHyperlinkClicked(app, event)
            comments = app.fileDetailsTextArea.Value;
            selectedUuid = app.currentSelectedFileBrowserDetail.UUID;
            app.updateFileDetails(selectedUuid, 'comments', comments);
        end
    
        function fileDetailsStatusDropdownValueChanged(app, event)
            status = app.fileDetailsStatusDropdown.Value;
            selectedUuid = app.currentSelectedFileBrowserDetail.UUID;
            app.updateFileDetails(selectedUuid, 'status', status);
            app.updateFileDetails(selectedUuid, 'statuscode', status);
        end

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


        function updateFileBrowserDetailsByRowSelection(app, event)
            % Get the row and column indices of the cell that was clicked

           if ismissing(app.currentSelectedFileBrowserRow)
                app.currentSelectedFileBrowserRow = 1;
                indices(1) = 1;
                app.fileDetailsPanel.Visible = 'on';
           else
                indices = event.Indices;
                app.currentSelectedFileBrowserRow = indices(1);
           end
            % Get the selected hash from the table
            selectedUuid = app.fileBrowserTable.Data.UUID{indices(1)};

            % Use hash to get ic_file object
            icFileObject = app.ih.Controller('getEegSetFileObjectByUuid', selectedUuid);

            fileBrowserDetailModel = icFileObject.Controller('generateFileBrowserDetailModel');

            app.fileDetailsNameLabel.Text = fileBrowserDetailModel.FILENAME;
            app.fileDetailsInfoLabel.Text = sprintf('FS: %d | PT: %d | T: %d | EP: %2.1fs | ICs: %d | EV: %d', ...
                fileBrowserDetailModel.SRATE, ...
                fileBrowserDetailModel.NO_SAMPLES, ...
                fileBrowserDetailModel.TRIALS, ...
                fileBrowserDetailModel.EPOCH_DURATION, ...
                fileBrowserDetailModel.NO_ICS, ...
                fileBrowserDetailModel.NO_EVENTS);

            app.fileDetailsTextArea.Value = fileBrowserDetailModel.COMMENTS;
            app.fileDetailsStatusDropdown.Value = fileBrowserDetailModel.STATUS;
            app.fileDetailsFlaggedCheckbox.Value = fileBrowserDetailModel.FLAGGED;

            app.currentSelectedFileBrowserDetail = fileBrowserDetailModel;
            
        end

        % Callback for fileDetailsFlaggedCheckbox
        
        % function fileDetailsFlaggedCheckboxValueChanged(app, event)
        %     value = app.fileDetailsFlaggedCheckbox.Value;
        %     selectedUuid = app.currentSelectedFileBrowserDetail.UUID;
        %     %selectedUuid = model.
        %     % Save the value back to the data model
        %     icFileObject = app.ih.Controller('getEegSetFileObjectByUuid', selectedUuid);
        %     icFileObject.manageSpeedic('update', 'flag', value);
        %     icFileObject.Controller('resaveEegSetFile');
        % end

        % function fileDetailsSaveCommentsHyperlinkClicked(app, event)
        %     comments = app.fileDetailsTextArea.Value;
        %     selectedUuid = app.currentSelectedFileBrowserDetail.UUID;
        %     icFileObject = app.ih.Controller('getEegSetFileObjectByUuid', selectedUuid);
        %     icFileObject.manageSpeedic('update', 'comments', comments);
        %     icFileObject.Controller('resaveEegSetFile');
        % end

        % function fileDetailsStatusDropdownValueChanged(app, event)
        %     status = app.fileDetailsStatusDropdown.Value;
        %     selectedUuid = app.currentSelectedFileBrowserDetail.UUID;
        %     icFileObject = app.ih.Controller('getEegSetFileObjectByUuid', selectedUuid);
        %     icFileObject.manageSpeedic('update', 'status', status);
        %     icFileObject.manageSpeedic('update', 'statuscode', status);
        %     icFileObject.Controller('resaveEegSetFile');
        % end


    
        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end