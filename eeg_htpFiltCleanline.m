function [EEG] = eeg_htpFiltCleanline(EEG,varargin)

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output
    

defaultBandwidth = 2;
defaultChanList = [1:EEG.nbchan];
defaultComputePower = 0;
defaultLineFreqs = [60 120 180 240 300];
defaultNormSpectrum=0;
defaultP=0.01;
defaultPad = 2;
defaultPlotFigures=0;
defaultScanForLines=1;
defaultSigType='Channels';
defaultTau=100;
defaultVerb = 1;
defaultWinSize = 4;
defaultWinStep = 4;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addOptional(ip, 'bandwidth',defaultBandwidth,@isnumeric);
addOptional(ip, 'chanlist',defaultChanList,@isnumeric);
addOptional(ip, 'computepower',defaultComputePower,@isnumeric);
addOptional(ip, 'linefreqs',defaultLineFreqs,@isnumeric);
addOptional(ip, 'normSpectrum',defaultNormSpectrum,@isnumeric);
addOptional(ip, 'p',defaultP,@isnumeric);
addOptional(ip, 'pad',defaultPad,@isnumeric);
addOptional(ip, 'PlotFigures',defaultPlotFigures,@isnumeric);
addOptional(ip, 'scanforlines',defaultScanForLines,@isnumeric);
addOptional(ip, 'sigtype',defaultSigType,@isnumeric);
addOptional(ip, 'tau',defaultTau,@isnumeric);
addOptional(ip, 'verb',defaultVerb,@isnumeric);
addOptional(ip, 'winsize',defaultWinSize,@isnumeric);
addOptional(ip, 'winstep',defaultWinStep,@isnumeric);


parse(ip,EEG,varargin{:});

EEG = pop_cleanline(EEG, 'bandwidth', ip.Results.bandwidth,'chanlist', ip.Results.chanlist, 'computepower', ip.Results.computepower, 'linefreqs', ip.Results.linefreqs,...
                'normSpectrum', ip.Results.normSpectrum, 'p', ip.Results.p, 'pad', ip.Results.pad, 'PlotFigures', ip.Results.PlotFigures, 'scanforlines', ip.Results.scanforlines, 'sigtype', ip.Results.sigtype, 'tau', ip.Results.tau,...
                'verb', ip.Results.verb, 'winsize', ip.Results.winsize, 'winstep', ip.Results.winstep);
EEG = eeg_checkset( EEG );
end

