function [EEG, results] = eeg_htpGraphPhaseLag(EEG, filterorder, varargin)
% eeg_htpGraphPhaseLag() - calculates phase lag index and associated
%                          graph theory measures from EEG set.
%
% Dependencies:
%    FastFc Toolbox        https://github.com/juangpc/FastFC
%    Braph 1.0 Toolbox     https://github.com/softmatterlab/BRAPH
% instructions: download source code and add to matlab path

% Usage:
%    >> [ EEG, results ] = eeg_htpGraphPhaseLag( EEG )
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
%  Contact: kyle.cullion@cchmc.org% function outline

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addRequired(ip, 'filterorder', @isnumeric);

parse(ip, EEG, filterorder);

% take source signal

% filter by frequency
freqbands = {
    'delta', 2 , 3.5;
    'theta', 3.5, 7.5;
    'alpha1', 8, 10;
    'alpha2', 10, 13;
    'beta', 13, 30;
    'gamma1', 30, 55;
    'gamma2', 65, 90;
    };

% defined frequency vector
nsteps = 50;
frex = logspace(log10(3.5), log10(80), nsteps);
stds = linspace(.5,3,nsteps);       % std for gaussian

fwpli = zeros(EEG.nbchan, EEG.nbchan, nsteps);

parfor fi = 1 : nsteps
    current_freq = [frex(fi) - stds(fi) frex(fi) + stds(fi)];
    fprintf("Filter Freq (order: 3300): %s\n", num2str(current_freq));

    fEEG = eeg_htpEegCreateEpochsEeglab( ...
        eeg_htpEegFilterFastFc( EEG, 'bandpass', current_freq, 'order', filterorder));

    fwpli(:,:, fi) = fastfc_wpli(eeg_htpCalcReturnColumnMatrix(fEEG));
    
end

% average by band
wpli = zeros(EEG.nbchan, EEG.nbchan, length(freqbands));
for fi = 1 : length(freqbands)

    select_freq = frex > freqbands{fi,2} & frex < freqbands{fi,3};
    disp(select_freq)
    wpli(:,:,fi) = mean(fwpli(:,:,select_freq),3);
end

% create label vectors
label_freqband = freqbands(:,1)';
label_chans = {EEG.chanlocs.labels};

% 
% if showplots == true
%     figure('color','w', 'Position', [194 849 2270 418]);
%     for ii = 1 : length(freqbands)
%         subplot(1, length(freqbands), ii);
%         imagesc( wpli(:,:,ii) );
%     axis square;
%     axis xy;
%     title(label_freqband{ii})    
%     end
% end

results.wpli = wpli;
results.fwpli = fwpli;

end
