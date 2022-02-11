function [results] = util_htpEegInfo( filepath, varargin )
% utility_htpEegInfo() - retreive stored htp reporting data rows from SET
% files. If no structure is found, data will be attempted to pull from SET
% structure directly. Does not load data, only SET structure.
%
% Usage:
%    >> [ results ] = utility_htpEegInfo( filepath, varargin )
%
% Example:
%    >> [results] = utility_htpEegInfo('/srv/rawdata/, 'nettype','EGI128', 'keyword', 'Experiment1', 'csvoutput', 'exp1_queue.csv' )
%
% Require Inputs:
%     filepath       - directory to get file list
%     'nettype'      - channel input type
%
% Function Specific Inputs:
%     'ext'          - specify file extenstion
%     'keyword'      - keyword search
%     'subdirOn'     - (true/false) search subdirectories
%     'dryrun'       - no actual changes to disk, default: true
%     'chanxml'      - specify channel catalog xml
%     'outputdir'    - output path (default: tempdir)
%
% Common Visual HTP Inputs:
%     'path_in'  - import directory
%     'path_out' - output directory
%     'file_out' - output file
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
defaultExt          = '.set';
defaultKeyword      = [];
defaultSubDirOn     = false;
defaultOutputDir    = tempdir;
defaultNetType      = 'undefined';
defaultCsvOut       = ['utility_htpFileInfo_' timestamp '.csv'];

validateExt = @( ext ) ischar( ext ) & all(ismember(ext(1), '.'));

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'filepath', @isfolder)
addParameter(ip,'ext', defaultExt, validateExt)
addParameter(ip,'keyword', defaultKeyword, @ischar)
addParameter(ip,'subdirOn', defaultSubDirOn, @islogical)
addParameter(ip,'csvout', defaultCsvOut, @ischar);
addParameter(ip,'nettype', defaultNetType, @ischar);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

parse(ip,filepath,varargin{:});

% START: Utilty code
if ip.Results.subdirOn, filepath = [filepath '**/']; end

% STEP 1: Get Net Type
netInfo = utility_htpReadNetCatalog('nettype', ip.Results.nettype);
csvfile = fullfile(ip.Results.outputdir, ip.Results.csvout);

filelist = util_htpDirListing(filepath, 'ext', ip.Results.ext, 'subdirOn', ip.Results.subdirOn);

for i = 1 : height(filelist)
    
    evalc( 'EEG = pop_loadset(''filename'', filelist.filename{i}, ''filepath'', filelist.filepath{i}, ''loadmode'', ''info'')');
    
    isHtpFieldPresent = any(strcmpi('vhtp', fieldnames(EEG))) || any(strcmpi('htp', fieldnames(EEG.etc)));
    
    if isHtpFieldPresent 
        if i == 1, res.inforow = EEG.vhtp.inforow; else, res.inforow = [res.inforow;  EEG.vhtp.inforow]; end   
    end
end

writetable(res.inforow, csvfile);

% Summary Message
fprintf('\n [Visual HTP EEG Import to SET]\n-Input Dir: %s\n-Check subdir: %s\n-Ext: %s\n-Total Files: %d\n-Output Dir:%s\n-Output CSV: %s\n',...
    ip.Results.filepath, string(ip.Results.subdirOn), ip.Results.ext, height(filelist), ip.Results.outputdir, ip.Results.csvout);
disp(['<a href = "file://' csvfile '"> Link to ' ip.Results.csvout '</a>']);
% END: Utility code

% QI Table
qi_table = cell2table({functionstamp, timestamp, height(filelist),csvfile, ip.Results.keyword, ip.Results.nettype }, ...
    'VariableNames', {'scriptname','timestamp', 'nofiles', 'csvfile', 'keyword', 'nettype'});

% Outputs:
results = res.inforow;

end