function tests = test_asrclean_cleaning
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testAsrClean(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    % converts epoched data to continuous data
    EEG = eeg_htpEegEpoch2Cont(EEG)

    EEG2 = eeg_htpEegAsrCleanEeglab(EEG,'asrmode',2);
    EEG1 = eeg_htpEegAsrCleanEeglab(EEG,'asrmode',1);
    EEG3 = eeg_htpEegAsrCleanEeglab(EEG,'asrmode',3);
    EEG4 = eeg_htpEegAsrCleanEeglab(EEG,'asrmode',4);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegAsrCleanEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %Asr clean function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrflatline"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrhighpass"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrchannel"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrnoisy"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrburst"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrwindow"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrmaxmem"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("asrmode"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegAsrCleanEeglab,HasField("qi_table"));  
    
    % Testing for size : currently not in use 
    %Verification that output data is constant size between runs

    testCase.verifyEqual(size(EEG2.data,1),27);
    testCase.verifyEqual(size(EEG2.data,2),38300);

    testCase.verifyEqual(size(EEG1.data,1),27);
    testCase.verifyEqual(size(EEG1.data,2),42000);

    testCase.verifyEqual(size(EEG3.data,1),25);
    testCase.verifyEqual(size(EEG3.data,2),35920);

    testCase.verifyEqual(size(EEG4.data,1),27);
    testCase.verifyEqual(size(EEG4.data,2),38300);
    
end