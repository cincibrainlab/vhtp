function [EEG] = eeg_htpEegFilterEeglab(EEG,method,varargin)
% eeg_htpEegFilterEeglab - Perform various filtering methods
%                           (hipass, lowpass, notch, and cleanline) on data
%
% Usage:
%    >> [ EEG ] = eeg_htpEegFilterEeglab( EEG, method)
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
%    method  - Text representing method utilized for Filtering
%
% Function Specific Inputs:
%   'lowpassfilt' - Number representing the higher edge frequency to use in 
%                   lowpass bandpass filter 
%                   default: 80
%
%   'hipassfilt' - Number representing the lower edge frequency to use in 
%                  highpass bandpass filter 
%                  default: .5
%
%   'notch' - Array of two numbers utilized for generating the line noise
%             used in harmonics calculation for notch filtering
%             default: [55 65]
%
%   'filtorder' - Number for filter order (filter length - 1)
%                 default: 3300
%
%   'revfilt' - Numeric boolean to invert filter from bandpass to notch
%               {0 -> bandpass, 1 -> notch}
%               default: 0    
%
%   'plotfreqz' - Numeric boolean to indicate whether to plot filter's frequency and
%                 phase response
%                 default: 0
%
%   'minphase' - Boolean for minimum-phase converted causal filter
%                default: false
%
%   'cleanlinebandwidth' - Number for width of spectral peak  for fixed
%                          frequency
%                          default: 2
%
%   'cleanlinechanlist' - Array of numbers for indices of channels to clean
%                         default: [1:EEG.nbchan]
%
%   'cleanlinecomputepower' - Numeric boolean for visualization of the original and
%                             cleaned spectra
%                             default: 0
%
%   'cleanlinelinefreqs' - Array of numbers for line frequencies to remove
%                          default: [60 120 180 240 300]
%
%   'cleanlinenormspectrum' - Numeric boolean to normalize log spectrum via
%                             detrending
%                             default: 0
%
%   'cleanlinep' - Number for p-value used for detection of sinusoid
%                  default: 0.01
%
%   'cleanlinepad' - Number for padding of FFT
%                    default: 2
%
%   'cleanlineplotfigures' - Numeric boolean for plotting figures
%                            default: 0
%
%   'cleanlinescanforlines' - Numeric boolean for scanning for line noise 
%                             default: 1
%
%   'cleanlinesigtype' - Text of signal type to clean 
%                         e.g. {'Channels','Components'}
%                        default: 'Channels'
%               
%   'cleanlinetau' - Number for smoothing factor of overlapping windows
%                    default: 100
%
%   'cleanlineverb' - Numeric boolean for verbose output
%                     default: 1
%
%   'cleanlinewinsize' - Number to set length of sliding window
%                        default: 4
%
%   'cleanlinewinstep' - Number to determine amount of overlap of sliding
%                        window
%                        default: 4
%
% Outputs:
%     EEG         - Updated EEGLAB structure
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

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

