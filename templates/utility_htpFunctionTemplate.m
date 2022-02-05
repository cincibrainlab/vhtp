function [results] = utility_htpParseNetTypes( filepath, varargin )
% utility_htpFunctionTemplate() - prototype function for eeg_htp functions.
%      This is a template for utility type functions only. No EEG input.
%      Add 'help' comments here to be viewed on command line.
%
% Usage:
%    >> [ results ] = utility_htpFunctionTemplate( varargin )
%
% Require Inputs:
%     variable       - variable description
% Function Specific Inputs:
%     'option1' - description
%
% Common Visual HTP Inputs:
%     'pathdef' - file path variable
%     
% Outputs:
%     results   - variable outputs
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%    
%  Contact: kyle.cullion@cchmc.org

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

% Inputs: Function Specific

% Inputs: Common across Visual HTP functions
defaultFilePath = tempdir;

% MATLAB built-in input validation
ip = inputParser();   
addRequired(ip, 'filepath', @isstruct);
addParameter(ip, 'keyword', defaultFilePath, @ischar)
parse(ip,filepath,varargin{:});


% START: Utility code


% END: Utility code

% QI Table
qi_table = cell2table({functionstamp, timestamp}, 'VariableNames', {'function','timestamp'});

% Outputs: 
results = [];


end