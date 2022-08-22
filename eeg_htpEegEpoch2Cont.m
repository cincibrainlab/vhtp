function EEG = eeg_htpEegEpoch2cont(EEG)
% Description: Converts epoched to continous data.
% Category: Preprocessing
% ShortTitle: Epoched to continuous data
% Tags: Epoching

    % MATLAB built-in input validation
    ip = inputParser();
    addRequired(ip, 'EEG', @isstruct);
    parse(ip,EEG);

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
