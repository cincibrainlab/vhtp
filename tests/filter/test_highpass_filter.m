function tests = test_highpass_filter
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testHighpassFilter(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegHighpassFilterEeglab(EEG,'highpassfilt',1,'filtorder',3300);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegHighpassFilterEeglab"));

    %Verify existence of function's outputs to mark input parameters to highpass filter
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegHighpassFilterEeglab,HasField("filtorder"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegHighpassFilterEeglab,HasField("locutoff"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegHighpassFilterEeglab,HasField("revfilt"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegHighpassFilterEeglab,HasField("plotfreqz"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegHighpassFilterEeglab,HasField("minphase"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegHighpassFilterEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));   
    

end

