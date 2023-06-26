%% input from processing file: Eden_power_processing.m
% Variables label & data: all_results (match with input_filelist)
% Table (ID) + group (external excel file from Chelsea)
% Variable EEG.chanlocs (utility)
% EEG = pop_loadset('D1005_RestingState_Run2_20210629_125121_postcomp.set', 'C:\data\14_Eden-resting_test\latest_0527\SfN dataset');

nband = ;
exclusion_chan = [17 48:49 73 81 88 113 119 125:128]; % Orekhova 2014
select_chan = setdiff(1:128, exclusion_chan); 
load('chanfiles\128-chan_hood.mat')
chan_hood = chan_hood(select_chan,select_chan);

%% part 1 relative band power
data = NaN(length(select_chan), nband, 22+24); ID = NaN(22+24,1);
for i=1:length(all_results)
    filename = cellfun(@(x) strsplit(x, '_202'), all_results{i}.qi_table.eegid, 'UniformOutput', false); % nested cell array
    partial_filename = vertcat(filename{:});          % x2 plain cell array
    partial_ID = strsplit(partial_filename{1},{'D','_'});
    ID(i) = str2double(strsplit(partial_ID{2},'D'));
%     data(:,:,i) = table2array(all_results{i}.summary_table(select_chan,16:21)); % RBP
    data(:,:,i) = table2array(all_results{i}.summary_table(select_chan,12:15)); % RBP

end
T = readtable("C:\data\14_Eden-resting_test\latest_0527\SfN dataset\IDs to Include and Hearing Variable.xlsx");
SID = T.SID;
group = T.HearingGroup_1_NH_2_HL_;
clear T

%% group separation (band power topo)
index_NH = find(group==1);
data_NH = data(:,:,index_NH); % 116(chan)x6(band)x22(subj)
n_NH = size(data_NH,3);
index_HL = find(group==2);
data_HL = data(:,:,index_HL);
n_HL = size(data_HL,3);

% bandNames = {'Delta (2-3.5 Hz)', 'Theta (4-7.5 Hz)', 'Alpha1 (8-10 Hz)', 'Alpha2 (10.5-12.5 Hz)', 'Beta (13-30 Hz)', 'Gamma (30-55 Hz)'};
bandNames = {'Delta (2-3.5 Hz)', 'Theta (4-6 Hz)', 'Alpha (7-10 Hz)', 'Beta (10-14 Hz)'};

