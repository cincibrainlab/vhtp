function result = util_htpSetupPythonInMatlab(varargin)
% Create an input parser object
p = inputParser;

% Add optional input arguments
addOptional(p, 'PythonExecutable', '');
addOptional(p, 'ExecutionMode', 'InProcess', @(x) any(validatestring(x,{'InProcess','OutOfProcess'})));

% Parse the input arguments
parse(p, varargin{:});

% Assign the parsed input arguments to variables
PythonExecutable = p.Results.PythonExecutable;
ExecutionMode = p.Results.ExecutionMode;

% Set the Python version and executable path
if ~isempty(PythonExecutable)
    pyenv('Version', PythonExecutable, 'ExecutionMode', ExecutionMode);
end

% check MATLAB builtin function for Python connection
e = pyenv;
result = struct();
if isempty(e.Version)
    warning('MATLAB Python connection not found. Please install Python and MATLAB Python connection.');
    result.PythonConnection = false;
else
    fprintf('MATLAB Python connection found.\n');
    fprintf('Python version: %s\n', e.Version);
    fprintf('Python executable: %s\n', e.Executable);
    fprintf('Python library: %s\n', e.Library);
    fprintf('Python home: %s\n', e.Home);
    result.PythonConnection = true;
    result.PythonVersion = e.Version;
    result.PythonExecutable = e.Executable;
    result.PythonLibrary = e.Library;
    result.PythonHome = e.Home;
end

% Get working directory of the current script
scriptPath = mfilename('fullpath');
[workingDir,~,~] = fileparts(scriptPath);
fprintf('Working directory of the current script: %s\n', workingDir);

% Check if spam module is available in Python
moduleName = {'mne','sklearn'};
for i = 1 : numel(moduleName)
    checkPythonModule(moduleName{i});
end

    function checkPythonModule(moduleName)
        % checkPythonModule checks if a specified Python module is available
        % Input:
        %   moduleName - a string, the name of the Python module to check

        % Create the command string to check for the module's existence
        commandStr = sprintf("import importlib.util; moduleTest = importlib.util.find_spec('%s'); hasModule = moduleTest is not None;", moduleName);

        % Run the command in Python and capture the output
        haveModule = pyrun(commandStr, 'hasModule');

        % Display the result
        if haveModule
            fprintf('%s package is installed.\n', moduleName);
        else
            fprintf('%s package is not installed.\n', moduleName);
            fprintf('To install the %s package, please follow these steps:\n', moduleName);
            fprintf('1. Open a terminal or command prompt.\n');
            fprintf('2. Ensure that you have pip installed. If not, get pip by following the instructions at https://pip.pypa.io/en/stable/installing/.\n');
            fprintf('3. Install the %s package by typing: pip install %s\n', moduleName, moduleName);
            fprintf('4. Once installation is complete try again.\n');
        end
    end



end