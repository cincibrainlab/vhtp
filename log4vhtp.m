classdef log4vhtp
    properties (Access = private)
        logLevelNumeric % Numeric representation of the current logging level
        logLevels % Map of log levels to numeric values
    end

    methods
        % Constructor
        function obj = log4vhtp(initialLogLevel)
            % Define log levels
            obj.logLevels = containers.Map(...
                {'trace', 'debug', 'info', 'warn', 'error', 'critical'}, ...
                {1, 2, 3, 4, 5, 6});
            % Validate initial log level
            if isKey(obj.logLevels, initialLogLevel)
                obj.logLevelNumeric = obj.logLevels(initialLogLevel);
            else
                error('Invalid initial log level: %s', initialLogLevel);
            end
            
            % Set initial log level
            if nargin < 1
                initialLogLevel = 'info';
            end
            obj.setLogLevel(initialLogLevel);
            obj.info(sprintf('Logging level: %s', initialLogLevel));
        end

        % Set log level
        function obj = setLogLevel(obj, level)
            if isKey(obj.logLevels, level)
                obj.logLevelNumeric = obj.logLevels(level);
            else
                error('Invalid log level: %s', level);
            end
        end

        % Generic log method
        function log(obj, level, message)
            % Get the name of the calling function
            [ST,~] = dbstack('-completenames');
            if length(ST) > 2
                callingFunction = ST(3).name;
            else
                callingFunction = '';
            end
            
            if obj.logLevels(level) >= obj.logLevelNumeric
                fprintf('[%s][%s]: %s\n', upper(level), callingFunction, message);
                if strcmp(level, 'critical')
                    error('[%s][%s]: %s\n', upper(level), callingFunction, message);
                end
            end
        end
    
        % Convenience methods for each log level
        function trace(obj, message), obj.log('trace', message); end
        function debug(obj, message), obj.log('debug', message); end
        function info(obj, message), obj.log('info', message); end
        function warn(obj, message), obj.log('warn', message); end
        function error(obj, message), obj.log('error', message); end
        function critical(obj, message), obj.log('critical', message); end
    end
end
