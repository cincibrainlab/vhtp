function [EEG,results] = eeg_htpEegAsrCleanEeglab(EEG,varargin)
% Description: Perform ASR cleaning via the clean_rawdata plugin provided through the EEGLAB interface
% Category: Preprocessing
% ShortTitle: Artifact Subspace Reconstruction
% Tags: Artifact
%
%% Syntax:
%    [ EEG, results ] = eeg_htpEegAsrCleanEeglab( EEG, varargin )
%
%% Required Inputs:
%     EEG [struct]           - EEGLAB Structure
%
%% Function Specific Inputs:
%   'asrmode'   - Integer indicating type of ASR cleaning performed
%                 Modes:
%                   1: flatline channel rejection, IIR highpass filter, correlation with reconstructed channel rejection, line-noise channel rejection
%                   
%                       Mode 1 will negate 'asrburst' and 'asrwindow' parameters
%
%                   2: ASR burst reparation, window rejection
%
%                       Mode 2 will negate 'asrflatline', 'asrhighpass', 'asrchannel', and 'asrnoisy' parameters
%
%                   3: flatline channel rejection, IIR highpass filter, correlation with reconstructed channel rejection, line-noise channel rejection, ASR burst reparation, window rejection
%
%                   4: ASR burst reparation, window rejection
%
%                       Mode 4 will negate 'asrflatline', 'asrhighpass', 'asrchannel', and 'asrnoisy' parameters
%
%                   5: Custom
%                 
%                 default: 2
%                 
%
%   'asrflatline'   - Integer representing the seconds of the max flatline duration. 
%                    Longer flatline is abnormal.
%                    
%                    default: 5
%
%   'asrhighpass' - Array of numbers indicating the transition band in Hz for the high-pass filter.  
%                   default: [0.25 0.75]
%
%   'asrchannel' - Number indicating the minimum channel correlation.
%                  Channels correlated to reconstructed channel at a value less than parameter is abnormal.  Needs accurate channel locations.
%                  
%                  default: 0.85
%
%   'asrnoisy' - Integer indicating the number of stdevs, based on channels, used to determine if channel has certain higher line noise to signal ratio to be considered abnormal.
%                default: 4
%
%   'asrburst' - Integer indicating stdev cutoff for burst removal.  
%                Lower the value the more conservative the removal.
%                
%                default: 20
%
%   'asrwindow' - Number indicating the max fraction of dirty channels accepted in output for each window. 
%                 default: 0.25
%
%   'saveoutput' - Boolean representing if output should be saved when executing step from VHTP preprocessing tool
%                  default: false
%
%   'outputdir' - text representing the output directory for the function
%                 output to be saved to
%                 default: ''      
%
%% Outputs:
%     EEG [struct]         - Updated EEGLAB structure
%
%     results [struct]     - Updated function-specfic structure containing qi table and input parameters used
%
%% Disclaimer:
%   Part of the Cincinnati Visual High Throughput EEG Pipeline
%
%   Please see http://github.com/cincibrainlab
%
%% Contact:
%   kyle.cullion@cchmc.org

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

defaultAsrMode = 2;
defaultAsrFlatline = 5;
defaultAsrHighpass = [0.25 0.75];
defaultAsrChannel = 0.85;
defaultAsrNoisy = 4;
defaultAsrBurst = 20;
defaultAsrWindow = 0.25;
defaultAsrMaxMem = 64;
defaultSaveOutput = false;
defaultOutputDir = '';

singleDigitValidation = @(x) (isnumeric(x) && x>=0) || strcmp(x,'off');
arrayValidation = @(x) max((isnumeric(x) & (size(x,2)>0 & x>=0)) | strcmp(x,'off'));

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'asrmode', defaultAsrMode, @isnumeric);
addParameter(ip, 'asrflatline', defaultAsrFlatline, singleDigitValidation);
addParameter(ip, 'asrhighpass',defaultAsrHighpass, arrayValidation);
addParameter(ip, 'asrchannel', defaultAsrChannel, singleDigitValidation);
addParameter(ip, 'asrnoisy', defaultAsrNoisy, singleDigitValidation);
addParameter(ip, 'asrburst',defaultAsrBurst,singleDigitValidation);
addParameter(ip, 'asrwindow', defaultAsrWindow, singleDigitValidation);
addParameter(ip, 'asrmaxmem', defaultAsrMaxMem, @isnumeric);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

parse(ip,EEG,varargin{:});

