function [results] = utility_htpDirectoryListing( filepath, varargin )
% utility_htpDirectoryListing() - prototype function for eeg_htp functions.
%      This is a template for utility type functions only. No EEG input.
%      Add 'help' comments here to be viewed on command line.
%
% Usage:
%    >> [ results ] = utility_htpFunctionTemplate( filepath, varargin )
%
% Require Inputs:
%     filepath       - directory to get file list
% Function Specific Inputs:
%     'ext'          - specify file extenstion
%     'keyword'      - keyword search
%     'subdirOn'     - (true/false) search subdirectories
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
defaultExt = [];
defaultKeyword = [];
defaultSubDirOn = true;

validateExt = @( ext ) ischar( ext ) & all(ismember(ext(1), '.'));

% MATLAB built-in input validation
ip = inputParser();   
addRequired(ip, 'filepath', @isfolder)
addParameter(ip,'ext', defaultExt, validateExt)
addParameter(ip,'keyword', defaultKeyword, @ischar)
addParameter(ip,'subdirOn', defaultSubDirOn, @islogical)
parse(ip,filepath,varargin{:});

% START: Utilty code

if ip.Results.subdirOn, filepath = [filepath '**/']; end

dirdump = dir(filepath);
results = dirdump(~cellfun('isempty', {dirdump.date}));

filelist = cell2table([{results([results.isdir] == false).folder}' {results([results.isdir] == false).name}'], ...
    'VariableNames', {'filepath','filename'});

if ~isempty(ip.Results.ext)
    filelist = filelist(contains(filelist.filename,ip.Results.ext),:);
end

if ~isempty(ip.Results.keyword)
    filelist = filelist(contains(filelist.filename,ip.Results.keyword),:);
end

% END: Utility code

% QI Table
qi_table = cell2table({functionstamp, timestamp}, 'VariableNames', {'scriptname','timestamp'});

% Outputs: 
results = filelist;


end