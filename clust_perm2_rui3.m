function [pval,t_orig,seed_state,est_alpha] = clust_perm2_rui3...
    (dataA, dataB, chan_hood, n_perm, fwer, tail, thresh_p, verblevel)
% clust_perm2_rui3 - two sample unpaired cluster-based permutation test for
% one-sided comparison 
% modified from clust_perm2.m from dmgroppe-Mass_Univariate_ERP_Toolbox, 
% motivation:
% divide all_t & t_orig grid into columns of frequency band 
% each apply individual clust-based permutation
% add cluster-wise fwer via strict Bonferroni for bands
% Output variable 'clust_info' is excluded
% last visit 06/21/2023

% Required Inputs:
%  dataA      - EEG feature matrix (Channel x Band x Participant)
%  dataB      - EEG feature matrix (Channel x Band x Participant)
%  chan_hood - 2D symmetric binary matrix specifying neighboring channels. E.g., if
%              chan_hood(2,10)=1, then Channel 2 and Channel 10 are
%              nieghbors. You can produce a chan_hood matrix using the
%              function spatial_neighbors.m.
%
% Optional Inputs:
%  n_perm          - Number of permutations {default=2000}.  Manly (1997) suggests
%                    using at least 1000 permutations for an alpha level of 0.05 and
%                    at least 5000 permutations for an alpha level of 0.01.
%  fwer            - Within-band cluster-level alpha threshold {default=.05}
%  tail            - Contrast direction: upper tailed test (1) or lower tailed test (-1).
%  thresh_p        - The channel-wise p-value threshold for cluster inclusion. When
%                    a channel has a raw p-value > thresh_p, it is assigned
%                    a p-value of 1 and its T value is not considered for clustering. 
%  verblevel       - An integer specifiying the amount of information you want
%                    this function to provide about what it is doing during runtime.
%                     Options are:
%                      0 - quiet, only show errors, warnings, and EEGLAB reports
%                      1 - stuff anyone should probably know
%                      2 - stuff you should know the first time you start working
%                          with a data set {default value}
%                      3 - stuff that might help you debug (show all reports)

% Outputs:
%  pval       - final corrected p-value at each electrode (preset 1's)
%  t_orig     - t-score at each electrode
%  seed_state - The random seed for generating the permutations. 
%               backup for reproducibility.
%  est_alpha  - New family-wise alpha threshold, post cluster-level correction & 
%               Bonferroni cross-band correction.

% Foundations of this test: 1) "exchangeable" subjects between the 2 groups
% (permutation), 2) cluster formation

if nargin<2
    error('You need to provide data for two groups of subjects.');
end

if nargin<3
    error('You need to provide a chan_hood matrix.');
end

if nargin<4
    n_perm=2000;
end

if nargin<5
    fwer=.05;
elseif (fwer>=1) || (fwer<=0)
    error('Argument ''fwer'' needs to be between 0 and 1.');
end

if fwer<=.01 && n_perm<5000
    watchit(sprintf('You are probably using too few permutations for an alpha level of %f. Type ">>help clust_perm2_rui3" for more info.',fwer));
elseif fwer<=.05 && n_perm<1000
    watchit(sprintf('You are probably using too few permutations for an alpha level of %f. Type ">>help clust_perm2_rui3" for more info.',fwer));
end

if nargin<6
    tail=1;fprintf('One-sided test, default contrast: Group A is greater than Group B.\n');
elseif (tail~=1) && (tail~=-1)
    error('Argument ''tail'' needs to be 1 or -1.');
end

if nargin<7
    thresh_p=.05;
elseif thresh_p<=0 || thresh_p>1
    error('Argument thresh_p needs to take a value between 0 and 1');
end

if nargin<8
    verblevel=2;
end

%get random # generator state
if verLessThan('matlab','9.4')
    error('Older versions of MATLAB (prior to R2018a) have not been tested.');
