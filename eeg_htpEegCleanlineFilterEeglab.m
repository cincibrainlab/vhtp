function [EEG,results] = eeg_htpEegCleanlineFilterEeglab(EEG,varargin)
% Description: Perform Cleanline filtering on data
% ShortTitle: Filter EEG using EEGLAB
% Category: Preprocessing
% Tags: Filter
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegCleanlineFilterEeglab( EEG, varargin)
%
%% Required Inputs:
%     EEG [struct]         - EEGLAB Structure
%
%% Function Specific Inputs:
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

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
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
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical)

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    EEG = pop_cleanline(EEG, 'bandwidth', ip.Results.cleanlinebandwidth,'chanlist', ip.Results.cleanlinechanlist, 'computepower', ip.Results.cleanlinecomputepower, 'linefreqs', ip.Results.cleanlinelinefreqs,...
        'normSpectrum', ip.Results.cleanlinenormspectrum, 'p', ip.Results.cleanlinep, 'pad', ip.Results.cleanlinepad, 'PlotFigures', ip.Results.cleanlineplotfigures, 'scanforlines', ip.Results.cleanlinescanforlines, 'sigtype', ip.Results.cleanlinesigtype, 'tau', ip.Results.cleanlinetau,...
        'verb', ip.Results.cleanlineverb, 'winsize', ip.Results.cleanlinewinsize, 'winstep', ip.Results.cleanlinewinstep);
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.completed = 1;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.bandwidth = ip.Results.cleanlinebandwidth;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.chanlist = ip.Results.cleanlinechanlist;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.computepower = ip.Results.cleanlinecomputepower;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.linefreqs = ip.Results.cleanlinelinefreqs;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.normspectrum=ip.Results.cleanlinenormspectrum;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.p=ip.Results.cleanlinep;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.pad = ip.Results.cleanlinepad;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.plotfigures=ip.Results.cleanlineplotfigures;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.scanforlines=ip.Results.cleanlinescanforlines;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.sigtype=ip.Results.cleanlinesigtype;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.tau=ip.Results.cleanlinetau;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.verb =ip.Results.cleanlineverb;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.winsize = ip.Results.cleanlinewinsize;
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.winstep = ip.Results.cleanlinewinstep;
        
catch e
    throw(e);
end

EEG = eeg_checkset(EEG);
qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegCleanlineFilterEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.qi_table = [EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegCleanlineFilterEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegCleanlineFilterEeglab;
end

