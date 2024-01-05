function [EEG, opts] = eeg_htpVisualizeIcErpImage(EEG, varargin)
% eeg_htpVisualizeIcErpImage generates an ERP heatmap from EEG time series data.
% The function can be used to generate an ERP image for a single IC or channel, or for all ICs or channels.
% The function can also be used to generate an ERP image for continuous data or for event epoched data.
%
% Inputs:
%   - EEG: A structure containing EEG data and metadata including sampling rate.
%   - ic_number: The number of the IC (or channel) to plot. If not provided, the user will be prompted to select an IC.
%   - useChannelData: A boolean indicating whether to use the ICA components or the original data. Default is true.
%   - plotAxesStyle: A string indicating whether to plot the ERP image for the continuous data or for each trial. Default is 'continuous'.
%   - showFigure: A boolean indicating whether to display the image in a figure. Default is false.
%   - useSmoothing: A boolean indicating whether to use smoothing. Default is true.
%   - useParallelToolbox: A boolean indicating whether to use useParallelToolbox processing. Default is false.
%
% Outputs:
%   - EEG: The EEG structure with the ERP image data added to the EEG.etc.vhtp.(mfilename) field.
%   - opts: A structure containing the options used to generate the ERP image.
%   - A popup figure displaying the ERP image (if showFigure is true).

% Input parser
p = inputParser;
addRequired(p, 'EEG', @isstruct);
addOptional(p, 'ic_number', [], @isnumeric);
addParameter(p, 'useChannelData', false, @islogical);
addParameter(p, 'plotAxesStyle', 'continuous', @(x) any(validatestring(x,{'continuous','trials'})));
addParameter(p, 'showFigure', false, @islogical);
addParameter(p, 'useSmoothing', false, @islogical);
addParameter(p, 'useParallelToolbox', true, @islogical);
addParameter(p, 'saveFiguresToFolder', missing, @isfolder);


parse(p, EEG, varargin{:});

% Assign inputs to variables
opts.ic_number              = p.Results.ic_number;
opts.useChannelData         = p.Results.useChannelData;
opts.plotAxesStyle          = p.Results.plotAxesStyle;
opts.showFigure             = p.Results.showFigure;
opts.useSmoothing           = p.Results.useSmoothing;
opts.useParallelToolbox     = p.Results.useParallelToolbox;
opts.saveFiguresToFolder    = p.Results.saveFiguresToFolder;

opts.singleIcMode   = true;

[EEG, opts] = checkIfEegLabAvailable(EEG, opts);

[EEG, opts] = checkInputParameters(EEG, opts);

[EEG, opts] = setVisualizationParameters(EEG, opts);

if isempty(opts.ic_number)
    opts.singleIcMode = false;
    erp_bitmaps = cell(1,opts.no_components);
    if opts.useParallelToolbox && detectParallelComputingToolbox()
        parfor ic_number = 1 : opts.no_components
            logMessage('info', 'Creating ERP Image for %d', ic_number);
            bitmap = createIcErpBitmap( EEG, opts, ic_number);
            erp_bitmaps{1, ic_number} = bitmap;
        end
    else
        for ic_number = 1 : opts.no_components
            logMessage('info', 'Creating ERP Image for %d', ic_number);
            bitmap = createIcErpBitmap( EEG, opts, ic_number);
            erp_bitmaps{1, ic_number} = bitmap;
        end
    end
    opts.erp_bitmaps = erp_bitmaps;
else
    ic_number = opts.ic_number;
    opts.erp_bitmaps = cell(1,opts.no_components);
    bitmap = createIcErpBitmap( EEG, opts, ic_number);
    opts.erp_bitmaps{1,opts.ic_number} = bitmap;
end

[EEG, opts] = tagEegSetFile(EEG, opts);

[EEG, opts] = saveFiguresToFolder(EEG, opts);

end

function [EEG, opts] = saveFiguresToFolder(EEG, opts)

    if ~ismissing(opts.saveFiguresToFolder)
        % Check if the target directory exists, if not, create it
        for ic_number = 1 : numel(EEG.etc.vhtp.(mfilename).erp_bitmap)
            [~, basename, ~] = fileparts(EEG.filename);
            filename = sprintf('%s_%s_%d.png', basename, opts.plotType, ic_number);
            subfolder = mfilename;
            filepath = fullfile(opts.saveFiguresToFolder, subfolder, filename);
            % Check if the subfolder exists, if not, create it
            [path, ~, ~] = fileparts(filepath);
            if ~exist(path, 'dir')
                mkdir(path);
            end
            imwrite(opts.erp_bitmaps{1, ic_number}, filepath);
            logMessage('info', 'Saved ERP Image for %d at %s', ic_number, filepath);
        end
    end

