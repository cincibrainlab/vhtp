classdef icHandlerClass < handle
    properties

        % load the YAML file
        appsettings;
        prechecks_results;
        postchecks_results;

        L;  % logger

        SpeedIcScriptDirectory;
        SavedState;
        EegSetFileWorkingDirectory;
        EegSetFileIcObjectArray
        EegSetFileList
        EegSetFileCell
        EegSetFileBrowserTable

        EegSetFileCurrent
        EegSetFileLast

        Constants
        AppFlags

        DB

        Files % Array of icFileClass objects
        SelectedFile % Currently selected icFileClass object
    end
    events

        processSuccess
        processError

    end
    methods
        function o = icHandlerClass(  )
            setupMatlabPaths(o);
            setupLogger(o);
            performPrechecks(o);
            loadAndValidateApplicationSettings(o, 'speedicUserSettings.yaml');
        end

        function o = initialize(o, workingDirectory)
            initializeAppFlags(o);
            validateAndSetWorkingDirectory(o, workingDirectory);
            performPostchecks(o);
            checkAndLoadSavedState(o);

            Controller(o, 'prepareEegSetFileForVisualizations');
        end

        function o = checkAndLoadSavedState(o)
            o.L.info('Checking and loading saved state...');
            if o.AppFlags.SavedStateFilesAvailable
                o.L.info('Saved state file found. Loading...');
                o.SavedState = load(fullfile(o.EegSetFileWorkingDirectory, 'speedicSavedState.mat'));
                o.SavedState = o.SavedState.DB;
                try
                    % Verify correct structure of savedstate load
                    o.L.info('Verifying the structure of the loaded state...');
                    assert(isfield(o.SavedState, 'EegSetFileWorkingDirectory'), 'Missing field: EegSetFileWorkingDirectory');
                    assert(isfield(o.SavedState, 'EegSetFileIcObjectArray'), 'Missing field: EegSetFileIcObjectArray');
                    assert(isfield(o.SavedState, 'EegSetFileList'), 'Missing field: EegSetFileList');
                    assert(isfield(o.SavedState, 'EegSetFileCell'), 'Missing field: EegSetFileCell');
                    assert(isfield(o.SavedState, 'EegSetFileBrowserTable'), 'Missing field: EegSetFileBrowserTable');
                    assert(isfield(o.SavedState, 'SavedStateDbFileName'), 'Missing field: SavedStateDbFileName');
                    assert(isfield(o.SavedState, 'SavedStateCsvFileName'), 'Missing field: SavedStateCsvFileName');
                    assert(isfield(o.SavedState, 'SavedStateLastUpdated'), 'Missing field: SavedStateLastUpdated');
                    assert(isfield(o.SavedState, 'SavedStateVersion'), 'Missing field: SavedStateVersion');
                    o.L.info('Structure verification successful.');

                catch ME
                    % If the saved state is non-conforming, move the files to a backup directory and start fresh
                    o.L.error('Non-conforming saved state detected. Moving files to backup directory and starting fresh...');
                    o.backupSavedState();
                    delete(fullfile(o.EegSetFileWorkingDirectory, 'speedicSavedState.mat'));
                    delete(fullfile(o.EegSetFileWorkingDirectory, 'speedicSavedState.csv'));
                    error('Non-conforming saved state detected. The files have been moved to the backup directory. Please start fresh.');
                end
                o.L.info('Loading saved state...');
                loadSavedState(o);
            else
                o.L.info('No saved state file found. Scanning directory.');
                % check for additiions or subtractions of files
                o.EegSetFileCell = o.Controller('createEegSetFileListFromWorkingDirectory');
                o.EegSetFileIcObjectArray  = o.Controller('createIcFileObjectsFromWorkingDirectory');
                o.EegSetFileBrowserTable = o.Controller('checkEegFileStructure');
                o.EegSetFileBrowserTable = o.Controller('forceUpdateFileBrowserEegSetFileTable');
                o.updateDatabase();

            end
        end

        function o = backupSavedState(o)
            o.L.info('Starting backup of saved state...');
            backupDir = fullfile(o.EegSetFileWorkingDirectory, 'speedic_backup');
            if ~exist(backupDir, 'dir')
                o.L.info('Backup directory does not exist. Creating...');
                mkdir(backupDir);
            end
            datestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
            o.L.info('Moving saved state files to backup directory...');
            copyfile(fullfile(o.EegSetFileWorkingDirectory, 'speedicSavedState.mat'), fullfile(backupDir, ['speedicSavedState_backup_' datestamp '.mat']));
            copyfile(fullfile(o.EegSetFileWorkingDirectory, 'speedicSavedState.csv'), fullfile(backupDir, ['speedicSavedState_backup_' datestamp '.csv']));
            o.L.info('Backup of saved state completed.');
        end

        function o = createSavedState(o)
            o.SavedState.EegSetFileWorkingDirectory = o.EegSetFileWorkingDirectory;
            o.SavedState.EegSetFileIcObjectArray = o.EegSetFileIcObjectArray;
            o.SavedState.EegSetFileList = o.EegSetFileList;
            o.SavedState.EegSetFileCell = o.EegSetFileCell;
            o.SavedState.EegSetFileBrowserTable = o.EegSetFileBrowserTable;
        end

        function o = loadSavedState(o)
            o.L.info('Backing up current state...');
            o.backupSavedState();

            % check for additiions or subtractions of files
            o.EegSetFileWorkingDirectory = o.SavedState.EegSetFileWorkingDirectory;
            o.EegSetFileCell = o.Controller('createEegSetFileListFromWorkingDirectory');
            o.EegSetFileIcObjectArray  = o.Controller('createIcFileObjectsFromWorkingDirectory');
            o.EegSetFileBrowserTable = o.Controller('checkEegFileStructure');
            o.EegSetFileBrowserTable = o.Controller('forceUpdateFileBrowserEegSetFileTable');

            % Check for missing files
            missingFiles = setdiff( o.SavedState.EegSetFileBrowserTable(:,'FULLFILE'), ... 
                o.EegSetFileBrowserTable(o.EegSetFileBrowserTable.FILEEXISTS==1,'FULLFILE'));
            if ~isempty(missingFiles)
                o.AppFlags.missingFilesPresent = true;
                o.L.warn('Missing files detected in the saved state. The files are:');
                for file = missingFiles
                    o.L.warn(char(file.FULLFILE));
                end
            else
                o.AppFlags.missingFilesPresent = false;
            end
            
            % Check for additional files
            additionalFiles = setdiff(o.EegSetFileBrowserTable(o.EegSetFileBrowserTable.FILEEXISTS==1,'FULLFILE'), o.SavedState.EegSetFileBrowserTable(:,'FULLFILE'));
            if ~isempty(additionalFiles)
                o.AppFlags.additionalFilesPresent = true;
                o.L.warn('Additional files detected in the saved state. The files are:');
                for file = additionalFiles
                    o.L.warn(char(file.FULLFILE));
                end
            else
                o.AppFlags.additionalFilesPresent = false;
                o.L.info('No additional files detected in the saved state.');
            end

            % Apply status and flag information from the previously saved files to the new list
            o.L.info('Applying status and flag information from the previously saved files to the new list...');
            for i = 1:height(o.EegSetFileBrowserTable)
                savedRow = o.SavedState.EegSetFileBrowserTable(strcmp(o.SavedState.EegSetFileBrowserTable.FILEHASH, o.EegSetFileBrowserTable.FILEHASH{i}), :);                
                if ~isempty(savedRow)
                    originalStatus = o.EegSetFileBrowserTable.FILESTATUSCODE{i};
                    originalFlag = o.EegSetFileBrowserTable.FILEFLAG(i);
                    o.EegSetFileBrowserTable.FILESTATUSCODE(i) = savedRow.FILESTATUSCODE;
                    o.EegSetFileBrowserTable.FILEFLAG(i) = savedRow.FILEFLAG;
                    o.L.info(sprintf('For file: %s, Status changed from %s to %s and Flag changed from %s to %s', o.EegSetFileBrowserTable.FILENAME{i}, ...
                        originalStatus, savedRow.FILESTATUSCODE{1}, string(originalFlag), string(savedRow.FILEFLAG(1))));
                else
                    o.L.warn(sprintf('No saved status and flag found for file: %s', char(o.EegSetFileBrowserTable.FILENAME{i})));
                end
            end
            % Save State
            o.updateDatabase();
        end

        function o = validateAndSetWorkingDirectory(o, workingDirectory)
            % Working Directory Validation
            p = inputParser;
            addRequired(p, 'workingDirectory', @(x) exist(x, 'dir') == 7);
            parse(p, workingDirectory);
            o.EegSetFileWorkingDirectory = workingDirectory;
            o.AppFlags.ValidWorkingDirectory = true;

        end

        function o = performPostchecks(o)
            % Perform postchecks related to file availability and log the status
            % Initialize postchecks structure
            o.AppFlags.SavedStateFilesAvailable = false;
        
            % Call the nested function to check file availability
            checkSpeedIcFiles();
        
            % Log status based on file availability
            if o.AppFlags.SavedStateFilesAvailable
                o.L.info('speedicSavedState.mat and speedicSavedState.csv are available in the working directory.');
            else
                o.L.warn('speedicSavedState.mat or speedicSavedState.csv is not available in the working directory');
            end
        
            % Nested function for checking file availability
            function checkSpeedIcFiles()

                % Check file availability
                matFileExists = exist(fullfile(o.EegSetFileWorkingDirectory, 'speedicSavedState.mat'), 'file') > 0;
                csvFileExists = exist(fullfile(o.EegSetFileWorkingDirectory, 'speedicSavedState.csv'), 'file') > 0;
                o.AppFlags.SavedStateFilesAvailable = matFileExists && csvFileExists;

                % Detailed logging
                if matFileExists
                    o.L.info('speedicSavedState.mat is available in the working directory.');
                else
                    o.L.warn('speedicSavedState.mat is not available in the working directory');
                end

                if csvFileExists
                    o.L.info('speedicSavedState.csv is available in the working directory.');
                else
                    o.L.warn('speedicSavedState.csv is not available in the working directory');
                end
            end
        end
        

        function o = loadAndValidateApplicationSettings(o, settingsFileName)
            % Get directory of current script
            o.SpeedIcScriptDirectory = fileparts(mfilename('fullpath'));
            o.appsettings = yaml.loadFile(fullfile(o.SpeedIcScriptDirectory, settingsFileName));
            numKeys = length(fieldnames(o.appsettings));
            o.L.trace(sprintf('YAML file loaded: %s', settingsFileName));
            o.L.trace(sprintf('Number of keys loaded from app settings: %d', numKeys));
            
            requiredFields = {'application_settings', 'paths', 'default_output_folders', 'file_statuses','ic_statuses'};
            for i = 1:length(requiredFields)
                if ~isfield(o.appsettings, requiredFields{i})
                    error('App settings YAML file is missing the required field: %s', requiredFields{i});
                end
            end

            appstruct = o.appsettings.application_settings;
            o.Constants.APPTITLE = appstruct.title;
            o.Constants.APPVERSION = appstruct.version;
            o.Constants.APPAUTHOR = appstruct.author.email;
            o.Constants.APPAUTHORORG = appstruct.author.organization;
            o.Constants.APPGITHUB = appstruct.repository;

            % Layout constants
            o.Constants.LAYOUT_RES = [appstruct.resolution.width ...
                appstruct.resolution.height];
            
            o.appsettings.ui.FileStatusCodes = fieldnames(o.appsettings.file_statuses);
            o.appsettings.ui.FileStatusLabels = cellfun(@(x) char(o.appsettings.file_statuses.(x).label), fieldnames(o.appsettings.file_statuses), 'UniformOutput', false);
            o.appsettings.ui.IcStatusLabels = cellfun(@(x) char(o.appsettings.ic_statuses.(x).label), fieldnames(o.appsettings.ic_statuses), 'UniformOutput', false);
        
            o.EegSetFileIcObjectArray     = {};
            o.EegSetFileCurrent           = missing;
            o.EegSetFileLast              = missing;

        end

        function setupMatlabPaths(~)
            % Add the current directory to the path
            addpath(genpath(fileparts(mfilename('fullpath'))));
        end

        function setupLogger(o)
            logFileName = fullfile(o.EegSetFileWorkingDirectory, 'speedicLogfile.txt');
            loggingLevel = 'trace';
            o.L = log4vhtp(loggingLevel,logFileName);
        end

        function performPrechecks(o)
            prechecks = initializePrechecks(o);
            prechecks = checkIfEegLabAvailable(o, prechecks);
            prechecks = checkMatlabVersion(o, prechecks);
            prechecks = checkEegLabPlugins(o, prechecks);
            o.prechecks_results = prechecks;
            disp('Prechecks Results:');
            disp(struct2table(o.prechecks_results));
            o.L.info('Logging prechecks results...');
            o.L.info('EEGLAB availability: %s', string(prechecks.eeglab));
            o.L.info('MATLAB version check: %s', string(prechecks.matlab));
            o.L.info('iclabel plugin availability: %s', string(prechecks.iclabel));
            o.L.info('view_props plugin availability: %s', string(prechecks.pop_prop_extended));

            function prechecks = initializePrechecks(o)
                prechecks = struct('eeglab', false, 'matlab', false, 'iclabel', false, 'pop_prop_extended', false);
            end
            function prechecks = checkIfEegLabAvailable( o, prechecks )
                prechecks.eeglab = ~isempty(which('eeglab'));
                if ~prechecks.eeglab
                    htpDoctor('fix_eeglab');
                    o.L.critical('EEGLAB is not available. Please add EEGLAB to the path and try again.');
                else
                    o.L.trace('EEGLAB is available. Attempting to start without GUI...');
                    system('eeglab(''nogui'') &');
                    o.L.trace(sprintf('EEGLAB started without GUI as a background process. EEGLAB path: %s', which('eeglab')));
                end
            end
            function prechecks = checkMatlabVersion( o, prechecks )
                prechecks.matlab = ~verLessThan('matlab', '9.7');
                if ~prechecks.matlab
                    o.L.error('MATLAB version 9.7 (R2019b) or higher is required. Please upgrade MATLAB and try again.');
                else
                    o.L.info('MATLAB version is 9.7 (R2019b) or higher.');
                end
            end
            function prechecks = checkEegLabPlugins( o, prechecks )
                prechecks.iclabel = exist('iclabel', 'file') > 0;
                if ~prechecks.iclabel
                    o.L.error('iclabel plugin is not available');
                else
                    o.L.info('iclabel plugin is available.');
                end
                prechecks.pop_prop_extended = exist('pop_prop_extended', 'file') > 0;
                if ~prechecks.pop_prop_extended
                    o.L.error('view_props plugin is not available');
                else
                    o.L.info('view_props plugin is available.');
                end
            end
        end

        function o = AppFlagHandler( o, action, varargin )

            p = inputParser;
            p.KeepUnmatched = true;
            p.addRequired('action', @ischar);
            o.L.trace('Parsing input arguments...');

            switch action
                case 'initializeAppFlags'
                    o.L.trace('Initializing application flags...');
                    o.AppFlags = struct();
                    o.AppFlags.Debug = true;
                    o.AppFlags.Verbose = false;
                    o.AppFlags.ValidWorkingDirectory = false;
                    o.AppFlags.IncludeSubFolders = true;
                    o.AppFlags.ValidWorkingDirectory = false;
                    o.AppFlags.ResetStatusCheckbox = true;
                    o.AppFlags.EegFileType        = 'SET';
                    o.AppFlags.SavedStateFilesAvailable = false;
                    o.AppFlags.missingFilesPresent = missing;
                    o.AppFlags.additionalFilesPresent = missing;
                    o.L.trace('Application flags initialized.');
                case 'setIncludeSubfoldersCheckbox'
                    o.L.trace('Setting IncludeSubfoldersCheckbox...');
                    p.addOptional('value', true, @mustBeNumericOrLogical);
                    p.parse(action, varargin{:});
                    o.AppFlags.IncludeSubFolders = p.Results.value;
                    o.L.trace('IncludeSubfoldersCheckbox set.');
                case 'setResetStatusCheckbox'
                    o.L.trace('Setting ResetStatusCheckbox...');
                    p.addOptional('value', 0,  @mustBeNumericOrLogical);
                    p.parse(action, varargin{:});
                    o.AppFlags.ResetStatusCheckbox = p.Results.value;
                    o.L.trace('ResetStatusCheckbox set.');
                otherwise
                    o.L.error('Unhandled action.');
                    error("Unhandled AppFlagHandler Action");
            end
        end
        % Convenience methods for AppFlags
        % initializeAppFlags
        function initializeAppFlags(o)
            AppFlagHandler(o, 'initializeAppFlags');
        end

        function o = DatabaseHandler( o, action, varargin )

            p = inputParser;
            p.KeepUnmatched = true;
            p.addRequired('action', @ischar);

            switch action
                case 'updateDatabase'
                    p.addOptional('dbFileName', missing,  @ischar);
                    p.addOptional('csvFileName', missing,  @ischar);

                    createSavedState(o);

                    p.parse(action, varargin{:});

                    if ~ismissing(p.Results.dbFileName)
                        o.DB = o.SavedState;
                        o.DB.SavedStateDbFileName = fullfile(o.EegSetFileWorkingDirectory, p.Results.dbFileName);
                        o.DB.SavedStateCsvFileName = fullfile(o.EegSetFileWorkingDirectory, p.Results.csvFileName);
                        o.DB.SavedStateLastUpdated = datetime('now','Format','yyyy-MM-dd HH:mm:ss');
                        o.DB.SavedStateVersion = o.Constants.APPVERSION;
                    else
                        o.L.error('Missing database filename');
                    end

                    o.DatabaseHandler('saveDatabase');

                case 'saveDatabase'
                    try
                        % Modify table to save without Status Color and
                        % other formatting
                        %rgb2hex(o.DB.EegSetFileBrowserTable.FILESTATUSCOLOR(1,:))
                        savetable = o.DB.EegSetFileBrowserTable;
                        %savetable.FILESTATUSCOLOR = [];

                        DB = o.DB;
                        save(o.DB.SavedStateDbFileName, 'DB');
                        o.L.info(['Database saved successfully: ' o.DB.SavedStateDbFileName]);
                        writetable(savetable,  o.DB.SavedStateCsvFileName);
                        o.L.info(['CSV saved successfully: '  o.DB.SavedStateCsvFileName]);
                    catch ME
                        o.L.error(['Unable to save database: ' o.DB.filename ' due to error: ' getReport(ME)]);
                    end
            end

        end


        % Convenience method: Update & Save DB/CSV
        function output = updateDatabase(o)
            try
                o.DatabaseHandler('updateDatabase', char(o.appsettings.application_settings.database_file), ...
                    char(o.appsettings.application_settings.csv_file));
                output = true;
            catch ME
                o.L.error(sprintf('%s', getReport(ME)));
            end
        end

        function L = getLogger(o)
            L = o.L;
        end

        function appsettings = getAppSettings(o)
            appsettings = o.appsettings;
        end

        function constants = getAppConstants(o, field)
            constants = o.Constants.(field);
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

                case 'createEegSetFileListFromWorkingDirectory'
                    working_dir = o.EegSetFileWorkingDirectory;
                    if isempty(working_dir) || ~isfolder(working_dir)
                        o.L.error("Invalid or missing working directory");
                        return
                    end
                    include_subfolder = o.AppFlags.IncludeSubFolders;
                    file_ext = o.AppFlags.EegFileType;
                    o.EegSetFileList = util_htpDirListing(working_dir, 'ext', file_ext, 'subdirOn', include_subfolder, 'keepentireext', true);
                    output = table2cell(o.EegSetFileList);

                case 'createIcFileObjectsFromWorkingDirectory'
                    filelist = o.EegSetFileCell;
                    for i = 1:height(filelist)
                        fullfilename = fullfile(filelist{i,1}, filelist{i,2});
                        try
                            filelist{i,3} = icFileClass(fullfilename, o.appsettings, o.L);
                        catch ME
                            filelist{i,3} = missing;
                            warning(getReport(ME));
                        end
                    end
                    o.EegSetFileCell = filelist;
                    output = filelist(:,3);
                    o.logMessage('info', ['Number of EEGLAB SET files loaded: ' num2str(height(filelist))]);

                case 'forceUpdateFileBrowserEegSetFileTable'
                    numFiles = numel(o.EegSetFileIcObjectArray);

                    % Using cellfun to apply 'getDetailedRow' function to each element
                    fileRows = cellfun(@(x) x.Controller('getDetailedRow'), o.EegSetFileIcObjectArray, 'UniformOutput', false);

                    % Concatenate the results vertically
                    output = vertcat(fileRows{:});


                case 'reportOnBrokenEegSetFileObjects'
                    missingFiles = ismissing(o.EegSetFileCell(:,3));
                    if any(missingFiles)
                        missingFilesList = o.EegSetFileCell(missingFiles,2);
                        for i = 1:numel(missingFilesList)
                            o.logMessage('error', ['File not included in table: ' missingFilesList{i}]);
                        end
                    end

                case 'getFileBrowserTableData'
                    % o.Controller('updateFileBrowserEegSetFileTable');
                    % output = o.EegSetFileBrowserTable;
                    output = o.Controller('forceUpdateFileBrowserEegSetFileTable');
                    o.EegSetFileBrowserTable = output;

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
                case 'checkEegFileStructure'
                    EegSetFileBrowserTable = o.EegSetFileBrowserTable;
                    objlist = o.EegSetFileIcObjectArray;
                    for i = 1 : numel(objlist)
                        try
                            objlist{i}.loadEegSetFileInfo();
                            %objlist{i}.EEGINFO.etc.vhtp = [];
                            %objlist{i}.Controller('resaveEegSetFile');
                            EegSetFileBrowserTable.ISVALIDSETFILE(i) = true;
                        catch ME
                            warning(ME.message);
                            EegSetFileBrowserTable.ISVALIDSETFILE(i) = false;
                        end
                    end
                    for i = 1 : numel(objlist)
                        try

                            if EegSetFileBrowserTable.ISVALIDSETFILE(i)
                                EegSetFileBrowserTable.ISVALIDICAWEIGHTS(i) = false;
                                EegSetFileBrowserTable.ISVALIDCHANLOCS(i) = false;
                                EegSetFileBrowserTable.ISVALIDICAACTS(i) = false;
                                curobj = objlist{i};

                                % Check ICA weights
                                if ~isfield(objlist{i}.EEGINFO, 'icaweights')
                                    o.L.error('%s: EEG does not contain ICA weights. Please run ICA first.', objlist{i}.EegSetFileName);
                                else
                                    %o.L.info('ICA weights found.');
                                    EegSetFileBrowserTable.ISVALIDICAWEIGHTS(i)  = true;
                                end
                                % Check for channel locations
                                if ~isfield(objlist{i}.EEGINFO, 'chanlocs')
                                    o.L.error('%s: EEG does not contain channel locations. Please add them first.', objlist{i}.EegSetFileName);
                                else
                                    %o.L.info('Channel locations found.');
                                    EegSetFileBrowserTable.ISVALIDCHANLOCS(i)  = true;
                                end
                                % Check for ICA activations
                                if ~isfield(objlist{i}.EEGINFO, 'icaact')
                                    o.L.warn('%s: ICA activations not found or components are required.', objlist{i}.EegSetFileName);
                                else
                                    %o.L.info('ICA activations found.');
                                    EegSetFileBrowserTable.ISVALIDICAACTS(i)  = true;
                                end
                                try
                                curobj.Controller('generateNativeEegSetFileBrowserDetailModel');
                                catch ME
                                    o.L.error(ME.message);
                                end
                            end
                        catch ME
                            o.L.error(ME.message);

                        end
                    end
                    output = EegSetFileBrowserTable;

                case 'prepareEegSetFileForVisualizations'
                    for i = 1:numel(o.EegSetFileIcObjectArray)
                        try
                            icFileObject = o.EegSetFileIcObjectArray{i};
                            icFileObject.validateEegSetFile();
                            icFileObject.prepareEegSetFileForVisualizations();
                            %icFileObject.loadEegSetFileData()
                        catch
                            notify(o, 'processError', icEventData(icFileObject));
                            FILESTATUSCODE = 'FILESTATUS_ERROR';
                            icFileObject.setFileStatusProperties(FILESTATUSCODE);
                            o.L.warn('%s failed', icFileObject.EegSetFileName);
                        end
                    end


                case 'runVisualizationPrep'
                    if isempty(gcp('nocreate'))
                        parpool; % Start a parallel pool with default settings
                    end
                                        % Initialize futures as a cell array
                    futures = cell(1, numel(o.EegSetFileIcObjectArray));

                    for i = 1:numel(o.EegSetFileIcObjectArray)
                        icFileObject = o.EegSetFileIcObjectArray{i};
                        try
                        icFileObject.loadEegSetFileData()
                        catch
                            notify(o, 'processError', icEventData(icFileObject));
                            FILESTATUSCODE = 'FILESTATUS_ERROR';
                            icFileObject.setFileStatusProperties(FILESTATUSCODE);
                            o.L.warn('%s failed', icFileObject.EegSetFileName);
                        end
                        %disp(icFileObject.EegSetFileUuid);

                        % Submit a parfeval job for each EEG dataset and store the future in the cell array
                        %futures{i} = parfeval(@eeg_checkset, 1, icFileObject.EEG);
                        futures{i} = parfeval(@performVisualizationPreparation, 1, icFileObject);
                    end

                    % Initialize output array
                    output = cell(size(futures));

                    % Fetch results
                    for i = 1:length(futures)
                        output{i} = fetchOutputs(futures{i});
                    end
                    return


                % case 'updateEegSetFileStatusAndFlag'
                %     StatusCodeNew = 'new';
                %     EegSetFileBrowserTable = o.EegSetFileBrowserTable;
                %     if ~ismember('Status', EegSetFileBrowserTable.Properties.VariableNames)
                %         EegSetFileBrowserTable.Status = repmat({StatusCodeNew}, height(EegSetFileBrowserTable), 1);
                %     end
                %     if ~ismember('Flag', EegSetFileBrowserTable.Properties.VariableNames)
                %         EegSetFileBrowserTable.Flag = num2cell(logical(false(height(EegSetFileBrowserTable), 1)));
                %     end
                %     for i = 1:height(EegSetFileBrowserTable)
                %         if isempty(EegSetFileBrowserTable.Status{i})
                %             EegSetFileBrowserTable.Status{i} = StatusCodeNew;
                %         end
                %         if isempty(EegSetFileBrowserTable.Flag{i})
                %             EegSetFileBrowserTable.Flag{i} = false;
                %         end
                %     end
                %     output = EegSetFileBrowserTable;

                case 'checkIfEegSetFileExistsAndUpdateTable'
                    EegSetFileBrowserTable = o.EegSetFileBrowserTable;
                    for i = 1:height(EegSetFileBrowserTable)
                        if ~ismissing(EegSetFileBrowserTable.FULLFILE{i})
                            if ~isfile(EegSetFileBrowserTable.FULLFILE{i})
                                EegSetFileBrowserTable.EXISTS{i} = false;
                            else
                                EegSetFileBrowserTable.EXISTS{i} = true;
                            end
                        end
                    end
                    output = EegSetFileBrowserTable;
            end
        end
        function view_component = View(o, action)
            switch action
                case 'getApplicationTitle'
                    view_component = sprintf('%s %s', o.Constants.APPTITLE, o.Constants.APPVERSION );

            end
        end
        function performVisualizationPreparation(o, icFileObject )
            icFileObject.runVisualizationPrep;
        end



        % Create a table from icFileClass objects using getFileRow
        function output = refreshFileTable(o)
            numColumns = size(o.EegSetFileBrowserTable, 2);
            fileRows = cell(numel(o.Files), numColumns);
            for i = 1:numel(o.Files)
                fileRows(i, :) = o.Files{i}.getFileRow();
            end
            o.EegSetFileBrowserTable = cell2table(fileRows, 'VariableNames', {'FileName', 'FilePath', 'Status', 'Flag','UUID'});
            disp(o.EegSetFileBrowserTable);
            output = o.EegSetFileBrowserTable;
            o.logMessage('info', 'File table created successfully');
        end

        % Method to create a view for the File Browser with specific columns
        function EegSetFileBrowserTable = FileBrowserView(o)
            fileTable = o.refreshFileTable();
            EegSetFileBrowserTable = fileTable(:, {'','FileName', 'Status', 'Flag'});
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