else
    defaultStream=RandStream.getGlobalStream;
    %Store state of random number generator
    seed_state=defaultStream.State;
end

if length(size(dataA))~=3 || length(size(dataB))~=3 
    error('dataA and dataB need to be three dimensional (chan x band x participant)')
end
[n_chan, n_band, n_subsA]=size(dataA);
[n_chan2, n_band2, n_subsB]=size(dataB);

if verblevel
    warning('off','all'); %for large # of subjects, nchoosek warns that its result is approximate
    n_psbl_prms=nchoosek(n_subsA+n_subsB,n_subsA);
    if n_psbl_prms<100
        watchit(sprintf(['Due to the very limited number of participants in each group,' ...
            ' the total number of possible permutations is small.\nThus only a limited number of p-values (at most %d) are possible and the test might be overly conservative.'], ...
            n_psbl_prms));
    end
    warning('on','all');
end

if n_chan~=n_chan2
    error('The number of channels in Group A (dataA) and Group B (dataB) need to be equal.');
elseif n_band~=n_band2
    error('The number of frequency bands in Group A (dataA) and Group B (dataB) need to be equal.');
end
%combine data
total_subs=n_subsA+n_subsB;
data=dataA; 
data(:,:,(n_subsA+1):total_subs)=dataB;

if verblevel~=0
    fprintf('2-sample number of channels: %d\n',n_chan);
%     if freq_domain
        fprintf('2-sample number of bands: %d\n',n_band);
%     else
%         fprintf('clust_perm2: Number of time points: %d\n',n_band);
%     end
    fprintf('Total # of comparisons: %d\n',n_chan*n_band);
    fprintf('Number of participants in Group A: %d\n',n_subsA);
    fprintf('Number of participants in Group B: %d\n',n_subsB);
    fprintf('t-score degrees of freedom: %d\n',total_subs-2);
end
VerbReport(sprintf('Executing permutation test with %d permutations...',n_perm),2,verblevel);
if (verblevel>=2)
    fprintf('Permutations completed: ');
end

% Factors that are used to compute t-scores.  Saves time to compute them
% now rather than to compute them anew for each permutation.
df=n_subsA+n_subsB-2;
mult_fact=(n_subsA+n_subsB)/(n_subsA*n_subsB);
thresh_t=tinv(thresh_p,df); % lookup T table, thresh_t<0 as thresh_p<0.5
mx_clust_mass=zeros(n_band,n_perm);


for perm=1:n_perm
    if ~rem(perm,100)
        if (verblevel>=2)
            if ~rem(perm-100,1000)
                fprintf('%d',perm);
            else
                fprintf(', %d',perm);
            end
            if ~rem(perm,1000)
                fprintf('\n');
            end
        end
    end
    %randomly assign participants to conditions
    r=randperm(total_subs);
    grp1=r(1:n_subsA);
    grp2=r((n_subsA+1):total_subs);

    %compute t-scores
    all_t=tmax2(data,grp1,grp2,n_subsA,n_subsB,df,mult_fact);
    
    %form t-scores into SPATIAL clusters:
    for bandi = 1:n_band
        if tail==1
            %upper tailed test
            [clust_ids, n_clust]=find_clusters(all_t(:,bandi),-thresh_t,chan_hood,1); %note, thresh_t should be negative by default
            % utility function find_clusters was designed to work on 2-D input, is
            % employed per electrode dimension/column only, i.e. clusters define 
            % neighboring electrodes within each band
            mx_clust_mass(bandi,perm)=find_mx_mass(clust_ids,all_t,n_clust,1);
        elseif tail==-1
            %lower tailed test
            [clust_ids, n_clust]=find_clusters(all_t(:,bandi),thresh_t,chan_hood,-1); %note, thresh_t should be negative by default
            mx_clust_mass(bandi,perm)=find_mx_mass(clust_ids,all_t,n_clust,-1);
        else
            error('One-sided test for clinical application & statistical power');
        end
    end
end

