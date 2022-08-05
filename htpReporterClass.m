classdef htpReporterClass < handle

    properties
        util;
        checks;
        session_info;
    end

    methods (Static)

        function display_header
            fprintf('\nWelcome to VHTP! - http://github.com/cincibrainlab/vhtp\n');
            fprintf('VHTP is an extensible, easy to learn framework for EEG analysis.\n');
            fprintf('================================================================\n');
            fprintf('The VHTP Reporter generates prose descriptions of vHtp actions.\n\n');
        end
        function display_instructions
            fprintf('Directions:\n\n');
            fprintf('\thtpReporter = htpReporterClass();\tcreate new htpReporter Object.\n');
            fprintf('\thtpReporter(''start'');\tstart new logging session.\n');
            fprintf('\thtpReporter(''stop'');\tstop logging session.\n');
            fprintf('\thtpReporter(''reset'');\treset logging session.\n');
            fprintf('\thtpReporter(''add'', ''function'', [vHTP function name], ''EEG'', [EEG SET(s)]);\tadd log for function and results.\n');

            fprintf('\n');
            fprintf('Parameters:\n');
            fprintf('\t''name''\tset custom session name (default: autonumber)\n');
            fprintf('\t''outputdir''\tset output directory (default: tempdir)\n');
            fprintf('\n');
        end

    end

    methods
        function o = htpReporterClass( action, varargin ) % Constructor
            % hard code version
            o.session_info.version = 0.5;
            o.load_helper_functions;
            %            o.setup_project_info;
            %            o.setup_project_status;
            %            o.check_dependencies;

            o.display_header;
            if nargin < 1, action = missing;
                o.display_instructions;
            end

            if ~ismissing(action)
                isValidAction =  ismember(action, ...
                    {...
                    'start', ...  # create new session
                    'stop', ...
                    'reset'...
                    'add', ... # log a function
                    });
            else
                action = 'default';
                isValidAction = true;
            end

            defaultName = ['htpReporter_' o.util.timestamp];
            defaultOutputDir = tempdir;

            % MATLAB built-in input validation
            ip = inputParser();
            addRequired(ip, action);
            addParameter(ip, 'name', defaultName, @ischar);
            addParameter(ip, 'outputdir', defaultOutputDir, @ischar);
            parse(ip, action, varargin{:});% specify some time-frequency parameters

            o.session_info.ip = ip.Results;

            if isValidAction
                switch action
                    case 'default'
                        checks = o.runChecks;
                        o.util.note('No instructions passed. Instructions only.')
                    case 'start'
                        checks = o.runChecks;
                        if checks
                            % create new session
                            o.session_handler('start');
                        else
                            return;
                        end
                    case 'stop'
                        results = o.runChecks;
                    case 'reset'
                        results = o.runChecks;
                    otherwise
                        o.util.note('No valid action requested.')
                end
            else
                o.util.note('Action keyphrase is invalid.');
            end

        end

        function load_helper_functions( o )
            % quick anonymous functions
            o.util = struct;
            o.util.note        = @(msg) fprintf('%s: %s\n', mfilename, msg );
            o.util.pickdir     = @() clipboard('copy', uigetdir([],'Choose a directory to copy to clipboard or hit cancel.'));
            o.util.projcode    = @create_project_details;
            o.util.add_path_without_subfolders = @( filepath ) addpath(fullfile( filepath ));
            o.util.add_path_with_subfolders    = @( filepath ) addpath(genpath(fullfile( filepath )));
            o.util.is_interactive = @check_interactive;
            o.util.failednote = @(msg) fprintf('%s: [N] FAILED: %s\n', mfilename, upper(msg) );
            o.util.successnote = @(msg) fprintf('%s:[Y] SUCCESS: %s\n', mfilename, upper(msg) );
            o.util.timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp

        end

        function all_checks_passed = runChecks( o )
            o.util.note('Checking requirements for htpReporter ...')

            % add path to vHTP
            % all checks are logical values
            try
                [vhtpdir, ~, ~] = fileparts(which(mfilename));
                o.util.note(sprintf('Adding vHTP to MATLAB Path (%s)...', vhtpdir))
                addpath(genpath(vhtpdir));
                o.checks.vhtp = true;
            catch
                o.checks.vhtp = false;
            end

            o.msgHandler(o.checks);
            fprintf('\n! htpReporter found %d issues.\n\n', sum(~struct2array(o.checks)));

            all_checks_passed = all(table2array(struct2table(o.checks)));

        end

        function session_handler( o, action )

            switch action
                case 'start'
                    o.util.note(sprintf('Creating session %s.', o.session_info.ip.name));
                    
                    % create new filename
                    o.session_info.session_file = fullfile( o.session_info.ip.outputdir, ...
                        [o.session_info.ip.name '.txt']);

                    % try to open file
                    try
                       fid = fopen( o.session_info.session_file, 'wt' );
                       o.util.note(sprintf('Session file %s open.', ...
                           o.session_info.session_file));
                       o.session_info.fileID = fid;
                        if  fid ~= -1
                            fprintf(fid,'VHTP Reporter\nDate: %s\nSession: %s\n', ...
                                datetime('now'), ...
                                o.session_info.session_file);
                            
                            % insert general vhtp citation
                            fprintf(fid, 'Citation:\n%s', o.snipitHandler('vhtp_citation'));
                            fclose(fid);
                            
                            % create hyperlink link to file
                            disp(['<a href="file://'  o.session_info.session_file '">Link to File</a>'])
                        else

                        end
                    catch
                        o.note('Error opening file.')
                    end
                otherwise
                    o.note(sprintf('Unhandled action: %s', action))
            end

        end

        function msgHandler( o, checks )
            check_fields = fieldnames(checks);
            for i = 1 : numel(check_fields)
                current_field = check_fields{i};
                check_now = checks.(current_field);
                if check_now
                    o.util.successnote(current_field);
                else
                    o.util.failednote(current_field);
                    cmd = fixCommands(current_field);
                    fixnote(cmd);
                end
            end
        end

        function str = snipitHandler( o, action )

            switch action
                case 'vhtp_citation'
                    str = sprintf('Cullion, K. and Pedapati, EV. Cincinnati Visual High Throughput Pipeline [Computer Software]. Version %1.2f. Accessed on %s. Retrieved from https://github.com/cincibrainlab/vhtp.', o.session_info.version, date);
            end


        end

    end
end