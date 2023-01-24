function tests = test_frequencyinterpolation_filter
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testFrequencyinterpolationFilter(testCase)
    import matlab.unittest.constraints.HasField
    
    %FUnction seems to have a problem with 32 channels
    %EEG = pop_loadset('filepath','../','filename','example_data_32.set');
    
    EEG = pop_loadset('filepath','../','filename','example_data_128.set');

    EEG2 = eeg_htpEegFrequencyInterpolation(EEG,'targetfrequency',60,'halfmargin',2);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegFrequencyInterpolation"));

    %Verify existence of function's outputs to mark input parameters to frequencyinterpolation filter
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegFrequencyInterpolation,HasField("targetfrequency"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegFrequencyInterpolation,HasField("halfmargin"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegFrequencyInterpolation,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));   
    

end

