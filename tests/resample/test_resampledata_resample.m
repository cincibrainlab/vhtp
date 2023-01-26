function tests = test_resampledata_resample
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function test_Resampledata(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');
    % impleneted to make sure data size is preserved through data
    % resampling 

    EEG = eeg_htpEegEpoch2Cont(EEG);

    EEG2 = eeg_htpEegResampleDataEeglab(EEG,'srate',500,'saveoutput',false);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegResampleDataEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %resample data function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegResampleDataEeglab,HasField("rawsrate"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegResampleDataEeglab,HasField("srate"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegResampleDataEeglab,HasField("qi_table"));  
   
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data,2),size(EEG.data,2)/2);
    
end