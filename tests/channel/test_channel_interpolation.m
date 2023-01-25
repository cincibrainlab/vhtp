
function tests = test_channel_interpolation
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testChannelInterpolation(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegInterpolateChansEeglab(EEG,'channels',[28]);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegInterpolateChansEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %channel interpolation function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegInterpolateChansEeglab,HasField("method"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegInterpolateChansEeglab,HasField("dataRank"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegInterpolateChansEeglab,HasField("nbchan_post"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegInterpolateChansEeglab,HasField("proc_ipchans"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegInterpolateChansEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));

    %Test data rank after interpolation of single channel, should reflect 
    %EEG2.nbchan-1 due to single interpolated channel
    testCase.verifyEqual(EEG2.vhtp.eeg_htpEegInterpolateChansEeglab.dataRank,EEG2.nbchan-1);
    

end
