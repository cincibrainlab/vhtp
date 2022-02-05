function [EEG2, results] = eeg_htpComputeSource( EEG, varargin )
% eeg_htpComputeSource() - compute forward solution using Brainstorm. By
% default the function creates an minimum norm estimate source model from
% EGI-128 formatted data. The datasets are stored as SET files with
% atlas regions as channels.
%
% Usage:
%    >> [ EEG, results ] = eeg_htpComputeSource( EEG )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
% Function Specific Inputs:
%     'option1' - description
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
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org
%
% download_headmodel = ...
%    'http://www.dropbox.com/s/0m8oqrnlzodfj2n/headmodel_surf_openmeeg.mat?dl=1';
% urlwrite(download_headmodel, precomputed_openmeeg);

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

% if ~isfile(precomputed_openmeeg)
%     urlwrite(download_headmodel, precomputed_openmeeg);
% end

% Inputs: Function Specific

% Inputs: Common across Visual HTP functions
defaultOutputDir = tempdir;
defaultBandDefs = {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10;
    'alpha2', 10, 12; 'beta', 13, 30;'gamma1', 30, 55;
    'gamma2', 65, 80; 'epsilon', 81, 120; };

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder)
addParameter(ip,'bandDefs', defaultBandDefs, @iscell)
parse(ip,EEG,varargin{:});

outputdir = ip.Results.outputdir;
bandDefs = ip.Results.bandDefs;

% base output file can be modified with strrep()
outputfile = fullfile(outputdir, [functionstamp '_'  EEG.setname '_' timestamp '.mat']);

% START: Signal Processing

% Create a new protocol if needed
ProtocolAnatSelection = 1;
ProtocolChannelSelection = 2;

% Precomputed Headmodel (OpenMEEG) (add alternate head models here)
openmeeg_egi128 = 'headmodel_surf_openmeeg.mat';
openmeeg = fullfile(tempdir, openmeeg_egi128);

if ~isfile(openmeeg), error("No head model available, please download. (http://www.dropbox.com/s/0m8oqrnlzodfj2n/headmodel_surf_openmeeg.mat?dl=1)"); end

% Get the protocol index of an existing protocol (already loaded previously in Brainstorm)
iProtocol = bst_get('Protocol', 'eeg_htp');

if isempty(iProtocol)
    gui_brainstorm('CreateProtocol', 'eeg_htp',...
        ProtocolAnatSelection, ProtocolChannelSelection);
else
    gui_brainstorm('SetCurrentProtocol', iProtocol);
end

% Select all recordings
files_to_delete = bst_process('CallProcess', 'process_select_files_data', [], [], ...
   'Comment', 'Link to raw file');

if ~isempty(files_to_delete)
    % Process: Delete subjects
    bst_process('CallProcess', 'process_delete', files_to_delete, [], ...
        'target', 1);  % Delete subjects
end

bstDefaults = bst_get('EegDefaults');

% define net
chanInfoStruct.headModel    = 'ICBM152';
chanInfoStruct.brand        = 'GSN';
chanInfoStruct.chanNumber   = '128';
chanInfoStruct.chanLabelFormat = 'E1';
net_index = selectBstDefaults(chanInfoStruct);

% generate continuous data for source model
cEEG = epoch2cont(EEG);
rawFile = fullfile(tempdir, EEG.filename);
pop_saveset(cEEG, rawFile);

filetype = 'EEG-EEGLAB';
sFile =  bst_process('CallProcess', ...
    'process_import_data_raw', [], [], ...
    'subjectname', EEG.setname, ...
    'datafile', {rawFile, filetype}, ...
    'channelreplace', net_index, ...
    'channelalign', 1, ...
    'evtmode', 'value');

sFile = bst_process('CallProcess', 'process_import_channel', ...
    sFile, [], ...
    'usedefault', net_index, ...% ICBM152: GSN HydroCel 128 E1
    'channelalign', 1, ...
    'fixunits', 1, ...
    'vox2ras', 1);

% Reselect all recordings
sFile = bst_process('CallProcess', 'process_select_files_data', sFile, [], ...
   'Comment', 'Link to raw file');

Protocol_Info = bst_get('ProtocolInfo');
subdirname = sFile.SubjectName;
default_dir = fullfile(Protocol_Info.STUDIES, ...
     bst_get('DirDefaultStudy'));
target_dir = fullfile(Protocol_Info.STUDIES, ...
    subdirname, bst_get('DirDefaultStudy'));

if ~isfile(fullfile(default_dir,openmeeg_egi128))
    copyfile(openmeeg, default_dir);
end
if ~isfile(fullfile(target_dir,openmeeg_egi128))
    copyfile(openmeeg, target_dir);
end

db_reload_database('current');

sFile = bst_process('CallProcess', 'process_noisecov', sFile, [], ...
    'baseline', [-500, -0.001], ...
    'datatimewindow', [0, 500], ...
    'sensortypes', 'MEG, EEG, SEEG, ECOG', ...
    'target', 1, ...% Noise covariance     (covariance over baseline time window)
    'dcoffset', 1, ...% Block by block, to avoid effects of slow shifts in data
    'identity', 1, ...
    'copycond', 0, ...
    'copysubj', 0, ...
    'copymatch', 0, ...
    'replacefile', 1); % Replace

