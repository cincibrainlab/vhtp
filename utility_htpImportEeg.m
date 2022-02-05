function [results] = utility_htpImportEeg( filepath, varargin )
% utility_htpDirectoryListing() - prototype function for eeg_htp functions.
%      This is a template for utility type functions only. No EEG input.
%      Add 'help' comments here to be viewed on command line.
%
% Usage:
%    >> [ results ] = utility_htpFunctionTemplate( filepath, varargin )
%
% Require Inputs:
%     filepath       - directory to get file list
%     'nettype'      - channel input type
%
% Function Specific Inputs:
%     'ext'          - specify file extenstion
%     'keyword'      - keyword search
%     'subdirOn'     - (true/false) search subdirectories
%     'dryrun'       - specify file extenstion
%     'chanxml'      - keyword search
%     'outputdir'    - keyword search
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
defaultExt          = '.raw';
defaultKeyword      = [];
defaultChanXml      = 'cfg_htpEegSystems.xml';
defaultSubDirOn     = false;
defaultDryrun       = true;
defaultOutputDir    = tempdir;
defaultNetType      = 'undefined';

validateExt = @( ext ) ischar( ext ) & all(ismember(ext(1), '.'));

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'filepath', @isfolder)
addParameter(ip,'ext', defaultExt, validateExt)
addParameter(ip,'keyword', defaultKeyword, @ischar)
addParameter(ip,'subdirOn', defaultSubDirOn, @islogical)
addParameter(ip,'dryrun', defaultDryrun, @islogical)
addParameter(ip,'chanxml', defaultChanXml, @ischar);
addParameter(ip,'nettype', defaultNetType, @ischar);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

parse(ip,filepath,varargin{:});

% START: Utilty code
if ip.Results.dryrun, fprintf("\n***DRY-RUN Configured. Output below shows what 'would' have occurred.\n***No file import will be performed without 'dryrun' set to false.\n"); end
if ip.Results.subdirOn, filepath = [filepath '**/']; end

% STEP 1: Get Net Type
if ~exist(ip.Results.chanxml,'file'), error('Channel XML File is missing. Download template from GITHUB or add to path'); end

netInfo = utility_htpReadNetCatalog('nettype', ip.Results.nettype);

% Prompt user to enter net type for correct import
if strcmpi('undefined',(ip.Results.nettype))
    error('Use key-value pair to specify net type (''nettype'',''EGI128'')');
end

% STEP 1: Preallocate import files and create table including output
% filenames
changeExtToSet = @( str ) strrep(str, ip.Results.ext, '.set'); % convert new filename to .set

filelist = utility_htpDirectoryListing(filepath, 'ext', ip.Results.ext, 'subdirOn', ip.Results.subdirOn);

if ~isempty(filelist.filename)
    filelist.success = false(height(filelist),1);
    filelist.importdate = repmat(string(timestamp), height(filelist),1);
    filelist.electype = repmat(ip.Results.nettype, height(filelist),1);
    filelist.ext = repmat(ip.Results.ext, height(filelist),1);
    outputfile_rows = varfun(changeExtToSet, filelist, 'InputVariables', {'filename'}, 'OutputFormat','cell');
    filelist.outputfile = outputfile_rows{1};
    filelist.outputdir = repmat(string(ip.Results.outputdir), height(filelist),1);
else
    error("File List is Empty");
end

netverify_filename = fullfile(ip.Results.outputdir, [netInfo.net_name 'verify_topoplot_' timestamp '.png']);

% Summary Message
fprintf('\n [Visual HTP EEG Import to SET]\n-Input Dir: %s\n-Ext: %s\n-Total Files: %d\n-Preset:%s\n-Output Dir: %s\n\n',...
    ip.Results.filepath, ip.Results.ext, height(filelist), ip.Results.ext, ip.Results.outputdir);

% Prompt for continue?

for i = 1 : height(filelist)
    
    original_file = fullfile(filelist.filepath{i},filelist.filename{i});
    output_file = fullfile(filelist.outputdir{i},filelist.outputfile{i});
    
    switch ip.Results.nettype
        case 'EGI128'
            try EEG = pop_readegi(original_file);
            catch, error('Check if EEGLAB 2021 is installed'); end
            
            % modified from EEGLAB readegilocs due to fixed path bug
            locs = readlocs(netInfo.net_file);
            locs(1).type = 'FID'; locs(2).type = 'FID'; locs(3).type = 'FID';
            locs(end).type = 'REF';
            
            if EEG.nbchan == 256 || EEG.nbchan == 257
                if EEG.nbchan == 256
                    chaninfo.nodatchans = locs([end]);
                    locs(end) = [];
                end
            elseif mod(EEG.nbchan,2) == 0
                chaninfo.nodatchans = locs([1 2 3 end]);
                locs([1 2 3 end]) = [];
            else
                chaninfo.nodatchans = locs([1 2 3]);
                locs([1 2 3]) = [];
            end % remove reference
            
            chaninfo.filename = netInfo.net_file;
            EEG.chanlocs   = locs;
            EEG.urchanlocs = locs;
            EEG.chaninfo   = chaninfo;
            
        otherwise
    end
    
    % Populate EEG SET File
    EEG.setname = filelist.outputfile{i};
    EEG.filename = filelist.outputfile{i};
    EEG.filepath = filelist.outputdir(i);
    EEG.subject = filelist.outputfile{i};
    
    % Populate EEG SET structure
    if ~isempty(EEG.event)
        has_events = true;
        event_codes = strjoin(unique({EEG.event.type}),'__');
    else
        has_events = false;
        event_codes = [];
    end
    
    setinfo = cell2table({filelist.outputfile(i) EEG.nbchan EEG.trials EEG.pnts EEG.srate EEG.xmin ...
        EEG.xmax EEG.ref has_events event_codes filelist.outputfile{i} filelist.outputdir(i) ...
        EEG.subject, original_file...
        }, ...
        'VariableNames', {'setname','nbchan','trials','pnts','srate','xmin', ...
        'xmax','ref','has_events','event_codes','filename','filepath','subject', 'original_file'});
    
    EEG.etc.htp.import = setinfo;
    EEG.htp.import = setinfo;
    
    if ~ip.Results.dryrun
        try
            EEG = pop_saveset( EEG, 'filename', output_file );
            filelist.success(i) = true;
        catch
            warning('Warning: Error saving file.');
        end
    else
        fprintf('DRYRUN: Expected Save: %s\n', output_file);
    end
    
    if i == 1
        % export figure to verify
        f = figure;
        topoplot([],EEG.chanlocs, 'style', 'blank', 'drawaxis', 'on', 'electrodes', ...
            'labelpoint', 'plotrad', [], 'chaninfo', EEG.chaninfo, 'whitebk', 'on');
        saveas(f, netverify_filename);
        close all;
    end
    
end

% END: Utility code

% QI Table
qi_table = cell2table({functionstamp, timestamp, height(filelist), ip.Results.ext, netverify_filename}, ...
    'VariableNames', {'script','timestamp', 'nofiles', 'fileext', 'verifyplot'});

% Outputs:
results = filelist;

end