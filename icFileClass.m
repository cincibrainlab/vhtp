classdef icFileClass < handle
    properties

        EegSetFileName % Name of the file
        EegSetFilePath % Path to the file
        EegSetFullFile % Full path to the file
        Status % Status of the file
        Flag % Flag of the file
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

            % Check if 'speedic' field exists in o.EEGINFO.etc.vhtp
            if ~isfield(o.EEGINFO.etc.vhtp, 'speedic')
                % Initialize 'speedic' with default values
                o.EEGINFO.etc.vhtp.speedic.status = o.Controller('getStatusByCode', 'FILESTATUS_NEW');
                o.EEGINFO.etc.vhtp.speedic.flag = false;
            else
                % Confirm or reset the child fields of 'speedic'
                if ~isfield(o.EEGINFO.etc.vhtp.speedic, 'status')
                    o.EEGINFO.etc.vhtp.speedic.status = o.Controller('getStatusByCode', 'FILESTATUS_NEW');
                end
                if ~isfield(o.EEGINFO.etc.vhtp.speedic, 'flag')
                    o.EEGINFO.etc.vhtp.speedic.flag = false;
                end
            end
        end

        function status = getEegSetFileStatus(o)
            % Method to get the EEG set file status
            if isfield(o.EEGINFO.etc.vhtp, 'speedic') && ...
               isfield(o.EEGINFO.etc.vhtp.speedic, 'status')
                status = o.EEGINFO.etc.vhtp.speedic.status;
            else
                status = []; % Return empty or a default value if status is not set
            end
        end

        function flag = getEegSetFileFlag(o)
            % Method to get the EEG set file flag
            if isfield(o.EEGINFO.etc.vhtp, 'speedic') && ...
               isfield(o.EEGINFO.etc.vhtp.speedic, 'flag')
                flag = o.EEGINFO.etc.vhtp.speedic.flag;
            else
                flag = []; % Return empty or a default value if flag is not set
            end
        end

        function output = Controller( o, action, varargin )
            p = inputParser;
            p.KeepUnmatched = true;
            p.addRequired('action', @ischar);
            output = missing;

            switch action
                case 'generateFileBrowserTableRow'
                    output = {o.EegSetFileName, o.getEegSetFileStatus, o.getEegSetFileFlag};
                case 'getStatusByCode'
                    p.addOptional('statusCode', missing, @ischar);
                    p.parse(action, varargin{:});
                    switch p.Results.statusCode
                        case 'FILESTATUS_NEW'
                            output = "NEW";
                        case missing
                            o.logMessage('error', 'Missing Status Code');
                        otherwise
                            o.logMessage('error', 'Invalid Status Code');
                    end
            end

        end
    end
    methods (Static)
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