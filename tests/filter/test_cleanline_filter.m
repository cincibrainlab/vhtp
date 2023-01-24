function tests = test_cleanline_filter
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testCleanlineFilter(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegCleanlineFilterEeglab(EEG,'cleanlinebandwidth',2,'cleanlinechanlist',[1:EEG.nbchan]);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegCleanlineFilterEeglab"));

    %Verify existence of function's outputs to mark input parameters to cleanline filter
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("bandwidth"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("chanlist"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("computepower"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("linefreqs"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("normspectrum"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("p"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("pad"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("plotfigures"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("scanforlines"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("sigtype"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("tau"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("verb"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("winsize"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("winstep"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCleanlineFilterEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));   
    

end
