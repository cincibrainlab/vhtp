% ribbon_visualize() - Visualize ribbon analysis results.
%
% Input:
%           rawSpectrogram: 3-D array Frequency x Time x Channels. 
%          ribbonStructure: Precalculated by ribbon_obtainSigmoidParameters.m. By default, the data is stored in EEG.etc.ribbon.ribbonStructure
%         icawinvColumnIdx: IC scalp topography of the selected IC. By default, it is EEG.icawinv(:,n) for nth IC.
%                 chanlocs: EEGLAB channel location data structure. By default, it is EEG.chanlocs.
%                     pvaf: 1x1 Percent variance accounted for.
%
% Example:
%         ribbon_visualize(EEG.etc.ribbon.spectrogram(:,:,icIdx), EEG.etc.ribbon.ribbonStructure.ic(icIdx), EEG.icawinv(:,icIdx), EEG.chanlocs, EEG.etc.ribbon.pvafMatrix(icIdx,2));
%
%         This function is assumed to be used as follows.
%         ribbon_visualize(EEG.etc.ribbon.ribbonStructure.ic(n), EEG.icaweights(:,n), EEG.chanlocs)
%
% History:
% 08/14/2023 Makoto. Visualize FOOOF results.
% 08/11/2023 Makoto. RSME from octave-weighted linear fitting added..
% 09/07/2021 Makoto. YTick added.
% 09/03/2021 Makoto. DC value added to gaussFittedRibbonPower.
% 08/23/2021 Makoto. ribbonStructure.gaussfit_ribbonPower fixed.
% 03/11/2021 Makoto. Added descriptiona to the help message.
% 08/29/2020 Makoto. Plus three PSD plots supported.
% 07/11/2020 Makoto. Minor change applied.
% 06/28/2020 Makoto. Created.

% Copyright (C) 2020 Makoto Miyakoshi. Swartz Center, INC, UCSD.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
% 1. Redistributions of source code must retain the above copyright notice,
% this list of conditions and the following disclaimer.
%
% 2. Redistributions in binary form must reproduce the above copyright notice,
% this list of conditions and the following disclaimer in the documentation
% and/or other materials provided with the distribution.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
% THE POSSIBILITY OF SUCH DAMAGE.

function ribbon_visualize(rawSpectrogram, ribbonStructure, icawinvColumn, chanlocs, pvaf)

% Check if Curve Fitting Toolbox is available.
matlabToolboxList = ver;
isCurveFittingToolboxPresent = any(strcmp(cellstr(char(matlabToolboxList.Name)), 'Curve Fitting Toolbox'));

if isempty(ribbonStructure.x50)
    disp('Unable to detect a peak.')
    return
end

set(gcf, 'color', [0.93 0.96 1], 'position', [189 302 1461 629])

% Plot PSD.
subplot(1,2,1)
raw_PSD     = mean(rawSpectrogram,2);
fooof_AP    = ribbonStructure.FOOOF.ap_fit;
fooof_PEAKS = ribbonStructure.FOOOF.peak_fit;
fooof_PSD   = ribbonStructure.FOOOF.fooofed_spectrum;
specFreqs   = ribbonStructure.specFreqs;
lineHandle1 = plot(specFreqs, 10*log10(raw_PSD),   'linewidth', 2, 'color', [0 0 0 0.5]); hold on;
lineHandle2 = plot(specFreqs, 10*log10(fooof_PSD), 'linewidth', 2, 'color', [1 0 0 0.5]);
lineHandle3 = plot(specFreqs, 10*log10(fooof_AP),  'linewidth', 1, 'color', [1 0 0], 'LineStyle', '--');

% Read alpha peak.
alphaIdx = find(specFreqs>=8 & specFreqs<=13);
[maxPow, maxIdx] = max(10*log10(fooof_PEAKS(alphaIdx)));
maxPowFreq = specFreqs(alphaIdx(maxIdx));
peakLineTop    = 10*log10(fooof_PSD(alphaIdx(maxIdx)));
peakLineBottom = 10*log10(fooof_AP(alphaIdx(maxIdx)));

line([maxPowFreq maxPowFreq], [peakLineTop peakLineBottom], 'linewidth', 0.5, 'color', [0 0 0], 'linestyle', ':')

