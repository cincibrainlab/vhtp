classdef htpAnalysisClass < handle
    %htpAnalysisClass - model/controller code for the htpAnalysisGui

    properties
        util;           % helper function
        checks;         % check dependencies
        input_filelist; % master filelist for setfiles
        proj_status;    % status only
        datasets;
    end
    methods (Static)
        %% HELPER FUNCTIONS =======================================================
        %  Support code only
        function space_in_gb = getUsableDiskSpace(filepath )
            FileObj      = java.io.File( filepath );
            space_in_gb = FileObj.getUsableSpace / 1e9;
        end

        function create_project_details()
            proj_details = inputdlg({'Project Name:','Author Name:','Description'}, ...
                'Paste from Clipboard after Entry', [1 40; 1 40; 4 40]);
            detail_code = '\tproject_name\t=''%s'';\n\tauthor_name\t\t=''%s'';\n\tdescription\t\t=''%s'';\n';
            clipboard('copy', sprintf(detail_code, ...
                proj_details{1}, proj_details{2},proj_details{3}));
        end

        function true_or_false = check_interactive()
            true_or_false = false;
            if isempty(mfilename) || contains(mfilename,'LiveEditorEvaluation') % only runs if in interactive mode
                true_or_false = true;
            end
        end

        function waitbar_fig = progress_bar( action, f, current, total )
            switch action
                case 'create'
                    waitbar_fig = waitbar(0,'Dataset Progress');
                case 'update'
                    waitbar( current/total, f, sprintf('Progress: %1.0f of %1.0f', current, total ));
            end
        end

        function command_str = createFxString( param_struct )

            fx_names = fieldnames(param_struct); % function names
            fx_no    = numel(fx_names);

            count = 1;

            for i = 1 : fx_no
                fx_parameters = param_struct.( fx_names{i} );
                keys = fieldnames( fx_parameters );
                vals = struct2cell( fx_parameters );

                for j = 1 : numel(keys)

                    selected_key   = categorical(keys(j));

                    if selected_key == 'function'

                        fx_name = func2str( vals{j} );
                        cmd{count} = sprintf('\t%s Function: %s\n\tEEG = %s(EEG, ', '%%', fx_name, fx_name);
                        count = count + 1;
                    else
                        selected_key = keys{j};
                        selected_value = vals{j};
                        value_type = class(selected_value);
                        %
                        %
                        %
                        %             fx_string = sprintf('%s %s %s', fx_string, selected_key, selected_value);
                        cmd{count} = sprintf( '''%s'', ', selected_key );
                        count = count + 1;
                        if j == numel(keys)
                            endchar = ');\n\n';
                        else
                            endchar =', ';
                        end

                        switch value_type
                            case 'double'
                                cmd{count} = sprintf( '%d%s', selected_value, endchar );
                            case 'logical'
                                cmd{count} = sprintf( '%d%s', selected_value, endchar );
                            case 'character'
                                cmd{count} = sprintf( '%s%s', selected_value, endchar );
                            case 'string'
                                cmd{count} = sprintf( '%s%s', selected_value, endchar );
                        end
                        count = count + 1;
                        % addstring = sprintf('%s%s',addstring,)
                    end
                end
                % fprintf('\n');
            end

            command_str = sprintf([cmd{:}]);


        end

    end
    methods
        function o = htpAnalysisClass() % Constructor
            o.load_helper_functions;
            o.setup_project_info;
            o.setup_project_status;
            o.check_dependencies;

            o.util.note('Starting support Class for htpAnalysisGui')
            o.util.note('Loading helper functions...');
        end
    end
    methods % common functions
        function o = assignProcessingSteps( o, selectedSteps )
            o.proj_status.selectedSteps = selectedSteps;
        end
        function o = assignProcessingType( o, processtype)
            o.proj_status.processingType = processtype;
            o.util.note(sprintf('Process Type set to %s.', processtype));
        end
        function o = run_analysis_loop( o )

            % get step number
            findStepPosition = @( step ) find(strcmp( o.proj_status.current_parameter_steps, step ));

            switch o.proj_status.processingType
                case 'All'
                    stepnumbers = 1 : numel( o.proj_status.current_parameter_steps );
                case 'IndividualStep'
                    stepnumbers = sort(cell2mat(cellfun(@(x) findStepPosition(x), o.proj_status.selectedSteps, 'uni', 0)));
                case 'Continuation'
                    step_list_by_position = sort(cell2mat(cellfun(@(x) findStepPosition(x), {o.proj_status.selectedSteps}, 'uni', 0)));
                    stepnumbers = step_list_by_position(1) : numel( o.proj_status.current_parameter_steps );
            end

            progress_bar = @o.progress_bar;

            useSubDir = ~o.proj_status.ignore_subdirectories;

            util_htpParadigmRun(...
                o.proj_status.data_dir, ...
                o.proj_status.current_parameter_PARAMS, ...
                o.proj_status.processingType, ...
                'dryrun', false, ...
                'subdirOn', useSubDir, ...
                'outputdir', o.proj_status.results_dir, ...
                'stepnumbers', stepnumbers, ...
                'analysisMode', true);

        end
        function load_helper_functions( o )
            % quick anonymous functions
            o.util = struct;
            o.util.note        = @(msg) fprintf('%s: %s\n', 'htpAnalysis', msg );
            o.util.pickdir     = @() clipboard('copy', uigetdir([],'Choose a directory to copy to clipboard or hit cancel.'));
            o.util.projcode    = @create_project_details;
            o.util.add_path_without_subfolders = @( filepath ) addpath(fullfile( filepath ));
            o.util.add_path_with_subfolders    = @( filepath ) addpath(genpath(fullfile( filepath )));
            o.util.is_interactive = @check_interactive;
            o.util.failednote = @(msg) fprintf('%s: [N] FAILED: %s\n', mfilename, upper(msg) );
            o.util.successnote = @(msg) fprintf('%s:[Y] SUCCESS: %s\n', mfilename, upper(msg) );
        end
        function isValid = check_dependencies( o )
            % htpDoctor based dependency checker
            % returns 0 if any dependency is broken
            [o.checks, o.proj_status.toolbox_paths] = htpDoctor;
            isValid = all(struct2array(o.checks));
            if isValid
                o.mark_dependencies_present;
            else
                o.mark_dependencies_missing;
            end

        end
        function setup_project_info( o )
            o.proj_status = struct();
            o.proj_status.project_name = [];
            o.proj_status.author_name = [];
            o.proj_status.description = [];

            % toolbox paths
            o.proj_status.eeglab_dir = [];
            o.proj_status.brainstorm_dir = [];

            [vhtpdir, ~, ~] = fileparts(which(mfilename));
            o.util.note(sprintf('vHtp Directory at %s...', vhtpdir))
            o.proj_status.vhtp_dir = vhtpdir;

            % datapaths
            o.proj_status.data_dir = [];
            o.proj_status.temp_dir = [];
            o.proj_status.results_dir = [];
        end
        function o = setup_project_status( o )
            o.proj_status.all_dependencies_present = false;
            o.proj_status.ignore_subdirectories = false;
            o.proj_status.last_directory = pwd;
        end
        function o = mark_dependencies_missing( o )
            o.proj_status.all_dependencies_present = false;
        end
        function o = mark_dependencies_present( o )
            o.proj_status.all_dependencies_present = true;
        end
        function res = get_dependencies_status( o )
            res = o.proj_status.all_dependencies_present;
        end
        function res = getLastDirectory( o )
            isempty(app.ha.proj_status.data_dir)
            if o.proj_status.last_directory == 0
                o.proj_status.last_directory = pwd;
                res = pwd;
            else
                res = o.proj_status.last_directory;
            end
        end
        function dir_name = pick_return_directory( o )
            desc = sprintf("Choose a directory:");
            dir_name = uigetdir(o.getLastDirectory(), desc);
            o.proj_status.last_directory = dir_name;
        end
        function o = set_directory_name( o, dir_code, dir_target )
            o.util.note('Setting %s directory to %s', dir_code, dir_target);
            o.proj_status.(dir_code) = dir_target;
        end
        function o = scan_set_directory( o, useSubDirectories )
            if nargin < 2
                useSubDirectories = true;
            end
            if ~isempty(o.proj_status.set_dir)
                o.input_filelist = util_htpDirListing(set_dir, 'ext', '.set', 'subdirOn', useSubDirectories );
                if isempty(o.input_filelist), error('No files found'), else
                    note(sprintf('Scanning %s\n\t%d Files loaded.\n\tTemp Dir: %s\n\tResults Dir: %s', ...
                        set_dir, height(o.input_filelist),temp_dir,results_dir));
                    o.input_filelist = o.input_filelist;
                end
            end
        end
        function set_ignore_subdirectory_state( o, state )
            o.proj_status.ignore_subdirectories = state;
            o.util.note(sprintf('ignore subfolder state %s', mat2str(state)));
        end
        function state = get_ignore_subdirectory_state( o )
            state = o.proj_status.ignore_subdirectories;
        end
        function  [fileCount, subFolderCount]  = createFileList(o, filepath)

            results = util_htpDirListing( filepath, 'ext', '.set', 'subdirOn', ~o.proj_status.ignore_subdirectories );

            %hideInputFolder = @(x) strrep(x, app.inputPath.Value, '');
            if isempty(results) == false
                fileCount = height(results);
                subFolderCount = height(unique(results.filepath));
                % app.UITable.Data = [results.filename  cellfun(hideInputFolder, results.filepath, 'UniformOutput', false)];
                % app.UITable.ColumnName = {'Filename','Subfolder'};
            else
                fileCount = 0;
                subFolderCount = 0;
                % app.UITable.Data = [];
                % app.UITable.ColumnName = {'Filename','Subfolder'};
            end
            o.input_filelist = results;
        end
        function res = getCurrentFileByRowNumber( o, row )
            res = o.input_filelist( row, : );
            o.proj_status.active_file = res;
        end
        function res = loadActiveEegSelection( o )
            filerow = o.proj_status.active_file;
            o.datasets.active_EEG = pop_loadset('filename', filerow.filename{1}, 'filepath', filerow.filepath{1});
        end
        function res = openEegPlot( o )
            pop_eegplot( o.datasets.active_EEG, 1, 0, 1);
        end
        function res = openInEeglab( o )
            EEG = o.datasets.active_EEG;
            assignin('base', 'EEG', EEG);
            eeglab redraw;
        end
        function res = openChanLocs( o )
            pop_chanedit(o.datasets.active_EEG);
        end
        function openExplorer( o )
            winopen(o.datasets.active_EEG.filepath);
        end
        function openPathInExplorer( o, target_path )
            winopen( target_path );
        end
        function openResultsFolder( o )
            winopen(o.proj_status.results_dir);
        end
        function singleEegHandler( o, action )
            switch action
                case 'openEegPlot'
                    o.openEegPlot;
                case 'openInEeglab'
                    o.openInEeglab;
                case 'openChanLocs'
                    o.openChanLocs;
                case 'openExplorer'
                    o.openExplorer;
            end

        end
        function list = listAnalysisParameterFiles(o)
            filelist = util_htpDirListing(fullfile( o.proj_status.vhtp_dir, 'parameters/'), 'ext', '.m', 'keyword', 'parameters');
            list = string(regexp(filelist{:,2},'(?<=parameters_)\w*','match'));
        end
        function extractCurrentParameterFile( o, selection )
            o.proj_status.current_parameter_code = selection;
            o.proj_status.current_parameter_file = strcat("parameters_",selection);
            o.proj_status.current_parameter_func =  str2func(strcat("parameters_",selection));
            o.parameterHandler('loadParameterFile');
        end
        function res = createManualTemplate( o )

            % run checks
            check_vector =struct();
            if ~o.proj_status.all_dependencies_present % 0 NO 1 YES
                check_vector.all_dependencies = 0;
                o.util.failednote('Please check dependencies (run htpDoctor).');
            else
                check_vector.all_dependencies = 1;
            end

            if isempty(o.input_filelist) % 0 no files, 1 files present
                check_vector.input_filelist = 0;
                o.util.failednote('No files loaded.');
            else
                check_vector.failednote = 1;
            end

            if ~all(cell2mat(struct2cell(check_vector))) % 0 not met
              o.util.failednote('Check errors before continuing.');
            else

                t = fileread(fullfile(o.proj_status.vhtp_dir, ...
                    'templates', filesep, 'eeg_htpAnalysisTemplate_dynamic.m'));
                template = regexp(t, '\r\n|\r|\n', 'split');

                commands = o.createFxString( o.proj_status.current_parameter_PARAMS );

                % create single struct
                v = o.proj_status;
                for fn = fieldnames(o.proj_status.toolbox_paths)'
                    v.(fn{1}) = o.proj_status.toolbox_paths.(fn{1});
                end
                % fill in black values
                if isempty(v.project_name), v.project_name = 'TBD'; end
                if isempty(v.author_name), v.author_name = 'TBD'; end
                if isempty(v.description), v.description = 'TBD'; end

                if o.proj_status.useMaxEpochs
                    startchar = '%- Use Max Trials -';
                    linechar = '%';
                    endchar = '%}';
                else
                    startchar = '';
                    linechar = '';
                    endchar = '';
                end
                select_trials = sprintf('%s\t\n%s\tif EEG.trials >= %d\n%s\t\tEEG = pop_select(EEG, ''trial'', 1:%d);\n%s\tend\n\t\n', ...
                    startchar,...
                    linechar, ...
                    o.proj_status.minTrials, ...
                    linechar, ...
                    o.proj_status.minTrials, ...
                    linechar);

                repstr = {...
                    '$filename'
                    '$creation_date'
                    '$project_name'
                    '$author_name'
                    '$description'
                    '$eeglab_dir'
                    '$brainstorm_dir'
                    '$vhtp_dir'
                    '$se_dir'
                    '$braph_dir'
                    '$bct_dir'
                    '$set_dir'
                    '$temp_dir'
                    '$results_dir'
                    '$select_trials'
                    '$loopcode'};

                repwithstr = {...
                    upper( v.project_name )
                    datestr(now, 29)
                    v.project_name
                    v.author_name
                    v.description
                    v.eeglab_dir
                    v.brainstorm_dir
                    v.vhtp_dir
                    v.spectralevents_dir
                    v.braph_dir
                    v.bct_dir
                    v.data_dir
                    v.temp_dir
                    v.results_dir
                    select_trials
                    commands
                    };

                for k = 1:numel(repwithstr)
                    template = strrep(template, repstr{k}, repwithstr{k});
                end
                out = sprintf('%s\n', template{:});

                % Write data to text file
                savefile = fullfile(v.results_dir,  strcat("htpAnalysis_", v.current_parameter_code,"_" ,datestr(now, 30), ".m"));
                try
                    writematrix(out, savefile, 'FileType', 'text', 'QuoteStrings','none');
                catch
                    writematrix(out, savefile, 'FileType', 'text', 'QuoteStrings',0);
                end
                fprintf('Analysis template saved to %s', savefile);
                open(savefile);
            end
        end
        function res = parameterHandler( o, action )
            switch action
                case 'loadParameterFile'
                    o.proj_status.current_parameter_PARAMS = ...
                        o.proj_status.current_parameter_func();
                    o.proj_status.current_parameter_steps = fieldnames(o.proj_status.current_parameter_PARAMS);

                case 'listParametersForTable'
                    res = o.proj_status.current_parameter_steps;
                case 'openParameterFileForEditing'
                    try
                        open(o.proj_status.current_parameter_file);
                        o.util.note(sprintf('Opened %s for editing.', ...
                            o.ha.proj_status.current_parameter_file));
                    catch
                        o.util.note('Warning: No parameters file selected.')
                    end
            end

        end
        function prepareEegForSave( o, EEG, step_name, outputdir )
            EEG.filename = [regexprep(EEG.subject,'.set','') '_' step_name '.set'];
            EEG.filepath = outputdir;

            o.datasets.last_EEG;
 
        end
        function saveEeg( o )

            EEG = o.datasets.last_EEG;
            pop_saveset(EEG,'filename', EEG.filename, 'filepath', EEG.filepath );

        end
    end
end