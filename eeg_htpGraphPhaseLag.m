function [EEG, results] = eeg_htpGraphPhaseLag(EEG, varargin)
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
% Required Inputs:
%     EEG       - EEGLAB Structure
% Function Specific Inputs:
%     'filterorder' - integer, override filter order
%     'threshold'   - thresholding type 'mediansd' implemented
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

defaultFilterOrder = 1625;
defaultThreshold = missing;

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'filterorder', defaultFilterOrder, @isnumeric);
addParameter(ip, 'threshold', defaultThreshold, @ischar);
parse(ip, EEG, varargin{:});

% take source signal

% filter by frequency
freqbands = {
    'delta', 2 , 3.5;
    'theta', 3.5, 7.5;
    'alpha1', 7.5, 10;
    'alpha2', 10, 13;
    'beta', 13, 30;
    'gamma1', 30, 55;
    'gamma2', 65, 90;
    };

% defined frequency vector
nsteps = 50;
frex = logspace(log10(2), log10(80), nsteps);
stds = linspace(.5,3,nsteps);       % std for gaussian

filterorder = ip.Results.filterorder;

%% Filter data by frequency band
fwpli = zeros(EEG.nbchan, EEG.nbchan, nsteps);
fEEG = cell(nsteps,1);
parfor fi = 1 : nsteps
    current_freq = [frex(fi) - stds(fi) frex(fi) + stds(fi)];
    fprintf("Filter Freq (order: 3300): %s\n", num2str(current_freq));

    fEEG{fi} = eeg_htpEegCreateEpochsEeglab( ...
        eeg_htpEegFilterFastFc( EEG, 'bandpass', current_freq, 'order', filterorder));
end

% separate computational steps to avoid precision errors with parfor
number_of_nans = 1;
while number_of_nans ~= 0
    parfor fi = 1 : nsteps
        bcm = eeg_htpCalcReturnColumnMatrix(fEEG{fi});
        fwpli(:,:, fi) = fastfc_wpli(bcm);
    end

    % check for NaN
    nanCheckArr = zeros(size(fwpli,3),3);
    for fi = 1 : size(fwpli,3)
        nanCheckArr(fi,1) = fi;
        nanCheckArr(fi,2) = frex(fi);
        nanCheckArr(fi,3) = any(any(isnan(fwpli(:,:,fi))));

    end
    number_of_nans = sum(nanCheckArr(:,3));
    
    fprintf("Mean: %d, Number of NaNs: %d\n", mean2(fwpli), number_of_nans);
end


if number_of_nans > 0 
    error('NaNs introduced into connectivity matrix. Check code.')
end

fEEG = [];

%%
% average by band
wpli = zeros(EEG.nbchan, EEG.nbchan, length(freqbands));
for fi = 1 : length(freqbands)

    select_freq = frex > freqbands{fi,2} & frex < freqbands{fi,3};
   % disp(select_freq)
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

bandtable = [];
for fi = 1 : size(wpli,3)
    tmptable = [table(string(repmat(EEG.setname, size(wpli,2),1)), string(repmat(label_freqband{fi}, size(wpli,2),1)), string(label_chans'), ...
        'VariableNames', {'eegid','freq', 'chanout'}) array2table(wpli(:,:,fi),  'VariableNames',label_chans)];
    if fi == 1
        bandtable = tmptable;
    else
        bandtable = [bandtable; tmptable];
    end
end

freqtable = [];
label_frex = string(num2cell(frex));
frex_by_band = label_frex;
for fi = 1 : length(freqbands)
    current_band_label = freqbands{fi,1};
    current_band_start = freqbands{fi,2};
    current_band_end = freqbands{fi,3};

    frex_by_band(frex >= current_band_start & frex < current_band_end) = current_band_label;
    

end

for fi = 1 : size(fwpli,3)
    tmptable = [table(string(repmat(EEG.setname, size(fwpli,2),1)),  string(repmat(frex_by_band{fi}, size(fwpli,2),1)), ...
        string(repmat(label_frex{fi}, size(fwpli,2),1)), string(label_chans'), ...
        'VariableNames', {'eegid','bandname','freq', 'chanout'}) array2table(fwpli(:,:,fi),  'VariableNames',label_chans)];
    if fi == 1
        freqtable = tmptable;
    else
        freqtable = [freqtable; tmptable];
    end
end

% Thresholding
if ~ismissing(ip.Results.threshold)
    % based on cohen ANTS Chapter 31
    switch ip.Results.threshold % per frequency 
        case 'mediansd'
            for fi = 1 : size(fwpli, 3)
                fwpli_current = fwpli(:,:,fi);
            pli_thresh = std(reshape(fwpli_current,1,[]))+ median(reshape(fwpli_current,1,[]));
            fwpli_current(fwpli_current < pli_thresh) = 0;
            fwpli(:,:,fi) = fwpli_current;
            disp(['WPLI Threshold Set at Median + SD (' num2str(frex(fi)) 'Hz): ' num2str(pli_thresh)]);
            threshold_vector(fi) = pli_thresh;
            end
    end
else
    threshold_vector = repmat(0,length(frex),1);
end



% any(any(isnan(fwpli(:,:,44))))
% Calculate Graph Measures
EEG = eeg_htpGraphBraphWU(EEG, fwpli, label_chans, frex);


% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});

% Outputs: 
EEG.vhtp.eeg_htpGraphPhaseLag.qi_table = qi_table;
EEG.vhtp.eeg_htpGraphPhaseLag.wpli = wpli;
EEG.vhtp.eeg_htpGraphPhaseLag.fwpli = fwpli;
EEG.vhtp.eeg_htpGraphPhaseLag.freqbands = label_freqband;
EEG.vhtp.eeg_htpGraphPhaseLag.summarytable = freqtable;
EEG.vhtp.eeg_htpGraphPhaseLag.bandtable = bandtable;
EEG.vhtp.eeg_htpGraphPhaseLag.graphWU = EEG.vhtp.eeg_htpGraphBraphWU.summary_table;
EEG.vhtp.eeg_htpGraphPhaseLag.chanlabels = label_chans;
EEG.vhtp.eeg_htpGraphPhaseLag.freqlabels = label_frex;
EEG.vhtp.eeg_htpGraphPhaseLag.thresholds = threshold_vector;

results = EEG.vhtp.eeg_htpGraphPhaseLag;
end
