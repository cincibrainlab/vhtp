classdef icHandlerClass < handle
    properties

        EegSetFileWorkingDirectory
        EegSetFileIcObjectArray
        EegSetFileList

        FileBrowserTable

        EegSetFileCurrent
        EegSetFileLast

        Constants
        AppFlags

        Files % Array of icFileClass objects
        WorkingDirectory % Path to the working directory
        SelectedFile % Currently selected icFileClass object
    end
    methods
        function o = icHandlerClass()

            defineAppConstants(o);
            initialize_app(o);

        end

        function o = defineAppConstants(o)
            o.Constants.APPTITLE = 'SpeedIC';
            o.Constants.APPVERSION = 'Pre-release';
            o.Constants.APPAUTHOR = 'ernest.pedapati@cchmc.org';
            o.Constants.APPAUTHORORG = 'Cincinnati Children''s Hospital Medical Center';
            o.Constants.APPGITHUB = 'https://github.com/cincibrainlab';
            
            % Layout constants
            o.Constants.LAYOUT_RES = [1280 720];
        end

        function constants = getAppConstants(o, field)
            constants = o.Constants.(field);
        end

        function initialize_app(o)
            AppFlagHandler(o, 'initializeAppFlags');
            Controller(o, 'initializeClassVariables');
            View(o, 'getApplicationTitle')
        end

        function o = AppFlagHandler( o, action )

            switch action
                case 'initializeAppFlags'
                    o.AppFlags = struct();
                    o.AppFlags.Debug = true;
                    o.AppFlags.Verbose = false;
                    o.AppFlags.ValidWorkingDirectory = false;
                otherwise
                    error("Unhandled AppFlagHandler Action");
            end

        end

        function output = Controller(o, action, varargin)
            % Setup input parser with optional
            p = inputParser;
                % Allows for unmatched name-value pairs
            p.KeepUnmatched = true;

            % Add the first required input 'action'
            p.addRequired('action', @ischar);

            output = missing;

            switch action
                case 'initializeClassVariables'
                    o.EegSetFileWorkingDirectory  = missing;
                    o.EegSetFileIcObjectArray     = {};
                    o.EegSetFileCurrent           = missing;
                    o.EegSetFileLast              = missing;
                    o.AppFlags.ValidWorkingDirectory = false;
                case 'setWorkingDirectory'
                    p.addOptional('directory', pwd, @ischar);
                    p.parse(action, varargin{:});                    
                    o.WorkingDirectory = p.Results.directory;
                    o.AppFlags.ValidWorkingDirectory = true;
                    o.logMessage('info', ['Working directory set successfully: ' o.WorkingDirectory]);
                    o.Controller('createEegSetFileListFromWorkingDirectory');
                    o.Controller('createIcFileObjectsFromWorkingDirectory');
                    o.Controller('updateFileBrowserEegSetFileTable');
                case 'createEegSetFileListFromWorkingDirectory'
                    working_dir = o.WorkingDirectory;
                    p.addOptional('file_ext', "SET", @isstring);
                    p.addOptional('subdirOn', true, @islogical);
                    p.parse(action, varargin{:});
                    file_ext = p.Results.file_ext;
                    subdirOn = p.Results.subdirOn;
                    o.EegSetFileList = util_htpDirListing(working_dir, 'ext', file_ext, 'subdirOn', subdirOn, 'keepentireext', true);    
                case 'createIcFileObjectsFromWorkingDirectory'
                    filelist = o.EegSetFileList;
                    try
                        for i = 1:height(filelist)
                            fullfilename = fullfile(filelist.filepath{i}, filelist.filename{i});
                            o.EegSetFileIcObjectArray{i} = icFileClass(fullfilename);
                        end
                        o.logMessage('info', ['Number of EEGLAB SET files loaded: ' num2str(height(filelist))]);
                    catch ME
                        o.logMessage('error', ['Error loading files: ' ME.message]);
                    end
                case 'updateFileBrowserEegSetFileTable'
                    icFileObjects = o.EegSetFileIcObjectArray;
                    fileRows = cell(numel(icFileObjects), 3);
                    for i = 1:numel(icFileObjects)
                        fileRows(i, :) = icFileObjects{i}.Controller('generateFileBrowserTableRow');
                    end
                    o.FileBrowserTable = cell2table(fileRows, 'VariableNames', {'FileName', 'Status', 'Flag'});
                    disp(o.FileBrowserTable);
                    o.logMessage('info', 'File table created successfully');
                case 'getFileBrowserTableData'
                   o.Controller('updateFileBrowserEegSetFileTable');
                   output = o.FileBrowserTable;
            end
        end

        function view_component = View(o, action)
            switch action
                case 'getApplicationTitle'
                    view_component = sprintf('%s %s', o.Constants.APPTITLE, o.Constants.APPVERSION );

            end
        end

        
        % Load files into icFileClass objects

        % Create a table from icFileClass objects using getFileRow
        function output = refreshFileTable(o)
            fileRows = cell(numel(o.Files), 4);
            for i = 1:numel(o.Files)
                fileRows(i, :) = o.Files{i}.getFileRow();
            end
            app.FileBrowserTable = cell2table(fileRows, 'VariableNames', {'FileName', 'FilePath', 'Status', 'Flag'});
            disp(app.FileBrowserTable);
            output = app.FileBrowserTable;
            o.logMessage('info', 'File table created successfully');
        end

        % Method to create a view for the File Browser with specific columns
        function fileBrowserTable = FileBrowserView(o)
            fileTable = o.refreshFileTable();
            fileBrowserTable = fileTable(:, {'FileName', 'Status', 'Flag'});
            o.logMessage('info', 'File browser view created successfully');
        end

        function logMessage(o,type, message)
            switch type
                case 'debug'
                    if o.AppFlags.Debug
                        fprintf('[DEBUG]: %s\n', message);
                    end
                case 'info'
                    fprintf('[INFO]: %s\n', message);
                case 'warning'
                    fprintf('[WARNING]: %s\n', message);
                case 'error'
                    error('[ERROR]: %s\n', message);
                otherwise
                    fprintf('[UNKNOWN]: %s\n', message);
            end
        end


    end
    methods (Static)

    end
end