end

function  [EEG, opts] = tagEegSetFile(EEG, opts)

EEG.etc.vhtp.(mfilename).run_success = true;
EEG.etc.vhtp.(mfilename).erp_bitmap = opts.erp_bitmaps;
EEG.etc.vhtp.(mfilename).erp_index = 1:opts.no_components;
EEG.etc.vhtp.(mfilename).opts = opts;
EEG.etc.vhtp.(mfilename).opts.erp_bitmaps = [];

end

function res = detectParallelComputingToolbox()

res = ~isempty(which('parpool'));

end

function bitmap = createIcErpBitmap( EEG, opts, ic_number)

opts.ic_number = ic_number;

[EEG, opts] = transformData(EEG, opts);

[~, opts] = plotErpImage(EEG, opts);

bitmap = opts.bitmap;


end

function [EEG, opts] = checkIfEegLabAvailable(EEG, opts)
opts.eeglab = ~isempty(which('eeglab'));
if ~opts.eeglab
    htpDoctor('fix_eeglab');
    logMessage('error', 'EEGLAB is not available. Please add EEGLAB to the path and try again.');
else
    logMessage('trace', 'EEGLAB is available. Attempting to start without GUI...');
    system('eeglab(''nogui'') &');
end
end

function [EEG, opts] = checkInputParameters(EEG, opts)
% Check that the EEG structure contains the required fields
if ~isfield(EEG, 'data')
    logMessage('error','EEG structure does not contain data.');
end
% Check for ICA weights
if ~isfield(EEG, 'icaweights')
    error('EEG structure does not contain ICA weights.');
end
% initialize ica time series
if isempty(EEG.icaact)
    EEG.icaact  = eeg_getdatact(EEG, 'component', 1:size(EEG.icaweights,1));
end
% Check if channel or IC number is valid
if ~isempty(opts.ic_number)
    if opts.useChannelData && (opts.ic_number < 1 || opts.ic_number > size(EEG.data, 1))
        error('Invalid channel number.');
    elseif ~opts.useChannelData && (opts.ic_number < 1 || opts.ic_number > size(EEG.icaweights, 1))
        error('Invalid IC number.');
    end
end
end

function [EEG, opts] = setVisualizationParameters(EEG, opts)
opts.ErpImageLines                  = 200; % Initial target for the number of lines in the ERP image
opts.initialSmoothingFactor         = 1; % Default smoothing factor
opts.isEpoched                      = ndims(EEG.data) > 2; %#ok<*ISMAT>
opts.colormap                       = 'jet'; % Default colormap
opts.colorAxisMax                   = .8; % Default color axis max
opts.decFactor                      = 1; % Default decimation factor

opts.xlabel = 'Time (ms)';
opts.ylabel = 'Trials';

opts.defaultFontSize                = 16;
opts.cbarLabel                      = 'RMS \muV per scalp channel';

% get number of components or channels
if ~opts.useChannelData
    opts.plotType = 'IC';
    opts.no_components              = size(EEG.icaweights,1);
else
    opts.plotType = 'Channel';
    opts.no_components              = EEG.nbchan;
end

opts.total_samples = size(EEG.data, 2);
end

function [EEG, opts] = transformData(EEG, opts)

% Determine whether to use ICA components or original data
if ~opts.useChannelData
    if opts.isEpoched
        icaacttmp = EEG.icaact(opts.ic_number,:,:);
    else
        icaacttmp = EEG.icaact(opts.ic_number,:);
    end
else
    if opts.isEpoched
        icaacttmp = EEG.data(opts.ic_number,:,:);
    else
        icaacttmp = EEG.data(opts.ic_number,:);
    end
end

