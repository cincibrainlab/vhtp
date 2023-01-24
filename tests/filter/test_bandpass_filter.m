function tests = test_bandpass_filter
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testBandpassFilter(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegBandpassFilterEeglab(EEG,'bandpassfilt',[55 65],'filtorder',3300);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegBandpassFilterEeglab"));

    %Verify existence of function's outputs to mark input parameters to bandpass filter
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegBandpassFilterEeglab,HasField("filtorder"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegBandpassFilterEeglab,HasField("bandpasscutoff"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegBandpassFilterEeglab,HasField("revfilt"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegBandpassFilterEeglab,HasField("plotfreqz"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegBandpassFilterEeglab,HasField("minphase"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegBandpassFilterEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));   
    

end
