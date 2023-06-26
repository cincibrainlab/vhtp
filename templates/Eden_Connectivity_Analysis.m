%% input from processing (10/25 before ID list update)
% Variable label: input_filelist (check processing order + select file)
% Variable data: all_results (match with input_filelist)
% Table (ID) + group (external from Chelsea)
% Variable EEG.chanlocs (utility)
% EEG = pop_loadset('D1005_RestingState_Run2_20210629_125121_postcomp.set', 'C:\data\14_Eden-resting_test\latest_0527\SfN dataset');

% filename = cellfun(@(x) strsplit(x, '_202'),
% input_filelist.filename([1:3,5,9:48,50:51]), 'UniformOutput', false); %
% 46x11 nested cell array ?
filename = cellfun(@(x) strsplit(x, '_202'), input_filelist.filename, 'UniformOutput', false); % 46x11 nested cell array
partial = vertcat(filename{:});          % 46x2 plain cell array
label = partial(:,1)'; % to match with SID*
T = readtable("C:\data\14_Eden-resting_test\latest_0527\SfN dataset\IDs to Include and Hearing Variable.xlsx");
SID = T.SID;
group = T.HearingGroup_1_NH_2_HL_;
clear T
% input = all_results([1:3,5,9:48,50:51]); % 1x46 cell array
input = all_results; % 1x46 cell array
clear data
for i=1:length(label)
    partial1 = split(label{i},{'D','_'});
    ID(i) = str2double(partial1{2});     % vector
    data(:,:,:,i) = input{i}.ruioutput.fdwpli; % 124(chan)x124x26(f)xsubj(i) mat
end

% load EEG.chanlocs
% Output: ID, data_NH, data_HL, no group (line 31)
%% parameters
frex = 2:0.5:14.5;
nfreq = length(frex);
exclusion_chan = [17 48:49 73 81 88 113 119 125:128]; % Orekhova 2014
select_chan = setdiff(1:128, exclusion_chan); 

%% group separation
index_NH = find(group==1);
data_NH = data(select_chan,select_chan,1:26,index_NH); % 116x116x26x22
ID_NH =  ID(index_NH);
index_HL = find(group==2);
data_HL = data(select_chan,select_chan,1:26,index_HL);
ID_HL =  ID(index_HL);

degree_NH = squeeze(mean(data_NH,1)); % 116x26(f)x22(subj)
global_degree_NH = squeeze(mean(degree_NH,1)); % 26x22(subj)

degree_HL = squeeze(mean(data_HL,1)); % 116x26(f)x24(subj)
global_degree_HL = squeeze(mean(degree_HL,1)); % 26x24(subj)

%% intuition on global_degree
figure;subplot(121);imagesc(1:22,frex,global_degree_NH);caxis([0.06 0.44])
colorbar;xlabel('subject');ylabel('frequency');title('NH')
subplot(122);imagesc(1:24,frex,global_degree_HL);caxis([0.06 0.44])
colorbar;xlabel('subject');ylabel('frequency');title('HL')

%% Figure 1A - global degree
figure;subplot(121);%plot(frex,mean(global_degree_NH,2),'k');
hold on;SEM = std(global_degree_NH,0,2)/sqrt(nfreq);
p1=errorbar(frex,mean(global_degree_NH,2),SEM,'k');
p2=errorbar(frex,mean(global_degree_NH,2),SEM,'k');ylim([.1 0.3])
p3=plot(frex,median(global_degree_NH,2),'r');
fill([7.5 10 10 7.5], [.1 .1 .3 .3],'cyan','FaceAlpha',0.2,'EdgeColor','none')
legend([p1,p3], {'mean and SEM','median'})
xlabel('Frequency (Hz)');ylabel('Global dWPLI');title('NH')
subplot(122);%plot(frex,mean(global_degree_HL,2),'k');
hold on;SEM = std(global_degree_HL,0,2)/sqrt(nfreq);
errorbar(frex,mean(global_degree_HL,2),SEM,'k');
errorbar(frex,mean(global_degree_HL,2),SEM,'k');ylim([.1 0.3])
plot(frex,median(global_degree_HL,2),'r');
fill([7.5 10 10 7.5], [.1 .1 .3 .3],'cyan','FaceAlpha',0.2,'EdgeColor','none')
xlabel('Frequency (Hz)');ylabel('Global dWPLI');title('HL')

