function tests = test_createerpepochs_epoch
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testCreateErpEpochs(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegCreateErpEpochsEeglab(EEG,'saveoutput',false);

    %Verify existence of vhtp structure and relevant function structure
    %testCase.verifyThat(EEG2,HasField("vhtp"));
    %testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegCreateErpEpochsEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %channel removal function
    %testCase.verifyThat(EEG2.vhtp.eeg_htpEegCreateErpEpochsEeglab,HasField("proc_removed_regions"));
    %testCase.verifyThat(EEG2.vhtp.eeg_htpEegCreateErpEpochsEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));
    
end