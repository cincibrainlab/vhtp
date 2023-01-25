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
    EEGtemp = eeg_htpEegResampleDataEeglab(EEG,'srate',500,'saveoutput',false);

    EEG2 = eeg_htpEegResampleDataEeglab(EEGtemp,'srate',1000,'saveoutput',false);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegResampleDataEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %resample data function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegResampleDataEeglab,HasField("rawsrate"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegResampleDataEeglab,HasField("srate"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegResampleDataEeglab,HasField("qi_table"));  
    
    % How should I test size ???
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));
    
end