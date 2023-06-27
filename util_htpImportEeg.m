function [results] = util_htpImportEeg( filepath, varargin )
% util_htpImportEeg() - main import function
%
% Usage:
%    >> [ results ] = util_htpImportEeg( filepath, varargin )
%
% Example:
%    >> [results] = util_htpImportEeg('/srv/rawdata/', 'nettype','EGI128', 'outputdir', '/srv/outputdata', 'dryrun', false )
%
% Require Inputs:
%     filepath       - directory to get file list OR filename
%     'nettype'      - channel input type
%
% Function Specific Inputs:
%     'ext'          - specify file extenstion
%     'keyword'      - keyword search
%     'subdirOn'     - (true/false) search subdirectories
%     'dryrun'       - no actual changes to disk, default: true
%     'chanxml'      - specify channel catalog xml
%     'outputdir'    - output path (default: tempdir)
%     'listing'      - (true/false) file list only
%
% Common Visual HTP Inputs:
%     'pathdef' - file path variable
%
% Outputs:
%     results   - variable outputs
%     EEG       - if single file, return EEG not file summary
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
defaultKeyword      = '';
defaultChanXml      = 'cfg_htpEegSystems.xml';
defaultSubDirOn     = false;
defaultDryrun       = true;
defaultOutputDir    = tempdir;
defaultNetType      = 'undefined';
defaultListing      = false;
defaultNotKeyword   = false;

validateExt = @( ext ) ischar( ext ) & all(ismember(ext(1), '.'));
validateFileOrFolder = @( filepath ) isfolder(filepath) | exist(filepath, 'file');
% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'filepath', validateFileOrFolder)
addParameter(ip,'ext', defaultExt, validateExt)
addParameter(ip,'keyword', defaultKeyword, @ischar)
addParameter(ip,'notKeyword', defaultNotKeyword, @islogical)
addParameter(ip,'subdirOn', defaultSubDirOn, @islogical)
addParameter(ip,'dryrun', defaultDryrun, @islogical)
addParameter(ip,'chanxml', defaultChanXml, @ischar);
addParameter(ip,'nettype', defaultNetType, @ischar);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);
addParameter(ip,'listing', defaultListing, @islogical);


parse(ip,filepath,varargin{:});

% START: Utilty code
if ip.Results.dryrun, fprintf("\n***DRY-RUN Configured. Output below shows what 'would' have occurred.\n***No file import will be performed without 'dryrun' set to false.\n"); end

% Edit EP 7/9/2022
% if ip.Results.subdirOn, filepath = fullfile(filepath, '**/'); end
filepath = fullfile(filepath);


% STEP 1: Get Net Type
if ~exist(ip.Results.chanxml,'file'), error('Channel XML File is missing. Download template from GITHUB or add to path'); end

netInfo = util_htpReadNetCatalog('nettype', ip.Results.nettype);

multiFileNetSwitch = ~isempty(regexp(netInfo.net_filter,'_','match'));

if multiFileNetSwitch
    file_ext = strrep(netInfo.net_filter,'*','');
else
    [~,~, file_ext] = fileparts(netInfo.net_filter);
end

% Prompt user to enter net type for correct import
if strcmpi('undefined',(ip.Results.nettype))
    error('Use key-value pair to specify net type (''nettype'',''EGI128'')');
end

% STEP 1: Preallocate import files and create table including output
% filenames
changeExtToSet = @( str ) strrep(str, file_ext, '.set'); % convert new filename to .set

switch exist(filepath)
    case 7
        if multiFileNetSwitch
            filelist = util_htpDirListing(filepath, 'ext', file_ext, 'subdirOn', ip.Results.subdirOn, 'keepentireext',true, ...
                'keyword', ip.Results.keyword, 'notKeyword', ip.Results.notKeyword);
        else
            filelist = util_htpDirListing(filepath, 'ext', file_ext, 'subdirOn', ip.Results.subdirOn, ...
                'keyword', ip.Results.keyword, 'notKeyword', ip.Results.notKeyword);
        end
        is_single_file = false;
    case 2
        [tmppath, tmpfile, tmpext] = fileparts(filepath);
        filelist.filename = {[tmpfile tmpext]};
        filelist.filepath = {tmppath};
        filelist = struct2table(filelist);
        is_single_file = true;
end

if ~isempty(filelist)
    filelist.success = false(height(filelist),1);
    filelist.importdate = repmat(string(timestamp), height(filelist),1);
    filelist.electype = repmat(ip.Results.nettype, height(filelist),1);
    filelist.ext = repmat(file_ext, height(filelist),1);
    outputfile_rows = varfun(changeExtToSet, filelist, 'InputVariables', {'filename'}, 'OutputFormat','cell');
    filelist.outputfile = outputfile_rows{1};
    filelist.outputdir = repmat(string(ip.Results.outputdir), height(filelist),1);
else
    results = filelist;
    warning("File List is Empty");
end

results = filelist;