sFile = bst_process('CallProcess', 'process_inverse_2018', sFile, [], ...
    'output', 1, ...% Kernel only: shared
    'inverse', struct(...
    'Comment', 'MN: EEG', ...
    'InverseMethod', 'minnorm', ...
    'InverseMeasure', 'amplitude', ...
    'SourceOrient', {{'fixed'}}, ...
    'Loose', 0.2, ...
    'UseDepth', 1, ...
    'WeightExp', 0.5, ...
    'WeightLimit', 10, ...
    'NoiseMethod', 'none', ...
    'NoiseReg', 0.1, ...
    'SnrMethod', 'fixed', ...
    'SnrRms', 1e-06, ...
    'SnrFixed', 3, ...
    'ComputeKernel', 1, ...
    'DataTypes', {{'EEG'}}));

% Process: Add Source Model Type Comment to each subject
sourceDesc = regexprep(sFile.Comment, ...
    {'[%(): ]+', '_+$'}, {'_', ''});

% manual confirmation of electrode placement
% via plot of scalp with electrodes
cfg.plot = [{'EEG'}    {'scalp'}    {[1]}];
cfg.map  = {sFile.ChannelFile};
[hFig, ~, ~] = view_channels_3d(cfg.map, cfg.plot{:});
saveas(hFig, fullfile(tempdir, ...
    'figure_makeMne_confirmElectrodeLocations.png'));
bst_memory('UnloadAll', 'Forced');
bst_progress('stop');

% retrieve atlas
sCortex = in_tess_bst('@default_subject/tess_cortex_pial_low.mat');
iAtlas = find(strcmpi({sCortex.Atlas.Name}, 'Desikan-Killiany'));
atlas = sCortex.Atlas(iAtlas);


% Process: Scouts time series: [68 scouts]
sFileExtract = bst_process('CallProcess', 'process_extract_scout', ...
    sFile, [], ...
    'timewindow',     [], ...
    'scouts',         {atlas.Name, {atlas.Scouts.Label}}, ...
    'scoutfunc',      1, ...  % Mean
    'isflip',         1, ...
    'isnorm',         0, ...
    'concatenate',    1, ...
    'save',           0, ...
    'addrowcomment',  1, ...
    'addfilecomment', 1);

% Create EEG Structure
EEG2 = EEG;

EEG2.times = [];
EEG2.data = [];
EEG2.chanlocs = [];
EEG2 = eeg_checkchanlocs(EEG2);

EEG2.times = sFileExtract.Time;  % times vector from bst
EEG2.data = sFileExtract.Value(:,:);  % data for each source channel

for j = 1 : length( sFileExtract.Atlas.Scouts )  % create chanlocs from atlas regions
    tmpatlas = sFileExtract.Atlas.Scouts(j);
    EEG2.chanlocs(j).labels = genvarname( tmpatlas.Label );
    EEG2.chanlocs(j).type = 'EEG';
end
EEG2.etc.atlas = atlas;
EEG2 = eeg_checkset(EEG2);

EEG2.filename = strrep(EEG2.filename, '.set', [sourceDesc '.set']);
EEG2.filepath = fullfile(ip.Results.outputdir, sourceDesc);
savefile = fullfile(EEG2.filepath, EEG2.filename);

if 7~=exist(EEG2.filepath,'dir'), status = mkdir(EEG2.filepath); end

EEG2 = pop_saveset( EEG2, 'filename', savefile );

% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, 'VariableNames', {'eegid','function','timestamp'});

% Outputs:
results = [];

end

function select_index = selectBstDefaults( chanInfoStruct )

bstDefaults = bst_get('EegDefaults');
strList = {''};
% Build a list of strings representing all the defaults
for iGroup = 1:length(bstDefaults)
    for iDef = 1:length(bstDefaults(iGroup).contents)
        strList{end+1} = [bstDefaults(iGroup).name ': ' ...
            bstDefaults(iGroup).contents(iDef).name];
    end
end
strList = strList';
allNetOptions = strList;
% L1: headmodel
L1 = strList(contains(strList,chanInfoStruct.headModel));
% L2: brandname
L2 = L1(contains(L1,chanInfoStruct.brand));
% L3: channels
L3 = L2(contains(L2,chanInfoStruct.chanNumber));
% L4: label format
L4 = L3(contains(L3,chanInfoStruct.chanLabelFormat));

select_index = find(strcmp(strList,L4));

end

function EEG = epoch2cont( EEG )
% revised 9/30/2021

if length(size(EEG.data)) > 2
    % starting dimensions
    [nchans, npnts, ntrial] = size(EEG.data);
    EEG.data = double(reshape(EEG.data, nchans, npnts*ntrial));
    EEG.pnts = npnts*ntrial;
    EEG.times = 1:1/EEG.srate:(size(EEG.data,2) / EEG.srate) * 1000;
else
    fprintf('No trial dimension present in data');
end

EEG = eeg_checkset( EEG );
EEG.data = double(EEG.data);

end

function sFile = computeHeadModel(sFile)

% Process: Compute head model
sFile = bst_process('CallProcess', 'process_headmodel', sFile, [], ...
    'Comment', '', ...
    'sourcespace', 1, ...% Cortex surface
    'volumegrid', struct(...
    'Method', 'isotropic', ...
    'nLayers', 17, ...
    'Reduction', 3, ...
    'nVerticesInit', 4000, ...
    'Resolution', 0.005, ...
    'FileName', ''), ...
    'meg', 3, ...% Overlapping spheres
    'eeg', 3, ...% OpenMEEG BEM
    'ecog', 2, ...% OpenMEEG BEM
    'seeg', 2, ...% OpenMEEG BEM
    'openmeeg', struct(...
    'BemSelect', [1, 1, 1], ...
    'BemCond', [1, 0.0125, 1], ...
    'BemNames', {{'Scalp', 'Skull', 'Brain'}}, ...
    'BemFiles', {{}}, ...
    'isAdjoint', 0, ...
    'isAdaptative', 1, ...
    'isSplit', 0, ...
    'SplitLength', 4000));

end