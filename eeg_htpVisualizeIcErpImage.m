function [EEG, opts] = eeg_htpVisualizeIcErpImage(EEG, varargin)
    % plotERPImage generates an ERP image from EEG time series data.
    %
    % Inputs:
    %   - EEG: A structure containing EEG data and metadata including sampling rate.
    %   - ic_number: The number of the IC (or channel) to plot. If not provided, the user will be prompted to select an IC.
    %   - icacomps: A boolean indicating whether to use the ICA components or the original data. Default is true.
    %   - plot_type: A string indicating whether to plot the ERP image for the continuous data or for each trial. Default is 'continuous'.
    %   - display_image: A boolean indicating whether to display the image in a figure. Default is false.
    %   - useSmoothing: A boolean indicating whether to use smoothing. Default is true.
    %
    % Outputs:
    %   A figure displaying the ERP image.

    % Input parser
    p = inputParser;
    addRequired(p, 'EEG', @isstruct);
    addOptional(p, 'ic_number', [], @isnumeric);
    addParameter(p, 'icacomps', true, @islogical);
    addParameter(p, 'plot_type', 'continuous', @(x) any(validatestring(x,{'continuous','trials'})));
    addParameter(p, 'display_image', false, @islogical);
    addParameter(p, 'useSmoothing', false, @islogical); 
    parse(p, EEG, varargin{:});

    % Assign inputs to variables
    opts.ic_number      = p.Results.ic_number;
    opts.icacomps       = p.Results.icacomps;
    opts.plot_type      = p.Results.plot_type;
    opts.display_image  = p.Results.display_image;
    opts.useSmoothing   = p.Results.useSmoothing; 

    [EEG, opts] = checkInputParameters(EEG, opts);

    [EEG, opts] = setVisualizationParameters(EEG, opts);

    if isempty(opts.ic_number)
        erp_bitmaps = cell(1,opts.no_components);
        for ic_number = 1 : opts.no_components

            logMessage('info', 'Creating ERP Image for %d', ic_number);

            bitmap = createIcErpBitmap( EEG, opts, ic_number);

            erp_bitmaps{1, ic_number} = bitmap;

        end
        opts.erp_bitmaps = erp_bitmaps;
    else
        ic_number = opts.ic_number;
        bitmap = createIcErpBitmap( EEG, opts, ic_number);
        opts.erp_bitmaps{1,opts.ic_number} = opts.bitmap;

    end
end

function bitmap = createIcErpBitmap( EEG, opts, ic_number)
    
    opts.ic_number = ic_number;

    [EEG, opts] = transformData(EEG, opts);
    
    [EEG, opts] = plotErpImage(EEG, opts);

    bitmap = opts.bitmap;


end

function [EEG, opts] = checkInputParameters(EEG, opts)
    % Check that the EEG structure contains the required fields
    if ~isfield(EEG, 'data')
        logMessage('error','EEG structure does not contain data.');
    end
    % Check if channel or IC number is valid
    if ~isempty(opts.ic_number)
        if ~opts.icacomps && (opts.ic_number < 1 || opts.ic_number > size(EEG.data, 1))
            error('Invalid channel number.');
        elseif opts.icacomps && (opts.ic_number < 1 || opts.ic_number > size(EEG.icaact, 1))
            error('Invalid IC number.');
        end
    end
    % Check for ICA weights
    if ~isfield(EEG, 'icaweights')
        error('EEG structure does not contain ICA weights.');
    end
    % initialize ica time series
    if ~isempty(EEG.icaact)
        EEG.icaact  = eeg_getdatact(EEG, 'component', 1:size(EEG.icaweights,1));
    end
end

function [EEG, opts] = setVisualizationParameters(EEG, opts)
    opts.ErpImageLines                  = 200; % Initial target for the number of lines in the ERP image
    opts.initialSmoothingFactor         = 1; % Default smoothing factor
    opts.isEpoched                      = ndims(EEG.data) > 2; %#ok<*ISMAT>
    opts.colormap                       = 'jet'; % Default colormap
    opts.colorAxisMax                   = .8; % Default color axis max
    opts.decFactor                      = 1; % Default decimation factor
    
    if strcmp(opts.plot_type, 'continuous')
        opts.title = 'Continuous Data';
    else
        opts.title = 'ERP Data';
    end

    opts.xlabel = 'Time (ms)';
    opts.ylabel = 'Trials';
    
    opts.defaultFontSize                = 14;
    opts.cbarLabel                      = 'RMS \muV per scalp channel';

    % get number of components or channels
    if opts.icacomps
        opts.no_components              = size(EEG.icaweights,1);
    else
        opts.no_components              = EEG.nbchan;
    end

    opts.ic_bitmaps                     = cell(1,opts.no_components);

    opts.total_samples = size(EEG.data, 2);
end

function [EEG, opts] = transformData(EEG, opts)

    % Determine whether to use ICA components or original data
    if opts.icacomps
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
    
    % Generate a time vector for the ERP image.
    opts.eegTimes = linspace(0, (opts.ErpImageFrames - 1) / EEG.srate, opts.ErpImageFrames);
    
    % Calculate the mean offset if needed.
    opts.offset = mean(icaacttmp, 'omitnan');
    
    opts.reshaped_data = reshape(icaacttmp(1,1:opts.ErpImageFramesTotal), ...
    opts.ErpImageFrames, ...
    opts.ErpImageLines) - opts.offset;

    wt_wind=ones(1,opts.smoothingFactor)/opts.smoothingFactor;

    [opts.smoothData, opts.outputTrials] = ...
        movav( opts.reshaped_data, ...
        1:opts.ErpImageLines, ...
        1, ...
        opts.decFactor, [], [], wt_wind);

   
end

function [EEG, opts] = plotErpImage(EEG, opts)
    
    logMessage('info', 'Creating canvas.');
    
    % Determine whether to display the image
    visibility = 'off';
    if opts.display_image
        visibility = 'on';
    end
    
    % Determine whether to use smoothed or unsmoothed data
    if opts.useSmoothing
        opts.plotData = opts.smoothData;
        opts.plotTrials = opts.smoothOutputTrials;
    else 
        opts.plotData = opts.reshaped_data;
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
    set(gca, 'YDir', 'normal', 'Tag', 'erpimage');
    colormap(jet);
    
    % Add titles and labels
    title(opts.title, 'FontSize', opts.defaultFontSize, 'FontWeight', 'Normal');
    xlabel(opts.xlabel)
    ylabel(opts.ylabel);
    colorbarLabel = text(1.27, 0.85, opts.cbarLabel, 'Units', 'normalized');
    set(colorbarLabel, 'Rotation', -90, 'FontSize', opts.defaultFontSize);
    
    % Set colormap and colorbar
    colormap(opts.colormap);
    colorbar; % Adds a colorbar to the current axes in the default (right) location

    % Convert the figure to a bitmap and store it in a cell array
    frame = getframe(opts.fh);
    bitmap = frame2im(frame);
    opts.bitmap = bitmap;
    close(opts.fh);

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