xlim([2 45])
xlabel('Freq (Hz)')
ylabel('10*log10 \muV^2/Hz (dB)')
title(['PSD (Peak alpha \Delta' sprintf('%.1f dB at %.1f Hz)', maxPow, maxPowFreq)])
legend([lineHandle1 lineHandle2 lineHandle3], {'Raw' 'Modeled' 'Exponent'})
set(gca, 'position', [0.13 0.55 0.2328 0.4])

    % wholeRibbonPsd = mean(ribbonStructure.trimmedSpectrogram,2);
    % specFreqs = ribbonStructure.specFreqs;
    % plot(specFreqs, 10*log10(wholeRibbonPsd), 'color', [0 0 0], 'linewidth', 2);
    % hold on
    % upperAsymptotePsd = mean(ribbonStructure.trimmedSpectrogram(:, ribbonStructure.longerUpperRibbonLimit:end),2);
    % lowerAsymptotePsd = mean(ribbonStructure.trimmedSpectrogram(:, 1:ribbonStructure.longerUpperRibbonLimit-1),2);
    % plot(specFreqs, 10*log10(upperAsymptotePsd), 'color', [1 0 0], 'linewidth', 2);
    % plot(specFreqs, 10*log10(lowerAsymptotePsd), 'color', [0 0 1], 'linewidth', 2);

    % % Plot PSD.
    % subplot(1,2,1)
    % wholeRibbonPsd = mean(ribbonStructure.trimmedSpectrogram,2);
    % freqs = ribbonStructure.specFreqs;
    % plot(freqs, 10*log10(wholeRibbonPsd), 'b', 'linewidth', 3);
    % hold on
    % lowerAsymptotePsd = mean(ribbonStructure.trimmedSpectrogram(:, 1:ribbonStructure.lowerRibbonLimit_sigmoid),2);
    % transitionBandPsd = mean(ribbonStructure.trimmedSpectrogram(:, ribbonStructure.lowerRibbonLimit_sigmoid+1:ribbonStructure.longerUpperRibbonLimit-1),2);
    % upperAsymptotePsd = mean(ribbonStructure.trimmedSpectrogram(:, ribbonStructure.longerUpperRibbonLimit:end),2);
    % plot(freqs, 10*log10(lowerAsymptotePsd), 'color', [1.00 0.1 0.1], 'linewidth', 1, 'linestyle', '--');
    % plot(freqs, 10*log10(transitionBandPsd), 'color', [0.1 1.00 0.1], 'linewidth', 1, 'linestyle', '--');
    % plot(freqs, 10*log10(upperAsymptotePsd), 'color', [0.1 0.1 1.00], 'linewidth', 1, 'linestyle', '--');
    % %xlim([min(freqs) max(freqs)]) % 10/11/2020 Makoto. For Fragile X project.


% Plot scalp topo.
insetHandle1 = axes('Position', [-0.075 0.05 0.35 0.35]);
box on
topoplot(icawinvColumn, chanlocs)
title(sprintf('PVAF %.2f%%', pvaf))

% Plot ribbon spectrogram.
insetHandle2 = axes('Position', [0.225 0.075 0.175 0.325]);
goodFreqIdx = find(ribbonStructure.specFreqs<=30);
plotSpectrogram     = ribbonStructure.trimmedSpectrogram(goodFreqIdx,:);

if round(size(plotSpectrogram,2)*0.01)>= 1
    smoothedSpectrogram = movmean(plotSpectrogram, round(size(plotSpectrogram,2)*0.01), 2);
else
    smoothedSpectrogram = movmean(plotSpectrogram, 2, 2); % Window size 2 is the minimum smoothing effect.
end
spectrogramDb = 10*log10(smoothedSpectrogram);
%spectrogramDb = 10*log10(plotSpectrogram);
colorScale = prctile(spectrogramDb(:), [1 99]);
imagesc(spectrogramDb, colorScale);
axis xy

plotFreqs = ribbonStructure.specFreqs(goodFreqIdx);
ytick = [find(plotFreqs>=2,1) find(plotFreqs>=4,1) find(plotFreqs>=8,1) find(plotFreqs>=13,1) find(plotFreqs>=30,1)];
set(gca, 'ytick', ytick, 'yticklabel', [2 4 8 13 30], 'xtick', [])
xlabel('Sorted time (1-% smoothed)')
ylabel('Frequency (Hz)')
title(sprintf('Time-sorted spectrogram\nRibbon width, sigma=%.2f(Hz)', ribbonStructure.gaussfit_ribbonWidth.c1/10));
colorbarHandle = colorbar;
%set(get(colorbarHandle,'title'),'String', '10*log10(dB)');
set(get(colorbarHandle,'title'),'String', 'dB');
set(gca, 'Position', [0.225 0.075 0.175 0.325]);


subplot(1,2,2)
% Plot the peak-power frequency ribbon and its power.
plotTime = 100/length(ribbonStructure.trimmedTimes):100/length(ribbonStructure.trimmedTimes):100;
% [AX,H1,H2] = plotyy(ribbonStructure.trimmedTimes, ribbonStructure.trimmedRibbon, ribbonStructure.trimmedTimes, ribbonStructure.smoothedRibbonPower);
[AX,H1,H2] = plotyy(plotTime, ribbonStructure.trimmedRibbon, plotTime, ribbonStructure.smoothedRibbonPower);
set(H1, 'marker', 'o', 'linestyle', 'none', 'MarkerEdgeColor', [0.6 0.6 0.6])
set(AX(1), 'ycolor', [0 0 0], 'ytick', [2 4 6 8 10 13])
set(get(AX(1),'YLabel'), 'String', 'Frequency (Hz)')
set(H2, 'Color', [0.8 0.8 0.95], 'linewidth', 2)
set(AX(2), 'ycolor', [0.4 0.4 0.8])
set(get(AX(2),'YLabel'), 'String', '5-% smoothed power (uV^2)', 'color', [0.4 0.4 0.8])
xlabel('Sorted normalized time (%)')
set(AX, 'position', [0.475    0.1100    0.4853    0.8150])

