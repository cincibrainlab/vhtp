function [EEG, results] = eeg_htpEegAssessPipelineHAPPE(EEG1, EEG2, varargin)
% eeg_htpEegAssessPipelineHAPPE() - adaptation of HAPPE pipeline quality
% assurance to incorporate additional visualization and export options.
%
% Key Changes from original HAPPE2 script:
%   1. Input has been modified from data matrixes to EEG SET files
%   2. Corr. coefs are stored in table format with column names for batch
%   export into CSV after batch run.
%   3. Corr. coefs have been grouped by frequency band
%   4. Lower quality channels are exported to console
%   5. Topographic plotting of corr. coefs
%   6. histogram of corr. coef by amplitude/frequency bands
%
% original code: Alexa D. Monachino, PINE Lab at Northeastern University, 2021
% https://github.com/PINE-Lab/HAPPE/blob/master/scripts/pipeline_scripts/assessPipelineStep.m
% vHTP adaptation by E. Pedapati 3/19/2022

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output
msglog = @(x) fprintf('%s: %s\n', functionstamp, x);
scrsz = get(0,'ScreenSize'); % left, bottom, width, height

% input parsing
defaultOutputDir = tempdir;

ip = inputParser();
addRequired(ip, 'EEG1', @isstruct);
addRequired(ip, 'EEG2', @isstruct);
addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)

parse(ip, EEG1, EEG2, varargin{:});

% check inputs
EEGCell = {EEG1,EEG2};

% prepare filename
[~,fn1,~] = fileparts(EEG1.setname);
[~,fn2,~] = fileparts(EEG2.setname);
basefilename = sprintf('%s_%s_%s_%s.TBD', functionstamp,timestamp,fn1,fn2);

fprintf('%s: EEG1: %s EEG2: %s Date: %s\n', functionstamp,fn1,fn2, timestamp);

% convert to continous data streams
datCell = cell(2,1);
for i = 1 : numel(EEGCell)
    current_EEG = EEGCell{i};
    if ndims(current_EEG.data) > 2 %#ok<ISMAT>
        msglog(['EEG ' num2str(i) ' is epoched. Coverting to continuous format.']);
        datCell{i} = reshape(current_EEG.data, size(current_EEG.data, 1),...
            size(current_EEG.data, 2) * size(current_EEG.data, 3));
    else
        datCell{i} = current_EEG.data;
    end
end

% check similar dimensions and samples
if ~isequal(size(datCell{1}),size(datCell{2}))
    error('EEG data structures have different dimensions.')
end

% ensure common sampling rate
if EEG1.srate ~= EEG2.srate
    error('EEGs have different sampling rates. Use ''resample'',''true'' to resample to lowest sample rate.')
end

% assign EEGs to sig1 and sig2
sig1 = datCell{1};
sig2 = datCell{2};

% QA #1: correlation by channel
% cr = channel x 1;
cr = corr(sig1', sig2');
cr = diag(cr);

% QA #2: correlation by frequency x channel
% cf = channel x freq
fvec = [0:80];
cf = mscohere(sig1', sig2', 1000, 0, fvec, EEG1.srate)';

% Other QA Measures from HAPPE2
% extracted from calcSNR_PSNR.m
% see: https://github.com/PINE-Lab/HAPPE/blob/master/scripts/calcSNR_PSNR.m
order = 2; % EEG2 - EEG1
orderMod = (order == 1)*sig1 + (order == 2)*sig2 ;
squared_differences = (sig1 - sig2).^2 ;
MSE = mean(squared_differences, 2) ;
DEN = sum(squared_differences, 2) ;
NUM = sum(orderMod.^2, 2) ;
SNR = mean(20*log10(realsqrt(NUM)./realsqrt(DEN))) ;
PeakSNR = mean(20 * log10(max(orderMod, [], 2)./realsqrt(MSE))) ;
RMSE = mean(realsqrt(mean((sig1 - sig2) .^ 2, 2)));
MAE = mean(mean(abs(sig1 - sig2), 2));

% Summary Measures
coefStruct = struct();

% add amplitude correlation coefficient
ampStruct(1).label = sprintf('CorrCoef\n%s', ...
    sprintf('Range: %.2f-%.2f', min(cr), max(cr)));
ampStruct(1).meancf = cr;
ampStruct(1).bandname = 'Amplitude';

% Calculate freq. coherence by band
BandDefs = {'Delta', 2, 3.5; 'Theta', 3.5, 7.5; 'Alpha1', 7.5, 10.5;
    'Alpha2', 10.5, 12.5; 'Beta', 13, 30; 'Gamma1', 30, 55;
    'Gamma2', 65, 80; 'Epsilon', 81, 120; };

