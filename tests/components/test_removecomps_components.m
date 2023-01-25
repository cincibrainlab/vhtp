function tests = test_removecomps_components
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testRemoveComps(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegRemoveCompsEeglab(EEG,'maxcomps',24);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegRemoveCompsEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %components removal function

    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRemoveCompsEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));
    
end