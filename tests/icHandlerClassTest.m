function tests = icHandlerClassTest
    tests = functiontests(localfunctions);
end

% Setup function
function setupOnce(testCase)
    % Load or create a sample EEG structure
    testCase.TestData.FullFileName = '/Users/ernie/Documents/ExampleData/APD/D0348_rest_postica_dipfit.set';
    testCase.TestData.WorkingDir =  '/Users/ernie/Documents/ExampleData';
    testCase.TestData.EEG = pop_loadset('filename','D0348_rest_postica_dipfit.set','filepath','/Users/ernie/Documents/ExampleData/APD/');
end

function testCreateIcFileClass_typical(testCase)
    icFileClass(testCase.TestData.FullFileName);
end
function testCreateIcFileClass_incompleteFileName(testCase)
    testCase.verifyWarning(@() icFileClass(testCase.TestData.EEG.filename),'icFileClass:Warning');
end

function testCreateIcFileClass_invalidFileName(testCase)
    testCase.verifyWarning(@() icFileClass('invalid_filename.set'), 'icFileClass:Warning');
end

% % 
% % Test typical use case
% function testTypicalUseCase(testCase)
%     icHandler = icHandlerClass();
%     % icFile = icFileClass(testCase.TestData.EEG.filename);
    
%     % Add assertions to verify the results
%     % Example: testCase.verifySize(EEG.data, [expectedSize]);
%     % Example: testCase.verifyEqual(opts.someField, expectedValue);
% end

function testLoadSetFiles(testCase)
     icHandler = icHandlerClass();
     icHandler.IcHandlerView('getApplicationTitle')
     icHandler.setWorkingDirectory(testCase.TestData.WorkingDir);
 end

% function testCreateFileTable(testCase)
%     icHandler = icHandlerClass();
%     icHandler.refreshFileTable();
% end
