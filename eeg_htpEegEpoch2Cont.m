function EEG = eeg_htpEegEpoch2Cont(EEG)
% Description: Converts epoched to continous data.
% ShortTitle: Epoched to continuous data
% Category: Preprocessing
% Tags: Epoching
%
%% Syntax:
%   EEG = eeg_htpEegRemoveSegmentsEeglab( EEG )
%
%% Required Inputs:
%   EEG [struct]           - EEGLAB Structure
%
%% Function Specific Inputs:
%
%% Outputs:
%   EEG [struct] - output structure with updated dataset
%
%% Disclaimer:
%   Part of the Cincinnati Visual High Throughput EEG Pipeline
%   
%   Please see http://github.com/cincibrainlab
%
%% Contact:
%   kyle.cullion@cchmc.org

    % MATLAB built-in input validation
    ip = inputParser();
    addRequired(ip, 'EEG', @isstruct);
    parse(ip,EEG);

    if length(size(EEG.data)) > 2
        % starting dimensions
        [nchans, npnts, ntrial]     = size(EEG.data);
        EEG.data                    = double(reshape(EEG.data, nchans, npnts * ntrial));
        EEG.pnts                    = npnts * ntrial;
        EEG.times                   = 1:1 / EEG.srate:(size(EEG.data, 2) / EEG.srate) * 1000;
    else
        warning('Data is likely already continuous.')
        fprintf('No trial dimension present in data');
    end

    EEG         = eeg_checkset(EEG);
    EEG.data    = double(EEG.data);

end
