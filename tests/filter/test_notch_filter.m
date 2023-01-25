function tests = test_notch_filter
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testNotchFilter(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegNotchFilterEeglab(EEG,'notchfilt',[55 65],'filtorder',3300);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegNotchFilterEeglab"));

    %Verify existence of function's outputs to mark input parameters to notch filter
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegNotchFilterEeglab,HasField("filtorder"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegNotchFilterEeglab,HasField("notchcutoff"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegNotchFilterEeglab,HasField("revfilt"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegNotchFilterEeglab,HasField("plotfreqz"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegNotchFilterEeglab,HasField("minphase"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegNotchFilterEeglab,HasField("qi_table"));

    %Verify that function has been completed
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegNotchFilterEeglab,HasField("completed"));
    testCase.verifyEqual(EEG2.vhtp.eeg_htpEegNotchFilterEeglab.completed,1);
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));   
    
end

