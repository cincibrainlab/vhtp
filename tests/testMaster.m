function testResults = testMaster()
    addpath('C:\Users\sueo8x\Documents\eeglab2022.1')
    eeglab nogui
    % Specify the folder where your test files are located
    testFolderPath = ['tests' filesep 'unitTestFiles'];
    setFolderPath = ['tests' filesep 'test_SetFiles'];

    % Get a list of all MATLAB files in the folder
    testFileList = dir(fullfile(testFolderPath, '*.m'));
    setFileList =  dir(fullfile(setFolderPath, '*.set'));

    % Initialize a structure to store test results
    testResults = struct('testFileName', {},'setFileName', {}, 'Status', {});

    for j = 1:numel(setFileList)
        EEG = pop_loadset(fullfile(setFileList(j).folder, setFileList(j).name));
        for i = 1:length(testFileList)
            % Extract the function name from the file name
            functionName = strrep(testFileList(i).name, '.m', '');
            setName = strrep(setFileList(j).name, '.set', '');
            % Load or create the MAT file for the function
            matFileName = ['tests' filesep 'savedForCompare' filesep 'testSave_' functionName '_' setName '.mat'];
            if exist(matFileName, 'file')
                % Load the existing MAT file
                load(matFileName, 'testDataEEG');
            else
                % Create an EEG variable or load data using pop_loadset
                % Here, you can define how to create or load your EEG data
                testDataEEG = feval(functionName, EEG);
                save(matFileName, 'testDataEEG');
            end
    
            % Call your function and pass the EEG variable
            outputEEG = feval(functionName, EEG);
    
            % Verify that the loaded EEG data and the function's output are equal
            assert(isequal(testDataEEG.data, outputEEG.data), ['Test for ', functionName, ' failed']);
        end
    end
    disp('All tests passed!');
end


