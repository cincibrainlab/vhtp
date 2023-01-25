function tests = test_asrclean_cleaning
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testAsrClean(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');
    
    %launch eeglab to use plugin
    %eeglab

    % converts epoched data to continuous data
    EEG = eeg_htpEegEpoch2Cont(EEG)

    EEG2 = eeg_htpEegAsrCleanEeglab(EEG,'asrmode',2);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegAsrCleanEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %channel removal function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrflatline"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrhighpass"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrchannel"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrnoisy"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrburst"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrwindow"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrmaxmem"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrmode"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("qi_table"));  
    
    %!!! Kyle are these supposed to not be equal?

    %Verification that output data is identical size
    %testCase.verifyEqual(size(EEG2.data),size(EEG.data));
    
end