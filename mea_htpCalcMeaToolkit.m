function MEA = mea_htpCalcMeaToolkit( MEA, path_to_results, varargin)
%  Multielectrode array signal toolkit based on vHtp Functions
%
%% Syntax
%   MEA = mea_htpCalcMeaToolkit( MEA )
%% Input
%   path_to_results [char] - folder to place result files
%   functionname [char] - htp function name (subfolder for results)
%   isParquet [logical] - alternative input for Parquet file
%% Output
%   results [struct] - output files
%% Disclaimer
%   Part of the Cincinnati Visual High Throughput EEG Pipeline
%

%% Helper Function Initialization
timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

[note] = htp_utilities();
note('Multielectrode array signal toolkit based on vHtp Functions', '*blue');

% MATLAB built-in input validation
validateFolder = @( folder ) exist(folder,"dir") ==7;

% default values
defaultGpuOn = false;

ip = inputParser();
addRequired(ip,'path_to_results', validateFolder);
addParameter(ip, 'gpuOn', defaultGpuOn, @islogical);

parse(ip, path_to_results, varargin{:});

MEA2 = eeg_htpCalcRestPower( MEA, 'useParquet', false, 'gpuOn', true, 'outputdir', path_to_results );

%MEA2 = eeg_htpCalcPhaseLag( MEA, 'gpuOn', true, 'outputdir', path_to_results );

MEA2 = eeg_htpGraphPhaseBcm( MEA, 'gpuOn', true, 'outputdir', path_to_results );


MEA2 = MEA;


    function note = htp_utilities()
        % using color printf if needed
        if exist('cprintf.m', 'file') == 2
            note        = @(msg, style) cprintf('blue', '%s: %s\n', mfilename, msg );
        else
            note        = @(msg, style) fprintf('%s: %s\n', mfilename, msg );
        end
    end

    function link = hyperlink( command, label )
        link = sprintf('<a href="matlab:%s">%s</a>', command, label);
    end

end