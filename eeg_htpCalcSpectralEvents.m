function [EEG, results] = eeg_htpCalcSpectralEvents(EEG, varargin)
% eeg_htpCalcSpectralEvents() - TBD
%
% Usage:
%    >> [ EEG, results ] = eeg_htpCalcSpectralEvents( EEG, varargin )
%
% Require Inputs:
%     EEG            - EEGLAB Structure
% Function Specific Inputs:
%     writeCsvFile   - Export subject summary table as CSV
%     useClassLabels - Logical. Use trial-by-trial classifications
%     classLabels    - Cell Array; 1 x EEG.trials. e.g. {'Hit','Miss'}
%     findMethod     - SE search method (see spectralevents_find.m)
%     fVec           - vector; low:high frequency; limits of TFR window.
%                      default: 2:80
%     vis            - create and store graphics for each source/frequency
%     selectChanList - Cell Array; SE limited to this list of channel
%                      names. eg. {'E1', 'E2', 'E4'};
%     selectBandList - Cell Array; restrict SE bands to list; select from
%                      {'theta', 'alpha1', 'alpha2', 'beta', 'gamma1', 'gamma2'}
%     outputdir      - change output base path; default: system tempdir
%
% Common Visual HTP Inputs:
%     'bandDefs'   - cell-array describing frequency band definitions
%     {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 'alpha2', 10.5, 12.5;
%     'beta', 13, 30;'gamma1', 30, 55; 'gamma2', 65, 80; 'epsilon', 81, 120;}
%     'outputdir' - path for saved output files (default: tempdir)
% Outputs:
%     EEG       - EEGLAB Structure with modified .vhtp field
%                 [table] summary_table: subject chan power_type_bandname
%                 [table] qi: parameters of analysis
%     results   - .vhtp structure
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output
csvtable = table();

% Inputs: Function Specific
defaultGpu = 0;

% Inputs: Common across Visual HTP functions
defaultOutputDir = tempdir;
defaultBandDefs = {
    'theta', 3.5, 7.5;
    'alpha1', 8, 10;
    'alpha2', 10.5, 12.5;
    'beta', 13, 30;
    'gamma1', 30, 55;
    'gamma2', 65, 80;
    };
defaultUseClassLabels = false;
defaultClassLabels = {'Hit','Miss'};
defaultFindMethod = 1;
defaultFVec = [2:80];
defaultVis = true;
defaultWriteCsvFile = true;

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'gpuOn', defaultGpu, @islogical);
addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
addParameter(ip, 'bandDefs', defaultBandDefs, @iscell)
addParameter(ip, 'useClassLabels', defaultUseClassLabels, @islogical);
addParameter(ip, 'classLabels', defaultClassLabels, @iscell);
addParameter(ip, 'findMethod', defaultFindMethod, @isinteger);
addParameter(ip, 'fVec', defaultFVec, @isvector);
addParameter(ip, 'vis', defaultVis, @islogical);
addParameter(ip, 'writeCsvFile', defaultWriteCsvFile, @islogical);


parse(ip, EEG, varargin{:});

outputdir = ip.Results.outputdir;
bandDefs = ip.Results.bandDefs;

% base output file can be modified with strrep()
outputfile = fullfile(outputdir, [functionstamp '_' EEG.setname '_' timestamp '.mat']);

% START: Signal Processing

%---------------------------------------------------------------
%                     Validate Input Data                     --
%---------------------------------------------------------------

if ndims(EEG.data) > 2
    fprintf('eeg_htpCalcSpectralEvents: Trials present (%d pnts x %d trials)\n', EEG.pnts, EEG.trials)
else
    warning('eeg_htpCalcSpectralEvents: No Trials Present. Please segment data.')
end

%---------------------------------------------------------------
% Spectral Events #1: Organize Inputs                         --
%---------------------------------------------------------------
% See spectralevents.m documentation for input specifications

