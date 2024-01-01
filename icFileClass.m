classdef icFileClass < handle
    properties

        L % Logger
        appsettings % App settings

        EegSetFileName % Name of the file
        EegSetFilePath % Path to the file
        EegSetFullFile % Full path to the file
        EegSetFileHash
        EegSetFileUuid
        EegSetFileStatusCode
        EegSetFileStatusLabel
        EegSetFileStatusColor
        EegSetFileComments
        EegSetFileExists
        EegSetFileFlag
        EegProperties % struct
        EEG
        EEGINFO
        ICTABLE

        fbDetailModel

        validateEegSetFileChecks = struct();
    end
    methods (Access = public)
        function o = icFileClass( full_filename, appsettings, logger, varargin )

            p = inputParser;
            p.KeepUnmatched = true;
            p.addRequired('full_filename', @ischar);
            p.addRequired('appsettings', @isstruct);

            addParameter(p, 'loadEEGDirectly', false, @mustBeNumericOrLogical);
            parse(p, full_filename, appsettings, varargin{:});

            o.L = logger;
            o.appsettings = appsettings;

            o.EegSetFullFile = full_filename;
            if exist(full_filename, 'file') == 2
                [pathstr, name, ext] = fileparts(full_filename);
                o.EegSetFileName = [name, ext];
                o.EegSetFilePath = pathstr;
                o.L.info('%s: Processing file...', o.EegSetFileName);
            else
                o.L.error('Invalid file: %s', full_filename);
            end

            % Assign UUID
            o.EegSetFileUuid = char(java.util.UUID.randomUUID);
            o.L.info('%s: UUID: %s', o.EegSetFileName, o.EegSetFileUuid);

            % Assign File Hash
            fileID = fopen(full_filename, 'r');
            data = fread(fileID, '*uint8'); % Read the file as bytes
            fclose(fileID);

            md = java.security.MessageDigest.getInstance('SHA-256');
            hash = typecast(md.digest(data), 'uint8');
            hashStr = dec2hex(hash)';
            hashStr = hashStr(:)';
            o.EegSetFileHash = hashStr;
            o.L.info('%s: SHA256: %s', o.EegSetFileName, o.EegSetFileHash);

            % Set the status of the file
            statusCode = 'FILESTATUS_NEW';
            setFileStatusProperties(o, statusCode);

            setFileFlagProperties(o, false);
            setFileCommentsProperties(o, {''});
   
        end

    end

    % Methods to Set User Defined Properties
    methods (Access = public)

        function o = setFileStatusProperties(o, statusCode)
            % Method to set the status properties of a file
            fileStatusStruct = o.getFileStatusByCode(statusCode);
            oldStatusCode = o.EegSetFileStatusCode;
            o.EegSetFileStatusCode = statusCode;
            o.EegSetFileStatusLabel = fileStatusStruct.label;
            o.EegSetFileStatusColor = rgb2hex(cell2mat(fileStatusStruct.color));
            o.L.info('%s: Status: %s>>%s', o.EegSetFileName, oldStatusCode, o.EegSetFileStatusCode)
        end
        function o = setFileFlagProperties(o, FILEFLAG)
            % Method to set the status properties of a file
            o.EegSetFileFlag = FILEFLAG;
            o.L.info('%s: Flag: %s>>%s', o.EegSetFileName, string(~FILEFLAG), string(FILEFLAG))
        end
        function o = setFileCommentsProperties(o, FILECOMMENTS)
            % method to set file commments
            previousComments = o.EegSetFileComments;
            newComments = FILECOMMENTS{1};

            if isempty(previousComments)
                previousComments = 'Empty';
            end
            if isempty(newComments)
                newComments = 'Empty';
            end
            o.EegSetFileComments = newComments;
            o.L.info('%s: Comments: %s>>%s', o.EegSetFileName, previousComments, newComments)
        end

    end

    % Methods to Handle File Operations
    methods (Access = public)

        function o = LoadEegSetFile(o, varargin)

            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'loadEEGDirectly', false, @mustBeNumericOrLogical);
            parse(p, varargin{:});

            full_filename = o.EegSetFullFile;


            if p.Results.loadEEGDirectly
                o.EEGINFO = pop_loadset('filename', full_filename, 'loadmode', 'info');

                %reset the status of the file
                o.Controller('resetSpeedIcStatus');
                o.resaveEegSetFile();

            else
                validateEegSetFile(o, full_filename);

                if o.EegProperties.validEegSetFile
                    updateEegSetFile(o);
                else
                    o.L.warn('%s: Validation checks failed. Please check the log for more information.', full_filename);
                    return;
                end
            end

        end

            %loadEegSetFileData()
        function o = updateEegSetFile(o)

            assignEegSetFile(o);
            loadEegSetFileInfo(o);
            checkEegSetFileRequirements(o);
            prepareEegSetFileRequirements(o);

        end

        function hasPassedAllChecks = validateEegSetFile(o)

            filename = o.EegSetFullFile;
            o.L.info('Validating EEG set file.');

            if isempty(o.EEGINFO)
               updateEegSetFile(o);
            end

            EEG = o.EEGINFO;

            o.validateEegSetFileChecks.isFullFilePath   = contains(filename, filesep);
            o.validateEegSetFileChecks.isEegSetFile     = contains(lower(filename), '.set', 'IgnoreCase', true);
            o.validateEegSetFileChecks.exists           = exist(fullfile(filename), 'file') == 2;
            o.validateEegSetFileChecks.hasIcaWeights    = isfield(EEG, 'icaweights');
            o.validateEegSetFileChecks.hasIcClassification = isfield(EEG.etc, 'ic_classification');
            o.validateEegSetFileChecks.hasIcaActivations = ~isfield(EEG, 'icaact') || isempty(EEG.icaact);
            o.validateEegSetFileChecks.hasDipfit         = isfield(EEG, 'dipfit') && ~isempty(EEG.dipfit);
            o.validateEegSetFileChecks.hasIcBitmap       = isfield(EEG, 'ic_bitmaps') &&  ~isempty(EEG.ic_bitmaps);
            
            o.validateEegSetFileChecks.allChecks        = all(struct2array(o.validateEegSetFileChecks));

            if ~o.validateEegSetFileChecks.isFullFilePath
                o.L.warn('The provided file name does not contain a full path.');
            end
            if ~o.validateEegSetFileChecks.isEegSetFile
                o.L.warn('The provided file name does not contain a valid EEG set file.');
            end
            if ~o.validateEegSetFileChecks.exists
                o.L.warn('The provided file name does not exist.');
            end
            if o.validateEegSetFileChecks.allChecks
                o.L.info('The provided file name passed all checks.');
                o.EegSetFullFile = filename;
                hasPassedAllChecks = true;
                o.EegProperties.validEegSetFile = true;
            else
                o.L.warn('The provided file name failed one or more checks.');
                hasPassedAllChecks = false;
                o.EegProperties.validEegSetFile = false;
            end
        end

        function o = assignEegSetFile(o)
            filename = o.EegSetFullFile;
            o.logMessage('info', 'Assigning EEG set file.');
            [o.EegSetFilePath, basefilename, ext] = fileparts(filename);
            o.EegSetFileName = [basefilename ext];
            o.EegSetFileUuid = o.generateUUID();
        end

        function o = loadEegSetFileInfo(o)
            % Load EEG set file info
            try
                o.EEGINFO = pop_loadset('filename', o.EegSetFileName, 'filepath', o.EegSetFilePath, 'loadmode', 'info');
                o.EegProperties.validEegFileInfoLoad = true;
            catch ME
                o.logMessage('error', ['Failed to load EEG info: ' ME.message]);
            end
        end

        function o = loadEegSetFileData(o)
            % Load EEG set file data
            try
                o.EEG = pop_loadset('filename', o.EegSetFileName, 'filepath', o.EegSetFilePath);
                o.EegProperties.validEegFileDataLoad = true;
            catch ME
                o.logMessage('error', ['Failed to load EEG info: ' ME.message]);
            end
        end

        function result = checkEegSetFileExists(o)
            result = exist(o.EegSetFullFile, 'file') == 2;
            o.EegSetFileExists = result;
        end

        function o = checkEegSetFileRequirements(o)
            % Initialize EEG properties
            o.EegProperties = struct();
            o.EegProperties.validIcaWeights = false;
            o.EegProperties.validChanLocs = false;
            o.EegProperties.validIcaAct = false;

            % Check ICA weights
            if ~isfield(o.EEGINFO, 'icaweights')
                o.L.error('%s: No ICA weights. Please run ICA first.', o.EegSetFileName);
            else
                o.L.info('%s: ICA weights found.', o.EegSetFileName);
                o.EegProperties.validIcaWeights  = true;
            end
            % Check for channel locations
            if ~isfield(o.EEGINFO, 'chanlocs')
                o.L.error('%s: No channel locations. Please add them first.', o.EegSetFileName);
            else
                o.L.info('%s: Channel locations found.', o.EegSetFileName);
                o.EegProperties.validChanLocs  = true;
            end
            % Check for ICA activations
            if ~isfield(o.EEGINFO, 'icaact')
                o.L.warning('%s: ICA activations not found or components are required. Calculating...', o.EegSetFileName);
            else
                o.L.info('%s: ICA activations found.', o.EegSetFileName);
                o.EegProperties.validIcaAct  = true;
            end
        end

        function o = prepareEegSetFileRequirements(o)
            
            newStatusCode = 'FILESTATUS_NEW';

            % Prepare EEG set file requirements
            if o.EegProperties.validIcaAct
                o.L.info('%s: ICA activations found. Skipping calculation.', o.EegSetFileName);
            else
                o.L.info('%s: Calculating ICA activations.', o.EegSetFileName);
                o.EEGINFO.icaact = eeg_getica(o.EEGINFO);
            end
            % Check if 'vhtp' field exists in o.EEGINFO.etc
            if ~isfield(o.EEGINFO.etc, 'vhtp')
                o.EEGINFO.etc.vhtp = struct(); % Initialize 'vhtp' as an empty structure
            end

            % Use the new speedic handlers
            if ~isfield(o.EEGINFO.etc.vhtp, 'speedic')
                o.manageSpeedic('create')
                o.manageSpeedic('update', 'flag', false);

                o.manageSpeedic('update', 'status', newStatusCode);
                o.manageSpeedic('update', 'statuscode', newStatusCode);
            else
                % Confirm or reset the child fields of 'speedic'
                if ~o.manageSpeedic('hasField','status')
                    o.EEGINFO.etc.vhtp.speedic.status = struct();
                end
                o.manageSpeedic('update', 'status',  newStatusCode)

                if ~o.manageSpeedic('hasField','statuscode')
                    o.EEGINFO.etc.vhtp.speedic.statuscode = missing;
                end
                o.manageSpeedic('update', 'statuscode', newStatusCode);

                if ~o.manageSpeedic('hasField','flag')
                    o.EEGINFO.etc.vhtp.speedic.flag = missing;
                end
                o.manageSpeedic('update', 'flag', false);
            end
        end

        function result = prepareEegSetFileForVisualizations(o)

            % check for ic classifications
            if ~o.validateEegSetFileChecks.hasDipfit
                FILESTATUSCODE = 'FILESTATUS_PREP';
            else
                FILESTATUSCODE = o.EegSetFileStatusCode;
            end
            if ~o.validateEegSetFileChecks.hasIcBitmap
                FILESTATUSCODE = 'FILESTATUS_PREP';
            else
                FILESTATUSCODE = o.EegSetFileStatusCode;
            end
            % check for dip fit

            % change status to FILESTATUS_PREP
            o.setFileStatusProperties(FILESTATUSCODE);
            o.L.warn('%s: Missing Visualization Fields (ICLABEL & DIPFIT)', o.EegSetFileName);

        end

        function o = runVisualizationPrep(o)

            if isempty(o.EEG)
                o.loadEegSetFileData;
            end
               
            EEG = o.EEG;
            FILESTATUSCODE = o.EegSetFileStatusCode;

            try
                if ~o.validateEegSetFileChecks.hasDipfit
                  %  EEG = eeg_htpEegCalcDipfit(EEG);
                    o.validateEegSetFileChecks.hasDipfit = true;
                end
            catch ME
                FILESTATUSCODE = 'FILESTATUS_ERROR';
                o.setFileStatusProperties(FILESTATUSCODE);
                o.L.warn('%s: %s', o.EegSetFileName, getReport(ME));
            end

            try
                if ~o.validateEegSetFileChecks.hasIcBitmap
                    EEG = eeg_htpVisualizeIcProps(EEG);
                    o.validateEegSetFileChecks.hasIcBitmap = true;
                end
            catch ME
                FILESTATUSCODE = 'FILESTATUS_ERROR';
                o.setFileStatusProperties(FILESTATUSCODE);
                o.L.warn('%s: %s', o.EegSetFileName, getReport(ME));
            end

            if o.validateEegSetFileChecks.hasDipfit && o.validateEegSetFileChecks.hasIcBitmap
                FILESTATUSCODE = 'FILESTATUS_NEW';
                o.setFileStatusProperties(FILESTATUSCODE);
                o.L.info('%s: Successful Prep for Visualization.', o.EegSetFileName);
            else
                FILESTATUSCODE = 'FILESTATUS_REDO';
                o.setFileStatusProperties(FILESTATUSCODE);
                o.L.info('%s: Please check file for errors.', o.EegSetFileName);
            end

        end

        function result = manageSpeedic(o, action, fieldName, value)
            % Unified method for various operations on 'speedic' structure
        
            % Check if 'speedic' structure exists
            if ~isfield(o.EEGINFO.etc.vhtp, 'speedic')
                o.EEGINFO.etc.vhtp.speedic = struct();
                o.EEGINFO.etc.vhtp.speedic.status = struct();
                o.EEGINFO.etc.vhtp.speedic.statuscode = missing;
                o.EEGINFO.etc.vhtp.speedic.flag = false;
                o.EEGINFO.etc.vhtp.speedic.comments = '';
                o.EEGINFO.etc.vhtp.speedic.history = {};
            end
        
            switch action
                case 'hasField'
                    % Check if the field exists in 'speedic'
                    result = isfield(o.EEGINFO.etc.vhtp.speedic, fieldName);
        
                case 'update'
                    % Update the 'speedic' structure
                    if nargin < 4
                        error('Field name and value are required for "update" action.');
                    end
                    if strcmp(fieldName, 'status')
                        o.EEGINFO.etc.vhtp.speedic.(fieldName) = o.Controller('getStatusByCode', value);
                    else
                        o.EEGINFO.etc.vhtp.speedic.(fieldName) = value;
                    end
        
                case 'get'
                    % Get the value of a field in 'speedic' structure
                    if nargin < 3
                        error('Field name is required for "get" action.');
                    end
                    result = o.EEGINFO.etc.vhtp.speedic.(fieldName);
        
                case 'remove'
                    if nargin < 3
                        error('Field name is required for "remove" action.');
                    end
                    if isfield(o.EEGINFO.etc.vhtp.speedic, fieldName)
                        o.EEGINFO.etc.vhtp.speedic = rmfield(o.EEGINFO.etc.vhtp.speedic, fieldName);
                        o.EEGINFO.etc.vhtp.speedic.(fieldName) = missing;
                    else
                        warning('Field "%s" does not exist in speedic structure, creating ...', fieldName);
                        o.EEGINFO.etc.vhtp.speedic.(fieldName) = missing;
                    end
                otherwise
                    error('Unknown action "%s".', action);
            end
        end

        function statusDetails = getFileStatusByCode(o, statusCode)
            % Method to get the details of a status code
            % For testing, override the output to give a random status
            % Maintain the original code to switch back too after testing
            FileStatusMap = containers.Map;
            % Check if the status code exists in the appsettings
            if isfield(o.appsettings.file_statuses, statusCode)
                % Assign the status code details from appsettings to the FileStatusMap
                FileStatusMap(statusCode) = o.appsettings.file_statuses.(statusCode);
            else
                % Log a warning or error if the status code is not found in appsettings
                o.logMessage('warning', sprintf('Missing file status code in YAML: %s', statusCode));
            end

            % Generate a random index to select a status
            randomIndex = randi([1 FileStatusMap.Count]);
            statusKeys = FileStatusMap.keys;
            randomStatusKey = statusKeys{randomIndex};

            % if isKey(FileStatusMap, statusCode)
            %     statusDetails = FileStatusMap(statusCode);
            %     statusDetails.label = char(statusDetails.label);
            % 

            if isKey(FileStatusMap, randomStatusKey)
                statusDetails = FileStatusMap(randomStatusKey);
                statusDetails.label = char(statusDetails.label);

            else
                statusDetails = struct('name', 'Unknown', 'color', 'Gray');
            end
        end

        function output = Controller( o, action, varargin )
            p = inputParser;
            p.KeepUnmatched = true;
            p.addRequired('action', @ischar);
            output = missing;

            switch action
                case 'resetSpeedIcStatus'
                    o.manageSpeedic('remove', 'status');
                    o.manageSpeedic('remove', 'statuscode');
                    o.manageSpeedic('update', 'status', o.Controller('getStatusByCode', 'FILESTATUS_NEW'));
                    o.manageSpeedic('update', 'statuscode', 'FILESTATUS_NEW');
                case 'generateBasicFileBrowserTableRow'
                    varnames = {'FULLFILE','FILENAME','FILEPATH','FILEUUID','FILEHASH','FILESTATUSCODE','FILESTATUSCOLOR','FILESTATUSLABEL','FILEFLAG','FILECOMMENTS','FILEEXISTS'};
                    row = {o.EegSetFullFile, o.EegSetFileName, o.EegSetFilePath, o.EegSetFileUuid, o.EegSetFileHash, o.EegSetFileStatusCode, ...
                     [o.EegSetFileStatusColor], o.EegSetFileStatusLabel, o.EegSetFileFlag, o.EegSetFileComments, o.checkEegSetFileExists};
                    output = cell2table(row, 'VariableNames', varnames);
                case 'generateFileBrowserTableRow'
                    output = {o.getEegSetFileStatusColor, o.EegSetFileName, o.getEegSetFileStatusLabel, o.getEegSetFileFlag, o.EegSetFileUuid};
                case 'getStatusByCode'
                    p.addOptional('statusCode', missing, @ischar);
                    p.parse(action, varargin{:});
                    if ismissing(p.Results.statusCode)
                        output = o.getFileStatusByCode('FILESTATUS_NEW');
                    else
                        switch p.Results.statusCode
                            case 'FILESTATUS_NEW'
                                output = o.getFileStatusByCode('FILESTATUS_NEW');  
                            otherwise
                                o.logMessage('error', 'Invalid Status Code');
                        end
                    end

                case 'generateNativeEegSetFileBrowserDetailModel'
                    fbDetailModel = table();
                    fbDetailModel.FILENAME = {o.EEGINFO.filename};
                    fbDetailModel.UUID = {o.EegSetFileUuid};
                    fbDetailModel.NO_ICS = {o.getNoComps()};
                    fbDetailModel.SRATE = {o.EEGINFO.srate};
                    fbDetailModel.NO_SAMPLES = {o.EEGINFO.pnts};
                    fbDetailModel.EPOCH_DURATION = {o.EEGINFO.xmax - o.EEGINFO.xmin};
                    fbDetailModel.TRIALS = {o.EEGINFO.trials};

                    if fbDetailModel.TRIALS{1} > 1
                        fbDetailModel.EPOCHED = {true};
                    else
                        fbDetailModel.EPOCHED = {false};
                    end


                    if isfield(o.EEGINFO, 'event')
                        fbDetailModel.NO_EVENTS = numel(o.EEGINFO.event);
                    else
                        fbDetailModel.NO_EVENTS = 0;
                    end
                
                    varnames = {'NO_ICS', 'SRATE', 'NO_SAMPLES', 'EPOCH_DURATION', 'EPOCHED', 'TRIALS', 'NO_EVENTS'};
                    row = {fbDetailModel.NO_ICS, fbDetailModel.SRATE, fbDetailModel.NO_SAMPLES, fbDetailModel.EPOCH_DURATION, fbDetailModel.EPOCHED, fbDetailModel.TRIALS, fbDetailModel.NO_EVENTS};
                    output = cell2table(row, 'VariableNames', varnames);

                    %output = fbDetailModel;
                    o.fbDetailModel = fbDetailModel;

                case 'getDetailedRow'
                    output = horzcat(o.Controller('generateBasicFileBrowserTableRow'), ...
                        o.Controller('generateNativeEegSetFileBrowserDetailModel'));
                        
                case 'speedicfields'

                    fbDetailModel.COMMENTS = o.EEGINFO.etc.vhtp.speedic.comments;
                    fbDetailModel.HISTORY = o.EEGINFO.etc.vhtp.speedic.history;
                    fbDetailModel.FLAGGED = o.EEGINFO.etc.vhtp.speedic.flag;
                    fbDetailModel.STATUS = o.EEGINFO.etc.vhtp.speedic.status.label;
                    fbDetailModel.STATUS_CODE = o.EEGINFO.etc.vhtp.speedic.statuscode;

                case 'resaveEegSetFile'
                    o.resaveEegSetFile();

            end

        end
        function resaveEegSetFile(o)
            if isempty(o.EEG)
                o.EEG = pop_loadset('filename', o.EEGINFO.filename);
            end
            o.EEG.etc.vhtp.speedic.info = o.Controller('getDetailedRow');
            disp(o.EEG.etc.vhtp.speedic.info);
            % o.EEG.etc.vhtp.speedic.comments = o.EEGINFO.etc.vhtp.speedic.comments;
            % o.EEG.etc.vhtp.speedic.history = o.EEGINFO.etc.vhtp.speedic.history;
            % o.EEG.etc.vhtp.speedic.flag = o.EEGINFO.etc.vhtp.speedic.flag;
            % o.EEG.etc.vhtp.speedic.status.label = o.EEGINFO.etc.vhtp.speedic.status.label;
            % o.EEG.etc.vhtp.speedic.statuscode = o.EEGINFO.etc.vhtp.speedic.statuscode;
            fprintf('Faux Saving EEG set file...\n');
            % o.EEG = pop_saveset(o.EEG, 'savemode', 'resave');
        end
        function no_comps = getNoComps(o)
            no_comps = size(o.EEGINFO.icaweights, 1);
        end
        
    end
    methods (Static)
        function uuid = generateUUID()
            uuid = char(java.util.UUID.randomUUID);
        end
        function hash = md5hash(data)
            md = java.security.MessageDigest.getInstance('MD5');
            hashedBytes = md.digest(uint8(data));
            hash = sprintf('%02x', typecast(hashedBytes, 'uint8'));
        end
        function logMessage(type, message)
            switch type
                case 'info'
                    fprintf('[INFO]: %s\n', message);
                case 'warning'
                    warning('icFileClass:Warning','[WARNING]: %s', message);
                case 'error'
                    error('icFileClass:Error','[ERROR]: %s', message);
                otherwise
                    fprintf('[UNKNOWN]: %s\n', message);
            end
        end
    end
end