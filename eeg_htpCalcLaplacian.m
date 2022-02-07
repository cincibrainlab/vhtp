function [EEG, results] = eeg_htpCalcLaplacian(EEG, varargin)
    % eeg_htpCalcLaplacian() - compute Laplacian of EEG data via Cohen's
    % implementation of Perrin et al. (1989). This function is a wrapper
    % for laplacian_perrinX (unmodified) from
    % https://github.com/mikexcohen/AnalyzingNeuralTimeSeries/blob/main/laplacian_perrinX.m
    % Units are in microvolts per mm^2.
    %
    % Usage:
    %    >> [ EEG, results ] = eeg_htpCalcLaplacian( EEG )
    %
    % Require Inputs:
    %     EEG       - EEGLAB Structure
    % Function Specific Inputs:
    %     'save' - also save the results to a new SET file
    %     'outdir' - directory to save the results to
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
    defaultSave = false;
    defaultOutdir = tempdir;

    % MATLAB built-in input validation
    ip = inputParser();
    addRequired(ip, 'EEG', @isstruct);
    addParameter(ip, 'outdir', defaultOutdir, @isfolder)
    addParameter(ip, 'save', defaultSave, @islogical)
    parse(ip, EEG, varargin{:});

    % base output file can be modified with strrep()
    outputfile = fullfile(ip.Results.outdir, [EEG.filename '_lap.mat']);

    % START: Signal Processing

    % extract XYZ coordinates from EEG structure
    X = [EEG.chanlocs.X];
    Y = [EEG.chanlocs.Y];
    Z = [EEG.chanlocs.Z];

    % External Fuction:
    % Source: https://github.com/mikexcohen/AnalyzingNeuralTimeSeries
    [EEG.data, ~, ~] = laplacian_perrinX(EEG.data, X, Y, Z);

    % Save dataset and create dir if needed
    if ip.Results.save

        if ~exist(ip.Results.outdir, 'dir')
            mkdir(ip.Results.outdir);
        end

        EEG = pop_saveset(EEG, 'filename', outputfile);
    end

    % END: Signal Processing

    % QI Table
    qi_table = cell2table({EEG.setname, functionstamp, timestamp, ...
                        ip.Results.save, ip.Results.outdir}, ...
        'VariableNames', {'eegid', 'scriptname', 'timestamp', 'savestatus', 'outdir'});

    % Outputs:
    results = [];

end
