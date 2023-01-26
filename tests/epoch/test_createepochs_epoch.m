function tests = test_createepochs_epoch
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testCreateEpochs(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_128.set');
    
    %inputEEG = eeg_htpEegEpoch2Cont(EEG);

    EEG2 = eeg_htpEegCreateEpochsEeglab(EEG,'epochlimits',[-1 1],'saveoutput',false);

    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEG2,HasField("vhtp"));
    testCase.verifyThat(EEG2.vhtp,HasField("eeg_htpEegCreateEpochsEeglab"));

    %Verify existence of function's outputs to mark input parameters to
    %create epochs function
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCreateEpochsEeglab,HasField("proc_xmax_epoch"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCreateEpochsEeglab,HasField("epochlength"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCreateEpochsEeglab,HasField("epochlimits"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCreateEpochsEeglab,HasField("trials"));
    testCase.verifyThat(EEG2.vhtp.eeg_htpEegCreateEpochsEeglab,HasField("qi_table"));  
    
    %!!!!!!! How do you want me to check size in this one ????
    %Verification that output data is identical size
    %testCase.verifyEqual(size(EEG2.data),size(EEG.data));

    %check data is preserved 
    %CheckDataEEG = eeg_htpEegEpoch2Cont(EEG);
    CheckDatainputEEG2 = eeg_htpEegEpoch2Cont(EEG2);
    %testCase.verifyEqual(CheckDatainputEEG2.data, EEG.data);
    testCase.verifyEqual(size(CheckDatainputEEG2.data),size(EEG.data));
    
end