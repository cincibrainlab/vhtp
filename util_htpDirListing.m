function [results] = util_htpDirListing( filepath, varargin )
% utility_htpDirectoryListing() - prototype function for eeg_htp functions.
%      This is a template for utility type functions only. No EEG input.
%      Add 'help' comments here to be viewed on command line.
%
% Usage:
%    >> [ results ] = util_htpFunctionTemplate( filepath, varargin )
%
% Require Inputs:
%     filepath       - directory to get file list
% Function Specific Inputs:
%     'ext'          - specify file extenstion
%     'keyword'      - keyword search
%     'notKeyword'   - negate keyword search
%     'subdirOn'     - (true/false) search subdirectories
%     'keepentireext' - keep entire file extension
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
% Reviewed on 8/20/2024

% Inputs: Common across Visual HTP functions
defaultExt = [];
defaultKeyword = [];
defaultSubDirOn = true;
defaultNotKeyword = false;
defaultKeepEntireExt = false;

validateExt = @( ext ) (any(strcmp(varargin,{'keepentireext'})) && varargin{find(strcmp(varargin,'keepentireext'))+1}) || (ischar( ext ) & all(ismember(ext(1), '.')));

% MATLAB built-in input validation
ip = inputParser();   
addRequired(ip, 'filepath', @isfolder)
addParameter(ip,'ext', defaultExt, validateExt)
addParameter(ip,'keyword', defaultKeyword, @ischar)
addParameter(ip,'notKeyword', defaultNotKeyword, @mustBeNumericOrLogical)
addParameter(ip,'subdirOn', defaultSubDirOn, @mustBeNumericOrLogical)
addParameter(ip, 'keepentireext',defaultKeepEntireExt, @mustBeNumericOrLogical);
parse(ip,filepath,varargin{:});

% START: Utilty code

if ip.Results.subdirOn, filepath = fullfile(filepath, '**/'); end
 
dirdump = dir(filepath);
results = dirdump(~cellfun('isempty', {dirdump.date}));

try
filelist = cell2table([{results([results.isdir] == false).folder}' {results([results.isdir] == false).name}'], ...
    'VariableNames', {'filepath','filename'});
catch
    results = []; % fixed for truly empty directory
    return;
end
if ~isempty(ip.Results.ext)
    filelist = filelist(contains(lower(filelist.filename), lower(ip.Results.ext)),:);
end

if ~isempty(ip.Results.keyword)
    if ~ip.Results.notKeyword
        filelist = filelist(contains(filelist.filename,ip.Results.keyword),:);
    else
        filelist = filelist(~contains(filelist.filename,ip.Results.keyword),:);
    end
end

% END: Utility code

% QI Table
qi_table = cell2table({functionstamp, timestamp}, 'VariableNames',...
 {'scriptname','timestamp'});

% Outputs: 
results = filelist;


end
