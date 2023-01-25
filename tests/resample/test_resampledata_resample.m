function tests = test_resampledata_resample
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function test_Resampledata(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegResampleDataEeglab(EEG,'saveoutput',false);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegResampleDataEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %channel removal function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegResampleDataEeglab,HasField("rawsrate"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegResampleDataEeglab,HasField("srate"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegResampleDataEeglab,HasField("qi_table"));  
    
    % How should I test size ???
    %Verification that output data is identical size
    %testCase.verifyEqual(size(EEG2.data),size(EEG.data));
    
end