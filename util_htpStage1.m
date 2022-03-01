function [results] = util_htpStage1(filepath,varargin)
%UTIL_HTPSTAGE1 Summary of this function goes here
%   Detailed explanation goes here

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

defaultExt          = '.set';
defaultHighPass = [];
defaultLowPass = [];
defaultNotch = [];
defaultCleanline = false;
defaultKeyword      = [];
defaultSubDirOn     = false;
defaultDryrun       = true;
defaultPresetXml = 'cfg_htpPresets.xml';
defaultOutputDir    = tempdir;
defaultNetType      = 'undefined';
defaultResampleData = [];

validateExt = @( ext ) ischar( ext ) & all(ismember(ext(1), '.'));

ip=inputParser();
addRequired(ip, 'filepath', @isfolder)
addParameter(ip,'highpass',defaultHighPass,@isnumeric)
addParameter(ip, 'lowpass',defaultLowPass,@isnumeric)
addParameter(ip,'notch',defaultNotch,@isnumeric)
addParameter(ip,'cleanline',defaultCleanline,@islogical)
addParameter(ip,'resampleData',defaultResampleData,@isnumeric)
addParameter(ip,'ext', defaultExt, validateExt)
addParameter(ip,'keyword', defaultKeyword, @ischar)
addParameter(ip,'subdirOn', defaultSubDirOn, @islogical)
addParameter(ip,'dryrun', defaultDryrun, @islogical)
addParameter(ip,'nettype', defaultNetType, @ischar);
addParameter(ip,'presetxml', defaultPresetXml, @ischar);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

parse(ip,filepath,varargin{:});

if ip.Results.dryrun, fprintf("\n***DRY-RUN Configured. Output below shows what 'would' have occurred.\n***No file import will be performed without 'dryrun' set to false.\n"); end
if ip.Results.subdirOn, filepath = [filepath '**/']; end

filelist = util_htpDirListing(filepath, 'ext', ip.Results.ext,'subdirOn', ip.Results.subdirOn);

filelist = filelist(~contains(filelist.filename,'_S1.'),:);

if ~isempty(filelist.filename)
    filelist.success = false(height(filelist),1);
    filelist.importdate = repmat(string(timestamp), height(filelist),1);
    %filelist.electype = repmat(ip.Results.nettype, height(filelist),1);
    filelist.ext = repmat(ip.Results.ext, height(filelist),1);
    outputfile_rows = {filelist.filename};
    filelist.outputfile = outputfile_rows{1};
    filelist.outputdir = repmat(string(ip.Results.outputdir), height(filelist),1);
else
    error("File List is Empty");
end

filelist.outputfile = regexprep(filelist.outputfile,'.set','_S1.set');


fprintf('\n [Visual HTP EEG Stage 1]\n-Input Dir: %s\n-Ext: %s\n-Total Files: %d\n-Preset:%s\n-Output Dir: %s\n\n',...
    ip.Results.filepath, ip.Results.ext, height(filelist), ip.Results.ext, ip.Results.outputdir);

try 
    cfgFilename = ip.Results.presetxml;
    xmldata = ext_xml2struct( cfgFilename );
    presetList = xmldata.PresetOptions;
catch e
    throw(e)
