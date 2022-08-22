function results = eeg_htpCalcEulerPac(EEG)
% Description: Euler PAC w/ debiasing term from van Driel et al., 2015
% ShortTitle: Euler Phase Amplitude Coupling
% Category: Analysis
% Tags: Connectivity

ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
parse(ip, EEG);

try
    EEG.data = gpuArray(EEG.data);
catch
    fprintf('GPU arrays not available.');
end

frex = linspace(10,90,70);
thetafreq = 6;
dpac = zeros(EEG.nbchan,length(frex));

nperm     = 100;
cutpoints = randsample(10:EEG.pnts-10,nperm);
permpac   = zeros(1,nperm);

% takes a while for all electrodes, or just run POz
for chani=1:EEG.nbchan

    % filter for 6 Hz
    phase = angle(hilbert(filterFGx(EEG.data(chani,:),EEG.srate,thetafreq,5)));

    % filter over lots of higher frequencies
    for fi=1:length(frex)
        pow = abs(hilbert(filterFGx(EEG.data(chani,:),EEG.srate,frex(fi),6)));

        % zPACd
        obspac = abs(mean( pow.*( exp(1i*phase)-mean(exp(1i*phase)) ) ));
        parfor permi=1:nperm
            permpac(permi) = abs(mean( pow([cutpoints(permi):end 1:cutpoints(permi)-1]).*( exp(1i*phase)-mean(exp(1i*phase)) ) ));
        end

        dpac(chani,fi) = (obspac-mean(permpac))/std(permpac);
    end
end
results = dpac;
toc;
end

function [filtdat,empVals] = filterFGx(data,srate,f,fwhm,showplot)
% filterFGx   Narrow-band filter via frequency-domain Gaussian
%  [filtdat,empVals] = filterFGx(data,srate,f,fwhm,showplot)
%
%
%    INPUTS
%       data : 1 X time or chans X time
%      srate : sampling rate in Hz
%          f : peak frequency of filter
%       fhwm : standard deviation of filter,
%              defined as full-width at half-maximum in Hz
%   showplot : set to true to show the frequency-domain filter shape
%
%    OUTPUTS
%    filtdat : filtered data
%    empVals : the empirical frequency and FWHM
%
% Empirical frequency and FWHM depend on the sampling rate and the
% number of time points, and may thus be slightly different from
% the requested values.
%
% mikexcohen@gmail.com

%% input check

if size(data,1)>size(data,2)
    help filterFGx
    error('Check data size')
end

if (f-fwhm)<0
    %     help filterFGx
    %     error('increase frequency or decrease FWHM')
end

if nargin<4
    help filterFGx
    error('Not enough inputs')
end

if fwhm<=0
    error('FWHM must be greater than 0')
end

if nargin<5
    showplot=false;
end

%% compute and apply filter

% frequencies
hz = linspace(0,srate,length(data));

% create Gaussian
s  = fwhm*(2*pi-1)/(4*pi); % normalized width
x  = hz-f;                 % shifted frequencies
fx = exp(-.5*(x/s).^2);    % gaussian
fx = fx./max(fx);          % gain-normalized

%% filter

filtdat = 2*real( ifft( bsxfun(@times,fft(data,[],2),fx) ,[],2) );

%% compute empirical frequency and standard deviation

idx = dsearchn(hz',f);
empVals(1) = hz(idx);

% find values closest to .5 after MINUS before the peak
empVals(2) = hz(idx-1+dsearchn(fx(idx:end)',.5)) - hz(dsearchn(fx(1:idx)',.5));

%% inspect the Gaussian (turned off by default)

if showplot
    figure(10001),clf
    plot(hz,fx,'o-')
    hold on
    plot([hz(dsearchn(fx(1:idx)',.5)) hz(idx-1+dsearchn(fx(idx:end)',.5))],[fx(dsearchn(fx(1:idx)',.5)) fx(idx-1+dsearchn(fx(idx:end)',.5))],'k--')
    set(gca,'xlim',[max(f-10,0) f+10]);

    title([ 'Requested: ' num2str(f) ', ' num2str(fwhm) ' Hz; Empirical: ' num2str(empVals(1)) ', ' num2str(empVals(2)) ' Hz' ])
    xlabel('Frequency (Hz)'), ylabel('Amplitude gain')
end



end
%% done.