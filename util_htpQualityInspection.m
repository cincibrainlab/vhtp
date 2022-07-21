function [results] = util_htpQualityInspection(filepath, presets,varargin)
% util_htpQualityInspection() - main inspection function
%
% Usage:
%    >> [ results ] = util_htpQualityInspection( filepath, presets, varargin )
%
% Example:
%    >> [results] = util_htpQualityInspection('/srv/rawdata/, 'nettype','EGI128', 'outputdir', '/srv/outputdata', 'dryrun', false )
%
% Require Inputs:
%     filepath       - directory to get file list
%     'presets'      - List of steps to take in the inspection routine
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

validateFileOrFolder = @( filepath ) isfolder(filepath) | exist(filepath, 'file');

validateExt = @( ext ) ischar( ext ) & all(ismember(ext(1), '.'));

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip,'filepath',validateFileOrFolder);
addRequired(ip, 'presets', @isstruct);
addParameter(ip,'ext', defaultExt, validateExt);
addParameter(ip,'keyword', defaultKeyword, @ischar);
addParameter(ip,'subdirOn', defaultSubDirOn, @islogical);
addParameter(ip,'dryrun', defaultDryrun, @islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

parse(ip,filepath,presets,varargin{:});

try 
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
    results=table('Size',[height(filelist),3],'VariableNames',{'File','Validation_Result','Fail_Reason'},'VariableTypes',{'string','string','string'});
    for i=1:height(filelist)
        EEG = pop_loadset('filename',fullfile(filelist.filepath(i),regexprep(filelist.filename(i),ip.Results.ext,'.set')));
        %EEG.vhtp.qi.type = presets.type;
        steps = fieldnames(presets);
%         if ~isfield(EEG.vhtp,'qi')
%             EEG.vhtp.qi.failreason = [];
%         end
        EEG.vhtp.qi.failreason = [];
        for j=1:length(fieldnames(presets))
            switch steps{j}
                case 'channel_montage'
                    EEG = channelMontageCheck(EEG,presets.(steps{j}));
                case 'file_duration'
                    EEG = durationCheck(EEG,presets.(steps{j}));
                case 'face_leads'
                    EEG = faceLeadCheck(EEG,presets.(steps{j}));
                case 'din_name'
                    EEG = dinNameCheck(EEG,presets.(steps{j}));
                case 'din_interval'
                    EEG = dinIntervalCheck(EEG,presets.(steps{j}));
                case 'custom_trial'
                    EEG = customTrial(EEG,presets.(steps{j}));

            end
        end
        results(i,1).File = filelist.filename(i);
        if isempty(EEG.vhtp.qi.failreason)  
            results(i,2).Validation_Result = "Passed"; 
            results(i,3).Fail_Reason = "N/A";
        else 
            results(i,2).Validation_Result = "Failed"; 
            results(i,3).Fail_Reason = strjoin(EEG.vhtp.qi.failreason,', ');
        end 
        

    end



catch e
    throw(e)
end

end

function EEG=channelMontageCheck(EEG,params)
    channeltimestamp    = datestr(now,'yymmddHHMMSS');  % timestamp 
    if strcmp(params.nettype,'EGI128')
        locs = readlocs(params.netfile);
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
        end
        locsfields = fieldnames(locs);
        eegfields = fieldnames(EEG.chanlocs);
        locs = rmfield(locs,locsfields(~ismember(fieldnames(locs),fieldnames(EEG.chanlocs))));
        chanstemp = rmfield(EEG.chanlocs,eegfields(~ismember(fieldnames(EEG.chanlocs),fieldnames(locs))));
        if isequal(locs,chanstemp)
            EEG.vhtp.qi.channelmontage.passed = 1;
        else
            EEG.vhtp.qi.channelmontage.passed = 0;
            EEG.vhtp.qi.failreason = [EEG.vhtp.qi.failreason; "Channel Montage"];
        end
    elseif strcmp(params.nettype,'MEA30')
        locs = readtable(params.netfile);
        eegfields = fieldnames(EEG.chanlocs);
        locs = removevars(locs,~ismember(locs.Properties.VariableNames,eegfields));
        locs = table2struct(locs);
        chanstemp = rmfield(EEG.chanlocs,eegfields(~ismember(eegfields,fieldnames(locs))));
        if isequal(locs,chanstemp)
            EEG.vhtp.qi.channelmontage.passed = 1;
        else
            EEG.vhtp.qi.channelmontage.passed = 0;
            EEG.vhtp.qi.failreason = [EEG.vhtp.qi.failreason,"Channel Montage"];
        end
    end
    EEG.vhtp.qi.channelmontage.timestamp = channeltimestamp;

end

function EEG=durationCheck(EEG,params)
    durationtimestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
    if EEG.xmax < params.duration
        EEG.vhtp.qi.duration.passed = 0;
        EEG.vhtp.qi.duration.difference = abs(duration-EEG.xmax);
        EEG.vhtp.qi.failreason = [EEG.vhtp.qi.failreason,"Duration"];
    else
        EEG.vhtp.qi.duration.passed = 1;
    end
    EEG.vhtp.qi.duration.timestamp = durationtimestamp;
end

function EEG=faceLeadCheck(EEG,params)
    faceleadtimestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
    if params.present
        EEG.vhtp.qi.faceleads.present = 1;
        if strcmp(params.handling,'remove')
            EEG = pop_select(EEG,'nochannel',params.channelnums);
            EEG=eeg_checkset(EEG);
            EEG.vhtp.qi.faceleads.method = 'remove';
            EEG.vhtp.qi.faceleads.faceleadchans = params.channelnums;
        else
            EEG = pop_interp(EEG,badchannels,params.interpmethod);
            EEG=eeg_checkset(EEG);
            EEG.vhtp.qi.faceleads.method = 'interpolate';
            EEG.vhtp.qi.faceleads.faceleadchans = params.channelnums;
        end
        EEG.vhtp.qi.faceleads.timestamp = faceleadtimestamp;
    end
end

function EEG=dinNameCheck(EEG, params)
    events = {EEG.event(:).type};
    %present = ismember(params.events,events);
    if all(ismember(params.events,events))
        EEG.vhtp.qi.eventnames.passed = 1;
    else
        EEG.vhtp.qi.eventnames.passed=0;
        EEG.vhtp.qi.eventnames.missing = params.events(~ismember(params.events,events));
        EEG.vhtp.qi.failreason = [EEG.vhtp.qi.failreason,"Din Names"];
    end
end

function EEG=dinIntervalCheck(EEG,params)
    dinintervaltimestamp = datestr(now,'yymmddHHMMSS');  % timestamp
    events = unique({EEG.event(:).type});
    events = events(ismember(events,params.events));
    for i=1:length(events)
        indices(i,:) = find(strcmp(events(i),{EEG.event(:).type}));
        intervals(i) = mean([EEG.event(indices(i,:)).latency]-[EEG.event(indices(i,:)-1).latency],'omitnan');
        if abs(intervals(i)-params.intervals{i})>params.threshold
            failed=1;
        end
    end
    if failed
        EEG.vhtp.qi.dininterval.swapped = 1;
        EEG.vhtp.qi.failreason = [EEG.vhtp.qi.failreason, "Din Intervals"];
    else
        EEG.vhtp.qi.dininterval.swapped=0; 
    end
    EEG.vhtp.qi.dininterval.timestamp = dinintervaltimestamp;
end

function EEG=customTrial(EEG,params)
    customtrialtimestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
    events = find(strcmp({EEG.event(:).type},params.event));
    if params.distractorpresent
        distractors = find({EEG.event(:).type},distractorevent);
        remove = distractors+1;
        nondistractors = setdiff(events,remove);
        trueIndex = union(distractors,nondistractors);
    else
        trueIndex = events;
    end
    %indexNum1 = find(strcmp({EEG.event.type},'DSTR')); % look for distractor trials - this is the start of distractor trials
    %indexNum2 = find(strcmp({EEG.event.type},'DIN8')); % not all have distractors, look for stim onsets
    %remove=indexNum1+1; % find stim onsets that will already be numbered based on distractor
    %remove = distractors+1;
    %indexNum3=setdiff(indexNum2,remove); % find stim onsets that do NOT have distractors - this is the start of non-distractor trials
    %nondistractors = setdiff(events,remove);
    %indexNum=union(indexNum1, indexNum3); % combine the lists of trial onsets
    %trueIndex = union(distractors,nondistractors);
    %trialNum = num2cell([1:length(indexNum)]);
    trialNum = num2cell([1:length(trueIndex)]);
    %[EEG.event(indexNum).behavioraltrial] = deal(trialNum{:});
    [EEG.event(trueIndex).behavioraltrial] = deal(trialNum{:});
    for j=1:length(trueIndex); behavioralTrialNum = EEG.event(trueIndex(j)).behavioraltrial; 
        if j~=length(trueIndex); [EEG.event(trueIndex(j):indexNum(j)+(diff(trueIndex(j:j+1))-1)).behavioraltrial] = deal(behavioralTrialNum); %edited by LAD to change 50 to indexNum
        else 
            [EEG.event(trueIndex(j):length(EEG.event)).behavioraltrial] = deal(behavioralTrialNum); 
        end 
    end
    EEG = eeg_checkset(EEG);
    %pop_saveset( EEG, 'filename', fullfile(files(i).folder,files(i).name));
    validationResults = max([EEG.event(:).behavioraltrial])==params.number;
    EEG.vhtp.qi.customtrial.timestamp = customtrialtimestamp;
end