end
for i = 1 : height(filelist)
    
    original_file = fullfile(filelist.filepath{i},filelist.filename{i});
    output_file = fullfile(filelist.outputdir{i},filelist.outputfile{i});
    EEG = pop_loadset(original_file);
    
    if ~isempty(ip.Results.highpass)
        filtOrder   = 6600;
        revFilt     = 0;
        plotFreqz   = 0;
        minPhase    = false;
        
        EEG = eeg_EegFilterEeglab(EEG,'Highpass','hipassfilt',ip.Results.highpass,'filtorder',filtOrder, 'revfilt', revFilt, 'plotfreqz',plotFreqz, 'minphase',minPhase);
    end
    if ~isempty(ip.Results.lowpass)
        filtOrder   = 3300;
        revFilt     = 0;
        plotFreqz   = 0;
        minPhase    = false;
        
        EEG = eeg_EegFilterEeglab(EEG,'Lowpass','lowpassfilt',ip.Results.lowpass);
    end
    if ~isempty(ip.Results.notch) && ip.Results.lowpass >= ip.Results.notch(2) && ~(ip.Results.cleanline)
        filtOrder   = 3300;
        revFilt     = 1;
        plotFreqz   = 0;
        minPhase    = false;
        
        EEG = eeg_EegFilterEeglab(EEG,'Notch','notch',ip.Results.notch,'filtorder',filtOrder, 'revfilt', revFilt, 'plotfreqz',plotFreqz, 'minphase',minPhase);
    end
    if (ip.Results.cleanline)
        cleanlineBandwidth = 2;
        cleanlineChanList = [1:EEG.nbchan];
        cleanlineComputePower = 0;
        cleanlineLineFreqs = [60 120 180 240 300];
        cleanlineNormSpectrum=0;
        cleanlineP=0.01;
        cleanlinePad = 2;
        cleanlinePlotFigures=0;
        cleanlineScanForLines=1;
        cleanlineSigType='Channels';
        cleanlineTau=100;
        cleanlineVerb = 1;
        cleanlineWinSize = 4;
        cleanlineWinStep = 4;
        
        EEG = eeg_htpEegFilterEeglab(EEG,'Cleanline','cleanlinebandwidth',cleanlineBandwidth,'cleanlinechanlist',cleanlineChanList,'cleanlinecomputepower',cleanlineComputePower,'cleanlinelinefreqs',cleanlineLineFreqs,...
                                        'cleanlinenormSpectrum',cleanlineNormSpectrum,'cleanlinep',cleanlineP, 'cleanlinepad',cleanlinePad,'cleanlineplotfigures',cleanlinePlotFigures,'cleanlinescanforlines',cleanlineScanForLines,...
                                        'cleanlinesigtype',cleanlineSigType, 'cleanlinetau',cleanlineTau,'cleanlineverb',cleanlineVerb, 'cleanlinewinsize', cleanlineWinSize,'cleanlinewinstep',cleanlineWinStep);
    end
    
    if ~isempty(ip.Results.resampleData)
        EEG = util_htpResampleData(EEG,ip.Results.resampleData);        
    end
    
    EEG.setname = filelist.outputfile{i};
    EEG.filename = filelist.outputfile{i};
    EEG.filepath = filelist.outputdir(i);
    EEG.subject = filelist.outputfile{i};
    
    EEG.vhtp.inforow.highpass_filt_cutoff = ip.Results.highpass;
    EEG.vhtp.inforow.lowpass_filt_cutoff = ip.Results.lowpass;
    EEG.vhtp.inforow.notch_filt = ip.Results.notch;
    EEG.vhtp.inforow.cleanline_filt = ip.Results.cleanline;
    if isempty(ip.Results.resampleData)
        EEG.vhtp.inforow.resample_srate = EEG.srate;
    else
        EEG.vhtp.inforow.resample_srate = ip.Results.resampleData;
    end
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
    
    
end

qi_table = cell2table({functionstamp, timestamp, height(filelist), ip.Results.ext}, ...
    'VariableNames', {'script','timestamp', 'nofiles', 'fileext'});

% Outputs:
results = filelist;

function [ s ] = ext_xml2struct( file )
%Convert xml file into a MATLAB structure
% [ s ] = xml2struct( file )
%
% A file containing:
% <XMLname attrib1="Some value">
%   <Element>Some text</Element>
%   <DifferentElement attrib2="2">Some more text</Element>
%   <DifferentElement attrib3="2" attrib4="1">Even more text</DifferentElement>
% </XMLname>
%
% Will produce:
% s.XMLname.Attributes.attrib1 = "Some value";
% s.XMLname.Element.Text = "Some text";
% s.XMLname.DifferentElement{1}.Attributes.attrib2 = "2";
% s.XMLname.DifferentElement{1}.Text = "Some more text";
% s.XMLname.DifferentElement{2}.Attributes.attrib3 = "2";
% s.XMLname.DifferentElement{2}.Attributes.attrib4 = "1";
% s.XMLname.DifferentElement{2}.Text = "Even more text";
%
% Please note that the following characters are substituted
% '-' by '_dash_', ':' by '_colon_' and '.' by '_dot_'
%
% Written by W. Falkena, ASTI, TUDelft, 21-08-2010
% Attribute parsing speed increased by 40% by A. Wanner, 14-6-2011
% Added CDATA support by I. Smirnov, 20-3-2012
%
% Modified by X. Mo, University of Wisconsin, 12-5-2012

if (nargin < 1)
    clc;
    help ext_xml2struct
    return
end

if isa(file, 'org.apache.xerces.dom.DeferredDocumentImpl') || isa(file, 'org.apache.xerces.dom.DeferredElementImpl')
    % input is a java xml object
    xDoc = file;
