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
            % obj.TestList = struct('testname','fname','result');
            obj.TestList = struct();
        end

        function testResults = runTests(obj)
            addpath(obj.eeglabPath);
            eeglab nogui;

            testFileList = dir(fullfile(obj.testFolderPath, '*.m'));
            setFileList = dir(fullfile(obj.setFolderPath, '*.set'));

            testResults = struct('testFileName', {}, 'setFileName', {}, 'Status', {});

            for j = 1:numel(setFileList)
                EEG = pop_loadset(fullfile(setFileList(j).folder, setFileList(j).name));
                for i = 1:length(testFileList)
                    functionName = strrep(testFileList(i).name, '.m', '');
                    setName = strrep(setFileList(j).name, '.set', '');
                    matFileName = ['tests/savedForCompare/testSave_' functionName '_' setName '.mat'];

                    if exist(matFileName, 'file')
                        load(matFileName, 'testDataEEG');
                    else
                        [testDataEEG,testResults] = feval(functionName, EEG);
                        testResults = rmfield(testResults,"qi_table");
                        save(matFileName, 'testDataEEG',"testResults");
                    end

                    [outputEEG,outputResults] = feval(functionName, EEG);
                    outputResults = rmfield(outputResults,"qi_table");

                    assert(isequal(testDataEEG.data, outputEEG.data), ['Test for ', functionName, ' failed']);
                    assert(isequal(testResults, outputResults), ['Test for ', functionName, ' failed']);
                end
            end
            disp('All tests passed!');
        end
    end
end