try
    
    switch ip.Results.asrmode
        case 1
            asrburst = 'off';
            asrwindow = 'off';
            
            EEG = clean_artifacts(EEG, 'FlatlineCriterion',ip.Results.asrflatline, 'Highpass',ip.Results.asrhighpass, 'ChannelCriterion',ip.Results.asrchannel, 'NoiseCriterion',ip.Results.asrnoisy, 'BurstCriterion',asrburst, 'WindowCriterion',asrwindow,'MaxMem',ip.Results.asrmaxmem);
            
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrflatline = ip.Results.asrflatline;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrhighpass = ip.Results.asrhighpass;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrchannel = ip.Results.asrchannel;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrnoisy = ip.Results.asrnoisy;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrburst = asrburst;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrwindow = asrwindow;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmaxmem = ip.Results.asrmaxmem;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmode = ip.Results.asrmode;
        case 2
            asrflatline = 'off';
            asrhighpass = 'off';
            asrchannel = 'off';
            asrnoisy = 'off';
            
            EEG = clean_artifacts(EEG, 'FlatlineCriterion',asrflatline, 'Highpass',asrhighpass, 'ChannelCriterion',asrchannel, 'NoiseCriterion',asrnoisy, 'BurstCriterion',ip.Results.asrburst, 'WindowCriterion',ip.Results.asrwindow,'MaxMem',ip.Results.asrmaxmem);
            
            
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrflatline = asrflatline;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrhighpass = asrhighpass;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrchannel = asrchannel;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrnoisy = asrnoisy;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrburst = ip.Results.asrburst;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrwindow = ip.Results.asrwindow;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmaxmem = ip.Results.asrmaxmem;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmode = ip.Results.asrmode;
        case 3
            asrburst = 'off';
            asrwindow = 'off';
            
            EEG = clean_artifacts(EEG, 'FlatlineCriterion',ip.Results.asrflatline, 'Highpass',ip.Results.asrhighpass, 'ChannelCriterion',ip.Results.asrchannel, 'NoiseCriterion',ip.Results.asrnoisy, 'BurstCriterion',asrburst, 'WindowCriterion',asrwindow,'MaxMem',ip.Results.asrmaxmem);
            
            asrflatline = 'off';
            asrhighpass = 'off';
            asrchannel = 'off';
            asrnoisy = 'off';
            
            EEG = clean_artifacts(EEG, 'FlatlineCriterion',asrflatline, 'Highpass',asrhighpass, 'ChannelCriterion',asrchannel, 'NoiseCriterion',asrnoisy, 'BurstCriterion',ip.Results.asrburst, 'WindowCriterion',ip.Results.asrwindow, 'MaxMem',ip.Results.asrmaxmem);
            
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrflatline = ip.Results.asrflatline;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrhighpass = ip.Results.asrhighpass;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrchannel = ip.Results.asrchannel;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrnoisy = ip.Results.asrnoisy;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrburst = ip.Results.asrburst;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrwindow = ip.Results.asrwindow;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmaxmem = ip.Results.asrmaxmem;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmode = ip.Results.asrmode;
            
        case 4 
            asrflatline = 'off';
            asrhighpass = 'off';
            asrchannel = 'off';
            asrnoisy = 'off';
            
            EEG = clean_artifacts(EEG, 'FlatlineCriterion',asrflatline, 'Highpass',asrhighpass, 'ChannelCriterion', asrchannel, 'NoiseCriterion',asrnoisy, 'BurstCriterion',ip.Results.asrburst, 'WindowCriterion',ip.Results.asrwindow,'MaxMem',ip.Results.asrmaxmem);
            
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrflatline = asrflatline;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrhighpass = asrhighpass;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrchannel = asrchannel;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrnoisy = asrnoisy;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrburst = ip.Results.asrburst;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrwindow = ip.Results.asrwindow;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmaxmem = ip.Results.asrmaxmem;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmode = ip.Results.asrmode;
        case 5
            
            EEG = clean_artifacts(EEG, 'FlatlineCriterion',ip.Results.asrflatline,'Highpass', ip.Results.asrhighpass, 'ChannelCriterion',ip.Results.asrchannel, 'LineNoiseCriterion',ip.Results.asrnoisy, 'BurstCriterion',ip.Results.asrburst, 'WindowCriterion',ip.Results.asrwindow,'MaxMem',ip.Results.asrmaxmem);

            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrflatline = ip.Results.asrflatline;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrhighpass = ip.Results.asrhighpass;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrchannel = ip.Results.asrchannel;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrnoisy = ip.Results.asrnoisy;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrburst = ip.Results.asrburst;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrwindow = ip.Results.asrwindow;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmaxmem = ip.Results.asrmaxmem;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmode = ip.Results.asrmode;
    end
    
    EEG.vhtp.eeg_htpEegAsrCleanEeglab.completed = 1;
    
catch e
    throw(e)
end

EEG = eeg_checkset(EEG);

qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
'VariableNames', {'eegid','scriptname','timestamp'});
EEG.vhtp.eeg_htpEegAsrCleanEeglab.qi_table = qi_table;
results = EEG.vhtp.eeg_htpEegAsrCleanEeglab;

if ip.Results.saveoutput && ~isempty(ip.Results.outputdir)
    if isfield(EEG.vhtp, 'currentStep')
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,EEG.vhtp.currentStep);
    else
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,['asr' ip.Results.method]);
    end
    fprintf('Output was copied to %s\n\n',ip.Results.outputdir);
end

end

