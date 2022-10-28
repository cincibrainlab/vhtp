function [results] = util_htpParadigmRun(filepath, presets, process, varargin)
% EP Edits
% useFileList - t/f filepath is a preexisting file list rather than a
% directory

% util_htpParadigmRun() - main Processing function to execute
%                         user-defined/selected steps
%
% Usage:
%    >> [ results ] = util_htpParadigmRun( EEG, varargin )
%
% Example:
%    >> [results] = util_htpParadigmRun('/srv/rawdata/, 'nettype','EGI128', 'outputdir', '/srv/outputdata', 'dryrun', false )
%
% Require Inputs:
%     filepath     - directory to get file list
%     presets      - channel input type
%     process      - Processing mode selected by user
%
% Function Specific Inputs:
%     'ext'          - specify file extenstion
%     'keyword'      - keyword search
%     'subdirOn'     - (true/false) search subdirectories
%     'dryrun'       - no actual changes to disk, default: true
%     'chanxml'      - specify channel catalog xml
%     'outputdir'    - output path (default: tempdir)
%     'useFileList' - pre-existing filelist rather than a directory
%     'analysisMode' - false/true to determine if analysis pathway is used 
%
% Common Visual HTP Inputs:
%     'pathdef' - file path variable
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

if nargin < 1
   fprintf('\nutil_htpParadigmRun\nPlease see comments for instructions on use.\n')
   return;
end


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
defaultUseFileList = false;
defaultAnalysisMode = false;


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
addParameter(ip, 'useFileList', defaultUseFileList,@islogical);
addParameter(ip, 'analysisMode', defaultAnalysisMode,@islogical);


parse(ip,filepath,presets,process,varargin{:});

stepnames = structfun(@(x) getfield(x,'function'),presets,'UniformOutput',false);
step_labels = fields(stepnames);

switch exist(filepath)
    case 7
        filelist = util_htpDirListing(filepath, 'ext', ip.Results.ext, 'subdirOn', ip.Results.subdirOn);
        if ip.Results.subdirOn
            filelist = filelist(~contains(filelist.filepath, fullfile(filepath,'preprocess')) & ~contains(filelist.filepath, fullfile(filepath,'completed')),:);
        end
        is_single_file = false;
    case 2
        [tmppath, tmpfile, tmpext] = fileparts(filepath);
        filelist.filename = {[tmpfile tmpext]};
        filelist.filepath = {tmppath};
        filelist = struct2table(filelist);
        is_single_file = true;
end

if ip.Results.analysisMode == false % two pathways to account for analysis functions
try
    for i=1:height(filelist)
        switch process
            case 'All'
                EEG = pop_loadset('filepath', filelist.filepath{i},'filename',regexprep(filelist.filename{i},ip.Results.ext,'.set'));
                if ~isfield(EEG,'vhtp') || (isfield(EEG,'vhtp') && ~isfield(EEG.vhtp,'stepPreprocessing'))
                    EEG = initializeStepProcessingHistory(EEG,fieldnames(stepnames));
                end
                processAll(EEG, stepnames,presets,ip.Results.dryrun,ip.Results.outputdir, ip.Results.stepnumbers);
                fileWildcard = sprintf('%s.*',string(regexp(filelist.filename{i},'^[^.]+','match')));
                movefile(fullfile(char(filelist.filepath(i)),fileWildcard),fullfile(char(filelist.filepath(i)),'completed'));
            case 'IndividualStep'
                EEG = pop_loadset('filepath', filelist.filepath{i},'filename',filelist.filename{i}); 
                if ~isfield(EEG,'vhtp') || (isfield(EEG,'vhtp') && ~isfield(EEG.vhtp,'stepPreprocessing'))
                    EEG = initializeStepProcessingHistory(EEG,fieldnames(stepnames));
                end
                % modified by EP
                if numel(ip.Results.stepnumbers) == 1
%                     processIndividualStep(EEG,ip.Results.individualstep,stepnames,presets,...
%                         ip.Results.dryrun,ip.Results.outputdir,ip.Results.stepnumbers);
                    processIndividualStep(EEG, step_labels{ip.Results.stepnumbers},stepnames,presets,...
                        ip.Results.dryrun,ip.Results.outputdir,ip.Results.stepnumbers);
                else
                    if numel(ip.Results.stepnumbers) > 1
                        processRerunStep(EEG,stepnames,presets,ip.Results.dryrun,ip.Results.outputdir,ip.Results.stepnumbers);
                    end
                end
                fileWildcard = sprintf('%s.*',string(regexp(filelist.filename{i},'^[^.]+','match')));
                movefile(fullfile(char(filelist.filepath(i)),fileWildcard),fullfile(char(filelist.filepath(i)),'completed'));
            case 'Continuation'
                EEG = pop_loadset('filepath',filelist.filepath{i},'filename',regexprep(filelist.filename{i},ip.Results.ext,'.set'));
                if ~isfield(EEG,'vhtp') || (isfield(EEG,'vhtp') && ~isfield(EEG.vhtp,'stepPreprocessing'))
                    EEG = initializeStepProcessingHistory(EEG,fieldnames(stepnames));
                end
                processRerunStep(EEG,stepnames,presets,ip.Results.dryrun,ip.Results.outputdir,ip.Results.stepnumbers);
                fileWildcard = sprintf('%s.*',string(regexp(filelist.filename{i},'^[^.]+','match')));
                movefile(fullfile(char(filelist.filepath(i)),fileWildcard),fullfile(char(filelist.filepath(i)),'completed'));
            otherwise
        end 
        if isfield(EEG.etc,'lastOutputDir')
            results.last_output_directory = EEG.etc.lastOutputDir;
        else
            results.last_output_directory = [];
        end
        EEG = eeg_emptyset;
    end
catch e 
    throw(e)
end

else
    % Analysis loop
    stepnumbers = ip.Results.stepnumbers;
    for i=1:height(filelist)
        EEG = pop_loadset('filename',fullfile(filelist.filepath(i),filelist.filename(i)));

        all_steps = fieldnames(stepnames);
        sel_steps = stepnumbers;
        for si =1:length(stepnumbers)

            sel_step_index = stepnumbers(si);
            processRerunStep(EEG,stepnames,presets,ip.Results.dryrun,ip.Results.outputdir, stepnumbers);

%             EEG = runAnalysisStep(EEG, ...
%                 options.(all_steps{sel_step_index}), ...
%                 steps{sel_step_index}, ...
%                 stepnames.(steps{sel_step_index}),...
%                 dryrun, ...
%                 newoutputdir, ...
%                 stepnumbers(sel_step_index));
        end

    end

end

end

function process_analysis_steps(EEG,stepnames,options,dryrun,outputdir, stepnumbers)
    steps =fieldnames(stepnames);
    for i =1:length(stepnumbers)
        current_step = stepnumbers(i);
        newoutputdir = fullfile(outputdir,char(stepnames.(steps{current_step})));
        EEG = runStep(EEG, options.(steps{current_step}), steps{current_step}, stepnames.(steps{current_step}), dryrun, newoutputdir, stepnumbers(current_step));
    end
end

function [EEG]=runAnalysisStep(EEG, params, step, functionName, dryRun,outputdir, stepNumber)
    inputs = [fieldnames(params).'; struct2cell(params).'];
    inputs = inputs(:).';
    prior_file = EEG.filename;
    
    EEG = functionName(EEG,inputs{3:end});
    EEG.vhtp.stepPreprocessing.(step) = true;
    EEG.vhtp.prior_file = prior_file;
    if ~dryRun && (isfield(params,'saveoutput') && params.saveoutput == 1)
        EEG.filename = [regexprep(EEG.subject,'.set','') '_' step '.set'];
        EEG.vhtp.stepPlacement = stepNumber;
        if ~exist(outputdir,'dir')
            mkdir(outputdir);
        end
        pop_saveset(EEG,'filename', EEG.filename, 'filepath', outputdir);
    end
end

function [EEG]=runStep(EEG, params, step, functionName, dryRun,outputdir, stepNumber)
    inputs = [fieldnames(params).'; struct2cell(params).'];
    inputs = inputs(:).';
    prior_file = EEG.filename;
    EEG.vhtp.currentStep = step; 
    if dryRun && ~isempty(find(strcmp(inputs,'saveoutput')))
        inputs{find(strcmp(inputs,'saveoutput'))+1} = false;
    end
    EEG = functionName(EEG,inputs{3:end});
    if ~EEG.vhtp.stepPreprocessing.(step)
        EEG.vhtp.stepPreprocessing.(step) = true;
    end
    EEG.vhtp.prior_file = prior_file;
    if ~dryRun && (isfield(params,'saveoutput') && params.saveoutput == 1)
        if ~isempty(EEG.subject)
            EEG.filename = [regexprep(EEG.subject,'.set','') '_' step '.set'];
        else
            EEG.subject = EEG.filename;
            EEG.filename = [regexprep(EEG.filename,'.set','') '_' step '.set'];
        end
        EEG.vhtp.stepPlacement = stepNumber;
        if ~exist(outputdir,'dir')
            mkdir(outputdir);
        end
        EEG.etc.lastOutputDir = outputdir;
        pop_saveset(EEG,'filename', EEG.filename, 'filepath', outputdir);
    end

end

function processAll(EEG,stepnames,options,dryrun,outputdir,stepnumbers)
    steps =fieldnames(stepnames);
    for i =1:length(steps)
        newoutputdir = fullfile(outputdir,char(stepnames.(steps{i})));
        EEG = runStep(EEG, options.(steps{i}), steps{i}, ...
            stepnames.(steps{i}), dryrun,newoutputdir, stepnumbers(i));
    end
end

function processIndividualStep(EEG,individualstep,stepnames,options,dryrun,outputdir,stepnumber)
    if ~isempty(individualstep)
        EEG = runStep(EEG,options.(individualstep),individualstep,stepnames.(individualstep),dryrun,outputdir,stepnumber);
    end
    
end

function processRerunStep(EEG,stepnames,options,dryrun,outputdir, stepnumbers)
    steps =fieldnames(stepnames);
    for i =1:length(stepnumbers)
        %current_step = stepnumbers(i);
        newoutputdir = fullfile(outputdir,char(stepnames.(steps{i})));
        EEG = runStep(EEG, options.(steps{i}), steps{i}, stepnames.(steps{i}), dryrun, newoutputdir, stepnumbers(i));
    end
end

function EEG = initializeStepProcessingHistory(EEG,stepnames)
    EEG.vhtp.stepPreprocessing = struct();
    for i=1:length(stepnames)
        EEG.vhtp.stepPreprocessing.(stepnames{i}) = false;
    end
end

