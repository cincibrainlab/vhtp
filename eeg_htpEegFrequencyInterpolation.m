function [EEG,results] = eeg_htpEegFrequencyInterpolation(EEG,varargin)
% Description: Perform Frequency Interpolation on data
% ShortTitle: Frequency Interpolation EEG 
% Category: Preprocessing
% Tags: Filter
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegFrequencyInterpolation( EEG, varargin)
%
%% Required Inputs:
%     EEG [struct]         - EEGLAB Structure
%
%% Function Specific Inputs:
%   'targetfrequency' - Number indicating target frequency used for window in 
%                       filtering and interpolation calculations
%                       default: 60
%   
%   'halfmargin' - Number indicating width of neighbouring frequencies used
%                  in spectrum interpolation
%                  default: 2
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
%     results [struct]   - Updated function-specific structure containing qi table and input parameters used
%
%% Disclaimer:
%  This file is part of the Cincinnati Visual High Throughput Pipeline
%  
%  Please see http://github.com/cincibrainlab
%
%% Contact:
%  kyle.cullion@cchmc.org

defaultTargetFrequency = 60;
defaultHalfMargin = 2;
defaultSaveOutput = false;
defaultOutputDir = '';
   
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'targetfrequency',defaultTargetFrequency,@isnumeric);
addParameter(ip, 'halfmargin',defaultHalfMargin, @isnumeric);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    targetFreqs = ip.Results.targetfrequency:ip.Results.targetfrequency:EEG.srate/2;
    halfMargin  = ip.Results.halfmargin;
    onsetOffsetFreqbandWidth = 1;

    correctedData = zeros(size(EEG.data));
    for elecIdx = 1:EEG.nbchan
        
        currentData = double(EEG.data(elecIdx,:));
        currentFft  = fft(currentData, EEG.pnts);
        freqs       = EEG.srate*linspace(0,1,EEG.pnts);
        
        for targetFreqIdx = 1:length(targetFreqs)
            
            currentTargetFreq = targetFreqs(targetFreqIdx);
            
            targetFreqBinIdx  = find(freqs > currentTargetFreq-halfMargin & freqs < currentTargetFreq+halfMargin);
            onsetFreqBinIdx   = find(freqs > currentTargetFreq-halfMargin-onsetOffsetFreqbandWidth & freqs < currentTargetFreq-halfMargin);
            offsetFreqBinIdx  = find(freqs > currentTargetFreq+halfMargin & freqs < currentTargetFreq+halfMargin+onsetOffsetFreqbandWidth);
            
            onsetPower  = mean(abs(currentFft(onsetFreqBinIdx)));
            offsetPower = mean(abs(currentFft(offsetFreqBinIdx)));
            
            interpolatingPower = linspace(onsetPower, offsetPower, length(targetFreqBinIdx));

            currentFft(:,targetFreqBinIdx) = bsxfun(@times, exp(bsxfun(@times, angle(currentFft(:,targetFreqBinIdx)), 1i)), interpolatingPower);
        end
        
        correctedData(elecIdx,:) = ifft(currentFft, [], 2, 'symmetric');
    end
    EEG.data = correctedData;
    EEG.vhtp.eeg_htpEegFrequencyInterpolation.completed = 1;
    EEG.vhtp.eeg_htpEegFrequencyInterpolation.targetfrequency = ip.Results.targetfrequency;
    EEG.vhtp.eeg_htpEegFrequencyInterpolation.halfmargin = ip.Results.halfmargin;

catch e
    throw(e);
end

EEG = eeg_checkset(EEG);

if isfield(EEG,'vhtp') && isfield(EEG.vhtp,'inforow')
    EEG.vhtp.inforow.proc_filt_frequency_interpolation = true;
    EEG.vhtp.inforow.proc_filt_frequency_interpolation_target_freq = ip.Results.targetfrequency;
    EEG.vhtp.inforow.proc_filt_frequency_interpolation_half_margin = ip.Results.halfmargin;
end

qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegFrequencyInterpolation,'qi_table')
    EEG.vhtp.eeg_htpEegFrequencyInterpolation.qi_table = [EEG.vhtp.eeg_htpEegFrequencyInterpolation.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegFrequencyInterpolation.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegFrequencyInterpolation;

if ip.Results.saveoutput && ~isempty(ip.Results.outputdir)
    if isfield(EEG.vhtp, 'currentStep')
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,EEG.vhtp.currentStep);
    else
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,'frequency_interpolation');
    end
    fprintf('Output was copied to %s\n\n',ip.Results.outputdir);
end

end



