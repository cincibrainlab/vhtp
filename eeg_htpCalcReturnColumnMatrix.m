function [x] = eeg_htpCalcReturnColumnMatrix(EEG)
% Description: Returns columnwise matrix of each channel.
% Category: Analysis
% Tag: Transform
%
%   Example form: 1000 samples x 100 channels (size(x))
%   Uses optional fast_fc filtering to return bandpass signal.
%
% Usage:
%    >> [ EEG, results ] = eeg_htpCalcReturnColumnMatrix( EEG, varargin )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
%
% Function Specific Inputs:
%     lowbound  - lower bound of bandpass
%     upperbound - upper bound of bandpass
%
% Outputs:
%     x         - columnwise matrix of EEG data (samples x columns)
%     xf        - filtered data
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org


timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output
csvtable = table();

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
parse(ip, EEG);

% START: Signal Processing
if ndims(EEG.data) < 3
    x = double(EEG.data');
else
    EEG = eeg_htpEegEpoch2Cont(EEG);
    x = double(EEG.data');
end

% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid', 'filename', 'scriptname', 'timestamp'});

% Outputs:
%  EEG.vhtp.eeg_htpCalcRestPower.summary_table = csvtable;
% EEG.vhtp.eeg_htpCalcRestPower.qi_table = qi_table;

end