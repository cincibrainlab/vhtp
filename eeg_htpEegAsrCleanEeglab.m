function [EEG,results] = eeg_htpEegAsrCleanEeglab(EEG,varargin)
%eeg_htpEegAsrCleanEeglab
%
% eeg_htpEegAsrClean - Perform ASR cleaning via the clean_rawdata plugin
% provided through the EEGLAB interface
%
% Usage:
%    >> [ EEG, results ] = eeg_htpEegAsrCleanEeglab( EEG, varargin )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
% Function Specific Inputs:
%
%   'asrmode'   - Integer indicating type of ASR cleaning performed
%                 Modes:
%                   1: flatline channel rejection, IIR highpass filter, correlation
%                      with reconstructed channel rejection, line-noise
%                      channel rejection
%                   2: ASR burst reparation, window rejection
%                   3: flatline channel rejection, IIR highpass filter, correlation
%                      with reconstructed channel rejection, line-noise
%                      channel rejection, ASR burst reparation, window rejection
%                   4: ??
%
%                   5: ASR burst reparation, window rejection
%                 default: 2
%                 
%
%   'asrflatline'   - Integer representing the seconds of the max flatline duration. 
%                    Longer flatline is abnormal.
%                    default: 5
%
%   'asrhighpass' - Array of numbers indicating the transition band in Hz for the high-pass filter.  
%                   default: [0.25 0.75]
%
%   'asrchannel' - Number indicating the minimum channel correlation.
%                  Channels correlated to reconstructed channel at a value less than parameter is abnormal.  Needs accurate channel locations.
%                  default: 0.85
%
%   'asrnoisy' - Integer indicating the number of stdevs, based on channels, used to determine if channel has certain higher line noise to signal ratio to be considered abnormal.
%                default: 4
%
%   'asrburst' - Integer indicating stdev cutoff for burst removal.  
%                Lower the value the more conservative the removal.
%                default: 20
%
%   'asrwindow' - Number indicating the max fraction of dirty channels accepted in output for each window. 
%                 default: 0.25
%
%           
% Outputs:
%     EEG         - Updated EEGLAB structure
%
%     results     - Updated function-specfic structure containing qi table
%                   and input parameters used
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

defaultAsrMode = 2;
defaultAsrFlatline = 5;
defaultAsrHighpass = [0.25 0.75];
defaultAsrChannel = 0.85;
defaultAsrNoisy = 4;
defaultAsrBurst = 20;
defaultAsrWindow = 0.25;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'asrmode', defaultAsrMode, @isnumeric);
addParameter(ip, 'asrflatline', defaultAsrFlatline, @isnumeric);
addParameter(ip, 'asrhighpass',defaultAsrHighpass, @isnumeric);
addParameter(ip, 'asrchannel', defaultAsrChannel, @isnumeric);
addParameter(ip, 'asrnoisy', defaultAsrNoisy, @isnumeric);
addParameter(ip, 'asrburst',defaultAsrBurst,@isnumeric);
addParameter(ip, 'asrwindow', defaultAsrWindow, @isnumeric);

parse(ip,EEG,varargin{:});

try
    
    switch ip.Results.asrmode
        case 1
            asrburst = -1;
            asrwindow = -1;
            
            EEG = clean_rawdata(EEG, ip.Results.asrflatline, ip.Results.asrhighpass, ip.Results.asrchannel, ip.Results.asrnoisy, asrburst, asrwindow);
            
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrflatline = ip.Results.asrflatline;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrhighpass = ip.Results.asrhighpass;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrchannel = ip.Results.asrchannel;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrnoisy = ip.Results.asrnoisy;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrburst = asrburst;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrwindow = asrwindow;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmode = ip.Results.asrmode;
        case 2
            asrflatline = -1;
            asrhighpass = -1;
            asrchannel = -1;
            asrnoisy = -1;
            
            EEG = clean_rawdata(EEG, asrflatline, asrhighpass, asrchannel, asrnoisy, ip.Results.asrburst, ip.Results.asrwindow);
            
            
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrflatline = asrflatline;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrhighpass = asrhighpass;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrchannel = asrchannel;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrnoisy = asrnoisy;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrburst = ip.Results.asrburst;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrwindow = ip.Results.asrwindow;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmode = ip.Results.asrmode;
        case 3
            asrburst = -1;
            asrwindow = -1;
            
            EEG = clean_rawdata(EEG, ip.Results.asrflatline, ip.Results.asrhighpass, ip.Results.asrchannel, ip.Results.asrnoisy, asrburst, asrwindow);
            
            asrflatline = -1;
            asrhighpass = -1;
            asrchannel = -1;
            asrnoisy = -1;
            
            EEG = clean_rawdata(EEG, asrflatline, asrhighpass, asrchannel, asrnoisy, ip.Results.asrburst, ip.Results.asrwindow);
            
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrflatline = ip.Results.asrflatline;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrhighpass = ip.Results.asrhighpass;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrchannel = ip.Results.asrchannel;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrnoisy = ip.Results.asrnoisy;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrburst = ip.Results.asrburst;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrwindow = ip.Results.asrwindow;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmode = ip.Results.asrmode;
            
        case 4 
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrmode = ip.Results.asrmode;
        case 5
            asrflatline = -1;
            asrhighpass = -1;
            asrchannel = -1;
            asrnoisy = -1;
            
            EEG = clean_rawdata(EEG, asrflatline, asrhighpass, asrchannel, asrnoisy, ip.Results.asrburst, ip.Results.asrwindow);
            
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrflatline = asrflatline;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrhighpass = asrhighpass;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrchannel = asrchannel;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrnoisy = asrnoisy;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrburst = ip.Results.asrburst;
            EEG.vhtp.eeg_htpEegAsrCleanEeglab.asrwindow = ip.Results.asrwindow;
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

end
