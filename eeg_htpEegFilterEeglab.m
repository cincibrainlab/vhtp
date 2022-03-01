function [EEG] = eeg_htpEegFilterEeglab(EEG,method,varargin)
%EEG_HTPEEGFILTEREEGLAB Summary of this function goes here
%   Detailed explanation goes here

defaultLoCutoff = 0.5;
defaultHiCutoff = 80;
defaultNotch = [55 65];
defaultFiltOrder   = 3300;
defaultRevFilt     = 0;
defaultPlotFreqz   = 0;
defaultMinPhase    = false;
defaultCleanlineBandwidth = 2;
defaultCleanlineChanList = [1:EEG.nbchan];
defaultCleanlineComputePower = 0;
defaultCleanlineLineFreqs = [60 120 180 240 300];
defaultCleanlineNormSpectrum=0;
defaultCleanlineP=0.01;
defaultCleanlinePad = 2;
defaultCleanlinePlotFigures=0;
defaultCleanlineScanForLines=1;
defaultCleanlineSigType='Channels';
defaultCleanlineTau=100;
defaultCleanlineVerb = 1;
defaultCleanlineWinSize = 4;
defaultCleanlineWinStep = 4;
    
validateMethod = @( method ) ischar( method ) && ismember(method, {'Lowpass', 'Highpass', 'Notch', 'Cleanline'});

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addRequired(ip, 'method', validateMethod);
addParameter(ip, 'lowpassfilt',defaultHiCutoff,@isnumeric);
addParameter(ip, 'hipassfilt',defaultLoCutoff,@isnumeric);
addParameter(ip, 'notch',defaultNotch,@isnumeric);
addParameter(ip, 'filtorder',defaultFiltOrder,@isnumeric);
addParameter(ip, 'revfilt',defaultRevFilt,@isnumeric);
addParameter(ip, 'plotfreqz',defaultPlotFreqz,@isnumeric);
addParameter(ip, 'minphase',defaultMinPhase,@islogical);
addParameter(ip, 'cleanlinebandwidth',defaultCleanlineBandwidth,@isnumeric);
addParameter(ip, 'cleanlinechanlist',defaultCleanlineChanList,@isnumeric);
addParameter(ip, 'cleanlinecomputepower',defaultCleanlineComputePower,@isnumeric);
addParameter(ip, 'cleanlinelinefreqs',defaultCleanlineLineFreqs,@isnumeric);
addParameter(ip, 'cleanlinenormspectrum',defaultCleanlineNormSpectrum,@isnumeric);
addParameter(ip, 'cleanlinep',defaultCleanlineP,@isnumeric);
addParameter(ip, 'cleanlinepad',defaultCleanlinePad,@isnumeric);
addParameter(ip, 'cleanlineplotfigures',defaultCleanlinePlotFigures,@isnumeric);
addParameter(ip, 'cleanlinescanforlines',defaultCleanlineScanForLines,@isnumeric);
addParameter(ip, 'cleanlinesigtype',defaultCleanlineSigType,@ischar);
addParameter(ip, 'cleanlinetau',defaultCleanlineTau,@isnumeric);
addParameter(ip, 'cleanlineverb',defaultCleanlineVerb,@isnumeric);
addParameter(ip, 'cleanlinewinsize',defaultCleanlineWinSize,@isnumeric);
addParameter(ip, 'cleanlinewinstep',defaultCleanlineWinStep,@isnumeric);

parse(ip,EEG,method,varargin{:});

