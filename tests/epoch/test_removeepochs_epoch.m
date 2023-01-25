function tests = test_removeepochs_epoch
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function test_RemoveEpochs(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');

    EEG2 = eeg_htpEegRemoveEpochsEeglab(EEG,'saveoutput',false);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegRemoveEpochsEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %channel removal function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRemoveEpochsEeglab,HasField("epoch_badtrials"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRemoveEpochsEeglab,HasField("epoch_badid"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRemoveEpochsEeglab,HasField("epoch_percent"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRemoveEpochsEeglab,HasField("epoch_trials"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegRemoveEpochsEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEG2.data),size(EEG.data));
    
end