else
    %check for existance
    if (exist(file,'file') == 0)
        %Perhaps the xml extension was omitted from the file name. Add the
        %extension and try again.
        if (isempty(strfind(file,'.xml')))
            file = [file '.xml'];
        end
        
        if (exist(file,'file') == 0)
            error(['The file ' file ' could not be found']);
        end
    end
    %read the xml file
    xDoc = xmlread(file);
end

%parse xDoc into a MATLAB structure
s = parseChildNodes(xDoc);

end

% ----- Subfunction parseChildNodes -----
function [children,ptext,textflag] = parseChildNodes(theNode)
% Recurse over node children.
children = struct;
ptext = struct; textflag = 'Text';
if hasChildNodes(theNode)
    childNodes = getChildNodes(theNode);
    numChildNodes = getLength(childNodes);
    
    for count = 1:numChildNodes
        theChild = item(childNodes,count-1);
        [text,name,attr,childs,textflag] = getNodeData(theChild);
        
        if (~strcmp(name,'#text') && ~strcmp(name,'#comment') && ~strcmp(name,'#cdata_dash_section'))
            %XML allows the same elements to be defined multiple times,
            %put each in a different cell
            if (isfield(children,name))
                if (~iscell(children.(name)))
                    %put existsing element into cell format
                    children.(name) = {children.(name)};
                end
                index = length(children.(name))+1;
                %add new element
                children.(name){index} = childs;
                if(~isempty(fieldnames(text)))
                    children.(name){index} = text;
                end
                if(~isempty(attr))
                    children.(name){index}.('Attributes') = attr;
                end
            else
                %add previously unknown (new) element to the structure
                children.(name) = childs;
                if(~isempty(text) && ~isempty(fieldnames(text)))
                    children.(name) = text;
                end
                if(~isempty(attr))
                    children.(name).('Attributes') = attr;
                end
            end
        else
            ptextflag = 'Text';
            if (strcmp(name, '#cdata_dash_section'))
                ptextflag = 'CDATA';
            elseif (strcmp(name, '#comment'))
                ptextflag = 'Comment';
            end
            
            %this is the text in an element (i.e., the parentNode)
            if (~isempty(regexprep(text.(textflag),'[\s]*','')))
                if (~isfield(ptext,ptextflag) || isempty(ptext.(ptextflag)))
                    ptext.(ptextflag) = text.(textflag);
                else
                    %what to do when element data is as follows:
                    %<element>Text <!--Comment--> More text</element>
                    
                    %put the text in different cells:
                    % if (~iscell(ptext)) ptext = {ptext}; end
                    % ptext{length(ptext)+1} = text;
                    
                    %just append the text
                    ptext.(ptextflag) = [ptext.(ptextflag) text.(textflag)];
                end
            end
        end
        
    end
end
end

% ----- Subfunction getNodeData -----
function [text,name,attr,childs,textflag] = getNodeData(theNode)
% Create structure of node info.

%make sure name is allowed as structure name
name = toCharArray(getNodeName(theNode))';
name = strrep(name, '-', '_dash_');
name = strrep(name, ':', '_colon_');
name = strrep(name, '.', '_dot_');

attr = parseAttributes(theNode);
if (isempty(fieldnames(attr)))
    attr = [];
end

%parse child nodes
[childs,text,textflag] = parseChildNodes(theNode);

if (isempty(fieldnames(childs)) && isempty(fieldnames(text)))
    %get the data of any childless nodes
    % faster than if any(strcmp(methods(theNode), 'getData'))
    % no need to try-catch (?)
    % faster than text = char(getData(theNode));
    text.(textflag) = toCharArray(getTextContent(theNode))';
end

end

% ----- Subfunction parseAttributes -----
function attributes = parseAttributes(theNode)
% Create attributes structure.

attributes = struct;
if hasAttributes(theNode)
    theAttributes = getAttributes(theNode);
    numAttributes = getLength(theAttributes);
    
    for count = 1:numAttributes
        %attrib = item(theAttributes,count-1);
        %attr_name = regexprep(char(getName(attrib)),'[-:.]','_');
        %attributes.(attr_name) = char(getValue(attrib));
        
        %Suggestion of Adrian Wanner
        str = toCharArray(toString(item(theAttributes,count-1)))';
        k = strfind(str,'=');
        attr_name = str(1:(k(1)-1));
        attr_name = strrep(attr_name, '-', '_dash_');
        attr_name = strrep(attr_name, ':', '_colon_');
        attr_name = strrep(attr_name, '.', '_dot_');
        attributes.(attr_name) = str((k(1)+2):(end-1));
    end
end
end

end

