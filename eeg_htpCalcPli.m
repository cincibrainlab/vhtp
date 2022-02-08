function [EEG, results] = eeg_htpCalcPli(EEG, varargin)
    % eeg_htpCalcPli() - calculates phase lag index on EEG set
    %
    % Usage:
    %    >> [ EEG, results ] = eeg_htpFunctionTemplate( EEG )
    %
    % Require Inputs:
    %     EEG       - EEGLAB Structure
    % Function Specific Inputs:
    %     'outputdir' - description
    %
    % Outputs:
    %     EEG       - EEGLAB Structure with modified .vhtp field
    %     results   - .vhtp structure
    %
    %  This file is part of the Cincinnati Visual High Throughput Pipeline,
    %  please see http://github.com/cincibrainlab
    %
    %  Contact: kyle.cullion@cchmc.org

    timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
    functionstamp = mfilename; % function name for logging/output

    % Inputs: Function Specific

    % Inputs: Common across Visual HTP functions
    defaultOutputDir = tempdir;

    % MATLAB built-in input validation
    ip = inputParser();
    addRequired(ip, 'EEG', @isstruct);
    addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
    parse(ip, EEG, varargin{:});

    outputdir = ip.Results.outputdir;


    % END: Signal Processing

    % QI Table
    qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid', 'scriptname', 'timestamp'});

    % Outputs:
    results = [];

end

function EEG = epoch2cont(EEG)
    % revised 9/30/2021

    if length(size(EEG.data)) > 2
        % starting dimensions
        [nchans, npnts, ntrial] = size(EEG.data);
        EEG.data = double(reshape(EEG.data, nchans, npnts * ntrial));
        EEG.pnts = npnts * ntrial;
        EEG.times = 1:1 / EEG.srate:(size(EEG.data, 2) / EEG.srate) * 1000;
    else
        warning('Data is likely already continuous.')
        fprintf('No trial dimension present in data');
    end

    EEG = eeg_checkset(EEG);
    EEG.data = double(EEG.data);

end
