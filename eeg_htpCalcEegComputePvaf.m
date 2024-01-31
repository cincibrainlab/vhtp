function [EEG] = eeg_htpCalcEegComputePvaf(EEG, varargin)
    % eeg_htpCalcEegComputePvaf - Computes the Percent Variance Accounted For (PVAF) for each IC
    %
    % Usage:
    %   [EEG] = eeg_htpCalcEegComputePvaf(EEG)
    %
    % Inputs:
    %   EEG - A struct representing an EEGLAB EEG dataset containing the following fields:
    %         EEG.icawinv - The weights of the independent components.
    %         EEG.icachansind - The channel indices used for the ICA decomposition.
    %         EEG.data - The EEG data.
    %         EEG.pnts - The number of points (samples) in the EEG data.
    %         EEG.trials - The number of trials in the EEG dataset.
    %
    % Outputs:
    %   EEG - The input EEG struct with an added field EEG.etc.vhtp.eeg_htpCalcEegComputePvaf.pvaftable
    %         containing a table with the PVAF values for each component.
    %
    % Description:
    %   This function calculates the PVAF for each independent component in the EEG dataset.
    %   The PVAF values are stored in a table within the EEG struct for further analysis.
    %
    % See also: eeg_getdatact

    % Input parser setup
    p = inputParser;
    addRequired(p, 'EEG', @isstruct);
    parse(p, EEG);

    logMessage('info', 'Computing PVAF.');

    no_of_components = size(EEG.icawinv, 2);
    icaact  = eeg_getdatact(EEG, 'component', 1:no_of_components);

    % Precompute outside the loop
    icachansind = ~isempty(EEG.icachansind) * EEG.icachansind + isempty(EEG.icachansind) * (1:EEG.nbchan);

    maxsamp = 1e5;
    reducefactor = 5;
    n_samp = min(maxsamp, (EEG.pnts*EEG.trials)/reducefactor);
    samp_ind = randperm(EEG.pnts*EEG.trials, n_samp);

    % Vectorized computation of dataSegment
    dataSegment = EEG.data(icachansind, samp_ind);

    % Initialize storage for pvafval
    pvafvals = zeros(1, no_of_components);

    % Loop through components
    for ic = 1:no_of_components
        icaacttmp = squeeze(icaact(ic,:,:));
        icaMult = EEG.icawinv(:, ic) * icaacttmp(samp_ind);

        % Optimized calculations
        datavar = mean(var(dataSegment, [], 2));
        projvar = mean(var(dataSegment - icaMult, [], 2));
        pvafvals(ic) = 100 * (1 - projvar / datavar);
    end

    % Create the table in one go
    pvaftable = table(repmat({EEG.filename}, no_of_components, 1), (1:no_of_components)', pvafvals', ...
        'VariableNames', {'Filename', 'ComponentNumber', 'VarianceAccountedFor'});

    logMessage('info', 'Calculating variance accounted for all components.');
    EEG.etc.vhtp.eeg_htpCalcEegComputePvaf.pvaftable = pvaftable;
end

function logMessage(type, varargin)
    % logMessage - Prints a message to the MATLAB command window.
    %
    % Usage:
    %   logMessage(type, message)
    %
    % Inputs:
    %   type - The type of message ('info', 'warning', 'error', or other custom types).
    %   message - The message to be printed, which can include sprintf formatting.
    %
    % Description:
    %   This function prints a formatted message to the MATLAB command window. If the type is 'error',
    %   it throws an error with the message.
    %
    % Examples:
    %   logMessage('info', 'This is an informational message.');
    %   logMessage('warning', 'This is a warning message.');
    %   logMessage('error', 'This is an error message.');

    message = sprintf(varargin{:});
    switch type
        case 'info'
            fprintf('[INFO]: %s\n', message);
        case 'warning'
            fprintf('[WARNING:icFileClass]: %s\n', message);
        case 'error'
            error('[ERROR:icFileClass]: %s\n', message);
        otherwise
            fprintf('[UNKNOWN]: %s\n', message);
    end
end