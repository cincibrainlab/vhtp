function results = htpDoctor( action )
timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
[note, fixnote, failednote, successnote] = htp_utilities();

if nargin < 1, action = missing;
    fprintf('\nWelcome to VHTP! - http://github.com/cincibrainlab/vhtp\n', timestamp);
    fprintf('VHTP is an extensible, easy to learn framework for EEG analysis.\n');
    fprintf('================================================================\n');
    fprintf('The VHTP Doctor verifies the installation and any necessary toolkits.\n\n');
    note('Running tests ...');
end


if ~ismissing(action)
    isValidAction =  ismember(action, {'fix_eeglab', 'check_eeglab', 'check_brainstorm',... 
        'check_biosig', 'fix_biosig', 'fix_viewprops', 'fix_cleanrawdata', 'fix_brainstorm', ...
        'fix_firfilt', 'check_spectralevents', 'fix_spectralevents'});
else
    action = 'default';
    isValidAction = true;
end

% MATLAB built-in input validation
if isValidAction
    switch action
        case 'default'
            checks = runChecks;
            results = checks;
        case 'autofix'
            checks = runChecks;
            autoFix(checks);
            results = checks;
        case 'check_eeglab'
            results = checkRequirements( 'eeglab' );
        case 'check_brainstorm'
            results = checkRequirements( 'brainstorm' );

        case 'fix_eeglab'
            results = fixHandler('eeglab');
        case 'check_biosig'
            results = checkRequirements( 'biosig' );
        case 'fix_biosig'
            results = fixHandler('biosig');
        case 'fix_viewprops'
            results = fixHandler('viewprops');
        case 'fix_cleanrawdata'
            results = fixHandler('clean_rawdata');
        case 'fix_firfilt'
            results = fixHandler('firfilt');
        case 'fix_brainstorm'
            results = fixHandler('brainstorm');

        case 'check_spectralevents'
            results = checkRequirements( 'spectralevents' );
        case 'fix_spectralevents'
            results = fixHandler('spectralevents');

        otherwise
           note('No valid action requested.')

    end
else
    note('Action keyphrase is invalid.');
end

% check vhtp version

% check other dependencies

% checkRequirement, send to messageHandler, send to guiHandler
    function checks = runChecks()
        note('Checking major tookits ...')

        % add path to vHTP
        [vhtpdir, ~, ~] = fileparts(which(mfilename));
        note(sprintf('Adding vHTP to MATLAB Path (%s)...', vhtpdir))
        addpath(genpath(vhtpdir));

        % check eeglab
        checks.eeglab = htpDoctor('check_eeglab');
        % check for brainstorm
        checks.brainstorm = htpDoctor('check_brainstorm');
        % check spectral events toolkit
        checks.spectralevents = htpDoctor('check_spectralevents');

        % eeglab dependencies
        note('Checking eeglab plugins ...')
        if checks.eeglab
            checks.biosig = checkRequirements( 'biosig' );
            checks.clean_rawdata = checkRequirements( 'clean_rawdata' );
            checks.iclabel = checkRequirements( 'iclabel' );
            checks.viewprops = checkRequirements( 'viewprops' );
            checks.firfilt = checkRequirements( 'firfilt' );
        end
        msgHandler(checks);
        fprintf('\n! htpDoctor found %d issues.\n\n', sum(~struct2array(checks)));
    end

