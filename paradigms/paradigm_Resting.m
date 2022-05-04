function [results] = paradigm_Resting(filepath, presets, process, varargin)
% paradigm_Resting() - main import function
%
% Usage:
%    >> [ results ] = paradigm_Resting( EEG, varargin )
%
% Example:
%    >> [results] = util_htpImportEeg('/srv/rawdata/, 'nettype','EGI128', 'outputdir', '/srv/outputdata', 'dryrun', false )
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
defaultExt          = '.set';
defaultKeyword      = [];
defaultSubDirOn     = false;
defaultDryrun       = true;
defaultOutputDir    = tempdir;
defaultIndividualStep = '';
defaultRerunStep = '';
defaultRerunSourceStep='';


validateProcess = @( process ) ismember(process,{'All','Rerun', 'IndividualStep'});

validateFileOrFolder = @( filepath ) isfolder(filepath) | exist(filepath, 'file');

validateExt = @( ext ) ischar( ext ) & all(ismember(ext(1), '.'));

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip,'filepath',validateFileOrFolder);
addRequired(ip, 'presets', @isstruct);
addRequired(ip, 'process',validateProcess);
addParameter(ip,'ext', defaultExt, validateExt);
addParameter(ip,'keyword', defaultKeyword, @ischar);
addParameter(ip,'subdirOn', defaultSubDirOn, @islogical);
addParameter(ip,'dryrun', defaultDryrun, @islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);
addParameter(ip,'individualstep',defaultIndividualStep,@ischar);
addParameter(ip,'rerunstep',defaultRerunStep,@ischar);
addParameter(ip,'rerunsourcestep',defaultRerunSourceStep,@ischar);
parse(ip,filepath,presets,process,varargin{:});

%util_htpImportEeg(filepath,'nettype',ip.Results.nettype,'outputdir',filepath,'dryrun',false);

stepnames = structfun(@(x) getfield(x,'function'),presets,'UniformOutput',false);

switch exist(filepath)
    case 7
        filelist = util_htpDirListing(filepath, 'ext', ip.Results.ext, 'subdirOn', ip.Results.subdirOn);
        if strcmp(process,'All')
            filelist = filelist(~contains(filelist.filename, fieldnames(stepnames)),:);
        elseif strcmp(process,'Rerun')
            filelist = filelist(contains(filelist.filename, ip.Results.rerunstep),:);
        else
            filelist = filelist(:,:);
        end
        is_single_file = false;
    case 2
        [tmppath, tmpfile, tmpext] = fileparts(filepath);
        filelist.filename = {[tmpfile tmpext]};
        filelist.filepath = {tmppath};
        filelist = struct2table(filelist);
        is_single_file = true;
end

try
    for i=1:height(filelist)
        switch process
            case 'All'
                %util_htpImportEeg(filepath,'nettype',ip.Results.nettype,'outputdir',filepath,'dryrun',false);
                EEG = pop_loadset('filename',fullfile(filelist.filepath(i),regexprep(filelist.filename(i),ip.Results.ext,'.set')));
                processAll(EEG, stepnames,presets,ip.Results.dryrun,ip.Results.outputdir);
            case 'IndividualStep'
                EEG = pop_loadset('filename',fullfile(filelist.filepath(i),filelist.filename(i)));
                processIndividualStep(EEG,ip.Results.individualstep,stepnames,presets,ip.Results.dryrun,ip.Results.outputdir);
            case 'Rerun'
%                 EEG = pop_loadset('filename', filelist.filename{i}, 'filepath', filelist.filepath{i}, 'loadmode', 'info');
%                 EEG = pop_loadset('filename', fullfile(filelist.filepath{1},EEG.vhtp.prior_file));
                EEG = pop_loadset(EEG,ip.Results.rerunstep,stepnames,presets,ip.Results.dryrun,ip.Results.outputdir);
                processRerunStep(EEG,ip.Results.rerunstep,stepnames,presets,ip.Results.dryrun,ip.Results.outputdir);
            otherwise
        end
        EEG = eeg_emptyset;
    end
catch e 
    throw(e)
end

end

function [EEG]=runStep(EEG, params, step, functionName, dryRun,outputdir)
    inputs = [fieldnames(params).'; struct2cell(params).'];
    inputs = inputs(:).';
    prior_file = EEG.filename;
    
    EEG = functionName(EEG,inputs{3:end});
    if ~dryRun
        EEG.vhtp.prior_file = prior_file;
        EEG.filename = [regexprep(EEG.subject,'.set','') '_' step '.set'];
        pop_saveset(EEG,'filename',fullfile(EEG.filepath,EEG.filename));
    end
end

function processAll(EEG,stepnames,options,dryrun,outputdir)
    steps =fieldnames(stepnames);
    for i =1:length(steps)
        EEG = runStep(EEG, options.(steps{i}), steps{i}, stepnames.(steps{i}), dryrun,outputdir);
    end
end

function processIndividualStep(EEG,individualstep,stepnames,options,dryrun,outputdir)
    if ~isempty(individualstep)
        EEG = runStep(EEG,options.(individualstep),individualstep,stepnames.(individualstep),dryrun,outputdir);
    end
    
end

function processRerunStep(EEG,rerunstep,stepnames,options,dryrun,outputdir)
    if ~isempty(rerunstep)
        EEG = runStep(EEG,options.(rerunstep),rerunstep,stepnames.(rerunstep),dryrun,outputdir);
    end
    
end

