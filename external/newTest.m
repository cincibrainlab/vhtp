function newTest(varargin)
% Create a new test case for existing function.
%
%   newTest(FUNNAME) opens the editor and pastes the content of a
%   user-defined template into the file test_FUNNAME.m.
%
%
%   References
%   Based on file 'tedit' from Peter Bodin.
%

% ------
% Author: David Legland
% e-mail: david.legland@inrae.fr
% Created: 2011-07-26,    using Matlab 7.9.0.529 (R2009b)
% Copyright 2011 INRA - Cepia Software Platform.

% HISTORY
% 2016-07-19 update for new version of Matlab


switch nargin
    case 0
        edit
        warning('newTest:MissingArgument', ...
            'newTest without argument is the same as edit');
        return;
        
    case 1
        funName = varargin{1};
        fileName = ['test_' funName];
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
        text = parse(funName);
        edhandle.builtinAppendDocumentText(doc, text);
    catch ex
        rethrow(ex)
    end
else
    try
        % get editor active document
        editorObject = matlab.desktop.editor.getActive;
        
        % append template header
        text = parse(funName);
        editorObject.appendText(text);
        
    catch ex
        rethrow(ex)
    end
end

    function out = parse(funName)
        
        template = { ...
            'function tests = $filename'
            '% Test suite for the file $funname.'
            '%'
            '%   Test suite for the file $funname'
            '%'
            '%   Example'
            '%   $filename'
            '%'
            '%   See also'
            '%     $funname'
            ''
            '% ------'
            '% Author: $author'
            '% e-mail: $mail'
            ['% Created: $date,    using Matlab ' version]
            '% Copyright $year $company.'
            ''
            'tests = functiontests(localfunctions);'
            ''
            'function test_Simple(testCase) %#ok<*DEFNU>'
            '% Test call of function without argument.'
            '$funname();'
            'value = 10;'
            'assertEqual(testCase, value, 10);'
            ''
            ''};

        t = fileread('C:\srv\vhtp\test_FUNNAME.m');
template = regexp(t, '\r\n|\r|\n', 'split');
        
        repstr = {...
            '$filename'
            '$FILENAME'
            '$funname'
            '$date'
            '$year'
            '$author'
            '$mail'
            '$company'};
        
        testName = ['test_' funName];
        
        repwithstr = {...
            testName
            upper(testName)
            funName
            datestr(now, 29)
            datestr(now, 10)
            'David Legland'
            'david.legland@inrae.fr'
            'INRAE - BIA-BIBS'};
        
        for k = 1:numel(repstr)
            template = strrep(template, repstr{k}, repwithstr{k});
        end
        out = sprintf('%s\n', template{:});
    end
end

