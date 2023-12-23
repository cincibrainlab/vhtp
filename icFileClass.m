classdef icFileClass < handle
    properties

        EegSetFileName % Name of the file
        EegSetFilePath % Path to the file
        EegSetFullFile % Full path to the file
        EegSetFileHash
        EegSetFileUuid
        EegProperties % struct
        EEG
        EEGINFO
        ICTABLE

        validateEegSetFileChecks = struct();
    end
    methods
        function o = icFileClass( full_filename )

            validateEegSetFile(o, full_filename);

            if o.EegProperties.validEegSetFile
                updateEegSetFile(o);
            else
                warning('File input (%s) failed validation checks. Please check the log for more information.', full_filename);
                return;
            end

        end

            %loadEegSetFileData()
        function o = updateEegSetFile(o)

            assignEegSetFile(o);
            loadEegSetFileInfo(o);
            checkEegSetFileRequirements(o)
            prepareEegSetFileRequirements(o)

        end

        function hasPassedAllChecks = validateEegSetFile(o, filename)

            o.logMessage('info', 'Validating EEG set file.');

            o.validateEegSetFileChecks.isFullFilePath   = contains(filename, filesep);
            o.validateEegSetFileChecks.isEegSetFile     = contains(lower(filename), '.set', 'IgnoreCase', true);
            o.validateEegSetFileChecks.exists           = exist(fullfile(filename), 'file') == 2;
            o.validateEegSetFileChecks.allChecks        = all(struct2array(o.validateEegSetFileChecks));

            if ~o.validateEegSetFileChecks.isFullFilePath
                o.logMessage('warning', 'The provided file name does not contain a full path.');
            end
            if ~o.validateEegSetFileChecks.isEegSetFile
                o.logMessage('warning', 'The provided file name does not contain a valid EEG set file.');
            end
            if ~o.validateEegSetFileChecks.exists
                o.logMessage('warning', 'The provided file name does not exist.');
            end
            if o.validateEegSetFileChecks.allChecks
                o.logMessage('info', 'The provided file name passed all checks.');
                o.EegSetFullFile = filename;
                hasPassedAllChecks = true;
                o.EegProperties.validEegSetFile = true;
            else
                o.logMessage('warning', 'The provided file name failed one or more checks.');
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

        function o = checkEegSetFileRequirements(o)
            % Initialize EEG properties
            o.EegProperties = struct();
            o.EegProperties.validIcaWeights = false;
            o.EegProperties.validChanLocs = false;
            o.EegProperties.validIcaAct = false;

            % Check ICA weights
            if ~isfield(o.EEGINFO, 'icaweights')
                o.logMessage('error', 'EEG does not contain ICA weights. Please run ICA first.');
            else
                o.logMessage('info', 'ICA weights found.');
                o.EegProperties.validIcaWeights  = true;
            end
            % Check for channel locations
            if ~isfield(o.EEGINFO, 'chanlocs')
                o.logMessage('error', 'EEG does not contain channel locations. Please add them first.');
            else
                o.logMessage('info', 'Channel locations found.');
                o.EegProperties.validChanLocs  = true;
            end
            % Check for ICA activations
            if ~isfield(o.EEGINFO, 'icaact')
                o.logMessage('warning', 'ICA activations not found or components are required. Calculating...');
            else
                o.logMessage('info', 'ICA activations found.');
                o.EegProperties.validIcaAct  = true;
            end
        end

        function o = prepareEegSetFileRequirements(o)
            % Prepare EEG set file requirements
            if o.EegProperties.validIcaAct
                o.logMessage('info', 'ICA activations found. Skipping calculation.');
            else
                o.logMessage('info', 'Calculating ICA activations.');
                o.EEGINFO.icaact = eeg_getica(o.EEGINFO);
            end
            % Check if 'vhtp' field exists in o.EEGINFO.etc
            if ~isfield(o.EEGINFO.etc, 'vhtp')
                o.EEGINFO.etc.vhtp = struct(); % Initialize 'vhtp' as an empty structure
            end

            % Use the new speedic handlers
            if ~o.manageSpeedic('hasField')
                o.manageSpeedic('create')
                o.manageSpeedic('update', 'flag', false);
                o.manageSpeedic('update', 'status', o.Controller('getStatusByCode', 'FILESTATUS_NEW'))
            else
                % Confirm or reset the child fields of 'speedic'
                if ~o.manageSpeedic('hasField','status')
                    o.manageSpeedic('update', 'status', o.Controller('getStatusByCode', 'FILESTATUS_NEW'))
                end
                if ~o.manageSpeedic('hasField','flag')
                    o.manageSpeedic('update', 'flag', false);
                end
            end
        end
        function result = manageSpeedic(o, action, fieldName, value)
            % Unified method for various operations on 'speedic' structure
            
            switch action
                case 'create'
                    % Create 'speedic' field if it doesn't exist
                    if ~isfield(o.EEGINFO.etc.vhtp, 'speedic')
                        o.EEGINFO.etc.vhtp.speedic = struct();
                        o.EEGINFO.etc.vhtp.speedic.status = struct();
                        o.EEGINFO.etc.vhtp.speedic.flag = false;
                        o.EEGINFO.etc.vhtp.speedic.comments = '';
                        o.EEGINFO.etc.vhtp.speedic.history = {};
                    end

                case 'hasField'
                    % Check if 'speedic' structure or a field in 'speedic' exists
                    if nargin < 3
                        % Check if 'speedic' structure exists
                        if isfield(o.EEGINFO.etc.vhtp, 'speedic')
                            % Return true if 'speedic' exists
                            result = true;
                        else
                            % Return false if 'speedic' does not exist
                            result = false;
                        end
                    else
                        % Check if the field exists in 'speedic'
                        if isfield(o.EEGINFO.etc.vhtp.speedic, fieldName)
                            % Return true if the field exists
                            result = true;
                        else
                            % Return false if the field does not exist
                            result = false;
                        end
                    end

                case 'update'
                    % Update the 'speedic' structure
                    if nargin < 4
                        error('Field name and value are required for "update" action.');
                    end
                    if isfield(o.EEGINFO.etc.vhtp.speedic, fieldName)
                        o.EEGINFO.etc.vhtp.speedic.(fieldName) = value;
                    else
                        error('Field "%s" does not exist in speedic structure.', fieldName);
                    end

                case 'get'
                    % Get the value of a field in 'speedic' structure
                    if nargin < 3
                        error('Field name is required for "get" action.');
                    end
                    if isfield(o.EEGINFO.etc.vhtp.speedic, fieldName)
                        result = o.EEGINFO.etc.vhtp.speedic.(fieldName);
                    else
                        error('Field "%s" does not exist in speedic structure.', fieldName);
                    end

                otherwise
                    error('Unknown action "%s".', action);
            end
        end
        function status = getEegSetFileStatusLabel(o)
            % Method to get the EEG set file status
            if o.manageSpeedic('hasField') && o.manageSpeedic('hasField','status') 
                status_tmp = o.manageSpeedic('get','status');
                status = status_tmp.name;
            else
                status = []; % Return empty or a default value if status is not set
            end
        end


        function status = getEegSetFileStatusColor(o)
            % Method to get the EEG set file status
            if o.manageSpeedic('hasField') && o.manageSpeedic('hasField','status')
                status_tmp = o.manageSpeedic('get','status');
                status = status_tmp.color;
            else
                status = []; % Return empty or a default value if status is not set
            end
        end

        function flag = getEegSetFileFlag(o)
            % Method to get the EEG set file flag
            if o.manageSpeedic('hasField') && o.manageSpeedic('hasField', 'flag')
                flag = o.manageSpeedic('get','flag');
            else
                flag = []; % Return empty or a default value if flag is not set
            end
        end

        function statusDetails = getFileStatusByCode(o, statusCode)
            % Method to get the details of a status code
            % For testing, override the output to give a random status
            % Maintain the original code to switch back too after testing
            FileStatusMap = containers.Map;
            FileStatusMap('FILESTATUS_NEW') = struct('name', 'New', 'color', '[0 0 1]'); % Blue in RGB
            FileStatusMap('FILESTATUS_DRAFT') = struct('name', 'Draft', 'color', '[1 1 0]'); % Yellow in RGB
            FileStatusMap('FILESTATUS_FINAL') = struct('name', 'Final', 'color', '[0 1 0]'); % Green in RGB
            FileStatusMap('FILESTATUS_REDO') = struct('name', 'Redo', 'color', '[0.5 0 0.5]'); % Purple in RGB
            FileStatusMap('FILESTATUS_EXCLUDE') = struct('name', 'Exclude', 'color', '[1 0 0]'); % Red in RGB

            % Generate a random index to select a status
            randomIndex = randi([1 FileStatusMap.Count]);
            statusKeys = FileStatusMap.keys;
            randomStatusKey = statusKeys{randomIndex};

            % if isKey(FileStatusMap, statusCode)
            %     statusDetails = FileStatusMap(statusCode);

            if isKey(FileStatusMap, randomStatusKey)
                statusDetails = FileStatusMap(randomStatusKey);
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
                case 'generateFileBrowserTableRow'
                    output = {o.getEegSetFileStatusColor, o.EegSetFileName, o.getEegSetFileStatusLabel, o.getEegSetFileFlag o.EegSetFileUuid};
                case 'getStatusByCode'
                    p.addOptional('statusCode', missing, @ischar);
                    p.parse(action, varargin{:});
                    switch p.Results.statusCode
                        case 'FILESTATUS_NEW'
                            output = o.getFileStatusByCode('FILESTATUS_NEW');  
                        case missing
                            o.logMessage('error', 'Missing Status Code');
                        otherwise
                            o.logMessage('error', 'Invalid Status Code');
                    end

                case 'generateFileBrowserDetailModel'
                    fbDetailModel = struct();
                    fbDetailModel.FILENAME = o.EEGINFO.filename;
                    fbDetailModel.UUID = o.EegSetFileUuid;
                    fbDetailModel.NO_ICS = o.getNoComps();
                    fbDetailModel.SRATE = o.EEGINFO.srate;
                    fbDetailModel.NO_SAMPLES = o.EEGINFO.pnts;
                    fbDetailModel.EPOCH_DURATION = o.EEGINFO.xmax - o.EEGINFO.xmin;
                    fbDetailModel.TRIALS = o.EEGINFO.trials;
                    fbDetailModel.COMMENTS = o.EEGINFO.etc.vhtp.speedic.comments;
                    fbDetailModel.HISTORY = o.EEGINFO.etc.vhtp.speedic.history;
                    fbDetailModel.FLAGGED = o.EEGINFO.etc.vhtp.speedic.flag;
                    fbDetailModel.STATUS = o.EEGINFO.etc.vhtp.speedic.status.name;

                    if isfield(o.EEGINFO, 'event')
                        fbDetailModel.NO_EVENTS = numel(o.EEGINFO.event);
                    else
                        fbDetailModel.NO_EVENTS = 0;
                    end

                    output = fbDetailModel;
                case 'resaveEegSetFile'
                    o.resaveEegSetFile();

            end

        end
        function resaveEegSetFile(o)
            o.EEGINFO = pop_saveset(o.EEGINFO, 'savemode', 'resave');
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