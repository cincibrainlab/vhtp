function [EEG, results] = eeg_htpCalcGedBounds(EEG, varargin)
    % eeg_htpCalcRestPower() - calculate spectral power on continuous data.
    %      Power is calculated using MATLAB pWelch function. Key parameter is
    %      window length with longer window providing increased frequency
    %      resolution. Overlap is set at default at 50%. A hanning window is
    %      also implemented. Speed is greatly incrased by GPU.
    %
    % Usage:
    %    >> [ EEG, results ] = eeg_htpCalcRestPower( EEG, varargin )
    %
    % Require Inputs:
    %     EEG       - EEGLAB Structure
    % Function Specific Inputs:
    %     gpuon     - [logical] use gpuArray. default: false
    %     duration  - [integer] duration to calculate on. default: 80 seconds
    %                 if duration is greater sample, will default to max size.
    %     offset    - [integer] start time in seconds. default: 0
    %
    % Common Visual HTP Inputs:
    %     'bandDefs'   - cell-array describing frequency band definitions
    %     {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 'alpha2', 10.5, 12.5;
    %     'beta', 13, 30;'gamma1', 30, 55; 'gamma2', 65, 80; 'epsilon', 81, 120;}
    %     'outputdir' - path for saved output files (default: tempdir)
    %
    % Outputs:
    % Outputs:
    %     EEG       - EEGLAB Structure with modified .vhtp field
    %                 [table] summary_table: subject chan power_type_bandname
    %                 [table] spectro: channel average power for spectrogram
    %     results   - .vhtp structure
    %
    %  This file is part of the Cincinnati Visual High Throughput Pipeline,
    %  please see http://github.com/cincibrainlab
    %
    %  Contact: kyle.cullion@cchmc.org

    timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
    functionstamp = mfilename; % function name for logging/output

    % Inputs: Function Specific
    defaultGpu = 0;
    defaultDuration = 80;
    defaultOffset = 0;
    defaultWindow = 2;

    % Inputs: Common across Visual HTP functions
    defaultOutputDir = tempdir;
    defaultBandDefs = {'delta', 2, 3.5; 'theta', 3.5, 7.5; 'alpha1', 8, 10;
                    'alpha2', 10.5, 12.5; 'beta', 13, 30; 'gamma1', 30, 55;
                    'gamma2', 65, 80; 'epsilon', 81, 120; };

    % MATLAB built-in input validation
    ip = inputParser();
    addRequired(ip, 'EEG', @isstruct);
    addParameter(ip, 'gpuOn', defaultGpu, @islogical);
    addParameter(ip, 'duration', defaultDuration);
    addParameter(ip, 'offset', defaultOffset);
    addParameter(ip, 'window', defaultWindow);
    addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
    addParameter(ip, 'bandDefs', defaultBandDefs, @iscell)
    parse(ip, EEG, varargin{:});

    outputdir = ip.Results.outputdir;
    bandDefs = ip.Results.bandDefs;

    % base output file can be modified with strrep()
    outputfile = fullfile(outputdir, [functionstamp '_' EEG.setname '_' timestamp '.mat']);

    % START: Signal Processing


    % END: Signal Processing

    % QI Table
    qi_table = cell2table({EEG.setname, EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid', 'filename', 'scriptname', 'timestamp'});

    % Outputs:
    EEG.vhtp.eeg_htpCalcRestPower.summary_table = csvtable;
    EEG.vhtp.eeg_htpCalcRestPower.pow.spectro = [spectro_info, spectro_values];
    EEG.vhtp.eeg_htpCalcRestPower.qi_table = qi_table;
    results = EEG.vhtp.eeg_htpCalcRestPower;

end
