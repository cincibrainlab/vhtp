function util_htpNewAnalysisTemplate(varargin)
% Create a new analysis file from parameters.
%
%   util_htpNewAnalysisTemplate( PROJECTNAME ) opens the editor and pastes the content of a
%   user-defined template into the file template_PROJECTNAME.m.
%
%
%   References
%   Based on file 'newTest' from David Legland.
%

% HISTORY
% 2016-07-19 update for new version of Matlab


switch nargin
    case 0
        edit
        warning('util_htpNewAnalysisTemplate:MissingArgument', ...
            'util_htpNewAnalysisTemplate without argument is the same as edit');
        return;

    case 1
        projectName = varargin{1};
        fileName = ['template_' projectName];
        edit(fileName);

    otherwise
        error('too many input arguments');

end

% Matlab interface changed with 7.12.0, so we need to switch
if verLessThan('matlab','7.12.0')
    try
        % Define the handle for the java commands:
        edhandle = com.mathworks.mlservices.MLEditorServices;

        % get editor active document
        doc = edhandle.builtinGetActiveDocument;

        % append template header
        text = parse(projectName);
        edhandle.builtinAppendDocumentText(doc, text);
    catch ex
        rethrow(ex)
    end
else
    try
        % get editor active document
        editorObject = matlab.desktop.editor.getActive;

        % append template header
        text = parse(projectName);
        editorObject.appendText(text);

    catch ex
        rethrow(ex)
    end
end

    function out = parse(funName)


        t = fileread('templates\eeg_htpAnalysisTemplate_dynamic.m');
        template = regexp(t, '\r\n|\r|\n', 'split');

        repstr = {...
            '$filename'
            '$creation_date'
            '$project_name'
            '$author_name'
            '$description'
            '$eeglab_dir'
            '$brainstorm_dir'
            '$vhtp_dir'
            '$se_dir'
            '$braph_dir'
            '$bct_dir'
            '$set_dir'
            '$temp_dir'
            '$results_dir'};

        repwithstr = {...
            upper(funName)
            datestr(now, 29)
            };

        for k = 1:numel(repstr)
            template = strrep(template, repstr{k}, repwithstr{k});
        end
        out = sprintf('%s\n', template{:});
    end
end

