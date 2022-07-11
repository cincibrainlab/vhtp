function [results] = util_htpImportMea( filepath, varargin )
% utility_htpImportMea() - main import function
%
% Usage:
%    >> [ results ] = util_htpImportMea( filepath, varargin )
%
% Example:
%    >> [results] = util_htpImportMea('/srv/rawdata/', 'nettype','EGI128', 'outputdir', '/srv/outputdata', 'dryrun', false )
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

netInfo = util_htpReadNetCatalog('nettype', ip.Results.nettype);

% Prompt user to enter net type for correct import
if strcmpi('undefined',(ip.Results.nettype))
    error('Use key-value pair to specify net type (''nettype'',''EGI128'')');
end

% STEP 1: Preallocate import files and create table including output
% filenames
changeExtToSet = @( str ) strrep(str, ip.Results.ext, '.set'); % convert new filename to .set

filelist = util_htpDirListing(filepath, 'ext', ip.Results.ext, 'subdirOn', ip.Results.subdirOn);

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
        case 'MEA30'
            try
                datafile =  filelist.filename{i};
                folder = filelist.filepath{i};
                
                edfFile = fullfile(folder, datafile);

                EEG = eeg_htpMeaImportAndRemapEdf( edfFile );
                
                try EEG = pop_biosig( edfFile );
                catch, error('Check if EEGLAB 2021 is installed'); end


                if EEG.nbchan == 33
                    EEG = pop_select( EEG, 'nochannel', [2,32,33]);
                elseif EEG.nbchan == 32
                    EEG = pop_select( EEG, 'nochannel', [2,32]);
                end


                
                try
                load('mea3d.mat', 'chanlocs');
                catch
                  error('mea3d.mat file missing'); 
                end
                
                chanlocs(31) = [];
                EEG.chanlocs = chanlocs;
                EEG = eeg_checkset( EEG );
                
                % clear chanlocs;
                
                %EEG = pop_select( EEG,'channel',{'17' '16' '15' '14' '19' '18' '13' '12' '21' '20' '11' ...
                %    '10' '24' '23' '22' '9' '8' '7' '27' '26' '25' '6' '5' '4' '30' '29' '28' '3' '2' '1'});
                
                % based on the revised NN remap provided by Carrie Jonak
                % (Channel remap.jpg)
                
                %EEG = pop_select( EEG,'channel',{'1','3','4','5','6','7','8','9','10', ...
                %                     '11','12','13','14','15','16','17','18','19','20','21','22','23','24', ...
                %                     '25','26','27','28','29','30','31'});
                %
                %
                %                 '17' '16' '15' '14' '19' '18' '13' '12' '21' '20' '11' ...
                %                     '10' '24' '23' '22' '9' '8' '7' '27' '26' '25' '6' '5' '4' '30' '29' '28' '3' '2' '1'});
                
                
                swCHANNEL = 0;
                swRESAMPLE  = 0;
                EEG.filename = datafile;
                EEG.chaninfo.filename = 'meachanlocs.mat';
                EEG = eeg_checkset(EEG);

            catch e
                throw(e);
            end
            chaninfo.filename = netInfo.net_file;
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
    
    setinfo = cell2table({filelist.outputfile(i) ip.Results.nettype ip.Results.ext timestamp EEG.nbchan EEG.trials EEG.pnts EEG.srate EEG.xmin ...
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
        f = figure;
        topoplot([],EEG.chanlocs, 'style', 'blank', 'drawaxis', 'off', 'electrodes', ...
            'labelpoint', 'plotrad', [], 'headrad', 0, 'chaninfo', EEG.chaninfo, 'whitebk', 'on');
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