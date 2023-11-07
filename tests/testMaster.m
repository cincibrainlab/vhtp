classdef testMaster
    properties
        eeglabPath
        testFolderPath
        setFolderPath
        TestList
    end
    
    methods
        function obj = testMaster(eeglabPath, testFolderPath, setFolderPath)
            if nargin < 3
                eeglabPath = 'C:\Users\sueo8x\Documents\eeglab2022.1';
                testFolderPath = 'tests/unitTestFiles';
                setFolderPath = 'tests/test_SetFiles';
            end
            obj.eeglabPath = eeglabPath;
            obj.testFolderPath = testFolderPath;
            obj.setFolderPath = setFolderPath;
            obj.TestList = struct();
        end

        function testResults = runTests(obj)
            addpath(obj.eeglabPath);
            eeglab nogui;

            testFileList = dir(fullfile(obj.testFolderPath, '*.m'));
            setFileList = dir(fullfile(obj.setFolderPath, '*.set'));

            failedTests = struct('testFileName', {}, 'setFileName', {}, 'FunctionName', {});

            for j = 1:numel(setFileList)
                EEG = pop_loadset(fullfile(setFileList(j).folder, setFileList(j).name));
                for i = 1:length(testFileList)
                    functionName = strrep(testFileList(i).name, '.m', '');
                    setName = strrep(setFileList(j).name, '.set', '');
                    matFileName = ['tests/savedForCompare/testSave_' functionName '_' setName '.mat'];

                    if exist(matFileName, 'file')
                        load(matFileName, 'testDataEEG', 'testResults');
                    else
                        [testDataEEG, testResults] = feval(functionName, EEG);
                        testResults = rmfield(testResults, 'qi_table');
                        save(matFileName, 'testDataEEG', 'testResults');
                    end

                    [outputEEG, outputResults] = feval(functionName, EEG);
                    outputResults = rmfield(outputResults, 'qi_table');

                    try
                        assert(isequal(testDataEEG.data, outputEEG.data), ['Test for ', functionName, ' failed']);
                        assert(isequal(testResults, outputResults), ['Test for ', functionName, ' failed']);
                    catch
                        failedTestEntry = struct('testFileName', testFileList(i).name, 'setFileName', setFileList(j).name, 'FunctionName', functionName);
                        failedTests(end+1) = failedTestEntry;
                    end
                end
            end

            if isempty(failedTests)
                fprintf('All tests passed!\n');
            else
                fprintf('Failed tests:\n');
                for k = 1:numel(failedTests)
                    fprintf('Test for %s in file %s failed\n', failedTests(k).FunctionName, failedTests(k).testFileName);
                end
            end
        end
    end
end