% Prepopulate data per channel/source
% Define trials or subject classification
% Opt. 1: All trials have a single label
% Opt. 2: Each trial has a individual label, i.e. 'hit' or 'miss'

channames   = {EEG.chanlocs.labels};

if ip.Results.useClassLabels == true
    assert( numel(ip.Results.classLabels) == EEG.trials, 'Classification Labels do not equal number of trials.')
else
    % create subject m-by-n matrix nested in channels
    warning('eeg_htpCalcSpectralEvents: All trials in single group.')
    sig = [];
    classLabels = [];
    for ci = channames
            sig.(ci{1}) = se_exportTrialsByChanName(EEG, ci{1}, EEG.pnts);
            classLabels.(ci{1}) = 1;
    end
end

%---------------------------------------------------------------
% Spectral Events #2: Analysis parameters                     --
%---------------------------------------------------------------
%% Define Band Ranges
bandDefs = ip.Results.bandDefs;
bandIntervals = [];
for bi = 1 : length(bandDefs)
    bandIntervals.(bandDefs{bi,1}) = [bandDefs{bi,2} bandDefs{bi,3}];
end

Fs = EEG.srate;  % sample rate
findMethod = ip.Results.findMethod;
fVec = ip.Results.fVec;
vis = ip.Results.vis;

%---------------------------------------------------------------
% Spectral Events #3: Run Analysis                            --
%---------------------------------------------------------------


specEvents = []; TFRs =[]; timeseries = [];
chanSpectralEvents = []; chanTFRs = []; chantimeseries = [];

bandNames = fieldnames(bandIntervals)';
   %% 
for ci = 1 : numel(channames)
    curchan = channames{ci}; % current channel
    disp(curchan);
    % logic for running selected channels only (i.e. per region)
    % TBD
    for bi = 1 : numel(bandNames)
       curBand = bandNames{bi};
       disp(curBand);
       eventBand = bandIntervals.(curBand);

       sigX = double(sig.(curchan));
       clX = classLabels.(curchan);

       [specEvents.(curBand), ~,~] = fx_spectralevents(eventBand,fVec, ...
           Fs,findMethod, vis, sigX, ...
           clX);

       if vis
           suffix = [curBand '_' curchan];
           imgfile1 = fullfile(tempdir, strrep(EEG.filename, '.set', ['_SE_TFR_' suffix '.png']));
           imgfile2 = fullfile(tempdir, strrep(EEG.filename, '.set', ['_SE_event_' suffix '.png']));
           saveas(1, imgfile1);
           saveas(2, imgfile2);
           close all;
       end
    end
    chanSpectralEvents.(curchan) = specEvents;
    %chanTFRs.(ci{1}) = TFRs;
    %chantimeseries.(ci{1}) = timeseries;  
end

