function tests = test_removechans_channel
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testRemoveChans(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegRemoveChansEeglab(EEG,'threshold',5,'automark',true,'removechannel',true);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegRemoveChansEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %channel removal function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRemoveChansEeglab,HasField("failReason"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRemoveChansEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));
    
end