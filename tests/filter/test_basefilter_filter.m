function tests = test_basefilter_filter
  tests = functiontests(localfunctions);
end

function setupOnce(~)
  addpath('../../');
end

function testBasefilterFilter(testCase)
    import matlab.unittest.constraints.HasField

    EEG = pop_loadset('filepath','../','filename','example_data_32.set');



    EEGhighpass = eeg_htpEegFilterEeglab(EEG,'method','highpass','highpassfilt',1,'filtorder',3300);
    EEGlowpass = eeg_htpEegFilterEeglab(EEG,'method','lowpass','lowpassfilt',80,'filtorder',3300);
    EEGnotch = eeg_htpEegFilterEeglab(EEG,'method','notch','notchfilt',[55 65],'filtorder',3300);
    
    EEGcleanline = eeg_htpEegFilterEeglab(EEG,'method','cleanline','cleanlinebandwidth',2,'cleanlinechanlist',[1:EEG.nbchan]);


    %%EEGhighpass
    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEGhighpass,HasField("vhtp"));
    testCase.verifyThat(EEGhighpass.vhtp,HasField("eeg_htpEegFilterEeglab"));

    %Verify existence of function's outputs to mark input parameters to basefilter-highpass filter
    testCase.verifyThat(EEGhighpass.vhtp.eeg_htpEegFilterEeglab,HasField("highpassfiltorder"));
    testCase.verifyThat(EEGhighpass.vhtp.eeg_htpEegFilterEeglab,HasField("highpassLocutoff"));
    testCase.verifyThat(EEGhighpass.vhtp.eeg_htpEegFilterEeglab,HasField("highpassRevfilt"));
    testCase.verifyThat(EEGhighpass.vhtp.eeg_htpEegFilterEeglab,HasField("highpassPlotfreqz"));
    testCase.verifyThat(EEGhighpass.vhtp.eeg_htpEegFilterEeglab,HasField("highpassMinPhase"));
    testCase.verifyThat(EEGhighpass.vhtp.eeg_htpEegFilterEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEGhighpass.data),size(EEG.data));   
    
    %%EEGlowpass
    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEGhighpass,HasField("vhtp"));
    testCase.verifyThat(EEGlowpass.vhtp,HasField("eeg_htpEegFilterEeglab"));

    %Verify existence of function's outputs to mark input parameters to basefilter-lowpass filter
    testCase.verifyThat(EEGlowpass.vhtp.eeg_htpEegFilterEeglab,HasField("lowpassfiltorder"));
    testCase.verifyThat(EEGlowpass.vhtp.eeg_htpEegFilterEeglab,HasField("lowpassHicutoff"));
    testCase.verifyThat(EEGlowpass.vhtp.eeg_htpEegFilterEeglab,HasField("lowpassRevfilt"));
    testCase.verifyThat(EEGlowpass.vhtp.eeg_htpEegFilterEeglab,HasField("lowpassPlotfreqz"));
    testCase.verifyThat(EEGlowpass.vhtp.eeg_htpEegFilterEeglab,HasField("lowpassMinPhase"));
    testCase.verifyThat(EEGlowpass.vhtp.eeg_htpEegFilterEeglab,HasField("qi_table")); 
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEGlowpass.data),size(EEG.data)); 


    %%EEGnotch
    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEGhighpass,HasField("vhtp"));
    testCase.verifyThat(EEGnotch.vhtp,HasField("eeg_htpEegFilterEeglab"));

    %Verify existence of function's outputs to mark input parameters to basefilter-notch filter
    testCase.verifyThat(EEGnotch.vhtp.eeg_htpEegFilterEeglab,HasField("notchfiltorder"));
    testCase.verifyThat(EEGnotch.vhtp.eeg_htpEegFilterEeglab,HasField("notchCutoff"));
    testCase.verifyThat(EEGnotch.vhtp.eeg_htpEegFilterEeglab,HasField("notchRevfilt"));
    testCase.verifyThat(EEGnotch.vhtp.eeg_htpEegFilterEeglab,HasField("notchPlotfreqz"));
    testCase.verifyThat(EEGnotch.vhtp.eeg_htpEegFilterEeglab,HasField("notchMinPhase"));
    testCase.verifyThat(EEGnotch.vhtp.eeg_htpEegFilterEeglab,HasField("qi_table"));  
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEGnotch.data),size(EEG.data)); 

    %%EEGcleanline
    %Verify existence of vhtp structure and relevant function structure
    testCase.verifyThat(EEGhighpass,HasField("vhtp"));
    testCase.verifyThat(EEGcleanline.vhtp,HasField("eeg_htpEegFilterEeglab"));

    %Verify existence of function's outputs to mark input parameters to basefilter-cleanline filter
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineBandwidth'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineChanlist'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineComputePower'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineLineFreqs'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineNormSpectrum'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineP'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlinePad'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlinePlotFigures'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineScanForLines'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineSigType'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineTau'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineVerb'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineWinSize'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('cleanlineWinStep'));
    testCase.verifyThat(EEGcleanline.vhtp.eeg_htpEegFilterEeglab,HasField('qi_table'));
    
    %Verification that output data is identical size
    testCase.verifyEqual(size(EEGcleanline.data),size(EEG.data)); 

end