% Overlay sigmoid analysis results.
hold on
patch([ribbonStructure.lowerRibbonLimit_sigmoid ...
       ribbonStructure.upperRibbonLimit_sigmoid ...
       ribbonStructure.upperRibbonLimit_sigmoid ...
       ribbonStructure.lowerRibbonLimit_sigmoid]*plotTime(1), ...
       [14 14 0 0], [1 0 0], 'FaceAlpha', 0.1, 'linestyle', 'none')
% line([plotTime(ribbonStructure.x50) plotTime(ribbonStructure.x50)]                                          , ylim, 'linestyle', '-',  'color', [0 0 0])
% line([plotTime(ribbonStructure.lowerRibbonLimit_sigmoid) plotTime(ribbonStructure.lowerRibbonLimit_sigmoid)], ylim, 'linestyle', '--', 'color', [0 0 0])
% line([plotTime(ribbonStructure.upperRibbonLimit_sigmoid)   plotTime(ribbonStructure.upperRibbonLimit_sigmoid)],   ylim, 'linestyle', '--', 'color', [0 0 0])


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Plot lines for lower and upper plateaus. %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%plot(plotTime(1:length(ribbonStructure.lowerAsymplateauFittedLine)), ribbonStructure.lowerAsymplateauFittedLine, 'linewidth', 1, 'linestyle', '--', 'color', [1 0 0])
%plot(plotTime(ribbonStructure.longerUpperRibbonLimit:end),            ribbonStructure.upperAsymplateauFittedLine, 'linewidth', 1, 'linestyle', '--', 'color', [1 0 0])
%plot(plotTime(ribbonStructure.lowerRibbonLimit_sigmoid:ribbonStructure.longerUpperRibbonLimit),...
%                                                                    ribbonStructure.sigmoidfit_inflection.ypred, 'linewidth', 1, 'linestyle', '--', 'color', [1 0 0])
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Plot another line for the upper plateau. %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
plot(plotTime(ribbonStructure.longerUpperRibbonLimit:end), ribbonStructure.longerUpperRibbonFittedLine, 'linewidth', 2, 'color', [1 0 0])
 
% Overlay fitted Gaussian to ribbon power.
hold(AX(2))
if ~isempty(ribbonStructure.gaussfit_ribbonPower)
    gaussPlottingIdx = ribbonStructure.lowerRibbonLimit_sigmoid:length(ribbonStructure.trimmedRibbonPower);

    if isCurveFittingToolboxPresent == 1
        disp('Using Curve Fitting Toolbox.')
        gaussToPlot = ribbonStructure.gaussfit_ribbonPower(1:length(gaussPlottingIdx));

    else
        disp('Curve Fitting Toolbox not installed. Using FOOOF submodule to substitute.')

        gaussFit = @(a,b,c,x) a(1).*exp(-((x-b(1))./c(1)).^2);
        gaussToPlot = gaussFit(ribbonStructure.gaussfit_ribbonPower.a1, ...
                               ribbonStructure.gaussfit_ribbonPower.b1, ...
                               ribbonStructure.gaussfit_ribbonPower.c1, ...
                               1:length(gaussPlottingIdx));
    end
    
    % Obtain the DC value to add (09/03/2021 Makoto)
    dcValueToRecover = min(ribbonStructure.smoothedRibbonPower(gaussPlottingIdx));
       
    plot(AX(2), plotTime(gaussPlottingIdx)', gaussToPlot + dcValueToRecover, 'color', [0.3 0.3 1], 'linewidth', 1)
end
xlim(AX(1), [plotTime(1) plotTime(end)])
ylim(AX(1), [0 14])
xlim(AX(2), [plotTime(1) plotTime(end)])

% Add a title.
title(sprintf('%.0f%% of data rejected for peak power > 13 Hz', 100*(1-length(ribbonStructure.trimmedRibbon)/length(ribbonStructure.trimmingMask))))

% Add text.
%text(3, 13.5, sprintf('Linear fitting RMSE: %.3f', ribbonStructure.rmseMatrix(1,1)), 'fontsize', 11) % (1,1) is unweighted, (1,2) is octave-weighted

set(findall(gcf, '-property', 'fontsize'), 'fontsize', 11)
hold off