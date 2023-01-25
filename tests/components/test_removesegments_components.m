function tests = test_removesegments_components
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testRemoveSegments(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegRemoveSegmentsEeglab(EEG,'saveoutput',false);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegRemoveSegmentsEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %segment removal function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRemoveSegmentsEeglab,HasField("proc_removed_regions"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRemoveSegmentsEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));
    
end