function [EEG, results] = eeg_htpCalcGedBounds(EEG, varargin)
% eeg_htpCalcGedBounds() - TBD
%
% Usage:
%    >> [ EEG, results ] = eeg_htpCalcGedBounds( EEG, varargin )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
% Function Specific Inputs:
%     gpuon     - [logical] use gpuArray. default: false
%
% Common Visual HTP Inputs:
%     'bandDefs'   - cell-array describing frequency band definitions
%     {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 'alpha2', 10.5, 12.5;
%     'beta', 13, 30;'gamma1', 30, 55; 'gamma2', 65, 80; 'epsilon', 81, 120;}
%     'outputdir' - path for saved output files (default: tempdir)
%
% Outputs:
% Outputs:
%     EEG       - EEGLAB Structure with modified .vhtp field
%                 [table] summary_table: subject chan power_type_bandname
%                 [table] spectro: channel average power for spectrogram
%     results   - .vhtp structure
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output
csvtable = table();

% Inputs: Function Specific
defaultGpu = 0;

% Inputs: Common across Visual HTP functions
defaultOutputDir = tempdir;
defaultBandDefs = {'delta', 2, 3.5; 'theta', 3.5, 7.5; 'alpha1', 8, 10;
    'alpha2', 10.5, 12.5; 'beta', 13, 30; 'gamma1', 30, 55;
    'gamma2', 65, 80; 'epsilon', 81, 120; };

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'gpuOn', defaultGpu, @islogical);
addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
addParameter(ip, 'bandDefs', defaultBandDefs, @iscell)
parse(ip, EEG, varargin{:});

outputdir = ip.Results.outputdir;
bandDefs = ip.Results.bandDefs;

% base output file can be modified with strrep()
outputfile = fullfile(outputdir, [functionstamp '_' EEG.setname '_' timestamp '.mat']);

% START: Signal Processing

EEG.etc.kernal = constructFilterKernal(EEG);


% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid', 'filename', 'scriptname', 'timestamp'});

% Outputs:
EEG.vhtp.eeg_htpCalcRestPower.summary_table = csvtable;
EEG.vhtp.eeg_htpCalcRestPower.qi_table = qi_table;

end

function [kernal, FILTORDER] = constructFilterKernal(EEG, lowerBound, upperBound, filter_order)
if nargin < 2
    % Default Filter Settings
    warning("Default Filter Settings Used.")
    lowerBound = 5; % lower theta bound in Hz
    upperBound = 7; % upper theta bound in Hz
    % filter_order = 3000; % higher order is better frequency resolution, poorer temporal resolution
end

SRATE           = EEG.srate;
TRANSWIDTHRATIO = 0.25;
LOWBOUND        = lowerBound;
HIGHBOUND       = upperBound;
EDGEBOUNDS      = sort([LOWBOUND HIGHBOUND]);
NYQUIST         = SRATE/ 2;

maxTBWArray = EDGEBOUNDS;       % Band-/highpass
maxTBWArray(end) = NYQUIST - EDGEBOUNDS(end);

maxDf = min(maxTBWArray);
df = min([max([EDGEBOUNDS(1) * TRANSWIDTHRATIO 2]) maxDf]);

df = min([max([EDGEBOUNDS(1) * TRANSWIDTHRATIO 2]) maxDf]);
filtOrder = 3.3 / (df / SRATE ); % Hamming window
filtOrder = ceil(filtOrder / 2) * 2; % Filter order must be even.
FILTORDER = filtOrder*3;

kernal = fir1(FILTORDER, [LOWBOUND/NYQUIST HIGHBOUND/NYQUIST]);

end