%% Create CSV
count = 1;
csvout = {};
for ci = fieldnames(chanSpectralEvents)'
    disp(ci);
    channame = ci{1};
    se_tmp = chanSpectralEvents.(channame);
    for bi = fieldnames(se_tmp)'
        eventBand = bi{1};
        se_band_tmp = se_tmp.(eventBand);

        se_TrialSummary = se_band_tmp.("TrialSummary");
        se_Events = se_band_tmp.("Events");
        se_IEI = se_band_tmp.("IEI");

        % create CSV
        csvout{count, 1} = EEG.setname;
        csvout{count, 2} = bi{1};
        csvout{count, 3} = ci{1};
        csvout{count, 4} = se_TrialSummary.NumTrials;

        features = {'eventnumber_median','eventnumber_mean','iei_mean','iei_median',...
            'eventduration_mean', 'noeventtrials_percent', 'eventpower_median','eventpower_mean', ...
            'trialpower_median','trialpower_mean', 'coverage_mean', 'fspan_mean'}; %Fields within specEv_struct

        for fi = features

            switch fi{1}
                case 'eventnumber_median'
                    csvout{count, 5} = ...
                        median(se_TrialSummary.TrialSummary.eventnumber);
                case 'eventnumber_mean'
                    csvout{count, 6} = ...
                        mean(se_TrialSummary.TrialSummary.eventnumber);
                case 'iei_mean' % Inter-event interval (IEI)
                    csvout{count, 7} = ...
                        mean(se_IEI.IEI_all);
                case 'iei_median' % Inter-event interval (IEI)
                    csvout{count, 8} = ...
                        median(se_IEI.IEI_all');
                case 'eventduration_mean' % no empty trials
                    csvout{count, 9} = ...
                        sum(se_TrialSummary.TrialSummary.meaneventduration)/nnz(se_TrialSummary.TrialSummary.meaneventduration);
                case 'noeventtrials_percent'
                    csvout{count, 10} = ...
                        sum(se_TrialSummary.TrialSummary.eventnumber' == 0) / se_TrialSummary.NumTrials;
                case 'eventpower_median'
                    csvout{count, 11} = ...
                        median(se_TrialSummary.TrialSummary.meaneventpower);
                case 'eventpower_mean'
                    csvout{count, 12} = ...
                        mean(se_TrialSummary.TrialSummary.meaneventpower);
                case 'trialpower_median'
                    csvout{count, 13} = ...
                        median(se_TrialSummary.TrialSummary.meanpower);
                case 'trialpower_mean'
                    csvout{count, 14} = ...
                        mean(se_TrialSummary.TrialSummary.meanpower);
                case 'coverage_mean'
                    csvout{count, 15} = ...
                        mean(se_TrialSummary.TrialSummary.coverage);
                case 'fspan_mean'
                    csvout{count, 16} = ...
                        sum(se_TrialSummary.TrialSummary.meaneventFspan) / nnz(se_TrialSummary.TrialSummary.meaneventFspan);
            end

        end
        count = count + 1;
    end
end

columnNames = {'eegid','channel','band','notrials','eventnumber_median','eventnumber_mean','iei_mean','iei_median',...
               'eventduration_mean', 'noeventtrials_percent', 'eventpower_median','eventpower_mean', ...
               'trialpower_median','trialpower_mean', 'coverage_mean', 'fspan_mean'};
csvtable = cell2table(csvout, "VariableNames", columnNames);


% END: Signal Processing

%---------------------------------------------------------------
%                   Quality Assurance Table                   --
%---------------------------------------------------------------

qi_table = cell2table({EEG.setname, EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid', 'filename', 'scriptname', 'timestamp'});

qi_temp = struct2table(ip.Results, 'AsArray',true);
qi_temp.EEG = [];
qi_temp.classLabels = [];
qi_temp.bandDefs = [];
qi_temp.fVec = sprintf('%d-%d',qi_temp.fVec(1), qi_temp.fVec(end));

qi_table = [qi_table qi_temp];

%---------------------------------------------------------------
%                   Outputs                                   --
%---------------------------------------------------------------

EEG.vhtp.eeg_htpCalcSpectralEvents.summary_table = csvtable;
EEG.vhtp.eeg_htpCalcSpectralEvents.qi_table = qi_table;

matsavefile = fullfile(tempdir, [functionstamp '_' strrep(EEG.filename, '.set', ['_SE_all' timestamp '.mat'])]);
save(matsavefile, 'chanSpectralEvents' );
disp(['CSV File:' matsavefile]);

if ip.Results.writeCsvFile
    writetable(csvtable, strrep(matsavefile,'.mat','.csv'))
    disp(['CSV File:' strrep(matsavefile,'.mat','.csv')]);
end


end


function mat = se_exportTrialsByChanName( EEG, channame, samplesPerTrial)

    chanIdx = strcmp(channame, {EEG.chanlocs.labels});
    tmpmat = EEG.data(chanIdx, :);
    mat = reshape(tmpmat, samplesPerTrial, []);

end