function [EEG, results] = eeg_htpEegFilterEeglab(EEG,varargin)
% Description: Perform various filtering methods (highpass, lowpass, notch, and cleanline) on data
% ShortTitle: Filter EEG using EEGLAB
% Category: Preprocessing
% Tags: Filter
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegFilterEeglab( EEG, varargin)
%
%% Required Inputs:
%     EEG [struct]         - EEGLAB Structure
%
%% Function Specific Inputs:
%   'method'  - Text representing method utilized for Filtering
%               default: 'highpass' e.g. {'highpass', 'lowpass', 'notch', 'cleanline'}
%
%   'lowpassfilt' - Number representing the higher edge frequency to use in 
%                   lowpass bandpass filter 
%                   default: 80
%
%   'highpassfilt' - Number representing the lower edge frequency to use in 
%                  highpass bandpass filter 
%                  default: .5
%
%   'notchfilt' - Array of two numbers utilized for generating the line noise
%             used in harmonics calculation for notch filtering
%             default: [55 65]
%
%
%   'revfilt' - Numeric boolean to invert filter from bandpass to notch
%               default: 0 e.g. {0 -> bandpass, 1 -> notch}
%
%   'plotfreqz' - Numeric boolean to indicate whether to plot filter's frequency and phase response
%                 default: 0
%
%
%   'minphase' - Boolean for minimum-phase converted causal filter
%                default: false
%
%   'filtorder' - numeric override of default EEG filters
%                 default: missing
%
%   'dynamicfiltorder' - numeric boolean indicating whether to use dynamic filtorder determined via EEGLAB filtering function
%                        default: 1
%   
%
%   'cleanlinebandwidth' - Number for width of spectral peak  for fixed frequency
%                          default: 2
%
%   'cleanlinechanlist' - Array of numbers for indices of channels to clean
%                         default: [1:EEG.nbchan]
%
%   'cleanlinecomputepower' - Numeric boolean for visualization of the original and cleaned spectra
%                             default: 0
%
%   'cleanlinelinefreqs' - Array of numbers for line frequencies to remove
%                          default: [60 120 180]
%
%   'cleanlinenormspectrum' - Numeric boolean to normalize log spectrum via detrending
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
%                        default: 'Channels' e.g. {'Channels','Components'}
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
%   'saveoutput' - Boolean representing if output should be saved when executing step from VHTP preprocessing tool
%                  default: false
%
%   'outputdir' - text representing the output directory for the function
%                 output to be saved to
%                 default: '' 
%
%% Outputs:
%     EEG [struct]         - Updated EEGLAB structure
%
%     results [struct]   - Updated function-specific structure containing qi table and input parameters used
%
%% Disclaimer:
%  This file is part of the Cincinnati Visual High Throughput Pipeline
%  
%  Please see http://github.com/cincibrainlab
%
%% Contact:
%  kyle.cullion@cchmc.org

defaultMethod = 'highpass';
defaultLoCutoff = 0.5;
defaultHiCutoff = 80;
defaultNotch = [55 65];
if any(strcmp(varargin,{'method'})) && strcmp(varargin(find(strcmp(varargin,'method'))+1),'notch'); defaultRevFilt=1; else; defaultRevFilt=0; end;
defaultPlotFreqz   = 0;
defaultMinPhase    = false;
defaultFiltOrder = missing;
defaultDynamicFiltOrder = 1;
defaultCleanlineBandwidth = 2;
defaultCleanlineChanList = [1:EEG.nbchan];
defaultCleanlineComputePower = 0;
defaultCleanlineLineFreqs = [60 120 180];
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
defaultSaveOutput = false;
defaultOutputDir = '';
    
