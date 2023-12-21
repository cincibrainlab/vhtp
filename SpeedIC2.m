classdef SpeedIC2 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        fileBrowserLabel        matlab.ui.control.Label
        fileBrowserFolderBox    matlab.ui.control.EditField
        fileBrowserOpenButton   matlab.ui.control.Button
        fileBrowserTable        matlab.ui.control.Table

        img_open_layout matlab.ui.container.GridLayout
    end

    
    properties (Access = private)
        ih % icHandlerClass

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

            app.ih = icHandlerClass();

            Controller(app, 'postStartupViewTasks')
            Controller(app, 'setupFileBrowser')
        end

        function Controller(app, action)

            switch action
                case 'postStartupViewTasks'
                    
                %  application title
                    app.UIFigure.Name = sprintf('%s (%s)', app.ih.getAppConstants('APPTITLE'), app.ih.getAppConstants('APPVERSION'));
                
                %  center application window
                    resolution = app.ih.getAppConstants('LAYOUT_RES');
                    screensize = get(0,'ScreenSize');
                    xpos = ceil((screensize(3)-resolution(1))/2); % center the figure in regards to width
                    ypos = ceil((screensize(4)-resolution(2))/2); % center the figure in regards to height
                    app.UIFigure.Position = [xpos ypos resolution(1) resolution(2)];

                case 'setupFileBrowser'
                % setup File Browser Pane
                    % set up labels
                    app.fileBrowserLabel.Text               = 'File Browser';
                    app.fileBrowserFolderBox.Placeholder    = 'Set working folder.';
                    app.fileBrowserOpenButton.Text          = 'Open';

                    % set up table
                    app.fileBrowserTable.ColumnName = {'File', 'Status', 'Flag'}; % Updated column names
                    app.fileBrowserTable.RowName = "";

                    % set up callbacks
                    app.fileBrowserOpenButton.ButtonPushedFcn = @(btn,event) app.selectDirectory();
                
                case 'updateFileBrowserTableView'
                    % get data
                    data = app.ih.Controller('getFileBrowserTableData');
                    % update table
                    app.fileBrowserTable.Data = data;


                otherwise
                    error('Unhandled App action: %s', action);
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

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create a grid layout manager within the figure
            % Assuming a layout of 2 rows and 3 columns
            gl = uigridlayout(app.UIFigure, [2, 3]);
            
            % Define the width of the columns and the height of the rows
            % The first column for the file browser, the second for the image, and the third for the component table
            gl.ColumnWidth = {'1.5x', '3x', '1.5x'};
            gl.RowHeight = {'.5x','3x', '1x'};
            
            fb_open_layout = uigridlayout(gl, [2, 2]);
            fb_open_layout.ColumnWidth = {'3x', '1x'};
            fb_open_layout.RowHeight = {'1x','1x'};
            
            % Add a label with bold and blue text
            app.fileBrowserLabel = uilabel(fb_open_layout);
            app.fileBrowserLabel.Layout.Row = 1;
            app.fileBrowserLabel.Layout.Column = [1 2];
            app.fileBrowserLabel.FontWeight = 'bold';
            app.fileBrowserLabel.FontSize = 16;
            app.fileBrowserLabel.FontColor = [0 0 1]; % Blue color
            app.fileBrowserLabel.Text   = '';

            app.fileBrowserFolderBox = uieditfield(fb_open_layout, 'text');
            app.fileBrowserFolderBox.Layout.Row = 2;
            app.fileBrowserFolderBox.Layout.Column = 1; 
            
            app.fileBrowserOpenButton = uibutton(fb_open_layout, 'Text', 'Open');
            app.fileBrowserOpenButton.Layout.Row = 2;
            app.fileBrowserOpenButton.Layout.Column = 2;
            
            
            app.fileBrowserTable = uitable(gl);
            app.fileBrowserTable.Layout.Row = [2, 3]; % Span both rows
            app.fileBrowserTable.Layout.Column = 1;
            app.fileBrowserTable.ColumnEditable = [false false true]; % Make only the 'Flag' column editable
            app.fileBrowserTable.ColumnWidth = {'auto', 'fit', 'fit'}; % Set the width of all columns to 'auto'
            app.fileBrowserTable.Data = []; % Example data with filenames, status, and logical flags

            app.img_open_layout = uigridlayout(gl, [2, 4]);
            app.img_open_layout.ColumnWidth = {'1x', '1x', '1x', '1x'};
            app.img_open_layout.RowHeight = {'1x','1x'};
            app.img_open_layout.Layout.Column = 2;  
            app.img_open_layout.Layout.Row = 2;
           
            % Add an axes for displaying the image in the first row and second column
            imgAxes = uiaxes(app.img_open_layout);
            imgAxes.Layout.Row = [1 2];
            imgAxes.Layout.Column = [1 4];
            
            % Add a panel for the buttons in the second row and second column
            buttonPanel = uipanel(gl);
            buttonPanel.Layout.Row = 3;
            buttonPanel.Layout.Column = 2;
            
            % Inside the panel, you can add buttons for quick tagging
            % Here's an example of adding a button
            tagButton = uibutton(buttonPanel, 'Text', 'Quick Tag');
            % You can set the button's position within the panel using its 'Position' property
            tagButton.Position = [20 20 100 30]; % [left bottom width height]
            
            % Add a table for displaying the components in the first and second row of the third column
            componentTable = uitable(gl);
            componentTable.Layout.Row = [2, 3]; % Span both rows
            componentTable.Layout.Column = 3;
            % Define the Data property of the table to include fit quality and other associated values
            componentTable.Data = { ...
                'IC01', 'Artifact', 'Rejected', false; ...
                'IC02', 'Brain', 'Accepted', true; ...
                'IC03', 'Muscle', 'Rejected', false; ...
                'IC04', 'Eye', 'Rejected', false; ...
                'IC05', 'Brain', 'Accepted', true; ...
                'IC06', 'Heart', 'Rejected', false; ...
                'IC07', 'Channel Noise', 'Rejected', false; ...
                'IC08', 'Brain', 'Accepted', true; ...
                'IC09', 'Artifact', 'Rejected', false; ...
                'IC10', 'Brain', 'Accepted', true ...
            }; % Realistic example data with IC labels, status, and flags
            componentTable.ColumnName = {'IC', 'Label', 'Status', 'Flag'}; % Updated column names
            componentTable.RowName = "";


            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = SpeedIC2

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end