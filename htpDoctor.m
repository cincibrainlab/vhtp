function checks = htpDoctor( action )

if nargin < 1, action = missing; end

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp

[note, fixnote, failednote, successnote] = htp_utilities();
fprintf('\nWelcome to VHTP! - http://github.com/cincibrainlab/vhtp\n', timestamp);
fprintf('VHTP is an extensible, easy to learn framework for EEG analysis.\n');
fprintf('================================================================\n');
fprintf('The VHTP Doctor verifies the installation and any necessary toolkits.\n\n');
note('Running tests ...');

if ~ismissing(action)
    isValidAction =  ismember(action, {'fix_eeglab'});
else
    action = 'default';
    isValidAction = true;
end

% MATLAB built-in input validation
if isValidAction
    checks.eeglab = checkRequirements( 'eeglab' );
    msgHandler(checks);
    switch action
        case 'default'
            % check eeglab
        case 'fix_eeglab'
            fixHandler('fix_eeglab')
        otherwise
    end
    fprintf('\n! htpDoctor found %d issues.\n\n', sum(~struct2array(checks)));
else
    note('Action keyphrase is invalid.');
end

% check vhtp version

% check other dependencies

% checkRequirement, send to messageHandler, send to guiHandler

% === CHECK DEPENDENCIES FUNCTIONS
    function results = checkRequirements( action )
        switch action
            case 'eeglab'
                try
                    eeglab nogui;
                    results = true;
                catch
                    results = false;
                end
            otherwise
        end
    end

% === Handlers
    function msgHandler( checks )

        check_fields = fieldnames(checks);

        for i = 1 : numel(check_fields)
            current_field = check_fields{i};
            check_now = checks.(current_field);

            switch current_field
                case 'eeglab'
                    if check_now
                        successnote(current_field);
                    else
                        failednote(current_field);
                        fixnote(fixCommands('eeglab'));
                    end
            end
        end
    end

    function fixHandler( action )
        switch action
            case 'fix_eeglab'
                EegLabIsAvailable = false;
                try_eeglab_path = missing;
                while EegLabIsAvailable == false
                    try
                        if ~ismissing(try_eeglab_path), addpath(try_eeglab_path); end
                        assert(checkRequirements('eeglab') );
                        EegLabIsAvailable = true;
                    catch
                        if ~ismissing(try_eeglab_path), rmpath(try_eeglab_path); end
                        try_eeglab_path = uigetdir([],'Choose EEGLAB directory or hit cancel.');
                    end
                end

        end

    end

    function str = fixCommands( action )

        fixCommands.eeglab = sprintf('htpDoctor(''fix_eeglab'')');

        try
            str = fixCommands.(action);
        catch
            note('FixCommands: Action not found.')
        end
    end


% === UTILITIES ADDIN: 2/2 ================================================
    function [note, fixnote, failednote, successnote] = htp_utilities()
        note        = @(msg) fprintf('%s: %s\n', mfilename, msg );
        fixnote        = @(msg) fprintf('%s: To fix try the command: %s\n', mfilename, msg );
        failednote = @(msg) fprintf('%s: [X] FAILED: %s\n', mfilename, upper(msg) );
        successnote = @(msg) fprintf('%s:[*] SUCCESS: %s\n', mfilename, upper(msg) );
    end

% === UTILITIES ADDIN: 2/2 ================================================

end