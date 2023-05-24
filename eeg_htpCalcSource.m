function [EEG2, results] = eeg_htpCalcSource(EEG, varargin)
    % Description: Compute forward solution using Brainstorm.
    % ShortTitle: Source Localization with Brainstorm
    % Category: Analysis
    % Tags: Source
    %
    % By default the function creates an minimum norm estimate source model from
    % EGI-128 formatted data. The datasets are stored as SET files with
    % atlas regions as channels.
    %
    % Usage:
    %    >> [ EEG, results ] = eeg_htpComputeSource( EEG )
    %
    % Require Inputs:
    %     EEG       - EEGLAB Structure
    % Function Specific Inputs:
    %     'saveset'     - save set to output dir (folder is source type)
    %     'confirmplot' - display and save image of channel locations
    %     default: false
    %     'headless'    - assume brainstorm is running in the background
    %     'outputdir'   - default output for tmp files; default tempdir
    %     'nettype'     - define nettype, default EGI128
    %     'computeheadmodel' - recalculate headmodel (check parameters)
    %     'headmodelfile' - specify headmodel template
    %     'deletetempfiles' - delete temporary cont. files default:false.
    %     'usepreexisting' - looks for preexisting files in output dir;
    %                       default: false
    %     'resetprotocol'         - delete and reset protocol (logical: default false)
    %     If option is true, cannot visualize results in brainstorm GUI.
    % 
    % Common Visual HTP Inputs:
    %     'bandDefs'   - cell-array describing frequency band definitions
    %     {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 'alpha2', 10.5, 12.5;
    %     'beta', 13, 30;'gamma1', 30, 55; 'gamma2', 65, 80; 'epsilon', 81, 120;}
    %     'outputdir' - path for saved output files (default: tempdir)
    %
    % Outputs:
    %     EEG       - EEGLAB Structure with modified .vhtp field
    %     results   - .vhtp structure
    %
    %  This file is part of the Cincinnati Visual High Throughput Pipeline,
    %  please see http://github.com/cincibrainlab
    %
    %  Contact: ernest.pedapati@cchmc.org
    %
    % Headmodels are available at https://figshare.com/articles/dataset/Precomputed_Headmodels_for_EEG_Source_Localization/20067350

    timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
    functionstamp = mfilename; % function name for logging/output

    % if ~isfile(precomputed_openmeeg)
    %     urlwrite(download_headmodel, precomputed_openmeeg);
    % end

    % Inputs: Function Specific
    defaultHeadless = false;
    defaultOutputDir = tempdir;
    defaultBandDefs = {'delta', 2, 3.5; 'theta', 3.5, 7.5; 'alpha1', 8, 10;
                    'alpha2', 10, 12; 'beta', 13, 30; 'gamma1', 30, 55;
                    'gamma2', 65, 80; 'epsilon', 81, 120; };
    defaultNetType = 'EGI128';
    defaultConfirmPlot = false;
    defaultSaveSet = true;
    defaultComputeHeadModel = false;
    defaultDeleteTempfiles = false;
    defaultUsePreexisting = false;
    defaultResetProtocol = false;
    defaultHeadModelFile = 'Empty';

    % MATLAB built-in input validation
    ip = inputParser();
    addRequired(ip, 'EEG', @isstruct);
    addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
    addParameter(ip, 'bandDefs', defaultBandDefs, @iscell)
    addParameter(ip, 'headless', defaultHeadless, @islogical);
    addParameter(ip, 'nettype', defaultNetType, @ischar);
    addParameter(ip, 'confirmplot', defaultConfirmPlot, @islogical);
    addParameter(ip, 'saveset', defaultSaveSet, @islogical);
    addParameter(ip, 'computeheadmodel', defaultComputeHeadModel, @islogical);
    addParameter(ip, 'headmodelfile', defaultHeadModelFile, @ischar);
    addParameter(ip, 'deletetempfiles', defaultDeleteTempfiles, @islogical);
    addParameter(ip, 'usepreexisting', defaultUsePreexisting, @islogical);
    addParameter(ip, 'resetprotocol', defaultResetProtocol, @islogical);
    parse(ip, EEG, varargin{:});

    % Dependency Check: Requires Brainstorm and EEGLAB Functions
    % BRAINSTORM
    if ~ip.Results.headless
       try
        fprintf('Brainstorm found.\n');
        if brainstorm('status'), warning('GUI Mode: Brainstorm Already Running.');
        else 
            brainstorm;
        end
       catch
            error('Please start Brainstorm or Turn on Server Mode (''headless'', true)');
       end
    end
    % EEGLAB
    if exist('eeglab', 'file') == 0,  error('Please add EEGLAB to path.'); else, fprintf('EEGLAB found.\n'); end
    % Access to Headmodel
    % see under nettype switch

    % START: Signal Processing

    iProtocol = bst_get('Protocol', 'eeg_htp');

    % default settings (modify for individual headmodels)
    ProtocolAnatSelection = 1;
    ProtocolChannelSelection = 2;

    % Get the protocol index of an existing protocol (already loaded previously in Brainstorm)
    if isempty(iProtocol)
        % Create a new protocol if needed
        gui_brainstorm('CreateProtocol', 'eeg_htp', ...
            ProtocolAnatSelection, ProtocolChannelSelection);
    else
        gui_brainstorm('SetCurrentProtocol', iProtocol);
        % get all recordings
        if ip.Results.resetprotocol
            gui_brainstorm('DeleteProtocol', 'eeg_htp');
            gui_brainstorm('CreateProtocol', 'eeg_htp', ...
                ProtocolAnatSelection, ProtocolChannelSelection);
        end
        % use preexisting data
        if ip.Results.usepreexisting
            preexisting_source_files = bst_process('CallProcess', 'process_select_files_results', [], [], ...
                'Comment', 'Link to raw file');
            subIdx = find(strcmp(EEG.setname, {preexisting_source_files.SubjectName}));
            if ~isempty(subIdx)
                sFile = preexisting_source_files(subIdx);
                % Process: Add Source Model Type Comment to each subject
                sourceDesc = regexprep(sFile.Comment, ...
                    {'[%(): ]+', '_+$'}, {'_', ''});
                source.filename = strrep(EEG.filename, '.set', [sourceDesc '.set']);  
                source.filepath = fullfile( ip.Results.outputdir, sourceDesc );
                sourceEEG = pop_loadset(source.filename, source.filepath);
                EEG2 = sourceEEG;
                return
            end
        end

    end

    % define net and select from brainstorm options dynamically
    switch ip.Results.nettype
        case 'EGI128'
            chanInfoStruct.headModel = 'ICBM152';
            chanInfoStruct.brand = 'GSN';
            chanInfoStruct.chanNumber = '128';
            chanInfoStruct.chanLabelFormat = 'E1';
            openmeeg_file = 'headmodel_surf_openmeeg_EGI128.mat';
            openmeeg_url = 'https://figshare.com/ndownloader/files/35889050';
        case 'EGI32'
            chanInfoStruct.headModel = 'ICBM152';
            chanInfoStruct.brand = 'GSN';
            chanInfoStruct.chanNumber = '32';
            chanInfoStruct.chanLabelFormat = 'E1';
            openmeeg_file = 'headmodel_surf_openmeeg_EGI32.mat';
            openmeeg_url = 'https://figshare.com/ndownloader/files/35889047';
        case 'BioSemi64' %Biosemi 64 A1
            chanInfoStruct.headModel = 'ICBM152';
            chanInfoStruct.brand = 'BioSemi';
            chanInfoStruct.chanNumber = '64';
            chanInfoStruct.chanLabelFormat = 'A1';
            openmeeg_file = 'headmodel_surf_openmeeg_BioSemi64.mat'; 
            openmeeg_url = 'https://figshare.com/ndownloader/files/35889044';
    end

    % verify data channels
    if str2double(chanInfoStruct.chanNumber) ~= EEG.nbchan
        error('Net Type: Incorrect Electrode Montage; number of channels in EEG files do not match headmodel. Specify nettype parameter.')
    end


    % refresh protocol number
    if isempty(iProtocol), iProtocol = bst_get('Protocol', 'eeg_htp'); end
    Protocol_Info = bst_get('ProtocolInfo');
    default_dir = fullfile(Protocol_Info.STUDIES, ...
        bst_get('DirDefaultStudy'));

    % Load specific head models
    net_index = selectBstDefaults(chanInfoStruct);

    % Check for headmodel in default directory
    default_headmodel_target =  fullfile(default_dir, 'headmodel_surf_openmeeg.mat');
    isDefaultHeadModelAvailable = exist(default_headmodel_target, 'file');

    % see if user requests file to be overwritten
    isExternalHeadmodelAvailable = isempty(ip.Results.headmodelfile);

    if ip.Results.computeheadmodel
        delete(default_headmodel_target);  % remove any existing headmodel 
        sFile = computeHeadModel( sFile ); % calculate headmodel
    else


        % download or copy headmodel
        if isDefaultHeadModelAvailable ~= 2 && isExternalHeadmodelAvailable == false
            fprintf('Headmodel: No default file available & No external file provided. \nHeadmodel: Will attempt download from figshare.\n');
            fprintf('Headmodel: Default file available & No external file provided.\n');
            fprintf('Dowloading %s to %s\nFigshare URL: %s\n', openmeeg_file, default_headmodel_target, openmeeg_url);
            try
                options = weboptions('CertificateFilename', '');
                websave(default_headmodel_target, openmeeg_url, options);
                disp("Headmodel: Successful download and save of headmodel to default protocol directory.");
            catch
                error("Headmodel: Unable to successfully download and save headmodel.");
            end

        else
            if isDefaultHeadModelAvailable == 2 && isExternalHeadmodelAvailable == false
                disp("Headmodel: Headmodel available in default protocol directory.");
            end

            if isExternalHeadmodelAvailable == true
                fprintf('Headmodel: External file provided. \nHeadmodel: Will copy to default protocol directory.\n');
                % add one copy of headmodel to default directory
                copyfile(ip.Results.headmodelfile, target_default_headmodel);
            end
        end
    end

    % Check if subject is already present, if so delete.
    [dupSub, iSub] = bst_get('Subject', EEG.setname);
    if ~isempty(dupSub)
        warning('Duplicate Subject Found. Deleting and Recalculating.')
        db_delete_subjects(iSub)
    end

    % EEG SET to Brainstrom
    % generate continuous data for source model
    cEEG = eeg_htpEegEpoch2Cont(EEG);

    % temporary storage for continuous data
    tempContFile = fullfile(ip.Results.outputdir, EEG.filename);
    pop_saveset(cEEG, 'filename', EEG.filename, 'filepath', ip.Results.outputdir);

    filetype = 'EEG-EEGLAB';
    sFile = bst_process('CallProcess', ...
        'process_import_data_raw', [], [], ...
        'subjectname', EEG.setname, ...
        'datafile', {tempContFile, filetype}, ...
        'channelreplace', net_index, ...
        'channelalign', 1, ...
        'evtmode', 'value');

    % Delete temporary file
    if ip.Results.deletetempfiles
        try delete(tempContFile); catch, warning('Warning: Temporary Continuous File Not Deleted or Missing.'); end
    end
    % Assign Channel File
    sFile = bst_process('CallProcess', 'process_import_channel', ...
        sFile, [], ...
        'usedefault', net_index, ... % ICBM152: GSN HydroCel 128 E1
        'channelalign', 1, ...
        'fixunits', 1, ...
        'vox2ras', 1);

     if ip.Results.computeheadmodel
        sFile = computeHeadModel( sFile ); % calculate headmodel
     end

    % Get subject directory to copy headfile
    subject_subdir = sFile.SubjectName;
    subject_dir = fullfile(Protocol_Info.STUDIES, subject_subdir, bst_get('DirDefaultStudy'));

    % check if headfile is already copied in subject directory
    subject_default_headmodel = fullfile(subject_dir, 'headmodel_surf_openmeeg.mat');
    isSubjectHeadModelAvailable = exist(subject_default_headmodel, 'file');

    % add one copy of headmodel to subject directory
    if ~isSubjectHeadModelAvailable, copyfile(default_headmodel_target, subject_default_headmodel); end
    db_reload_database('current');

    % Reselect all recordings
    % Process: Select data files in: D1156_rest_postcomp.set/*
    sFile = bst_process('CallProcess', 'process_select_files_data', [], [], ...
        'subjectname',   subject_subdir, ...
        'condition',     '', ...
        'tag',           '', ...
        'includebad',    0, ...
        'includeintra',  0, ...
        'includecommon', 0);

    sFile = bst_process('CallProcess', 'process_noisecov', sFile, [], ...
        'baseline', [-500, -0.001], ...
        'datatimewindow', [0, 500], ...
        'sensortypes', 'MEG, EEG, SEEG, ECOG', ...
        'target', 1, ... % Noise covariance     (covariance over baseline time window)
        'dcoffset', 1, ... % Block by block, to avoid effects of slow shifts in data
        'identity', 1, ...
        'copycond', 0, ...
        'copysubj', 0, ...
        'copymatch', 0, ...
        'replacefile', 1); % Replace

    sFile = bst_process('CallProcess', 'process_inverse_2018', sFile, [], ...
        'output', 1, ... % Kernel only: shared
        'inverse', struct( ...
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
    if ip.Results.confirmplot
        cfg.plot = [{'EEG'} {'scalp'} {[1]}];
        cfg.map = {sFile.ChannelFile};
        [hFig, ~, ~] = view_channels_3d(cfg.map, cfg.plot{:});
        saveas(hFig, fullfile(tempdir, ...
            'eeg_htpCalcSource_confirmplot.png'));
        bst_memory('UnloadAll', 'Forced');
        bst_progress('stop');
    end

    % retrieve atlas
    sCortex = in_tess_bst('@default_subject/tess_cortex_pial_low.mat');
    iAtlas = find(strcmpi({sCortex.Atlas.Name}, 'Desikan-Killiany'));
    atlas = sCortex.Atlas(iAtlas);

    % Process: Scouts time series: [68 scouts]
    sFileExtract = bst_process('CallProcess', 'process_extract_scout', ...
    sFile, [], ...
        'timewindow', [], ...
        'scouts', {atlas.Name, {atlas.Scouts.Label}}, ...
        'scoutfunc', 1, ... % Mean
        'isflip', 1, ...
        'isnorm', 0, ...
        'concatenate', 1, ...
        'save', 0, ...
        'addrowcomment', 1, ...
        'addfilecomment', 1);

    % EEG2 = Source EEG SET (using original SET as template)
    EEG2 = EEG; EEG2.times = []; EEG2.data = []; EEG2.chanlocs = [];
    EEG2 = eeg_checkchanlocs(EEG2);
    EEG2.times = sFileExtract.Time; % times vector from bst
    EEG2.data = sFileExtract.Value(:, :); % data for each source channel
    EEG2.trials = 1;
    EEG2.pnts = size(EEG2.data ,2);

    % added 3/4/22 to strip ICA information on conversion which causes load issues on some systems.
    EEG2.icawinv        = [];
    EEG2.icasphere      = [];
    EEG2.icaweights     = []; 
    EEG2.icachansind    = [];

    for j = 1:length(sFileExtract.Atlas.Scouts) % create chanlocs from atlas regions
        tmpatlas = sFileExtract.Atlas.Scouts(j);
        EEG2.chanlocs(j).labels = genvarname(tmpatlas.Label);
        EEG2.chanlocs(j).type = 'EEG';
    end
    EEG2.nbchan = numel(EEG2.chanlocs);


    EEG2.filename = strrep(EEG2.filename, '.set', ['_' sourceDesc '.set']);
    EEG2.filepath = fullfile(ip.Results.outputdir, sourceDesc);
    savefile = fullfile(EEG2.filepath, EEG2.filename);

    EEG2.vhtp.eeg_htpCalcSource.atlas = atlas;
    EEG2.etc.atlas = atlas;

    EEG2 = eeg_checkset(EEG2);

    if ip.Results.saveset
        if 7 ~= exist(EEG2.filepath, 'dir'), status = mkdir(EEG2.filepath); end
        EEG2 = pop_saveset(EEG2, 'filename', savefile);
    else
        warning('eeg_htpCalcSource.atlas: Source SET not saved (use option ''saveset'', true).')
    end

    % END: Signal Processing
    % QI Table
    EEG2.vhtp.eeg_htpCalcSource.qi_table = ...
        cell2table({EEG.setname, functionstamp, timestamp ip.Results.outputdir, ...
        ip.Results.headless, ip.Results.nettype, ip.Results.confirmplot, ip.Results.saveset}, ...
        'VariableNames', {'eegid', 'scriptname', 'timestamp', 'outputdir', ...
        'headless','nettype','confirmplot','saveset'});

    % Outputs:
    results = EEG2.vhtp.eeg_htpCalcSource;

end

function select_index = selectBstDefaults(chanInfoStruct)

    bstDefaults = bst_get('EegDefaults');
    strList = {''};
    % Build a list of strings representing all the defaults
    for iGroup = 1:length(bstDefaults)

        for iDef = 1:length(bstDefaults(iGroup).contents)
            strList{end + 1} = [bstDefaults(iGroup).name ': ' ...
                            bstDefaults(iGroup).contents(iDef).name];
        end

    end

    strList = strList';
    allNetOptions = strList;
    % L1: headmodel
    L1 = strList(contains(strList, chanInfoStruct.headModel));
    % L2: brandname
    L2 = L1(contains(L1, chanInfoStruct.brand));
    % L3: channels
    L3 = L2(contains(L2, chanInfoStruct.chanNumber));
    % L4: label format
    L4 = L3(contains(L3, chanInfoStruct.chanLabelFormat));

    select_index = find(strcmp(strList, L4));

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

function sFile = computeHeadModel(sFile)

    % Process: Compute head model
    sFile = bst_process('CallProcess', 'process_headmodel', sFile, [], ...
    'Comment', '', ...
        'sourcespace', 1, ... % Cortex surface
        'volumegrid', struct( ...
        'Method', 'isotropic', ...
        'nLayers', 17, ...
        'Reduction', 3, ...
        'nVerticesInit', 4000, ...
        'Resolution', 0.005, ...
        'FileName', ''), ...
        'meg', 3, ... % Overlapping spheres
        'eeg', 3, ... % OpenMEEG BEM
        'ecog', 2, ... % OpenMEEG BEM
        'seeg', 2, ... % OpenMEEG BEM
        'openmeeg', struct( ...
        'BemSelect', [1, 1, 1], ...
        'BemCond', [1, 0.0125, 1], ...
        'BemNames', {{'Scalp', 'Skull', 'Brain'}}, ...
        'BemFiles', {{}}, ...
        'isAdjoint', 0, ...
        'isAdaptative', 1, ...
        'isSplit', 0, ...
        'SplitLength', 4000));

end