if ~opts.isEpoched
    opts.title = sprintf('%s d: Continuous Data', opts.plotType, opts.ic_number);
    
    % Ensure ERPIMAGELINES does not exceed the total available data points divided by the sample rate.
    while opts.total_samples < opts.ErpImageLines * EEG.srate
        opts.ErpImageLines   = floor(0.9 * opts.ErpImageLines);  % Reduce ERPIMAGELINES if there's not enough data
    end
    
    % Determine smoothing factor based on the final number of ERP image lines.
    opts.smoothingFactor = opts.initialSmoothingFactor + (opts.ErpImageLines >= 6)*2;
    
    % Calculate the number of frames for each line of the ERP image.
    opts.ErpImageFrames = floor(opts.total_samples / opts.ErpImageLines);
    
    % Calculate the total number of frames to use.
    opts.ErpImageFramesTotal = opts.ErpImageFrames * opts.ErpImageLines;
    
    % Generate a time vector for the ERP image in milliseconds.
    opts.eegTimes = linspace(0, ((opts.ErpImageFrames - 1) / EEG.srate) * 1000, opts.ErpImageFrames);
    
    % Calculate the mean offset if needed.
    opts.offset = mean(icaacttmp, 'omitnan');
    
    opts.reshaped_data = reshape(icaacttmp(1,1:opts.ErpImageFramesTotal), ...
        opts.ErpImageFrames, ...
        opts.ErpImageLines) - opts.offset;
    
    wt_wind=ones(1,opts.smoothingFactor)/opts.smoothingFactor;
    
    [opts.smoothData, opts.smoothOutputTrials] = ...
        movav( opts.reshaped_data, ...
        1:opts.ErpImageLines, ...
        1, ...
        opts.decFactor, [], [], wt_wind);
    
    opts.originalData = opts.reshaped_data;
    opts.outputTrials = 1:opts.ErpImageLines;
else
    opts.title = sprintf('%s %d: Original Epochs', opts.plotType, opts.ic_number);
    
    icaacttmp = squeeze(icaacttmp);
    opts.ErpImageLines = EEG.trials;
    
    % Determine smoothing factor based on the final number of ERP image lines.
    opts.smoothingFactor = opts.initialSmoothingFactor + (opts.ErpImageLines >= 6)*2;
    
    
    logMessage('info', 'Data is in epoch format: Original trials will be used')
    opts.eegTimes = linspace(EEG.xmin, EEG.xmax, EEG.pnts);
    
    % Calculate the mean offset if needed.
    opts.offset = mean(icaacttmp(:), 'omitnan');
    
    wt_wind=ones(1,opts.smoothingFactor)/opts.smoothingFactor;
    
    [opts.smoothData, opts.smoothOutputTrials] = ...
        movav( icaacttmp, ...
        1:opts.ErpImageLines, ...
        1, ...
        opts.decFactor, [], [], wt_wind);
    
    opts.originalData = icaacttmp - opts.offset;
    opts.outputTrials = 1:opts.ErpImageLines;
    opts.eegTimes = EEG.times;
end


end

function [EEG, opts] = plotErpImage(EEG, opts)

logMessage('info', 'Creating canvas.');

% Determine whether to display the image
visibility = 'off';
if opts.showFigure
    visibility = 'on';
end

% Determine whether to use smoothed or unsmoothed data
if opts.useSmoothing
    opts.plotData = opts.smoothData;
    opts.plotTrials = opts.smoothOutputTrials;
else
    opts.plotData = opts.originalData;
    opts.plotTrials = opts.outputTrials;
end

% Initialize figure handle
opts.fh = [];

% Determine color axis limits
colorAxisMax = opts.colorAxisMax * max(abs(opts.plotData(:)));

% Plot the ERP image
opts.fh = figure( 'color', [0.9300 0.9600 1.0000],...
    'numbertitle', 'off',...
    'PaperPositionMode','auto',...
    'Visible', visibility, ...
    'ToolBar', 'none',...
    'MenuBar','none');
imagesc(opts.eegTimes, opts.plotTrials, opts.plotData', [-colorAxisMax, colorAxisMax]);
set(gca, 'YDir', 'normal', 'Tag', 'erpimage','FontSize', opts.defaultFontSize-3);
colormap(opts.colormap);

% Add titles and labels
title(opts.title, 'FontSize', opts.defaultFontSize+2, 'FontWeight', 'Normal');
xlabel(opts.xlabel, 'FontSize',  opts.defaultFontSize);
ylabel(opts.ylabel, 'FontSize',  opts.defaultFontSize);
% Add colorbar and set its label
cb = colorbar;
ylabel(cb, opts.cbarLabel, 'FontSize', opts.defaultFontSize);

frame = getframe(opts.fh);
bitmap = frame2im(frame);
opts.bitmap = bitmap;

if ~opts.singleIcMode && ~opts.showFigure
    close(opts.fh);
end

end
function logMessage(type, varargin)
message = sprintf(varargin{:});
switch type
    case 'info'
        fprintf('[INFO]: %s\n', message);
    case 'warning'
        fprintf('[WARNING]: %s\n', message);
    case 'error'
        error('[ERROR]: %s\n', message);
    otherwise
        fprintf('[UNKNOWN]: %s\n', message);
end
end