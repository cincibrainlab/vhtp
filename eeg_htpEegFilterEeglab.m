function [EEG, results] = eeg_htpEegFilterEeglab(EEG,varargin)
% eeg_htpEegFilterEeglab - Perform various filtering methods
%                           (hipass, lowpass, notch, and cleanline) on data
%
% Usage:
%    >> [ EEG, results ] = eeg_htpEegFilterEeglab( EEG, varargin)
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
% Function Specific Inputs:
%
%   'method'  - Text representing method utilized for Filtering
%
%   'lowpassfilt' - Number representing the higher edge frequency to use in 
%                   lowpass bandpass filter 
%                   default: 80
%
%   'hipassfilt' - Number representing the lower edge frequency to use in 
%                  highpass bandpass filter 
%                  default: .5
%
%   'notchfilt' - Array of two numbers utilized for generating the line noise
%             used in harmonics calculation for notch filtering
%             default: [55 65]
%
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
%     results   - Updated function-specific structure containing qi table
%                 and input parameters used
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

defaultMethod = 'highpass';
defaultLoCutoff = 0.5;
defaultHiCutoff = 80;
defaultNotch = [55 65];
if any(strcmp(varargin,{'method'})) && strcmp(varargin(find(strcmp(varargin,'method'))+1),'notch'); defaultRevFilt=1; else; defaultRevFilt=0; end;
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
    
validateMethod = @( method ) ischar( method ) & ismember(method, {'lowpass', 'highpass', 'notch', 'cleanline'});
validateRevFilt = @(revfilt) isnumeric(revfilt) && ((revfilt==1 &&  strcmp(varargin(find(strcmp(varargin,'method'))+1),'notch')) || (revfilt==0 && ~strcmp(varargin(find(strcmp(varargin,'method'))+1),'notch')));

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'method', defaultMethod, validateMethod);
addParameter(ip, 'lowpassfilt',defaultHiCutoff,@isnumeric);
addParameter(ip, 'hipassfilt',defaultLoCutoff,@isnumeric);
addParameter(ip, 'notchfilt',defaultNotch,@isnumeric);
addParameter(ip, 'revfilt',defaultRevFilt,validateRevFilt);
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

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    switch ip.Results.method
        case 'highpass'
            highpassfiltorder = 6600;
            EEG = pop_eegfiltnew(EEG,  'locutoff',ip.Results.hipassfilt, 'hicutoff', [],'filtorder',highpassfiltorder);
            EEG.vhtp.eeg_htpEegFilterEeglab.completed = 1;
            EEG.vhtp.eeg_htpEegFilterEeglab.highpassLocutoff = ip.Results.hipassfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.highpassRevfilt     = ip.Results.revfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.highpassPlotfreqz   = ip.Results.plotfreqz;
            EEG.vhtp.eeg_htpEegFilterEeglab.highpassMinPhase    = ip.Results.minphase;
            
        case 'lowpass'
            lowpassfiltorder = 3300;
            EEG = pop_eegfiltnew(EEG,  ...
                'locutoff', [],  'hicutoff', ip.Results.lowpassfilt,'filtorder',lowpassfiltorder);
            EEG.vhtp.eeg_htpEegFilterEeglab.completed = 1;
            EEG.vhtp.eeg_htpEegFilterEeglab.lowpassHicutoff    = ip.Results.lowpassfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.lowpassRevfilt     = ip.Results.revfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.lowpassPlotfreqz   = ip.Results.plotfreqz;
            EEG.vhtp.eeg_htpEegFilterEeglab.lowpassMinPhase    = ip.Results.minphase;
            
        case 'notch'
            
            notchfiltorder = 3300;
            linenoise = floor((ip.Results.notchfilt(1) + ip.Results.notchfilt(2)) / 2);
            harmonics = floor((EEG.srate/2) / linenoise);
            if EEG.srate < 2000
                for i = 1 : harmonics
                    EEG = pop_eegfiltnew(EEG, 'locutoff', (linenoise * i)-2, 'hicutoff', (linenoise * i)+2, 'filtorder',notchfiltorder,'revfilt', ip.Results.revfilt, 'plotfreqz',ip.Results.plotfreqz);
                end
            end
            EEG.vhtp.eeg_htpEegFilterEeglab.completed = 1;
            EEG.vhtp.eeg_htpEegFilterEeglab.notchCutoff = ip.Results.notchfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.notchRevfilt     = ip.Results.revfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.notchPlotfreqz   = ip.Results.plotfreqz;
            EEG.vhtp.eeg_htpEegFilterEeglab.notchMinPhase    = ip.Results.minphase;
        case 'cleanline'
            EEG = pop_cleanline(EEG, 'bandwidth', ip.Results.cleanlinebandwidth,'chanlist', ip.Results.cleanlinechanlist, 'computepower', ip.Results.cleanlinecomputepower, 'linefreqs', ip.Results.cleanlinelinefreqs,...
                'normSpectrum', ip.Results.cleanlinenormspectrum, 'p', ip.Results.cleanlinep, 'pad', ip.Results.cleanlinepad, 'PlotFigures', ip.Results.cleanlineplotfigures, 'scanforlines', ip.Results.cleanlinescanforlines, 'sigtype', ip.Results.cleanlinesigtype, 'tau', ip.Results.cleanlinetau,...
                'verb', ip.Results.cleanlineverb, 'winsize', ip.Results.cleanlinewinsize, 'winstep', ip.Results.cleanlinewinstep);
            EEG.vhtp.eeg_htpEegFilterEeglab.completed = 1;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineBandwidth = ip.Results.cleanlinebandwidth;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineChanlist = ip.Results.cleanlinechanlist;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineComputePower = ip.Results.cleanlinecomputepower;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineLineFreqs = ip.Results.cleanlinelinefreqs;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineNormSpectrum=ip.Results.cleanlinenormspectrum;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineP=ip.Results.cleanlinep;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlinePad = ip.Results.cleanlinepad;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlinePlotFigures=ip.Results.cleanlineplotfigures;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineScanForLines=ip.Results.cleanlinescanforlines;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineSigType=ip.Results.cleanlinesigtype;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineTau=ip.Results.cleanlinetau;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineVerb =ip.Results.cleanlineverb;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineWinSize = ip.Results.cleanlinewinsize;
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanlineWinStep = ip.Results.cleanlinewinstep;
        otherwise
            EEG.vhtp.eeg_htpEegFilterEeglab.completed = 0;
    end
        
catch e
    throw(e);
end

EEG = eeg_checkset(EEG);
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
EEG.vhtp.eeg_htpEegFilterEeglab.qi_table = qi_table;

results = EEG.vhtp.eeg_htpEegFilterEeglab;
end

