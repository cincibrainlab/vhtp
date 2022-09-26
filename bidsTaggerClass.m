classdef bidsTaggerClass < handle
    % BIDSTAGGERCLASS Used to prepare SET files for BIDS export
    %   Authors: K. Cullion and E. Pedapati
    %   Source: https://github.com/cincibrainlab/vhtp

    properties
        bids_parameters;
        bids_template;
        setpath;
        setlist;
        exportpath;

        populateData;
        pinfo_table;

        % dependencies
        eeglab_present;
        bidsplugin_present;
        all_dependencies_present;
        % validation
        last_validation;

        % display
        statuslog;
        db;

        % gate for actions
        button_export;
        button_template;
        button_setdir;
        button_exportdir;
        button_recheck;

    end

    methods % main
        function obj = bidsTaggerClass()
            % BIDSTAGGER Construct class

            obj.statuslog = obj.outputHandler('init');
            obj.outputHandler('msg', sprintf('MATLAB Version %s', version));
            obj.createLabelDatabase;

            obj.buttonHandler('all_buttons_off');

            obj.button_recheck = true;
            obj.eeglab_present = false;
            obj.bidsplugin_present = false;
            obj.checkDependencies;


        end
        function obj = loadParameterFile( obj, parameter_file )
            % output struct matches export_bids specifications
            % see example at https://github.com/cincibrainlab/vhtp/bids_parameters/bids_Resting.m

            % Check for previous parameters
            if obj.validationHandler('is_valid_struct', obj.bids_parameters)
                obj.outputHandler('msg', sprintf("Current BIDS parameters cleared.") );
                obj.bids_parameters = [];
            else
                obj.outputHandler('msg', sprintf("No current BIDS parameters loaded.") );
            end

            % User can select or pass file name
            if nargin < 2
                [file, path] = uigetfile('*.m');
                if isequal(file,0)
                    obj.outputHandler('error', sprintf("BIDS parameters file selection canceled.") );
                else
                    parameter_file = fullfile(path,file);
                end
            else
                obj.outputHandler('msg', sprintf("Loading BIDS parameters from %s", parameter_file) );
            end

            % prepare to run script to capture variables
            obj.outputHandler('msg', sprintf("Loading BIDS parameters from %s", parameter_file) );

            if obj.validationHandler('is_valid_file', parameter_file)
                obj.outputHandler('valid', sprintf("%s File found.", parameter_file) );
                try
                    [~,f,~] = fileparts(parameter_file);
                    obj.bids_parameters = feval(f);
                    n_fields = numel(fieldnames(obj.bids_parameters));
                    obj.outputHandler('valid', sprintf("%d BIDS parameter fields loaded", n_fields) );
                catch
                    obj.outputHandler('error', "Check BIDS parameter file format");
                end
            else
                obj.outputHandler('error', "BIDS Parameter file not found");
            end

            % assign parameter file to object
            obj.bids_template = parameter_file;

        end
        function obj = loadSetFiles(obj, setpath)
            if nargin < 2
                obj.setpath = uigetdir;
                obj.outputHandler('msg', 'No directory provided, using selection interface.');
            else
                obj.setpath = setpath;
                obj.outputHandler('msg', sprintf('Loading SET files from %s', obj.setpath));
            end
            try
                obj.setlist = util_htpDirListing(obj.setpath, 'ext', '.set', 'subdirOn', 0);
                if obj.validationHandler('is_valid_table', obj.setlist)
                    obj.outputHandler('valid', sprintf('Loaded %d SET files from SET path.', height(obj.setlist)));
                else
                    obj.outputHandler('error', 'Invalid SET directory.')
                end
            catch
                obj.outputHandler('error', 'Invalid SET directory.')
            end

        end
        function obj = setExportPath( obj, exportpath )
            if nargin < 2
                obj.exportpath = uigetdir;
                obj.outputHandler('msg', 'No directory provided, using selection interface.');
            else
                obj.exportpath = exportpath;
                obj.outputHandler('msg', sprintf('Setting export path as %s', obj.exportpath));
            end
        end
        function obj = changeParameter( obj, field, value)
            multi_level_field = split(field, '.'); % fn is a cell array
            obj.bids_parameters = setfield(obj.bids_parameters, multi_level_field{:}, value);
            obj.outputHandler('msg', sprintf('Updated value for %s', field));

        end
        function obj = populateFileData(obj, filelist)
            obj.populateData = struct();
            for i=1:height(filelist)
                obj.populateData(i).file = fullfile(filelist.filepath(i),filelist.filename(i));
            end
        end
        function obj = bidsExport(obj)
            obj.specialParameterHandler()
            inputs = {'targetdir','taskName','gInfo','README','CHANGES','stimuli','pInfo',...
                'eInfo','eInfoDesc','cInfo','cInfoDesc','renametype','trialtype','tInfo','chanlocs'};
            bids_export(obj.populateData,  obj.findParams(inputs));
        end
        function obj = specialParameterHandler( obj )

            % reassign task name to main structure
            % also make name compliant by removing spaces or special
            % characters
            obj.bids_parameters.taskName = matlab.lang.makeValidName(obj.bids_parameters.ginfo.taskName);
            obj.bids_parameters.tinfo.TaskName = obj.bids_parameters.taskName;
        end
        function params=findParams(obj,inputs)
            presets = obj.bids_parameters;
            presets.targetdir = obj.exportpath;

            fields = fieldnames(presets);
            for i=1:length(fields)
                stepinput = inputs(ismember(lower(inputs),lower(fields{i})));
                if ~isempty(stepinput)
                    params.(stepinput{:}) = presets.(fields{i});
                end
            end
        end
        function obj = scanParticipants(obj)
            % create participant info
            sz = [numel(obj.populateData) 6];
            varTypes = ["char","char","char","double", "double","char"];
            varNames = ["participant_id", "group","condition", "trials", "xmax", "filename"];

            pinfo_table = table('Size',sz,'VariableTypes',varTypes,'VariableNames',varNames);

            % pinfo_table.Properties.VariableNames = {'subject','group','condition','filename'};

            for i = 1 : numel(obj.populateData)
                eeg_file = obj.populateData(i).file{1};
                EEG = pop_loadset('filename', eeg_file, 'loadmode', 'info');
                pinfo_table.participant_id{i} = EEG.subject;
                pinfo_table.group{i} = EEG.group;
                pinfo_table.condition{i} = EEG.condition;
                pinfo_table.trials(i) = EEG.trials;
                pinfo_table.xmax(i) = EEG.xmax;
                pinfo_table.filename{i} = EEG.filename;
            end

            pinfo_cell = table2cell(pinfo_table);
            obj.bids_parameters.pInfo = [pinfo_table.Properties.VariableNames; pinfo_cell];
            obj.pinfo_table = pinfo_table;
        end

    end

    methods % GUI outputs
        function tbl = getSetTable( obj )
            if height(obj.setlist) > 0
                tbl = [obj.setlist(:,2) obj.setlist(:,1)];
            else
                tbl = table();
            end
        end
        function str = getBidsTemplateFilename( obj )
            str = obj.bids_template;
        end
        function str = getStatusLog( obj )
            str = obj.statuslog;
        end
        function str = getSetPath( obj )
            if ~isempty(obj.setpath)
                str = obj.setpath;
            else
                str = 'Path to SET files not found.';
            end
        end
        function str = getExportPath( obj )
            if ~isempty(obj.exportpath)
                str = obj.exportpath;
            else
                str = 'Export path not found.';
            end
        end
        function str = getSetListStatus( obj )
            if height(obj.setlist) > 0
                str = sprintf('%d SET files found.',height(obj.setlist));
            else
                str = sprintf('No files available.');
            end
        end
        function params = getBidsParam( obj )
            params = obj.bids_parameters;
        end
        function buttonHandler( obj, action )
            switch action
                case 'all_buttons_off'
                    obj.button_export = false;
                    obj.button_template = false;
                    obj.button_setdir = false;
                    obj.button_exportdir = false;
                case 'export_button_on'
                    obj.button_exportdir = true;
                case 'export_button_off'
                    obj.button_exportdir = false;
                case 'file_buttons_on'
                    obj.button_export = false;
                    obj.button_template = true;
                    obj.button_setdir = true;
                    obj.button_exportdir = true;
                case 'recheck_button_toggle'
                    obj.button_recheck = ~obj.button_recheck;
            end

            if obj.button_template && obj.button_setdir && obj.button_exportdir
                obj.button_export = true;
            else
                obj.button_export = false;
            end



        end
    end

    methods
        function isCommandValid = checkCommand( obj, command )
            try
                obj.outputHandler('msg', sprintf('Trying %s to check dependencies...', command));
                evalc(command);
                isCommandValid = true;
                obj.outputHandler('valid', sprintf('%s found.', command));
            catch
                isCommandValid = false;
                obj.outputHandler('error', sprintf('Error %s. Check MATLAB path.', command));
            end
        end
        function isPluginAvailable = checkEeglabPlugin( obj, name_of_plugin )
            try
                obj.outputHandler('msg', sprintf('Checking for %s EEGLAB Plugin...', name_of_plugin));
                PLUGINLIST = evalin('base', 'PLUGINLIST'); % check current EEGLAB plugins
                isPluginAvailable = any(strcmpi(name_of_plugin, {PLUGINLIST.plugin}));
                obj.outputHandler('valid', sprintf('%s EEGLAB Plugin found.', name_of_plugin));

            catch
                isPluginAvailable = false;
                obj.outputHandler('error', sprintf('Add %s EEGLAB Plugin.', name_of_plugin));
            end
        end
    end

    methods % validation + display functions only

        function  res = validationHandler( obj, action, x )
            switch action
                case 'is_valid_file'
                    res = isfile(x);
                case 'is_valid_struct'
                    res = isstruct(x);
                case 'is_valid_table'
                    res = istable(x) && height(x) > 0;
                case 'is_valid_eeglab'
                    res = obj.checkCommand( 'eeglab nogui' );
                case 'is_valid_bids_toolbox'
                    res = obj.checkEeglabPlugin('bids-matlab-tools');
                otherwise
            end
            obj.last_validation = res;
        end

        function res = checkDependencies( obj )

            if  ~obj.validationHandler('is_valid_eeglab')
                obj.outputHandler('error', sprintf('Install dependencies before continuing.'));
            else,  obj.eeglab_present = true;
            end
            if ~obj.validationHandler('is_valid_bids_toolbox')
                obj.outputHandler('error', sprintf('Install dependencies before continuing.'));
            else,  obj.bidsplugin_present = true;
            end

            obj.all_dependencies_present = obj.validationHandler('is_valid_eeglab') && obj.validationHandler('is_valid_bids_toolbox');

            res =  obj.all_dependencies_present;
            if res
                obj.outputHandler('valid', sprintf('All dependencies present, activating file buttons.'));
                obj.button_recheck = false;
                obj.buttonHandler('file_buttons_on');
            else
                obj.outputHandler('error', sprintf('Recheck failed.'));

            end

        end

        function res = outputHandler( obj, action, x )
            prefix = 'bidstagger';
            switch action
                case 'init'
                    msg = sprintf("[%s] Initializing Bids Tagger (%s)", prefix, datetime("now"));
                case 'error'
                    msg = sprintf("[%s] %s",prefix, x);
                case 'valid'
                    msg = sprintf("[%s] Success: %s",prefix, x);
                case 'warning'
                    msg = sprintf("[%s] Warning: %s",prefix, x);
                case 'msg'
                    msg = sprintf("[%s] Status: %s",prefix, x);
                otherwise
                    msg = sprintf('[%s] Warning: Action not caught.', prefix);
            end
            disp(sprintf("%s",msg));
            res = msg;
            obj.statuslog = sprintf('%s\n%s',  obj.statuslog, res );
        end

        function createLabelDatabase( obj )

            keyValueSet = ... % fieldnames and display labels
                {'Name',                       'Dataset Name:'; ...
                'taskName',                    'Short Task Name:'; ...
                'ReferencesAndLinks',          'Dataset References:'; ...
                'InstitutionName',             'Institution Name:'; ...
                'InstitutionalDepartmentName', 'Institution Department:'; ...
                'InstitutionAddress',          'Institution Address:'; ...
                'PowerLineFrequency',          'Power Line Frequency:'; ...
                'ManufacturersModelName',      'Manufacturer Name:'; ...
                'EEGChannelCount',             'EEG Channel Count:'; ...
                };

            obj.db = containers.Map(keyValueSet(:,1), keyValueSet(:,2));
            obj.outputHandler('msg', sprintf("Optional field-label database created with %d entries.", length(keyValueSet)));

        end

        function res = getLabelDatabase( obj )
            res = obj.db;
        end
    end

end