%End of permutations, print carriage return if it hasn't already been done
%(i.e., perm is NOT a multiple of 1000)
if (verblevel>=2) && rem(perm,1000)
    fprintf('\n');
end

%Compute critical t's for each band & corrected by Bonferroni
% to estimate permutation alpha
est_alpha = zeros(1,n_band);
for bandi = 1:n_band
    if tail==1
        % upper tailed
        tmx_ptile=prctile(mx_clust_mass(bandi,:),100-100*fwer/n_band); % add Bonferroni
        % returns threshold in sample range
        % hist(mx_clust_mass(bandi,:),100)
        est_alpha(bandi)=mean(mx_clust_mass(bandi,:)>=tmx_ptile); 
        % empirical Prob.
        % acquire new alpha threshold through monte carlo
    elseif tail==-1
        % lower tailed
        tmx_ptile=prctile(mx_clust_mass(bandi,:),fwer*100/n_band);
        est_alpha(bandi)=mean(mx_clust_mass(bandi,:)<=tmx_ptile);
    end
end

if verblevel~=0
    fprintf('Desired family-wise error rate within band: %f\n',fwer);
    fprintf('FWER post band-wise Bonferroni correction: %f\n',est_alpha);
end

%Compute t-scores of ACTUAL observations
t_orig=tmax2(data,1:n_subsA,(n_subsA+1):total_subs,n_subsA,n_subsB,df,mult_fact);
%compute p-values
pval=ones(n_chan,n_band);
for bandi = 1:n_band
    if tail==1
        % positive clusters
        [clust_ids, n_clust]=find_clusters(t_orig(:,bandi),-thresh_t,chan_hood,1); %note thresh_t is negative by default
        for a=1:n_clust
            use_ids=find(clust_ids==a);
            clust_mass=sum(t_orig(use_ids,bandi)); % bias to larger cluster
            clust_p=mean(mx_clust_mass(bandi,:)>=clust_mass); % deciding whether real data cluster is outstanding
            pval(use_ids,bandi)=clust_p; % significant cluster assignment back to electrodes
        end
    elseif tail==-1
        % negative clusters
        [clust_ids, n_clust]=find_clusters(t_orig(:,bandi),thresh_t,chan_hood,-1); %note thresh_t is negative by default
        for a=1:n_clust
            use_ids=find(clust_ids==a);
            clust_mass=sum(t_orig(use_ids,bandi));
            clust_p=mean(mx_clust_mass(bandi,:)<=clust_mass);
            pval(use_ids,bandi)=clust_p;
        end
    end
end

%%% End of Main Function %%%


function mx_clust_mass=find_mx_mass(clust_ids,data_t,n_clust,tail)

mx_clust_mass=0;
if tail<0
    %looking for most negative cluster mass
    for z=1:n_clust
        use_ids=(clust_ids==z);
        use_mass=sum(data_t(use_ids));
        if use_mass<mx_clust_mass
            mx_clust_mass=use_mass;
        end
    end
elseif tail>0
    %looking for most positive cluster mass
    for z=1:n_clust
        use_ids=(clust_ids==z);
        use_mass=sum(data_t(use_ids));
        if use_mass>mx_clust_mass
            mx_clust_mass=use_mass;
        end
    end
end


function all_t=tmax2(dat,grp1,grp2,n_subsA,n_subsB,df,mult_fact)
% might make this faster by moving it into the code

x1=dat(:,:,grp1); %32*6*29
x2=dat(:,:,grp2);

sm1=sum(x1,3);
mn1=sm1/n_subsA; %32*6 mean
ss1=sum(x1.^2,3)-(sm1.^2)/n_subsA;

sm2=sum(x2,3);
mn2=sm2/n_subsB;
ss2=sum(x2.^2,3)-(sm2.^2)/n_subsB;

pooled_var=(ss1+ss2)/df;
stder=sqrt(pooled_var*mult_fact);

all_t=(mn1-mn2)./stder;