try
    switch method
        case 'Highpass'
            
            EEG = pop_eegfiltnew(EEG,  'locutoff',ip.Results.hipassfilt, 'hicutoff', [], 'filtorder', ip.Results.filtorder);
            EEG.vhtp.Filter.completed = 1;
            EEG.vhtp.Filter.locutoff = ip.Results.hipassfilt;
            EEG.vhtp.Filter.filtorder   = ip.Results.filtorder;
            EEG.vhtp.Filter.revfilt     = ip.Results.revfilt;
            EEG.vhtp.Filter.plotfreqz   = ip.Results.plotfreqz;
            EEG.vhtp.Filter.minphase    = ip.Results.minphase;
            
        case 'Lowpass'
                       
            EEG = pop_eegfiltnew(EEG,  'locutoff', [],  'hicutoff', ip.Results.lowpassfilt, 'filtorder', ip.Results.filtorder);
            EEG.vhtp.Filter.completed = 1;
            EEG.vhtp.Filter.hicutoff = ip.Results.lowpassfilt;
            EEG.vhtp.Filter.filtorder   = ip.Results.filtorder;
            EEG.vhtp.Filter.revfilt     = ip.Results.revfilt;
            EEG.vhtp.Filter.plotfreqz   = ip.Results.plotfreqz;
            EEG.vhtp.Filter.minphase    = ip.Results.minphase;
            
        case 'Notch'
            
            
            linenoise = floor((ip.Results.notch(1) + ip.Results.notch(2)) / 2);
            harmonics = floor((EEG.srate/2) / linenoise);
            if EEG.srate < 2000
                for i = 1 : harmonics
                    EEG = pop_eegfiltnew(EEG, 'locutoff', (linenoise * i)-2, 'hicutoff', (linenoise * i)+2, 'filtorder', ip.Results.filtorder, 'revfilt', ip.Results.revfilt, 'plotfreqz',ip.Results.plotfreqz);
                end
            end
            EEG.vhtp.Filter.completed = 1;
            EEG.vhtp.Filter.filtorder   = ip.Results.filtorder;
            EEG.vhtp.Filter.revfilt     = ip.Results.revfilt;
            EEG.vhtp.Filter.plotfreqz   = ip.Results.plotfreqz;
            EEG.vhtp.Filter.minphase    = ip.Results.minphase;
        case 'Cleanline'
            EEG = pop_cleanline(EEG, 'bandwidth', ip.Results.cleanlinebandwidth,'chanlist', ip.Results.cleanlinechanlist, 'computepower', ip.Results.cleanlinecomputepower, 'linefreqs', ip.Results.cleanlinelinefreqs,...
                'normSpectrum', ip.Results.cleanlinenormspectrum, 'p', ip.Results.cleanlinep, 'pad', ip.Results.cleanlinepad, 'PlotFigures', ip.Results.cleanlineplotfigures, 'scanforlines', ip.Results.cleanlinescanforlines, 'sigtype', ip.Results.cleanlinesigtype, 'tau', ip.Results.cleanlinetau,...
                'verb', ip.Results.cleanlineverb, 'winsize', ip.Results.cleanlinewinsize, 'winstep', ip.Results.cleanlinewinstep);
            EEG.vhtp.Filter.completed = 1;
            EEG.vhtp.Filter.bandwidth = ip.Results.cleanlinebandwidth;
            EEG.vhtp.Filter.chanlist = ip.Results.cleanlinechanlist;
            EEG.vhtp.Filter.computepower = ip.Results.cleanlinecomputepower;
            EEG.vhtp.Filter.linefreqs = ip.Results.cleanlinelinefreqs;
            EEG.vhtp.Filter.normspectrum=ip.Results.cleanlinenormspectrum;
            EEG.vhtp.Filter.p=ip.Results.cleanlinep;
            EEG.vhtp.Filter.pad = ip.Results.cleanlinepad;
            EEG.vhtp.Filter.plotfigures=ip.Results.cleanlineplotfigures;
            EEG.vhtp.Filter.scanforlines=ip.Results.cleanlinescanforlines;
            EEG.vhtp.Filter.sigtype=ip.Results.cleanlinesigtype;
            EEG.vhtp.Filter.tau=ip.Results.cleanlinetau;
            EEG.vhtp.Filter.verb =ip.Results.cleanlineverb;
            EEG.vhtp.Filter.winsize = ip.Results.cleanlinewinsize;
            EEG.vhtp.Filter.winstep = ip.Results.cleanlinewinstep;
        otherwise
            EEG.vhtp.Filter.completed = 0;
    end
        
catch e
    throw(e);
end

EEG = eeg_checkset(EEG);

end

