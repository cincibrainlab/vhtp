classdef log4vhtp < handle
    properties (Access = private)
        logLevelNumeric % Numeric representation of the current logging level
        logLevels % Map of log levels to numeric values
        logFile % File to write logs to
        lastLogLine % Last log line written
        lastHtmlLogLine
    end

    events
        LogLineWritten
    end

    methods
        % Constructor
        function obj = log4vhtp(initialLogLevel, logFileName)
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

            % Open log file
            obj.logFile = fopen(logFileName, 'a');
            if obj.logFile == -1
                error('Could not open log file: %s', logFileName);
            end
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
        function log(obj, level, varargin)
            % Get the name of the calling function
            [ST,~] = dbstack('-completenames');
            if length(ST) > 2
                callingFunction = ST(3).name;
            else
                callingFunction = '';
            end

            if obj.logLevels(level) >= obj.logLevelNumeric
                message = sprintf(varargin{:});
                message = strrep(message, '\n', ''); % Remove newline characters

                timestamp = datetime('now', 'Format', 'yy/MM/dd HH:mm:ss');                
                obj.lastLogLine = sprintf('[%s][%s][%s]: %s\n', timestamp, upper(level), callingFunction, message);
                fprintf(obj.logFile, obj.lastLogLine);
                fprintf(obj.lastLogLine);
                % Create last HTML line with color coding for different levels
                switch level
                    case 'trace'
                        color = '#808080'; % gray
                    case 'debug'
                        color = '#0000FF'; % blue
                    case 'info'
                        color = '#008000'; % green
                    case 'warn'
                        color = '#FFA500'; % orange
                    case 'error'
                        color = '#FF0000'; % red
                    case 'critical'
                        color = '#8B0000'; % dark red
                    otherwise
                        color = '#000000'; % default to black
                end
                obj.lastHtmlLogLine = sprintf('<p style="color: %s;">[%s][%s][%s]: %s</p>', color, timestamp, upper(level), callingFunction, message);
                notify(obj, 'LogLineWritten');
             end
            if strcmp(level, 'critical')
                error('[%s][%s]: %s\n', upper(level), callingFunction, message);
            end
        end

        function lastLogLine = getLastLogLine(obj)
            lastLogLine = obj.lastLogLine;
        end

        function lastHtmlLogLine = getLastHtmlLogLine(obj)
            lastHtmlLogLine = obj.lastHtmlLogLine;
        end


        % Convenience methods for each log level
        function trace(obj, varargin), obj.log('trace', varargin{:}); end
        function debug(obj, varargin), obj.log('debug', varargin{:}); end
        function info(obj, varargin), obj.log('info', varargin{:}); end
        function warn(obj, varargin), obj.log('warn', varargin{:}); end
        function error(obj, varargin), obj.log('error', varargin{:}); end
        function critical(obj, varargin), obj.log('critical', varargin{:}); end
    end
end