for bi = 1 : size(BandDefs,1)
    f1 = BandDefs{bi,2};
    f2 = BandDefs{bi,3};
    if  f2 <= fvec(end)
        cftmp = [];
        band_index = dsearchn(fvec',f1):dsearchn(fvec',f2);
        cftmp = mean(cf(:, band_index),2);
        rangetmp = sprintf('Range: %.2f-%.2f', min(cftmp), max(cftmp));
        coefStruct(bi).meancf = cftmp;
        labeltmp = sprintf('%s (%1.1f-%1.1f)\n%s', BandDefs{bi,1}, f1, f2, rangetmp);
        coefStruct(bi).label = labeltmp;
        coefStruct(bi).bandname =  BandDefs{bi,1};
    end
end

% merge amplitude and frequency coherence
coefStruct = [ampStruct coefStruct];

% Visualization
f1 = figure('Color','white','Position', [100 100 1536 1000]);
plotno =  numel(coefStruct);

for bi = 1 : plotno
    h1 = subplot(3,4,bi);
    topoplotIndie(coefStruct(bi).meancf,...
        EEG1.chanlocs, 'electrodes', 'labels', ...
        'shading','flat');
    if bi == 1, sub1_pos = get(gca,'position'); end
    sub_pos = get(gca,'position'); % get subplot axis position
    if bi <=4
        set(gca,'position',sub_pos.*[.9 .9 1.1 1.1]); % modufy pos of row 1
    else
        set(gca,'position',sub_pos.*[.9 .9 1.1 1.1]); % modufy pos of row 1
    end
    %set(h1, 'Units', 'normalized');
    %set(h1, 'OuterPosition', [[], [], .8, .2]);
    title(coefStruct(bi).label, 'FontSize', 12);
    caxis([.95 1]);
    colormap bone;
end

hp4 = sub_pos;
cb = colorbar('Position', [.85  .5  0.025 .3], 'FontSize', 14);
cb.Label.String = 'Corr. Coef.';
ctitle = sprintf('%s: Channel Cross-Correlation (Run Date:%s)\nEEG1 = %s   EEG2 = %s', ...
    functionstamp, timestamp, EEG1.setname, EEG2.setname);
allCoefs = horzcat(coefStruct(:).meancf);
subplot(3,4,9:12);
hist(allCoefs);
xlabel('Correlation Coefficent', 'FontSize', 12);
set(gca,'FontSize',12);
ylabel('Count', 'FontSize', 12);
title('Histogram of Amplitude/Frequency Correlation Coefficents', 'FontSize',14);
legend( {coefStruct(:).bandname}, 'Location', 'northwest', 'FontSize', 12);
annotation('textbox', sub1_pos.*[1 1.075 1 1],'String',ctitle, ...
    'FontSize', 14,  'FitBoxToText','on', 'LineStyle','none', 'Interpreter', 'none');
image_filename = fullfile(tempdir, strrep(basefilename,'.TBD','.png'));
saveas(f1, image_filename);

% identify trouble channels/frequencies
count = 1;
summarytmp = struct();
for bi = 1 : numel(coefStruct)
    tmpBand = coefStruct(bi);
    summarytmp(bi).label = tmpBand.bandname;
    summarytmp(bi).mean = mean( tmpBand.meancf );
    for ti = 1 : numel(tmpBand.meancf)
        if tmpBand.meancf(ti) < .95
            troubleStruct(count).setname = EEG1.setname;
            troubleStruct(count).bandname = tmpBand.bandname;
            troubleStruct(count).chan = EEG1.chanlocs(ti).labels;
            troubleStruct(count).value = tmpBand.meancf(ti);
            troubleStruct(count).label = sprintf('%s (Chan: %s)', ...
                troubleStruct(count).bandname, troubleStruct(count).chan);
            count = count + 1;
        end
    end
end
troubleChannelTable = struct2table(troubleStruct);

summaryCoefs = rows2vars(struct2table(summarytmp),'VariableNamesSource', 'label');
summary_table_tmp = horzcat(summaryCoefs, table(SNR, PeakSNR, RMSE, MAE));

summary_table = horzcat(cell2table({EEG1.setname, EEG2.setname}, 'VariableNames', {'EEG1','EEG2'}), ...
    summary_table_tmp);
fprintf('<strong>%s: Quality Assurance Summary\n</strong>', functionstamp);
disp(summary_table);
fprintf('%s: Channels below quality threshold (.95)\n', functionstamp);
disp(troubleChannelTable);
fprintf('%s: Visualization:  %s \n', functionstamp, image_filename );


% QI Table
qi_table = cell2table({EEG1.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
qi_temp = struct2table(ip.Results, 'AsArray',true);

% Outputs:
EEG.vhtp.eeg_htpEegAssessPipelineHAPPE.summary_table =  summary_table;
EEG.vhtp.eeg_htpEegAssessPipelineHAPPE.qi_table = qi_table;

results = EEG.vhtp.eeg_htpEegAssessPipelineHAPPE;
end