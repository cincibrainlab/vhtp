classdef htpAnalysisClass < handle
    %htpAnalysisClass - model/controller code for the htpAnalysisGui

    properties
        util;           % helper function
        checks;         % check dependencies
        proj_info;
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
                o.proj_info.data_dir, ...
                o.proj_status.current_parameter_PARAMS, ...
                o.proj_status.processingType, ...
                'dryrun', false, ...
                'subdirOn', useSubDir, ...
                'outputdir', o.proj_info.results_dir, ...
                'stepnumbers', stepnumbers, ...
                'analysisMode', true);
            
            
%             %% RUN ANALYSIS LOOPS -----------------------------------------------------|
%             number_of_input_files = height( filelist );
% 
%             % Main analysis loop
%             waitf = progress_bar('create');
%             for i = 1 : number_of_input_files
% 
%                 % active SET file
%                 current_set = filelist.filename{i};
%                 current_subfolder = filelist.filepath{i};
% 
%                 % load EEG (EEGLAB)
%                 EEG = pop_loadset('filename', current_set, ...
%                     'filepath', current_subfolder);
% 
%                 % = begin function chain, i.e. EEG in and EEG out ====================
%                 [EEG, results{i}] = eeg_htpCalcRestPower( EEG,...
%                     'useParquet', true, ...
%                     'gpuOn', true, 'outputdir', results_dir );
% 
%                 % update progress bar
%                 progress_bar('update',waitf, i, number_of_input_files)
% 
%             end
%             close(waitf); % waitbar
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
            o.checks = htpDoctor;
            isValid = all(struct2array(o.checks));
            if isValid
                o.mark_dependencies_present;
            else
                o.mark_dependencies_missing;
            end
            
        end
        function setup_project_info( o )
            o.proj_info.project_name = [];
            o.proj_info.author_name = [];
            o.proj_info.description = [];
    
            % toolbox paths
            o.proj_info.eeglab_dir = [];
            o.proj_info.brainstorm_dir = [];

            [vhtpdir, ~, ~] = fileparts(which(mfilename));
            o.util.note(sprintf('vHtp Directory at %s...', vhtpdir))
            o.proj_info.vhtp_dir = vhtpdir;

            % datapaths
            o.proj_info.data_dir = [];
            o.proj_info.temp_dir = [];
            o.proj_info.results_dir = [];
        end
        function o = setup_project_status( o )
            o.proj_status = struct();
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
            o.proj_info.(dir_code) = dir_target;
        end
        function o = scan_set_directory( o, useSubDirectories )
            if nargin < 2
                useSubDirectories = true;
            end
            if ~isempty(o.proj_info.set_dir)
                o.input_filelist = util_htpDirListing(set_dir, 'ext', '.set', 'subdirOn', useSubDirectories );
                if isempty(o.input_filelist), error('No files found'), else
                    note(sprintf('Scanning %s\n\t%d Files loaded.\n\tTemp Dir: %s\n\tResults Dir: %s', ...
                        set_dir, height(o.input_filelist),temp_dir,results_dir));
                    o.input_filelist = o.input_filelist;
                end
            end
        end
        % handling subfolders for file list
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
        function openResultsFolder( o )
            winopen(o.proj_info.results_dir);
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
            filelist = util_htpDirListing(fullfile( o.proj_info.vhtp_dir, 'analysis_templates/'), 'ext', '.m', 'keyword', 'parameters');
            list = string(regexp(filelist{:,2},'(?<=parameters_)\w*','match'));
        end
        function extractCurrentParameterFile( o, selection )
               o.proj_status.current_parameter_code = selection;
               o.proj_status.current_parameter_file = strcat("parameters_",selection);
               o.proj_status.current_parameter_func =  str2func(strcat("parameters_",selection));              

               o.parameterHandler('loadParameterFile');
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

%             % get current parameter code
%             code = o.proj_status.current_parameter_code;
% 
%                     if ~isempty( code )
%                         % load parameters function and get preprocessing steps
%                         try
%                             app.PARAMS=current_parameter_func();
%                             app.actionHandler('loadCurrentParametersSteps');
%                             app.actionHandler('listIndividualSteps');
%                             app.actionHandler('updateStepDetails');
%                             app.allowIndividualSteps;
%                         catch
%                             error('Error loading %s (parameters) file.', app.currentParametersFile);
%                         end
%                         allowProcessStyle(app);
%                         app.PROCESS='All';
%                         denyContinuationSteps(app);
%                         %denyIndividualSteps(app);
%                     else
%                         denyAll(app);
%                     end

        end
    end
end