%% pass global_degree_xx to Chelsea in table 10/31
value = [global_degree_NH(:);global_degree_HL(:)];
EEGID = [repelem(ID_NH, nfreq)';repelem(ID_HL, nfreq)'];
freq = repmat(frex', length(ID_NH)+length(ID_HL), 1);
T = table(EEGID,freq,value);
% writetable(T,'...\global_degree.csv')

%% Figure 1B - degree/ group aggregation
figure;subplot(121);
topoplot(squeeze(mean(degree_NH(:,find(frex==8):find(frex==10),:),[2 3])),...
    EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on');
caxis([0.2 0.25]);
h=colorbar('SouthOutside','FontSize',12);
h.Label.String = 'Averaged dWPLI';title('NH','FontSize',14)
subplot(122);
topoplot(squeeze(mean(degree_HL(:,find(frex==8):find(frex==10),:),[2 3])),...
    EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on');
caxis([0.2 0.25]);
h=colorbar('SouthOutside','FontSize',12);
h.Label.String = 'Averaged dWPLI';title('HL','FontSize',14)
sgtitle('Alpha1 Band (8-10 Hz)','FontSize',14)

%% cluster based permutation on degree centrality; below tested on alpha 8-12 Hz, NO OUTPUT
load('chanfiles\128-chan_hood.mat')
chan_hood = chan_hood(select_chan,select_chan);
% NH > HL
[pval1, t_orig1, ~, est_alpha1] = clust_perm2_rui3(mean(degree_NH(:,find(frex==8):find(frex==10),:),2), ...
    mean(degree_HL(:,find(frex==8):find(frex==10),:),2), chan_hood, 5000, .05, 1, .05, 1); 
% NH < HL
[pval2, t_orig2, ~, est_alpha2] = clust_perm2_rui3(mean(degree_NH(:,find(frex==8):find(frex==10),:),2), ...
    mean(degree_HL(:,find(frex==8):find(frex==10),:),2), chan_hood, 5000, .05,-1, .05, 1); 

nband = 1;
% figure('units','normalized','outerposition',[0 0 1 1])
for m = 1:nband
    index1(:, m) = logical(pval1(:,m)<est_alpha1(m));
    t_orig_sig1(:,m) = t_orig1(:,m).*index1(:,m);
    index2(:, m) = logical(pval2(:,m)<est_alpha2(m));
    t_orig_sig2(:,m) = t_orig2(:,m).*index2(:,m)*-1;

    subplot(2,nband,m)
%     if any(t_orig_sig1(:,m))
        topoplot(t_orig_sig1(:,m),EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on');
        caxis([-4 4]); h=colorbar('SouthOutside','FontSize',14);
        if m==1, h.Label.String = 'T values';end %title(bandNames{m}, 'FontSize',16)
%     else
%         topoplot(zeros(size(select_chan)),EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on');
        % suppress line 1230 5% caxis limit
%     end

%     if any(t_orig_sig2(:,m))
        subplot(2,nband,m+nband);
        topoplot(t_orig_sig2(:,m),EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on');
        caxis([-4 4]); h=colorbar('SouthOutside','FontSize',14, 'visible','on');
%     end
end
% dim = [.062 .10 .2 .18]; str = {'NH>HL'};
% annotation(gcf, 'textbox',dim,  'EdgeColor', 'none', ...
%                 'String',str,'FitBoxToText','on', 'FontSize', 20);
% dim = [.062 .1 .2 .18]; str = {'NH<HL'};
% annotation(gcf, 'textbox',dim,  'EdgeColor', 'none', ...
%                 'String',str,'FitBoxToText','on', 'FontSize', 16);

%% detect connected structure from connectivity network
% Dual of cluter-based permutation test, define neighboring connections instead of neighboring nodes 
% implementation in NBS1.2; NO OUTPUT from poster data (n=46)
% below tested alpha band 8-10 Hz (see line 154 configuration)

% Parameter 0: group selection
grp1 = size(data_NH, 4);
grp2 = size(data_HL, 4);

cum_dbwpli_band_com = cat(4, data_NH, data_HL); % 116x116x26(f)x46(22+24)
% GLM-structure to use NBSstats
g = grp1+grp2;
nbchan = size(cum_dbwpli_band_com,1);

% 2-sample model1
GLM.X = [ones(1,grp1) zeros(1,grp2);zeros(1,grp1) ones(1,grp2)]';
GLM.contrast = [1 -1]; % 2-sample model1
GLM.y = NaN(g, nbchan*(nbchan-1)/2);
for i=1:g
    data1 = squeeze(mean(cum_dbwpli_band_com(:,:,find(frex==8):find(frex==10),i),3)); % parameter 1: frequency
    mask = triu(true(size(data1)), 1);
    GLM.y(i,:) = data1(mask); 
end
GLM.test = 'ttest';
GLM.perms = 5000;

% STATS-structure to use NBSstats
STATS.alpha = .15; % .05, cannot pass the permutation
% STATS.thresh = -tinv(STATS.alpha,g-2); % parameter 2: univariate testing threshold
STATS.thresh = 3; % 3.1
STATS.size = 'intensity'; % 'extent'
STATS.N = nbchan;
STATS.test_stat = [];
[n, conn, p] = NBSstats(STATS, -1, GLM)


[alpha_i,alpha_j] = find(conn{1});
alpha = unique([alpha_i,alpha_j]); % for plot
alpha_connections = cell(length(alpha_i),1); % for csv
for k=1:length(alpha_i)
    alpha_connections{k} = ['E',num2str(alpha_i(k)),...
                            '_E',num2str(alpha_j(k))];
end
plotchans3d_mod([[EEG.chanlocs.X]',[EEG.chanlocs.Y]', [EEG.chanlocs.Z]'], ...
    {EEG.chanlocs.labels}, alpha, [alpha_i alpha_j])
title({'Alpha band NH > HL'},{['T thresh=', num2str(STATS.thresh), ...
    ', cluster \alpha=', num2str(STATS.alpha), ' sub-network']})

%% alpha band 8-10 Hz panel by pair
pair = [40 23; 40 99; 40 102; 40 106; 102 36; 102 38; 102 40; 106 40; 106 79; 106 92];
 
alpha_NH = squeeze(mean(data_NH(:,:,find(frex==8):find(frex==10),:),3));
alpha_HL = squeeze(mean(data_HL(:,:,find(frex==8):find(frex==10),:),3));

figure('units','normalized','outerposition',[0 0 1 1])
clear x y
x = squeeze(alpha_NH(pair(1,1),pair(1,2),:)); y = squeeze(alpha_HL(pair(1,1),pair(1,2),:));
[~, p] = ttest2(x, y, 'tail', 'right'); % equal var (default)
xy_label = reordercats(categorical(cellstr([repmat('NH',grp1,1); repmat('HL',grp2,1)])), {'NH','HL'});
subplot(3,4,1);boxchart(xy_label, [x; y]); hold on
swarmchart(xy_label, [x; y]);
if p<.001
    title(['E',num2str(pair(1,1)),'-E',num2str(pair(1,2)),'  P-value<.001']);
else
    title(['E',num2str(pair(1,1)),'-E',num2str(pair(1,2)),'  P-value=',num2str(round(p,3))]);
end
% (2)
clear x y
x = squeeze(alpha_NH(pair(2,1),pair(2,2),:)); y = squeeze(alpha_HL(pair(2,1),pair(2,2),:));
[~, p] = ttest2(x, y, 'tail', 'right'); % equal var (default)
xy_label = reordercats(categorical(cellstr([repmat('NH',grp1,1); repmat('HL',grp2,1)])), {'NH','HL'});
subplot(3,4,2);boxchart(xy_label, [x; y]); hold on
swarmchart(xy_label, [x; y]);
if p<.001
    title(['E',num2str(pair(1,1)),'-E',num2str(pair(1,2)),'  P-value<.001']);
else
    title(['E',num2str(pair(1,1)),'-E',num2str(pair(1,2)),'  P-value=',num2str(round(p,3))]);
end
% (3)
clear x y
x = squeeze(alpha_NH(pair(3,1),pair(3,2),:)); y = squeeze(alpha_HL(pair(3,1),pair(3,2),:));
[~, p] = ttest2(x, y, 'tail', 'right'); % equal var (default)
xy_label = reordercats(categorical(cellstr([repmat('NH',grp1,1); repmat('HL',grp2,1)])), {'NH','HL'});
subplot(3,4,3);boxchart(xy_label, [x; y]); hold on
swarmchart(xy_label, [x; y]);
if p<.001
    title(['E',num2str(pair(1,1)),'-E',num2str(pair(1,2)),'  P-value<.001']);
else
    title(['E',num2str(pair(1,1)),'-E',num2str(pair(1,2)),'  P-value=',num2str(round(p,3))]);
end
% (4)
clear x y
x = squeeze(alpha_NH(pair(4,1),pair(4,2),:)); y = squeeze(alpha_HL(pair(4,1),pair(4,2),:));
[~, p] = ttest2(x, y, 'tail', 'right'); % equal var (default)
xy_label = reordercats(categorical(cellstr([repmat('NH',grp1,1); repmat('HL',grp2,1)])), {'NH','HL'});
subplot(3,4,4);boxchart(xy_label, [x; y]); hold on
swarmchart(xy_label, [x; y]);
if p<.001
    title(['E',num2str(pair(4,1)),'-E',num2str(pair(4,2)),'  P-value<.001']);
else
    title(['E',num2str(pair(4,1)),'-E',num2str(pair(4,2)),'  P-value=',num2str(round(p,3))]);
end

% (5)
clear x y
x = squeeze(alpha_NH(pair(5,1),pair(5,2),:)); y = squeeze(alpha_HL(pair(5,1),pair(5,2),:));
[~, p] = ttest2(x, y, 'tail', 'right'); % equal var (default)
xy_label = reordercats(categorical(cellstr([repmat('NH',grp1,1); repmat('HL',grp2,1)])), {'NH','HL'});
subplot(3,4,5);boxchart(xy_label, [x; y]); hold on
swarmchart(xy_label, [x; y]);
if p<.001
    title(['E',num2str(pair(5,1)),'-E',num2str(pair(5,2)),'  P-value<.001']);
else
    title(['E',num2str(pair(5,1)),'-E',num2str(pair(5,2)),'  P-value=',num2str(round(p,3))]);
end
% (6)
clear x y
x = squeeze(alpha_NH(pair(6,1),pair(6,2),:)); y = squeeze(alpha_HL(pair(6,1),pair(6,2),:));
[~, p] = ttest2(x, y, 'tail', 'right'); % equal var (default)
xy_label = reordercats(categorical(cellstr([repmat('NH',grp1,1); repmat('HL',grp2,1)])), {'NH','HL'});
subplot(3,4,6);boxchart(xy_label, [x; y]); hold on
swarmchart(xy_label, [x; y]);
if p<.001
    title(['E',num2str(pair(6,1)),'-E',num2str(pair(6,2)),'  P-value<.001']);
else
    title(['E',num2str(pair(6,1)),'-E',num2str(pair(6,2)),'  P-value=',num2str(round(p,3))]);
end
% (7)
clear x y
x = squeeze(alpha_NH(pair(7,1),pair(7,2),:)); y = squeeze(alpha_HL(pair(7,1),pair(7,2),:));
[~, p] = ttest2(x, y, 'tail', 'right'); % equal var (default)
xy_label = reordercats(categorical(cellstr([repmat('NH',grp1,1); repmat('HL',grp2,1)])), {'NH','HL'});
subplot(3,4,7);boxchart(xy_label, [x; y]); hold on
swarmchart(xy_label, [x; y]);
if p<.001
    title(['E',num2str(pair(7,1)),'-E',num2str(pair(7,2)),'  P-value<.001']);
else
    title(['E',num2str(pair(7,1)),'-E',num2str(pair(7,2)),'  P-value=',num2str(round(p,3))]);
end

% (8)
clear x y
x = squeeze(alpha_NH(pair(8,1),pair(8,2),:)); y = squeeze(alpha_HL(pair(8,1),pair(8,2),:));
[~, p] = ttest2(x, y, 'tail', 'right'); % equal var (default)
xy_label = reordercats(categorical(cellstr([repmat('NH',grp1,1); repmat('HL',grp2,1)])), {'NH','HL'});
subplot(3,4,9);boxchart(xy_label, [x; y]); hold on
swarmchart(xy_label, [x; y]);
if p<.001
    title(['E',num2str(pair(8,1)),'-E',num2str(pair(8,2)),'  P-value<.001']);
else
    title(['E',num2str(pair(8,1)),'-E',num2str(pair(8,2)),'  P-value=',num2str(round(p,3))]);
end
% (9)
clear x y
x = squeeze(alpha_NH(pair(9,1),pair(9,2),:)); y = squeeze(alpha_HL(pair(9,1),pair(9,2),:));
[~, p] = ttest2(x, y, 'tail', 'right'); % equal var (default)
xy_label = reordercats(categorical(cellstr([repmat('NH',grp1,1); repmat('HL',grp2,1)])), {'NH','HL'});
subplot(3,4,10);boxchart(xy_label, [x; y]); hold on
swarmchart(xy_label, [x; y]);
if p<.001
    title(['E',num2str(pair(9,1)),'-E',num2str(pair(9,2)),'  P-value<.001']);
else
    title(['E',num2str(pair(9,1)),'-E',num2str(pair(9,2)),'  P-value=',num2str(round(p,3))]);
end
% (10)
clear x y
x = squeeze(alpha_NH(pair(10,1),pair(10,2),:)); y = squeeze(alpha_HL(pair(10,1),pair(10,2),:));
[~, p] = ttest2(x, y, 'tail', 'right'); % equal var (default)
xy_label = reordercats(categorical(cellstr([repmat('NH',grp1,1); repmat('HL',grp2,1)])), {'NH','HL'});
subplot(3,4,11);boxchart(xy_label, [x; y]); hold on
swarmchart(xy_label, [x; y]);
if p<.001
    title(['E',num2str(pair(10,1)),'-E',num2str(pair(10,2)),'  P-value<.001']);
else
    title(['E',num2str(pair(10,1)),'-E',num2str(pair(10,2)),'  P-value=',num2str(round(p,3))]);
end
sgtitle('dWPLI')


%% initial degree topoplots
% band = [2 3; 3.5 6; 6.5 10; 10.5 12; 12.5 14.5];
% nband = size(band, 1);
% for i=1:nband
%     for j=1:2
%         band_index(i,j) = find(frex==band(i,j));
%     end
% end

for subi = 1:length(label)
%     figure;
%     for fi = 1:nfreq
%         dwpli_temp = data{subi}.ruioutput.fdwpli(:,:,fi);
%         subplot(4,7,fi);plot(mean(dwpli_temp));axis tight
%         title([num2str(frex(fi)),'Hz'])
%     end
%     sgtitle(strjoin(string(strsplit(label{subi},'_'))))

%     figure('units','normalized','outerposition',[0 0 1 1])
%     for fi = 1:nfreq
%         dwpli_temp = data{subi}.ruioutput.fdwpli(:,:,fi);
%         subplot(4,7,fi);topoplot(mean(dwpli_temp),EEG.chanlocs(select_chan),'electrodes','on','headrad',.5);
%         caxis([0 .5]);h=colorbar('EastOutside');
%         title([num2str(frex(fi)),'Hz'])
%     end
%     sgtitle(strjoin(["dWPLI:", string(strsplit(label{subi},'_'))]))
%     saveas(gca,...
%         ['C:\data\14_Eden-resting_test\latest_0527\vhtp-main_results\1024_connectivity\connectivity_topo\degree_topo_',...
%         label{subi},'_individual_freq.png']);close

    figure('units','normalized','outerposition',[0 0 1 1])
    for fi = 1:nfreq
        wpli_temp = data{subi}.ruioutput.fwpli(:,:,fi);
        subplot(4,7,fi);topoplot(mean(wpli_temp),EEG.chanlocs(select_chan),'electrodes','on','headrad',.5,'conv','on');
        caxis([0 .9]);h=colorbar('EastOutside');
        title([num2str(frex(fi)),'Hz'])
    end
    sgtitle(strjoin(["WPLI:", string(strsplit(label{subi},'_'))]))
    saveas(gca,...
        ['C:\data\14_Eden-resting_test\latest_0527\vhtp-main_results\1024_connectivity\connectivity_topo\comparison\wpli_',...
        label{subi},'_individual_freq.png']);close

%     figure('Renderer', 'painters', 'Position', [10 10 800 500])
%     for bandi = 1:nband
%         dwpli_temp = data{subi}.ruioutput.fdwpli(:,:,band_index(bandi,1):band_index(bandi,2));
%         subplot(2,3,bandi);topoplot(mean(dwpli_temp,[1 3]),EEG.chanlocs(select_chan),'electrodes','on','headrad',.5);
%         caxis([0 .5]);h=colorbar('EastOutside');
%         title([num2str(band(bandi,1)),'-',num2str(band(bandi,2)),'Hz'])
%     end
%     sgtitle(strjoin(["dWPLI:", string(strsplit(label{subi},'_'))]))
%     saveas(gca,...
%         ['C:\data\14_Eden-resting_test\latest_0527\vhtp-main_results\1024_connectivity\connectivity_topo\degree_topo_band',...
%         label{subi},'.png']);close

end