if ip.Results.listing == false

    netverify_filename = fullfile(ip.Results.outputdir, [netInfo.net_name 'verify_topoplot_' timestamp '.png']);
    filelist_filename = fullfile(ip.Results.outputdir, ['filelist_' netInfo.net_name '_' timestamp '.csv']);

    % Summary Message
    fprintf('\n [Visual HTP EEG Import to SET]\n-Input Dir: %s\n-Ext: %s\n-Total Files: %d\n-Preset:%s\n-Output Dir: %s\n\n',...
        ip.Results.filepath, file_ext, height(filelist), ip.Results.nettype, ip.Results.outputdir);

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

            case 'BVNIRS'
                % placeholder for import function
                % htpDoctor plugin for BV import
                % channel file is BV_nirs_31.sfp 

            case 'EGI64'
                try EEG = pop_readegi(original_file);
                catch, error('Check if EEGLAB 2021 is installed'); end

                locs = readlocs(netInfo.net_file);
                locs(1).type = 'FID'; locs(2).type = 'FID'; locs(3).type = 'FID';
                %Remove just the file identifiers for non-ref datasets
                %Otherwise remove file identifiers and ref
                if mod(EEG.nbchan,2) ~= 0
                    chaninfo.nodatchans = locs([1 2 3]);
                    locs([1 2 3]) = [];
                else
                    locs(end).type = 'REF';
                    chaninfo.nodatchans = locs([1 2 3 end]);
                    locs([1 2 3 end]) = [];
                end

                chaninfo.filename = netInfo.net_file;
                EEG.chanlocs = locs;
                EEG.urchanlocs = locs;
                EEG.chaninfo = chaninfo;


            case 'EGI32'
                try EEG = pop_readegi(original_file);
                catch, error('Check if EEGLAB 2021 is installed'); end

                locs = readlocs(netInfo.net_file);
                locs(1).type = 'FID'; locs(2).type = 'FID'; locs(3).type = 'FID';
                %Remove just the file identifiers for non-ref datasets
                %Otherwise remove file identifiers and ref
                if mod(EEG.nbchan,2) ~= 0
                    chaninfo.nodatchans = locs([1 2 3]);
                    locs([1 2 3]) = [];
                else
                    locs(end).type = 'REF';
                    chaninfo.nodatchans = locs([1 2 3 end]);
                    locs([1 2 3 end]) = [];
                end

                chaninfo.filename = netInfo.net_file;
                EEG.chanlocs = locs;
                EEG.urchanlocs = locs;
                EEG.chaninfo = chaninfo;
                
            case 'MEA30'
                % chan 2 is reference
                % chan 32 EDF is reference
                % chan 33 EDF is piezo

                try
                    datafile =  filelist.filename{i};
                    folder = filelist.filepath{i};

                    edfFile = fullfile(folder, datafile);

                    % using remap function for Neuronexus
                    EEG = util_htpImportAndRemapMea( edfFile );

                    EEG.filename = datafile;
                    % EEG.chaninfo.filename = 'meachanlocs.mat';

                catch e
                    error('MEA EDF Import Failed.')
                end

               % chaninfo.filename = netInfo.net_file;
               % EEG.chaninfo   = chaninfo;


            case 'MEA30XDAT'
                % chan 2 is reference
                % chan 32 EDF is reference
                % chan 33 EDF is piezo
    
                try
                    datafile =  filelist.filename{i};
                    folder = filelist.filepath{i};
                    
                    xdatfile = fullfile(folder, datafile);
                      
                    % using remap function for Neuronexus
                    EEG = util_htpImportAndRemapMea( xdatfile );
    
                    EEG.filename = datafile;
                    % EEG.chaninfo.filename = 'meachanlocs.mat';
    
                catch e
                    error('MEA EDF Import Failed.')
                end
    
               % chaninfo.filename = netInfo.net_file;
               % EEG.chaninfo   = chaninfo;

            case 'EDFGENERIC'
                try
                    datafile =  filelist.filename{i};
                    folder = filelist.filepath{i};
                    edfFile = fullfile(folder, datafile);
                    EEG = pop_biosig( edfFile );
                catch e
                    error('EDF Import Failed.')
                end
            
            case 'SET'
                try
                    datafile =  filelist.filename{i};
                    folder = filelist.filepath{i};
                    % setFile = fullfile(folder, datafile);
                    EEG = pop_loadset(datafile, folder);
                catch e
                    error('SET Import Failed.')
                end  

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
            if isnumeric(EEG.event(1).type)
                event_code_str = cellfun(@(x) num2str(x), {EEG.event.type}, 'uni',0);
                event_codes = strjoin(unique(event_code_str),'__');
            else
            event_codes = strjoin(unique({EEG.event.type}),'__');
            end
        else
            has_events = false;
            event_codes = [];
        end

        setinfo = cell2table({filelist.outputfile(i) ip.Results.nettype file_ext timestamp EEG.nbchan EEG.trials EEG.pnts EEG.srate EEG.xmin ...
            EEG.xmax EEG.ref has_events numel(EEG.event) event_codes filelist.outputfile{i} filelist.outputdir(i) ...
            EEG.subject filelist.filename{i} filelist.filepath{i}...
            }, ...
            'VariableNames', {'setname','nettype','raw_fmt','import_date', 'raw_nbchan','raw_trials','raw_pnts','raw_srate','raw_xmin', ...
            'raw_xmax','raw_ref','raw_has_events','raw_no_events','raw_event_codes','raw_filename','raw_filepath','raw_subject', 'source_file','source_path'});

        EEG.vhtp.inforow = setinfo;



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
            if EEG.nbchan > 20
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

        % Return EEG if single file, if not, EEG is cleared
        if is_single_file
            results = EEG;
        else
            % Outputs:
            results = filelist;
            writetable(filelist, filelist_filename);
        end

    end
end


end