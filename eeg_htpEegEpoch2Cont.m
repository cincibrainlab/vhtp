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
