function [EEG, results] = eeg_htpCalcAacGlobal( EEG, varargin )
% Description: calculates  amplitude-amplitude coupling (AAC)
% ShortTitle: Amplitude-Amplitude Coupling
% Category: Analysis
% Tags: Connectivity
% Implemented as described in Wang et al. (2017). Global (mean) power
% of the low frequency band is coupled with local gamma power.
%
% Usage:
%    >> [ EEG, results ] = eeg_htpCalcAacGlobal( EEG, varargin )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
% Function Specific Inputs:
%     gpuon     - [logical] use gpuArray. default: false
%   sourcemode  - use DK atlas with source data
%
% Common Visual HTP Inputs:
%     'bandDefs'   - cell-array describing frequency band definitions
%     {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 'alpha2', 10.5, 12.5;
%     'beta', 13, 30;'gamma1', 30, 55; 'gamma2', 65, 80; 'epsilon', 81, 120;}
%     'outputdir' - path for saved output files (default: tempdir)
%
% Outputs:
%     EEG       - EEGLAB Structure with modified .etc.htp field
%     results   - etc.htp results structure or customized
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab/vhtp for details. 
%
%  Contact: kyle.cullion@cchmc.org

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

% Inputs: Function Specific
defaultOutputDir = tempdir;
defaultBandDefs = {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10;
    'alpha2', 10, 12; 'beta', 13, 30;'gamma1', 30, 55;
    'gamma2', 65, 80; 'epsilon', 81, 120; };
defaultGpuOn = 0;
defaultMeaOn = 0;
defaultSourceMode = false;
defaultDuration = 60;

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder)
addParameter(ip,'bandDefs', defaultBandDefs, @iscell)
addParameter(ip, 'gpuon', defaultGpuOn, @islogical);
addParameter(ip, 'meaOn', defaultMeaOn, @islogical);
addParameter(ip, 'sourcemode', defaultSourceMode, @islogical);
addParameter(ip, 'duration', defaultDuration, @isnumeric);
parse(ip,EEG,varargin{:});

outputdir = ip.Results.outputdir;
bandDefs = ip.Results.bandDefs;

% base output file can be modified with strrep()
outputfile = fullfile(ip.Results.outputdir, ...
    [functionstamp '_'  EEG.setname '_' timestamp '.mat']);

% START: Signal Processing
% check if data is continuous, if not epoch to 1 s bins
if ndims(EEG.data) > 2
    warning("Data is epoched. Converted to continuous.")
    EEG = epoch2cont(EEG);
    % EEG = eeg_regepochs(EEG, 'recurrence', 1);
end

% Consistent Duration
totalTime = EEG.pnts / EEG.srate;
if totalTime < ip.Results.duration
        warning("Insufficient Data, using max samples.")
else
      EEG = pop_select(EEG, 'time', [EEG.xmin EEG.xmin+ip.Results.duration]); % extract baseline
end

if ip.Results.gpuon
    warning('GPU Arrays Enabled.')
    EEG.data = gpuArray(EEG.data);
