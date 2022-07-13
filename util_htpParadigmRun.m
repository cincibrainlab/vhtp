function [results] = util_htpParadigmRun(filepath, presets, process, varargin)
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
defaultStepNumbers=[];


validateProcess = @( process ) ismember(process,{'All','Continuation', 'IndividualStep'});

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
addParameter(ip,'continuationstep',defaultRerunStep,@ischar);
addParameter(ip, 'stepnumbers',defaultStepNumbers,@isnumeric);

parse(ip,filepath,presets,process,varargin{:});

stepnames = structfun(@(x) getfield(x,'function'),presets,'UniformOutput',false);

switch exist(filepath)
    case 7
        filelist = util_htpDirListing(filepath, 'ext', ip.Results.ext, 'subdirOn', ip.Results.subdirOn);
        if ip.Results.subdirOn
            filelist = filelist(~contains(filelist.filepath, fullfile(filepath,'preprocess')),:);
        end
%         if strcmp(process,'All')
%             filelist = filelist(~contains(filelist.filename, fieldnames(stepnames)),:) ;
%         elseif strcmp(process,'Continuation')
%             filelist = filelist(~contains(filelist.filename, fieldnames(stepnames)),:);
%         else
%             filelist = filelist;
%         end
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
                EEG = pop_loadset('filename',fullfile(filelist.filepath(i),regexprep(filelist.filename(i),ip.Results.ext,'.set')));
                if ~isfield(EEG.vhtp,'stepPreprocessing')
                    EEG = initializeStepProcessingHistory(EEG,fieldnames(stepnames));
                end
                processAll(EEG, stepnames,presets,ip.Results.dryrun,ip.Results.outputdir,ip.Results.stepnumbers);
            case 'IndividualStep'
                EEG = pop_loadset('filename',fullfile(filelist.filepath(i),filelist.filename(i)));
                if ~isfield(EEG.vhtp,'stepPreprocessing')
                    EEG = initializeStepProcessingHistory(EEG,fieldnames(stepnames));
                end
                processIndividualStep(EEG,ip.Results.individualstep,stepnames,presets,ip.Results.dryrun,ip.Results.outputdir,ip.Results.stepnumbers);
            case 'Continuation'
                EEG = pop_loadset('filename',fullfile(filelist.filepath(i),regexprep(filelist.filename(i),ip.Results.ext,'.set')));
                if ~isfield(EEG.vhtp,'stepPreprocessing')
                    EEG = initializeStepProcessingHistory(EEG,fieldnames(stepnames));
                end
                processRerunStep(EEG,stepnames,presets,ip.Results.dryrun,ip.Results.outputdir,ip.Results.stepnumbers);
            otherwise
        end
        EEG = eeg_emptyset;
    end
catch e 
    throw(e)
end

end

function [EEG]=runStep(EEG, params, step, functionName, dryRun,outputdir, stepNumber)
    inputs = [fieldnames(params).'; struct2cell(params).'];
    inputs = inputs(:).';
    prior_file = EEG.filename;
    
    EEG = functionName(EEG,inputs{3:end});
    EEG.vhtp.stepPreprocessing.(step) = true;
    EEG.vhtp.prior_file = prior_file;
    if ~dryRun && (isfield(params,'saveoutput') && params.saveoutput == 1)
        EEG.filename = [regexprep(EEG.subject,'.set','') '_' step '.set'];
        EEG.vhtp.stepPlacement = stepNumber;
        pop_saveset(EEG,'filename',fullfile(outputdir,EEG.filename));
    end
end

function processAll(EEG,stepnames,options,dryrun,outputdir,stepnumbers)
    steps =fieldnames(stepnames);
    for i =1:length(steps)
        newoutputdir = fullfile(outputdir,char(stepnames.(steps{i})));
        EEG = runStep(EEG, options.(steps{i}), steps{i}, stepnames.(steps{i}), dryrun,newoutputdir,stepnumbers(i));
    end
end

function processIndividualStep(EEG,individualstep,stepnames,options,dryrun,outputdir,stepnumber)
    if ~isempty(individualstep)
        EEG = runStep(EEG,options.(individualstep),individualstep,stepnames.(individualstep),dryrun,outputdir,stepnumber);
    end
    
end

function processRerunStep(EEG,stepnames,options,dryrun,outputdir, stepnumbers)
    steps =fieldnames(stepnames);
    for i =1:length(steps)
        newoutputdir = fullfile(outputdir,char(stepnames.(steps{i})));
        EEG = runStep(EEG, options.(steps{i}), steps{i}, stepnames.(steps{i}), dryrun,newoutputdir, stepnumbers(i));
    end
end

function EEG = initializeStepProcessingHistory(EEG,stepnames)
    EEG.vhtp.stepPreprocessing = struct();
    for i=1:length(stepnames)
        EEG.vhtp.stepPreprocessing.(stepnames{i}) = false;
    end
end

