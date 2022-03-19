function [EEG, results] = eeg_htpEegWaveletDenoiseHappe(EEG, varargin)
    % eeg_htpEegWaveletDenoiseHappe() - standalone implementation of HAPPE 2.0 wavelet
    %      thresholding to EEG SET data. Original implementation by Dr. Gabard-Durham:
    %       https://github.com/PINE-Lab/HAPPE/blob/master/scripts/pipeline_scripts/happe_wavThresh.m
    %
    %       Requirements: Mathworks MATLAB Wavelet toolkit for wdenoise function.
    %
    % Usage:
    %    >> [ EEG, results ] = eeg_htpEegWaveletDenoiseHappe( EEG, options )
    %
    % Require Inputs:
    %     EEG         - EEGLAB Structure
    % Function Specific Inputs:
    %     'outputdir' - path to place output files
    %.    'isErp'     - Per HAPPE: Set wavelet level depending on the task paradigm and sampling rate
    %.    'wavLvl'    - Per MATLAB: Level of wavelet decomposition, specified as a positive integer.
    %.    'wavelet'   - Per MATLAB: Name of wavelet, specified as a character array, to use for denoising 
    %.    'DenoisingMethod' - Per MATLAB: Denoising method used to determine the denoising thresholds for the data X.
    %.                        Opts: "Bayes" | "BlockJS" | "FDR" | "Minimax" | "SURE" | "UniversalThreshold"
    %.    'ThresholdRule' - Per MATLAB: Threshold rule, specified as a character array, to use to shrink the wavelet coefficients. 
    %                       "BlockJS" — The only supported option is "James-Stein". You do not need to specify ThresholdRule for "BlockJS".
    %                       "SURE", "Minimax", "UniversalThreshold" — Valid options are "Soft" or "Hard". The default is "Soft".
    %                       "Bayes" — Valid options are "Median", "Mean", "Soft", or "Hard". The default is "Median".
    %                       "FDR" — The only supported option is "Hard". You do not need to define ThresholdRule for "FDR"
    %.    'NoiseEstimate' - Per MATLAB: Method of estimating variance of noise in the data.
    %                       Opts: LevelIndependent | LevelDependent
    %.    'highpass'.    - high pass filter frequency for ERP data (isERP must = true)
    %.    'lowpass'.     - low pass filter frequency for ERP data (isERP must = true)
    %.
    %.    Default options as per HAPPE 2
    %.          wavLvl: automatically set based on sampling rate & isErp
    %.          wavelet: 'coif4'
    %.          DenoisingMethod: Bayes
    %.          ThresholdRule: automatically set based on sampling rate & isErp
    %.          NoiseEstimate: LevelDependent

    %.    Additional Defaults:
    %.          highpass = .5
    %.          lowpass  = 30;

    % Outputs:
    %     EEG       - EEGLAB Structure with modified .vhtp field
    %     results   - .vhtp structure
    %
    %  This file is part of the Cincinnati Visual High Throughput Pipeline,
    %  please see http://github.com/cincibrainlab
    %
    %  Contact: ernest.pedapati@cchmc.org
    %
    %
    %

    timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
    functionstamp = mfilename; % function name for logging/output

    % Inputs: Function Specific

    % Inputs: Common across Visual HTP functions
    defaultOutputDir = tempdir;
    defaultIsErp = false;
    defaultWavelet = 'coif4';
    defaultWavLvl = [];
    defaultThresholdRule = '';
    defaultDenoisingMethod = "Bayes";
    defaultNoiseEstimate = 'LevelDependent';
    defaultLowPass = .5;
    defaultHighPass = 30;

    % MATLAB built-in input validation
    ip = inputParser();
    addRequired(ip, 'EEG', @isstruct);
    addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
    addParameter(ip, 'isERP', defaultOutputDir, @isfolder)
    addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
    addParameter(ip, 'wavlvl', defaultWavLvl, @int)
    addParameter(ip, 'wavelet', defaultWavelet, @char)
    addParameter(ip, 'DenoisingMethod', defaultDenoisingMethod, @char)
    addParameter(ip, 'ThresholdRule', defaultThresholdRule, @ischar)
    addParameter(ip, 'NoiseEstimate', defaultNoiseEstimate, @ischar)
    addParameter(ip, 'highpass', defaultHighPass, @int)
    addParameter(ip, 'lowpass', defaultLowPass, @int)

    
    parse(ip, EEG, varargin{:});

    % HAPPE 2 Algorithm (happe_wavThresh.m Line: 73-93)
    % DEFAULT WAVELET:
    % Uses a global threshold for the wavelets. Wavelet family is coiflet 
    % (level depending). Threshold the wavelet coefficients to generate 
    % artifact signals, reconstructing signal as channels x samples format.
    if isErp
        if EEG.srate > 500; wavLvl = 13 ;
            elseif EEG.srate > 250 && EEG.srate <= 500; wavLvl= 12 ;
            elseif EEG.srate <= 250; wavLvl = 11 ;
        end
        ThresholdRule = 'Soft' ;
    else
        if EEG.srate > 500; wavLvl = 10;
            elseif EEG.srate > 250 && EEG.srate <= 500; wavLvl = 9;
            elseif EEG.srate <=250; wavLvl = 8;
        end
        ThresholdRule = 'Hard' ;
    end

    % Parameter input overrides
    if ~isempty(ip.Results.ThresholdRule)
        ThresholdRule = ip.Results.ThresholdRule;
        end
    if ~isempty(ip.Results.wavLvl)
        wavLvl = ip.Results.wavLvl;
        end


    dataCols = reshape(EEG.data, size(EEG.data, 1),[])';

    % Wavelet Thresholding Function (requires MATLAB Wavelet Toolbox)
    artifacts = wdenoise(dataCols, ...
        wavLvl, ...
        'Wavelet', ip.Results.wavelet, ...
        'DenoisingMethod', ip.Results.DenoisingMethod, ...
        'ThresholdRule', ThresholdRule, ...
        'NoiseEstimate', ip.Results.NoiseEstimate)' ;

    % HAPPE 2 Algorithm (happe_wavThresh.m Line: 95-112)
    % REMOVE ARTIFACT FROM DATA: Subtract out the wavelet artifact signal from 
    % the EEG signal and save the wavcleaned data into an EEGLAB structure. If 
    % conducting ERP analyses, filter the data to the user-specified frequency 
    % range for analyses purposes only.
    if isErp
        preEEG = reshape(pop_eegfiltnew(EEG, ip.Results.highpass, ...
            ip.Results.lowpass, [], 0, [], 0).data, ...
            size(EEG.data, 1), []) ;
        EEG.data = reshape(EEG.data, size(EEG.data,1), []) - artifacts ;
        postEEG = reshape(pop_eegfiltnew(EEG, ip.Results.highpass, ...
            ip.Results.lowpass, [], 0, [], 0).data, ...
            size(EEG.data, 1), []) ;
    else
        preEEG = reshape(EEG.data, size(EEG.data,1), []) ;
        postEEG = preEEG - artifacts ;
        EEG.data = postEEG ;
    end    

    % END: Signal Processing

    % QI Table
    qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
        'VariableNames', {'eegid','scriptname','timestamp'});

    % Outputs:
    EEG.vhtp.eeg_htpEegWaveletDenoiseHappe.summary_table =  summary_table;
    EEG.vhtp.eeg_htpEegWaveletDenoiseHappe.qi_table = qi_table;

    results = EEG.vhtp.eeg_htpEegWaveletDenoiseHappe;
end