end
% get channel structure
chanlocs = EEG.chanlocs;
if ~ip.Results.sourcemode
    % create full atlas table in chanlocs order
    if ip.Results.meaOn
           chanlocs = EEG.chanlocs;
 
    else
    chanlist = cell2table({chanlocs.labels}', 'VariableNames', {'chan'});
    chanlist.index = (1:height(chanlist)).';
    atlasLookupTable = readtable("GSN-HydroCel-129_dict.csv");
    matchedAtlasTable = innerjoin( chanlist, atlasLookupTable, ...
        'Keys', {'chan','chan'});

    matchedAtlasTable = sortrows(matchedAtlasTable,'index');

    % Remove the "other" nodes
    checkchans = chanlocs(~(matchedAtlasTable.position == "OTHER"));
    chanlocs(~(matchedAtlasTable.position == "OTHER"))
    EEG = pop_select(EEG, 'channel', find(~(matchedAtlasTable.position == "OTHER")));
    chanlocs = EEG.chanlocs;
    end
else
    % create full atlas table in chanlocs order
    chanlist = cell2table({chanlocs.labels}', 'VariableNames', {'labelclean'});
    atlasLookupTable = readtable("DK_atlas-68_dict.csv");
    matchedAtlasTable = innerjoin( chanlist, atlasLookupTable, 'Keys', {'labelclean','labelclean'});

    networks = unique(matchedAtlasTable.RSN);
    for i = 1 : numel(networks)
        netindex.(networks{i}) = strcmp(matchedAtlasTable.RSN,  networks{i});
    end

    nodes = unique(matchedAtlasTable.labelclean);
    for i = 1 : numel(nodes)
        nodeindex.(nodes{i}) = find(strcmp(matchedAtlasTable.labelclean,  nodes{i}));
    end
end


% alternative power calculation
upperFreqLimit = 90;
deviationFromLog = 5;
PSD = [];
freqBins = logspace(log10(1+deviationFromLog), log10(upperFreqLimit+deviationFromLog), 281)-deviationFromLog;
PSDType = {'absolute','relative'}; PSDArray = [];
for pi = 1 : numel(PSDType)
    for i = 1 : size(EEG.data,1)
        [~, freqs, times, firstPSD] = spectrogram(EEG.data(i,:), EEG.srate, ...
            floor(EEG.srate/2), freqBins, EEG.srate);
        % hz x trial x chan
        switch PSDType{pi}
            case 'absolute'
                PSDArray.(PSDType{pi})(:,:,i) = firstPSD; %#ok<*SAGROW> % 100 (hz pnts) x 161 (trials) x 68
            case 'relative'
                PSDArray.(PSDType{pi})(:,:,i) = firstPSD ./ sum(firstPSD,1); % Relative Power
        end
    end
end
%firstPSD2 = squeeze(s.rest_rel_power);
%%

glmaac=[]; count = 0;
loBandArr = {'theta','alpha1','alpha2'};
hiBandArr = {'gamma1'};

% create band indexes and global cluster for correlation
bandname = []; bandindex =[]; bandpower =[]; cluster =[];
for pi = 1 : numel(PSDType)

    PSD = gather(PSDArray.(PSDType{pi}));

    for bandi = 1 : length(bandDefs)
        bandname =[ PSDType{pi} '_' bandDefs{bandi,1}];
        bandindex.(bandname) = freqs > bandDefs{bandi,2} & freqs < bandDefs{bandi,3};
        bandpower.(bandname) = squeeze(mean(PSD(bandindex.(bandname),:,:),1));
        cluster_indices = 1 : numel(chanlocs);  % replace with any channel index, i.e. network indexes
        cluster.(bandname) =  squeeze(mean(bandpower.(bandname)(:,cluster_indices),2));
    end

end

% compute global to local AAC
globalaac = @(globalPower, localNodePower) corr(globalPower, localNodePower, 'Type', 'Spearman');
bandDefs2 = fieldnames(cluster); aac = []; PSD = [];
for pi = 1 : numel(PSDType)
    PSD = PSDArray.(PSDType{pi});
    for bandi = 1 : length(bandDefs2)
        % bandname = bandDefs{bandi,1};
        bandname = bandDefs2{bandi};
        bandSplitName = strsplit(bandname, "_");
        lowerPowerType = bandSplitName{1};

        if contains(bandname, {'theta','alpha1','alpha2'}) % low to high frequency
            lowerband = bandname;

            globalnode = repmat(cluster.(lowerband), [1 size(bandpower.(lowerband),2)]);
            localnodes = bandpower.(bandname);

            % upperbands = {'absolute_gamma1','absolute_gamma2','absolute_epsilon'};
            for ui = 1 : length(bandDefs2)
                upperband = bandDefs2{ui,1};
                bandSplitName = strsplit(upperband, "_");
                upperPowerType = bandSplitName{1};
                if strcmp(lowerPowerType, upperPowerType)
                    if contains(upperband, {'gamma1','gamma2','epsilon'})
                        % aac for just upper bands with lower bands
                        label = sprintf("%s_%s_aac", lowerband, bandDefs2{ui,1});
                        aac.(label) = globalaac(globalnode, bandpower.(bandDefs2{ui,1}));
                    end
                end
            end
        end
    end
end

for i = 1 : numel(fieldnames(aac))
    label = fieldnames(aac);
    aac.(label{i}) = aac.(label{i})(1,:);
end

% Create CSV rows
% count = 1;
csvout = {};
datafields = fieldnames(aac);
for ci = 1 : numel(chanlocs)
    csvout{ci, 1} = EEG.setname;
    csvout{ci, 2} = chanlocs(ci).labels;
    csvout{ci, 3} = EEG.filename;
    for fi = 1 : numel(datafields)
        workingField = aac.(datafields{fi});
        csvout{ci, 3+fi} = workingField(ci);
    end
end

% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp, ip.Results.sourcemode}, ...
    'VariableNames', {'eegid','scriptname','timestamp', 'sourcemode'});

% Outputs:
EEG.vhtp.eeg_htpCalcAacGlobal.summary_table = ...
    cell2table(csvout, "VariableNames", [{'eegid'},{'chan'},{'filename'}, datafields(:)']);
EEG.vhtp.eeg_htpCalcAacGlobal.qi_table = qi_table;

results = EEG.vhtp.eeg_htpCalcAacGlobal;

end


function EEG = epoch2cont(EEG)
% revised 9/30/2021

if length(size(EEG.data)) > 2
    % starting dimensions
    [nchans, npnts, ntrial] = size(EEG.data);
    EEG.data = double(reshape(EEG.data, nchans, npnts * ntrial));
    EEG.pnts = npnts * ntrial;
    EEG.times = 1:1 / EEG.srate:(size(EEG.data, 2) / EEG.srate) * 1000;
else
    warning('Data is likely already continuous.')
    fprintf('No trial dimension present in data');
end

EEG = eeg_checkset(EEG);
EEG.data = double(EEG.data);

end