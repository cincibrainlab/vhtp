function util_htpExportBids(filepath,presets,varargin)
% util_htpExportBids() - Function to export core processed files to bids
%                        directory
%
% Usage:
%    >> util_htpExportBids( filepath,presets, varargin )
%
% Example:
%    >> util_htpExportBids('/srv/rawdata/, parameter_struct_var, 'subdirOn',0,'ext','.set', 'outputdir', '/srv/outputdata', 'paradigm', 'Resting' )
%
% Require Inputs:
%     filepath     - directory to get file list
%     presets      - structure containing user-defined parameters for bids
%                    export
%
% Function Specific Inputs:
%     'ext'          - specify file extenstion
%     'subdirOn'     - (true/false) search subdirectories
%     'outputdir'    - output path (default: tempdir)
%     'paradigm'     - Name of paradigm matching subdirectory for processed
%                      files
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

defaultExt = [];
defaultSubDirOn = false;
defaultOutputDir    = tempdir;
defaultParadigm = 'missing_paradigm_name_placeholder';

validateExt = @( ext ) ischar( ext ) & all(ismember(ext(1), '.'));

% MATLAB built-in input validation
ip = inputParser();  
ip.StructExpand = 0;
addRequired(ip, 'filepath', @isfolder)
addRequired(ip,'presets',@isstruct)
addParameter(ip,'ext', defaultExt, validateExt)
addParameter(ip,'subdirOn', defaultSubDirOn, @islogical)
addParameter(ip,'outputdir', defaultOutputDir, @ischar)
addParameter(ip,'paradigm',defaultParadigm,@ischar)

parse(ip, filepath,presets,varargin{:})


switch exist(filepath)
        case 7
            filelist = util_htpDirListing(filepath, 'ext', ip.Results.ext, 'subdirOn', ip.Results.subdirOn);
            if ip.Results.subdirOn
                filelist = filelist(~contains(filelist.filepath, fullfile(filepath,'preprocess')),:);
            end
            is_single_file = false;
        case 2
            [tmppath, tmpfile, tmpext] = fileparts(filepath);
            filelist.filename = {[tmpfile tmpext]};
            filelist.filepath = {tmppath};
            filelist = struct2table(filelist);
            is_single_file = true;
end

data = populateData(filelist);
presets.targetdir = ip.Results.outputdir;
inputs = {'targetdir','taskName','gInfo','README','CHANGES','stimuli','pInfo','eInfo','eInfoDesc','cInfo','cInfoDesc','renametype','trialtype','tInfo','chanlocs'};
params=findParams(presets,inputs);
bids_export(data, params);
finaloutput = fullfile(ip.Results.outputdir, 'derivatives',ip.Results.paradigm);
if ~exist(finaloutput,"dir")
    mkdir(finaloutput);
end
copyfile(fullfile(filepath,'preprocess',ip.Results.paradigm),finaloutput)

end

function data = populateData(filelist)
    data = struct();
    for i=1:height(filelist)
            data(i).file = fullfile(filelist.filepath(i),filelist.filename(i)); 
    end

end

function params=findParams(presets,inputs)
    fields = fieldnames(presets);
    for i=1:length(fields)
        stepinput = inputs(ismember(lower(inputs),lower(fields{i})));
        if ~isempty(stepinput)
            params.(stepinput{:}) = presets.(fields{i});
        end
    end
end