% === CHECK DEPENDENCIES FUNCTIONS
    function results = checkRequirements( action )
        switch action
            case 'eeglab'
                results = checkCommand( 'eeglab nogui' );
            case 'brainstorm'
                results = checkScriptName( 'brainstorm' );
            case 'spectralevents'
                results = checkScriptName( 'spectralevents' );
            otherwise
                results = checkEeglabPlugin(action);
        end
    end
    function isScriptValid = checkScriptName( command )
            note(sprintf('Locating script %s ...', command));
            if exist(command,'file') == 2
                isScriptValid = true;
            else
                isScriptValid = false;
            end
    end
    function isCommandValid = checkCommand( command )
        try
            note(sprintf('Trying %s ...', command));
            evalc(command);
            isCommandValid = true;
        catch
            isCommandValid = false;
        end
    end
    function isPluginAvailable = checkEeglabPlugin( name_of_plugin )
        try 
            PLUGINLIST = evalin('base', 'PLUGINLIST'); % check current EEGLAB plugins
            isPluginAvailable = any(strcmpi(name_of_plugin, {PLUGINLIST.plugin}));
        catch 
            isPluginAvailable = false;
        end
    end
    function results = fixHandler( action )
        switch action
            case 'eeglab'
                results = addMatlabPath( action );
            case 'brainstorm'
                results = addMatlabPath( action );
            case 'spectralevents'
                results = addMatlabPath( action );
            otherwise
                results = downloadEegLabPlugin( action );
        end

    end

    function results = addMatlabPath( action )

        ToolIsAvailable = checkRequirements( action );
        try_matlab_path = missing;
        while ToolIsAvailable == false
            try
                if ~ismissing(try_matlab_path), addpath(try_matlab_path); end
                assert(checkRequirements( action ) );
                ToolIsAvailable = true;
                successnote( action );
                results = ToolIsAvailable;
            catch
                if ~ismissing(try_matlab_path), rmpath(try_matlab_path); end
                try_matlab_path = uigetdir([], ...
                    sprintf('Choose %s directory or hit Cancel.', action));
                if try_matlab_path == false
                    failednote([action ': No directory selected.']);
                    switch action
                        case 'eeglab'
                            note('Install from https://eeglab.org/download/')
                        case 'brainstorm'
                            note('Install from https://neuroimage.usc.edu/brainstorm/Installation');
                        case 'spectralevents'
                            note('Install from https://github.com/jonescompneurolab/SpectralEvents')
                    end
                    results = ToolIsAvailable;
                    break;
                end
            end

        end


    end

    function res = downloadGitHubRepository( action )
        switch action
            case 'spectralevents'
                zip = 'https://github.com/jonescompneurolab/SpectralEvents/archive/refs/heads/master.zip';
                name = 'SpectralEvents';
            otherwise
                note('Github repository not configured. Please see htpDoctor code.');
        end


    end

    function res = downloadEegLabPlugin( action )
        switch action
            case 'clean_rawdata'
                zip = 'http://sccn.ucsd.edu/eeglab/plugins/clean_rawdata2.7.zip';
                name = 'clean_rawdata';
                version = '2.7';
                pluginsize = 1.5;
            case 'biosig'
                zip = 'http://sccn.ucsd.edu/eeglab/plugins/BIOSIG3.8.1.zip';
                name = 'Biosig';
                version = '3.8.1';
                pluginsize = 4.3000;
            case 'iclabel'
                name = 'ICLabel';
            case 'viewprops'
                name = 'viewprops';
            case 'firfilt'
                zip =  'http://sccn.ucsd.edu/eeglab/plugins/firfilt2.4.zip';
                name = 'firfilt';
                version = '2.4';
                pluginsize = 42.7;
        end
        ToolIsAvailable = checkRequirements(action);
        while ToolIsAvailable == false
            try
                assert(ToolIsAvailable);
                ToolIsAvailable = true;
            catch
                try
                    note(sprintf('Attemping EEGLAB Plugin Download of %s by name.', action ));
                    plugin_askinstall(name, 'sopen', true);
                    % assert(res);
                    % eeglab nogui;
                    checkRequirements('eeglab');
                    ToolIsAvailable = checkRequirements(action);
                    assert( ToolIsAvailable );
                    successnote(action);
                    res = ToolIsAvailable;
                catch
                    try
                        note(sprintf('Failed by name %s, trying more details.', action ));
                        plugin_install(zip, name, version, pluginsize, 1);
                    catch
                        failednote(action);
                        warning(sprintf(['%s Toolbox autoinstall failure. ...' ...
                            ' Please add through EEGLAB and restart.'], upper(action)));
                        res = false;

                        break;
                    end

                end
            end
        end


    end

    % === Message Handlers
    %     Display success/fail output to the user
    function msgHandler( checks )
        check_fields = fieldnames(checks);
        for i = 1 : numel(check_fields)
            current_field = check_fields{i};
            check_now = checks.(current_field);
            if check_now
                successnote(current_field);
            else
                failednote(current_field);
                cmd = fixCommands(current_field);
                fixnote(cmd);
            end
        end
    end

    % === Fix Handlers
    %     Display 'fix' command to user
    function str = fixCommands( action )
        try
            switch action
                otherwise
                    str = sprintf( 'htpDoctor(''fix_%s'')', action);
            end
        catch
            note('FixCommands: Action not found.')
        end
    end


% === UTILITIES ADDIN: 2/2 ================================================
    function [note, fixnote, failednote, successnote] = htp_utilities()
        note        = @(msg) fprintf('%s: %s\n', mfilename, msg );
        fixnote        = @(msg) fprintf('%s: \tFix command: %s\n', mfilename, msg );
        failednote = @(msg) fprintf('%s: [N] FAILED: %s\n', mfilename, upper(msg) );
        successnote = @(msg) fprintf('%s:[Y] SUCCESS: %s\n', mfilename, upper(msg) );
    end

% === UTILITIES ADDIN: 2/2 ================================================

end