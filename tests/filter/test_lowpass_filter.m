

function tests = test_lowpass_filter
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testLowpassFilter(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegLowpassFilterEeglab(EEG,'lowpassfilt',80,'filtorder',3300);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegLowpassFilterEeglab"));

    %Verify existence of function's outputs to mark input parameters to lowpass filter
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegLowpassFilterEeglab,HasField("lowpassfiltorder"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegLowpassFilterEeglab,HasField("hicutoff"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegLowpassFilterEeglab,HasField("revfilt"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegLowpassFilterEeglab,HasField("plotfreqz"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegLowpassFilterEeglab,HasField("minphase"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegLowpassFilterEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));   
    

end