classdef icHandlerClass < handle
    properties

        % load the YAML file
        appsettings;

        L;  % logger

        EegSetFileWorkingDirectory
        EegSetFileIcObjectArray
        EegSetFileList
        EegSetFileCell

        FileBrowserTable

        EegSetFileCurrent
        EegSetFileLast

        Constants
        AppFlags

        DB

        Files % Array of icFileClass objects
        WorkingDirectory % Path to the working directory
        SelectedFile % Currently selected icFileClass object
    end
    methods
        function o = icHandlerClass(LogObject, ExternalAppSettings)

            p = inputParser;
            addOptional(p, 'LogObject', [], @isobject);
            addOptional(p, 'ExternalAppSettings', [], @isstruct);
            parse(p, LogObject, ExternalAppSettings);

            try
                o.L = LogObject;
            catch ME
                o.L.error(sprintf('%s', getReport(ME)));
            end

            try
                o.appsettings = ExternalAppSettings;
            catch ME
                o.L.error(sprintf('%s', getReport(ME)));
            end

            try
                o.DatabaseHandler('initDatabase', char(o.appsettings.application_settings.database_file))
            catch ME
                o.L.error(sprintf('%s', getReport(ME)));
            end

            defineAppConstants(o);
            AppFlagHandler(o, 'initializeAppFlags');
            Controller(o, 'initializeClassVariables');
            View(o, 'getApplicationTitle')
        end


        function o = defineAppConstants(o)
            app = o.appsettings.application_settings;
            o.Constants.APPTITLE = app.title;
            o.Constants.APPVERSION = app.version;
            o.Constants.APPAUTHOR = app.author.email;
            o.Constants.APPAUTHORORG = app.author.organization;
            o.Constants.APPGITHUB = app.repository;
            
            % Layout constants
            o.Constants.LAYOUT_RES = [app.resolution.width ...
                app.resolution.height];

        end

        function constants = getAppConstants(o, field)
            constants = o.Constants.(field);
        end

        function initialize_app(o)

        end

        function o = DatabaseHandler( o, action, varargin )

            p = inputParser;
            p.KeepUnmatched = true;
            p.addRequired('action', @ischar);

            switch action
                case 'initDatabase'
                    p.addOptional('dbFileName', missing,  @ischar);
                    p.parse(action, varargin{:});

                    if ~ismissing(p.Results.dbFileName)
                        o.DB.filename = fullfile(fileparts(mfilename('fullpath')), p.Results.dbFileName);
                        o.DB.desc ='Speed IC database';
                        o.DB.lastUpdated = datetime('now','Format','yyyy-MM-dd HH:mm:ss');
                        else
                        o.L.error('Missing database filename');
                    end
                    o.L.info(['Database initialized successfully: ' o.DB.filename]);
                    o.DatabaseHandler('saveDatabase');
                    
                case 'saveDatabase'
                    try
                        o.DB.lastUpdated = datetime('now','Format','yyyy-MM-dd HH:mm:ss');
                        DB = o.DB;
                        save(o.DB.filename, 'DB');
                        o.L.info(['Database saved successfully: ' o.DB.filename]);
                    catch ME
                        o.L.error(['Unable to save database: ' o.DB.filename ' due to error: ' getReport(ME)]);
                    end


            end

        end

        function o = AppFlagHandler( o, action, varargin )

            p = inputParser;
            p.KeepUnmatched = true;
            p.addRequired('action', @ischar);

            switch action
                case 'initializeAppFlags'
                    o.AppFlags = struct();
                    o.AppFlags.Debug = true;
                    o.AppFlags.Verbose = false;
                    o.AppFlags.ValidWorkingDirectory = false;
                    o.AppFlags.IncludeSubFolders = true;
                    o.AppFlags.ValidWorkingDirectory = false;
                    o.AppFlags.ResetStatusCheckbox = true;
                    o.AppFlags.EegFileType        = 'SET';
                case 'setIncludeSubfoldersCheckbox'
                    p.addOptional('value', true, @mustBeNumericOrLogical);
                    p.parse(action, varargin{:});
                    o.AppFlags.IncludeSubFolders = p.Results.value;
                case 'setResetStatusCheckbox'
                    p.addOptional('value', 0,  @mustBeNumericOrLogical);
                    p.parse(action, varargin{:}); 
                    o.AppFlags.ResetStatusCheckbox = p.Results.value;
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


                case 'setWorkingDirectory'
                    p.addOptional('directory', pwd, @ischar);
                    p.parse(action, varargin{:});                    
                    o.WorkingDirectory = p.Results.directory;
                    o.AppFlags.ValidWorkingDirectory = true;
                    o.L.info(['Working directory set successfully: ' o.WorkingDirectory]);
                    o.Controller('createEegSetFileListFromWorkingDirectory');
                    o.Controller('createIcFileObjectsFromWorkingDirectory');
                    o.Controller('updateFileBrowserEegSetFileTable');

                case 'createEegSetFileListFromWorkingDirectory'
                    working_dir = o.WorkingDirectory;
                    include_subfolder = o.AppFlags.IncludeSubFolders;
                    file_ext = o.AppFlags.EegFileType;
                    o.EegSetFileList = util_htpDirListing(working_dir, 'ext', file_ext, 'subdirOn', include_subfolder, 'keepentireext', true);    
                    o.EegSetFileCell = table2cell(o.EegSetFileList);

                case 'createIcFileObjectsFromWorkingDirectory'
                    filelist = o.EegSetFileCell;
                    for i = 1:height(filelist)
                        fullfilename = fullfile(filelist{i,1}, filelist{i,2});
                        try
                            filelist{i,3} = icFileClass(fullfilename, o.appsettings);
                        catch ME
                            filelist{i,3} = missing;
                            warning(getReport(ME));
                        end
                    end
                    o.EegSetFileCell = filelist;
                    o.EegSetFileIcObjectArray = filelist(:,3);
                    o.logMessage('info', ['Number of EEGLAB SET files loaded: ' num2str(height(filelist))]);

                case 'createIcFileObjectsFromWorkingDirectory_backup'
                    filelist = o.EegSetFileCell;
                    try
                        for i = 1:height(filelist)
                            fullfilename = fullfile(filelist{i,1}, filelist{i,2});
                            try 
                                if o.AppFlags.ResetStatusCheckbox
                                    filelist{i,3} = icFileClass(fullfilename, o.appsettings);
                                    filelist{i,3}.Controller('resetSpeedIcStatus');
                                else
                                    filelist{i,3} = icFileClass(fullfilename);
                                end
                            catch ME
                                filelist{i,3} = icFileClass(fullfilename, o.appsettings, 'loadEEGDirectly', true);
                                if ~ismissing(filelist{i,3})
                                    filelist{i,3}.Controller('updateStatusField', 'Error');
                                end
                                o.L.warning(['unable to load:' fullfilename ' due to error: ' getReport(ME)]);
                                filelist{i,3} = missing;
                            end
                        end
                        o.EegSetFileCell = filelist;
                        o.EegSetFileIcObjectArray = filelist(:,3);
                        o.logMessage('info', ['Number of EEGLAB SET files loaded: ' num2str(height(filelist))]);
                    catch ME
                        o.logMessage('error', sprintf('Error loading file: %s from %s', fullfilename, getReport(ME)));
                    end
                
                case 'updateFileBrowserEegSetFileTable'
                    o.Controller('reportOnBrokenEegSetFileObjects');
                    icFileObjectsWithoutMissing = o.EegSetFileIcObjectArray(~ismissing(o.EegSetFileIcObjectArray));
                    numColumns = numel(icFileObjectsWithoutMissing{1}.Controller('generateFileBrowserTableRow'));
                    fileRows = cell(numel(icFileObjectsWithoutMissing), numColumns);
                    for i = 1:numel(icFileObjectsWithoutMissing)
                        fileRows(i, :) = icFileObjectsWithoutMissing{i}.Controller('generateFileBrowserTableRow');
                    end
                    o.FileBrowserTable = cell2table(fileRows, 'VariableNames', {'Color','FileName', 'Status', 'Flag','UUID'});
                    disp(o.FileBrowserTable);
                    o.logMessage('info', 'File table created successfully');

                case 'reportOnBrokenEegSetFileObjects'
                    missingFiles = ismissing(o.EegSetFileCell(:,3));
                    if any(missingFiles)
                        missingFilesList = o.EegSetFileCell(missingFiles,2);
                        for i = 1:numel(missingFilesList)
                            o.logMessage('error', ['File not included in table: ' missingFilesList{i}]);
                        end
                    end
                
                case 'getFileBrowserTableData'
                   o.Controller('updateFileBrowserEegSetFileTable');
                   output = o.FileBrowserTable;
                   
                case 'getEegSetFileObjectByUuid'
                    p.addOptional('uuid', missing, @ischar);
                    p.parse(action, varargin{:});
                    uuid = p.Results.uuid;
                    if ismissing(uuid)
                        o.logMessage('error', 'Missing UUID value');
                    else
                        for i = 1:numel(o.EegSetFileIcObjectArray)
                            if strcmp(o.EegSetFileIcObjectArray{i}.EegSetFileUuid, uuid)
                                output = o.EegSetFileIcObjectArray{i};
                                break;
                            end
                        end
                        if ismissing(output)
                            o.logMessage('error', 'No matching UUID found');
                        end
                    end

                
            end
        end

        function view_component = View(o, action)
            switch action
                case 'getApplicationTitle'
                    view_component = sprintf('%s %s', o.Constants.APPTITLE, o.Constants.APPVERSION );

            end
        end

        

        % Create a table from icFileClass objects using getFileRow
        function output = refreshFileTable(o)
            numColumns = size(o.FileBrowserTable, 2);
            fileRows = cell(numel(o.Files), numColumns);
            for i = 1:numel(o.Files)
                fileRows(i, :) = o.Files{i}.getFileRow();
            end
            app.FileBrowserTable = cell2table(fileRows, 'VariableNames', {'FileName', 'FilePath', 'Status', 'Flag','UUID'});
            disp(app.FileBrowserTable);
            output = app.FileBrowserTable;
            o.logMessage('info', 'File table created successfully');
        end

        % Method to create a view for the File Browser with specific columns
        function fileBrowserTable = FileBrowserView(o)
            fileTable = o.refreshFileTable();
            fileBrowserTable = fileTable(:, {'','FileName', 'Status', 'Flag'});
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
