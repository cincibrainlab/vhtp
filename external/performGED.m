function [ evals, evecs, evecs_rel, covS, covRr, evecs_unnormed ] = ...
    performGED( MEEG, covS_window, covR_window, kernel )
%PERFORMGED Performs generalized eigendecomposition on filtered vs.
%broadband data.
%   PERFORMGED filters the supplied data, constructs a "signal"
%   covariance matrix S from the filtered data and a "noise" covariance
%   matrix R from the unfiltered broadband data, and applies a GED to find
%   components that maximize the energy ratio between S and R.
%
%   FUNCTION INPUTS
%       MEEG            The data matrix; sensors x timepoints x trials
%       covS_window     Time window (1x2) to use for constructing S, in ms
%       covR_window     Time window (1x2) to use for constructing R, in ms
%       kernel          Filter kernel to use to filter the data
%
%   FUNCTION OUTPUTS
%       evals           Array of eigenvalues
%       evecs           Matrix of eigenvectors, scaled to unit length
%       evecs_rel       Matrix of eigenvectors, scaled to relative eigenvalue
%       covS            Covariance matrix S (filtered data)
%       covRr           Covariance matrix R (broadband data), 1% regularized
%       evecs_unnormed  Matrix of eigenvectors, not scaled to unit length

%% Filter data
disp('Filtering data...');
fft_len = size(MEEG.data,2)+length(kernel)-1; % number of time points/frequencies for fft to return
trim_len = (length(kernel)-1)/2; % number of time points to trim from start and end of result
fdata = 2*real( ifft( bsxfun(@times,fft(MEEG.data,fft_len,2),fft(kernel, fft_len)) ,[],2) );
fdata = reshape(fdata(:,trim_len+1:end-trim_len,:),size(MEEG.data,1), MEEG.pnts, MEEG.trials);

%% Convert time windows for GEDs from ms to timepoint index
tidx_S = dsearchn(MEEG.times(:),covS_window');
tidx_R = dsearchn(MEEG.times(:),covR_window');

%% Construct noise matrix R (broadband)

disp('Computing broadband covariance matrix...');
covR = zeros(MEEG.nbchan);

% Take average covariance matrix over all trials
for triali=1:MEEG.trials
    tmpd = squeeze(MEEG.data(:,tidx_R(1):tidx_R(2),triali)); %select time window per trial
    tmpd = zscore(tmpd); % normalize energy in S vs. R
    covR = covR + tmpd*tmpd' / MEEG.nbchan;
end
covR = covR ./ MEEG.trials;

% Regularization
g = 0.01;
covRr = (1-g)*covR + g*mean(eig(covR))*eye(MEEG.nbchan);

%% Construct signal matrix S (filtered)
disp('Computing filtered covariance matrix...');
covS = zeros(MEEG.nbchan);

% Take average covariance matrix over all trials
for triali=1:MEEG.trials
    tmpd = squeeze(fdata(:,tidx_S(1):tidx_S(2),triali)); %select time window per trial
    tmpd = zscore(tmpd); % normalize energy in S vs. R
    covS = covS + tmpd*tmpd' / MEEG.nbchan;
end
covS = covS ./ MEEG.trials;

%% Perform GED on filtered vs. broadband covariance matrices
[evecs, evals] = eig(covS, covRr);
[evals, sidx] = sort(diag(evals), 'descend');
evecs = evecs(:, sidx);

%% Normalize eigenvectors to unit length
% Also create variable containing eigenvectors normalized to the relative
% eigenvalue. This is later used to scale the component time series, to
% facilitate power and amplitude comparisons between components and
% between subjects.

evecs_unnormed = evecs;
evecs_rel = zeros(size(evecs));
for v = 1:size(evecs,2)
    evecs(:,v) = evecs(:,v)/norm(evecs(:,v)); % normalize to unit length
    rel_eval = evals(v)/sum(evals); % extract relative eigenvalue
    evecs_rel(:,v) = evecs(:,v) * rel_eval; % normalize to relative eigenvalue
end

end