validateMethod = @( method ) ischar( method ) & ismember(method, {'lowpass', 'highpass', 'notch', 'cleanline'});
validateRevFilt = @(revfilt) isnumeric(revfilt) && ((revfilt==1 &&  strcmp(varargin(find(strcmp(varargin,'method'))+1),'notch')) || (revfilt==0 && ~strcmp(varargin(find(strcmp(varargin,'method'))+1),'notch')));

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'method', defaultMethod, validateMethod);
addParameter(ip, 'lowpassfilt',defaultHiCutoff,@isnumeric);
addParameter(ip, 'highpassfilt',defaultLoCutoff,@isnumeric);
addParameter(ip, 'notchfilt',defaultNotch,@isnumeric);
addParameter(ip, 'revfilt',defaultRevFilt,validateRevFilt);
addParameter(ip, 'plotfreqz',defaultPlotFreqz,@isnumeric);
addParameter(ip, 'minphase',defaultMinPhase,@islogical);
addParameter(ip, 'filtorder',defaultFiltOrder,@isnumeric);
addParameter(ip, 'dynamicfiltorder', defaultDynamicFiltOrder,@islogical);
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
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    switch ip.Results.method
        case 'highpass'
            if ~(ip.Results.dynamicfiltorder)
                if ismissing(ip.Results.filtorder)
                    highpassfiltorder = 6600;
                else
                    highpassfiltorder = ip.Results.filtorder;
                end
                EEG = pop_eegfiltnew(EEG,  'locutoff',ip.Results.highpassfilt, 'hicutoff', [],'filtorder',highpassfiltorder,'revfilt',ip.Results.revfilt,'plotfreqz',ip.Results.plotfreqz,'minphase',ip.Results.minphase);
                EEG.vhtp.eeg_htpEegFilterEeglab.highpassfiltorder    = highpassfiltorder;
            else
                EEG = pop_eegfiltnew(EEG,  'locutoff',ip.Results.highpassfilt, 'hicutoff', [],'revfilt',ip.Results.revfilt,'plotfreqz',ip.Results.plotfreqz,'minphase',ip.Results.minphase);
                EEG.vhtp.eeg_htpEegFilterEeglab.highpassfiltorder    = 'dynamic';
            end
            EEG.vhtp.eeg_htpEegFilterEeglab.highpass_completed = 1;
            EEG.vhtp.eeg_htpEegFilterEeglab.highpassLocutoff = ip.Results.highpassfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.highpassRevfilt     = ip.Results.revfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.highpassPlotfreqz   = ip.Results.plotfreqz;
            EEG.vhtp.eeg_htpEegFilterEeglab.highpassMinPhase    = ip.Results.minphase;
            
        case 'lowpass'
            if ~(ip.Results.dynamicfiltorder)
                if ismissing(ip.Results.filtorder)
                    lowpassfiltorder = 3300;
                else
                    lowpassfiltorder = ip.Results.filtorder;
                end
                EEG = pop_eegfiltnew(EEG,  ...
                    'locutoff', [],  'hicutoff', ip.Results.lowpassfilt,'filtorder',lowpassfiltorder,'revfilt',ip.Results.revfilt,'plotfreqz',ip.Results.plotfreqz,'minphase',ip.Results.minphase);
                EEG.vhtp.eeg_htpEegFilterEeglab.lowpassfiltorder    = lowpassfiltorder;
            else
                EEG = pop_eegfiltnew(EEG,  ...
                    'locutoff', [],  'hicutoff', ip.Results.lowpassfilt,'revfilt',ip.Results.revfilt,'plotfreqz',ip.Results.plotfreqz,'minphase',ip.Results.minphase);
                EEG.vhtp.eeg_htpEegFilterEeglab.lowpassfiltorder    = 'dynamic';
            end
            EEG.vhtp.eeg_htpEegFilterEeglab.lowpass_completed = 1;
            EEG.vhtp.eeg_htpEegFilterEeglab.lowpassHicutoff    = ip.Results.lowpassfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.lowpassRevfilt     = ip.Results.revfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.lowpassPlotfreqz   = ip.Results.plotfreqz;
            EEG.vhtp.eeg_htpEegFilterEeglab.lowpassMinPhase    = ip.Results.minphase;
            
        case 'notch'
            harmonics = 3;
            linenoise = floor((ip.Results.notchfilt(1) + ip.Results.notchfilt(2)) / 2);
            if ~(ip.Results.dynamicfiltorder)
                if ismissing(ip.Results.filtorder)
                    notchfiltorder = 3300;
                else
                    notchfiltorder = ip.Results.filtorder;
                end
                if EEG.srate < 2000
                    for i = 1 : harmonics
                        EEG = pop_eegfiltnew(EEG, 'locutoff', (linenoise * i-(abs(ip.Results.notchfilt(1)-ip.Results.notchfilt(2))/2)), 'hicutoff', (linenoise * i+(abs(ip.Results.notchfilt(1)-ip.Results.notchfilt(2))/2)), 'filtorder',notchfiltorder,'revfilt', ip.Results.revfilt, 'plotfreqz',ip.Results.plotfreqz,'minphase',ip.Results.minphase);
                    end
                end
                EEG.vhtp.eeg_htpEegFilterEeglab.notchfiltorder    = notchfiltorder;
            else
                if EEG.srate < 2000
                    for i = 1 : harmonics
                        EEG = pop_eegfiltnew(EEG, 'locutoff', (linenoise * i-(abs(ip.Results.notchfilt(1)-ip.Results.notchfilt(2))/2)), 'hicutoff', (linenoise * i+(abs(ip.Results.notchfilt(1)-ip.Results.notchfilt(2))/2)), 'revfilt', ip.Results.revfilt, 'plotfreqz',ip.Results.plotfreqz,'minphase',ip.Results.minphase);
                    end
                end
                EEG.vhtp.eeg_htpEegFilterEeglab.notchfiltorder    = 'dynamic';
            end
            EEG.vhtp.eeg_htpEegFilterEeglab.notch_completed = 1;
            EEG.vhtp.eeg_htpEegFilterEeglab.notchCutoff = ip.Results.notchfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.notchRevfilt     = ip.Results.revfilt;
            EEG.vhtp.eeg_htpEegFilterEeglab.notchPlotfreqz   = ip.Results.plotfreqz;
            EEG.vhtp.eeg_htpEegFilterEeglab.notchMinPhase    = ip.Results.minphase;
        case 'cleanline'
            EEG = pop_cleanline(EEG, 'bandwidth', ip.Results.cleanlinebandwidth,'chanlist', ip.Results.cleanlinechanlist, 'computepower', ip.Results.cleanlinecomputepower, 'linefreqs', ip.Results.cleanlinelinefreqs,...
                'normSpectrum', ip.Results.cleanlinenormspectrum, 'p', ip.Results.cleanlinep, 'pad', ip.Results.cleanlinepad, 'PlotFigures', ip.Results.cleanlineplotfigures, 'scanforlines', ip.Results.cleanlinescanforlines, 'sigtype', ip.Results.cleanlinesigtype, 'tau', ip.Results.cleanlinetau,...
                'verb', ip.Results.cleanlineverb, 'winsize', ip.Results.cleanlinewinsize, 'winstep', ip.Results.cleanlinewinstep);
            EEG.vhtp.eeg_htpEegFilterEeglab.cleanline_completed = 1;
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
qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegFilterEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegFilterEeglab.qi_table = [EEG.vhtp.eeg_htpEegFilterEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegFilterEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegFilterEeglab;
if ip.Results.saveoutput && ~isempty(ip.Results.outputdir)
    if isfield(EEG.vhtp, 'currentStep')
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,EEG.vhtp.currentStep);
    else
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,['filter_' ip.Results.method]);
    end
    fprintf('Output was copied to %s\n\n',ip.Results.outputdir);
end

end

