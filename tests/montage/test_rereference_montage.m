function tests = test_rereference_montage
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function test_Rereference(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegRereferenceEeglab(EEG,'saveoutput',false);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegRereferenceEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %rereference function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRereferenceEeglab,HasField("method"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRereferenceEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));
    
end