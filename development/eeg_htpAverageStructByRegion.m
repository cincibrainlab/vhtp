function EEG = eeg_htpAverageStructByRegion( EEG, varargin )
% Description: ERP dimension reduction (nodes -> regions)
% Category: Analysis
% Tags: ERP Source
% Currently built for DK atlas, however, can be adapted to any atlas.

defaultScriptName = 'eeg_htpVisualizeChirpItcErsp';

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'scriptname', defaultScriptName)
parse(ip,EEG,varargin{:});

atlas_file = 'chanfiles/DK_atlas-68_dict.csv';

switch ip.Results.scriptname
    case 'eeg_htpVisualizeChirpItcErsp'
        % placeholder
end

% Create Region Level Channels
regionatlas = readtable(atlas_file);

EEGRegion = EEG;

% Assign Regions to Chanlocs
for i = 1 : numel(EEGRegion.chanlocs)
    tmpChan = EEGRegion.chanlocs(i).labels;
    EEGRegion.chanlocs(i).Region = table2cell(regionatlas(find(strcmp(tmpChan, regionatlas.labelclean)), 'region'));
    EEGRegion.chanlocs(i).Region =  EEGRegion.chanlocs(i).Region{1};
    ordered_regions{i} = EEGRegion.chanlocs(i).Region;
end

% Get index of regions to reduce dimension of channel data
regiontable = table();
regiontable.labels = ordered_regions';
regiontable.category = categorical(ordered_regions');
region_categories = unique(regiontable.category);
category_index = {};
category_name = {};
for i = 1 : numel(region_categories)
    category_index{i} = find(regiontable.category == region_categories(i));
    category_name{i} = region_categories(i);
end

EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.itc1_region = {};
tmp_region_mean = {};
for i = 1 : numel(category_index)
    tmp_region_mean_itc{i} = mean(EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.itc1(:,:,category_index{i} ),3);
    tmp_region_mean_ersp{i} = mean(EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.ersp1(:,:,category_index{i} ),3);
end

EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.region_itc1 = cat(3, tmp_region_mean_itc{:});
EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.region_ersp = cat(3, tmp_region_mean_ersp{:});

EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.chan_itc1 = EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.itc1;
EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.chan_ersp1 = EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.ersp1;
EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.chan_chanlocs = EEGRegion.chanlocs;

EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.itc1 = cat(3, tmp_region_mean_itc{:});
EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.ersp = cat(3, tmp_region_mean_ersp{:});

EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.region_chanlocs = EEGRegion.chanlocs(1);
for i = 1 : numel(category_name)
    EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.region_chanlocs(i).labels = char(category_name{i});
end

EEGRegion.chanlocs = EEGRegion.vhtp.eeg_htpCalcChirpItcErsp.region_chanlocs;

EEG = EEGRegion;

end