plot_NH = squeeze(mean(data_NH,3));
plot_HL = squeeze(mean(data_HL,3));
figure('units','normalized','outerposition',[0 0 .7 1])
for k=1:nband
    subplot(4,nband,k)
    topoplot(plot_NH(:,k), EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on');
%     if k==1, caxis([.1 .2]);
% %     elseif k==2, caxis([.013 .035]);
%     elseif k==2, caxis([.023 .035]);
%     elseif k==3, caxis([.002 .01]);
%     elseif k==4, caxis([.003 .0065]);
%     elseif k==5, caxis([.001 .004]);
%     else, caxis([0 .002]);
%     end
    h=colorbar('SouthOutside','FontSize',14);if k==1, h.Label.String = 'relative band power';end
    title(bandNames{k}, 'FontSize',16)
    subplot(4,nband,k+nband)
    topoplot(plot_HL(:,k), EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on');
%     if k==1, caxis([.1 .2]);
% %     elseif k==2, caxis([.013 .035]);
%     elseif k==2, caxis([.023 .035]);
%     elseif k==3, caxis([.002 .01]);
%     elseif k==4, caxis([.003 .0065]);
%     elseif k==5, caxis([.001 .004]);
%     else, caxis([0 .002]);
%     end
    h=colorbar('SouthOutside','FontSize',14, 'visible','on');
end

dim = [.06 .70 .2 .18]; str = {['NH (n=',num2str(n_NH),')']};
annotation(gcf, 'textbox',dim,  'EdgeColor', 'none', ...
                'String',str,'FitBoxToText','on', 'FontSize', 20);
dim = [.06 .40 .2 .18]; str = {['HL (n=',num2str(n_HL),')']};
annotation(gcf, 'textbox',dim,  'EdgeColor', 'none', ...
                'String',str,'FitBoxToText','on', 'FontSize', 20);



%% band power comparison
% NH > HL
[pval1, t_orig1, ~, est_alpha1] = clust_perm2_rui3(data_NH, data_HL, chan_hood, 5000, .05, 1, .05, 2); 
% pval - chan x band matrix with pre-filled 1's, use when entries <
% est_alpha1 (see line 87)
% t_orig1 - chan x band matrix for plot only, advantage: normalized range cross bands
% function clust_perm2_rui3 & interactive/utility function VerbReport from toolbox
% dmgroppe-Mass_Univariate_ERP_Toolbox-d1e60d4, now are in external folder
% 06/21/2023

% NH < HL
[pval2, t_orig2, ~, est_alpha2] = clust_perm2_rui3(data_NH, data_HL, chan_hood, 5000, .05,-1, .05, 2); 

% figure('units','normalized','outerposition',[0 0 1 1])
for m = 1:nband
    index1(:, m) = logical(pval1(:,m)<est_alpha1(m));
    t_orig_sig1(:,m) = t_orig1(:,m).*index1(:,m);
    index2(:, m) = logical(pval2(:,m)<est_alpha2(m));
    t_orig_sig2(:,m) = t_orig2(:,m).*index2(:,m)*-1;

    subplot(4,nband,m+2*nband)
%     if any(t_orig_sig1(:,m))
        topoplot(t_orig_sig1(:,m),EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on'); % 
        caxis([-4 4]); h=colorbar('SouthOutside','FontSize',14);
        if m==1, h.Label.String = 'T values';end %title(bandNames{m}, 'FontSize',16)
%     else
%         topoplot(zeros(size(select_chan)),EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on');
        % suppress line 1230 5% caxis limit
%     end

%     if any(t_orig_sig2(:,m))
        subplot(4,nband,m+3*nband);
        topoplot(t_orig_sig2(:,m),EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on');
        caxis([-4 4]); h=colorbar('SouthOutside','FontSize',10, 'visible','off');
%     end
end
dim = [.062 .10 .2 .18]; str = {'NH>HL'};
annotation(gcf, 'textbox',dim,  'EdgeColor', 'none', ...
                'String',str,'FitBoxToText','on', 'FontSize', 20);
% dim = [.062 .1 .2 .18]; str = {'NH<HL'};
% annotation(gcf, 'textbox',dim,  'EdgeColor', 'none', ...
%                 'String',str,'FitBoxToText','on', 'FontSize', 16);

%% part 2: spectrum (exploratory, no-show in poster)
freq = all_results{1}.pow.spectro.freq;
spectrum = NaN(length(freq), size(data,3)); ID = NaN(size(data,3),1);
for i=1:length(all_results)
    filename = cellfun(@(x) strsplit(x, '_202'), all_results{i}.qi_table.eegid, 'UniformOutput', false); % nested cell array
    partial_filename = vertcat(filename{:});          % x2 plain cell array
    partial_ID = strsplit(partial_filename{1},{'D','_'});
    ID(i) = str2double(strsplit(partial_ID{2},'D'));
    spectrum(:,i) = mean(table2array(all_results{i}.pow.spectro(:,select_chan+259)),2); % mean-chan spectrum
end

%% group separation (spectrum)
index_NH = find(group==1);
spectrum_NH = spectrum(:,index_NH); % 107(freq)x22(subj)
index_HL = find(group==2);
spectrum_HL = spectrum(:,index_HL);

figure('units','normalized','outerposition',[0 0 0.2 0.35]);
subplot(121);plot(freq, log(spectrum_NH), 'color', [0, 0.4470, 0.7410, 0.3])
hold on;plot(freq, mean(log(spectrum_NH),2), 'color', 'r','linewidth',1.2);xlim([1 17]);ylim([-7 -1])
% a = get(gca,'XTickLabel'); set(gca,'XTickLabel',a,'fontsize',12)
ax=gca; ax.FontSize = 12
xlabel('Frequency (Hz)', 'FontSize',14);ylabel('Relative Spectrum (dB)', 'FontSize',14);title(['NH (n=',num2str(n_NH),')'], 'FontSize',16)
subplot(122);plot(freq, log(spectrum_HL), 'color', [0, 0.4470, 0.7410, 0.3])
hold on;plot(freq, mean(log(spectrum_HL),2), 'color', 'r','linewidth',1.2);xlim([1 17]);ylim([-7 -1])
% b = get(gca,'XTickLabel'); set(gca,'XTickLabel',b,'fontsize',12)
bx=gca; bx.FontSize = 12
xlabel('Frequency (Hz)', 'FontSize',14);ylabel('Relative Spectrum (dB)', 'FontSize',14);title(['HL (n=',num2str(n_HL),')'], 'FontSize',16)

%% variability difference from above figure
% 2-sample test for variances (homogeneity) 
freqband = find(freq(freq>6.5 & freq<11)); 
[h, p] = vartest2(mean(spectrum_NH(freqband,:),1), mean(spectrum_HL(freqband,:),1), 'Tail', 'right'); 
% infant alpha band (6.5-11 Hz), p=0.0169
p = vartestn([[mean(spectrum_NH(freqband,:),1)'; NaN; NaN], mean(spectrum_HL(freqband,:),1)'], 'TestType', 'LeveneQuadratic') 
% p=0.145

[h, p] = vartest2(spectrum_NH(find(freq==14),:), spectrum_HL(find(freq==14),:), 'Tail', 'right') % F-test
p = vartestn([[spectrum_NH(find(freq==14),:)'; NaN; NaN], spectrum_HL(find(freq==14),:)'], 'TestType', 'LeveneQuadratic') 
%           F-test (normal)   Levene test (nonnormal)
% 8Hz       p=0.0191            x
% 8.5Hz     p=0.0057            x
% 9Hz       p=0.0021            p=0.0598
% 9.5Hz     p=0.0098            x
% 10Hz      p=0.0100            x
% 10.5Hz    p=0.0296            x
% 11Hz      p=0.0204            p=0.0847
% 11.5Hz    p=0.0042            p=0.0627
% 12Hz      p=0.0031            p=0.0687
% 12.5Hz    p=0.0069            p=0.0434
% 13Hz      p=0.0101            p=0.0316























