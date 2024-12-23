function EEG_postcomps = eeg_htpEegAutoPostComps( EEG, varargin )
    % This function performs automated post-ICA component rejection.
    % Rationale:
    % This function aims to automate the process of post-ICA component rejection
    % by identifying and removing components that are likely to represent artifacts.
    % The procedure involves several steps:
    % 1. Running ICLabel to classify components into different categories.
    % 2. Calculating the variance accounted for by each component, using a
    %    variance threshold to identify significant components.
    % 3. Identifying components to remove based on the threshold criteria,
    %    including the variance threshold.
    % 4. Optionally, saving images of the components marked for removal.
    % 5. Removing the identified components to clean the EEG data.

    % Instructions for function usage:
    % - EEG: EEG structure after ICA decomposition.
    % - 'ThresholdRatio': The ratio of the variance threshold for component rejection (default 25).
    % - 'VarianceThreshold': The threshold of variance below which components are always retained (default 1).
    % - 'PerformComponentRemoval': Logical flag to perform component removal and return modified EEG (default true).
    % - 'SaveComponentImages': Logical flag to save images of components (default true).
    % - 'RerunICLabel': Logical flag to rerun ICLabel classification (default false).
    % - 'RemovalCategories': Cell array of component categories to remove (default {'Eye', 'Heart', 'Muscle', 'Other', 'Line Noise', 'Channel Noise'}).
    % - 'BrainComponentOnlyMode': Logical flag to only consider brain components to retain (default false).
    % - 'ComponentsToKeep': Array of component numbers to retain regardless of other criteria (default []).
    % - 'ComponentsToRemove': Array of component numbers to remove regardless of other criteria (default []).
    
    % It relies on the following dependencies:
    % - EEGLAB: https://sccn.ucsd.edu/eeglab/index.php
    % - ICLabel: https://github.com/sccn/ICLabel
    % - viewprops (for component variance): https://github.com/sccn/viewprops

    p = inputParser;
    addRequired(p, 'EEG');
    addParameter(p, 'ThresholdRatio', 20, @isnumeric);
    addParameter(p, 'VarianceThreshold', 1, @isnumeric);
    addParameter(p, 'PerformComponentRemoval', true, @islogical);
    addParameter(p, 'SaveComponentImages', true, @islogical);
    addParameter(p, 'RerunICLabel', false, @islogical);
    addParameter(p, 'RemovalCategories', {'Eye', 'Heart', 'Muscle', 'Other', 'Line Noise', 'Channel Noise'}, @iscell);
    addParameter(p, 'BrainComponentOnlyMode', false, @islogical);
    addParameter(p, 'ComponentsToKeep', [], @isnumeric);
    addParameter(p, 'ComponentsToRemove', [], @isnumeric);
    parse(p, EEG, varargin{:});
    EEG = p.Results.EEG;
    thresholdRatio = p.Results.ThresholdRatio;
    varianceThreshold = p.Results.VarianceThreshold;
    performComponentRemoval = p.Results.PerformComponentRemoval;
    saveComponentImages = p.Results.SaveComponentImages;
    rerunICLabel = p.Results.RerunICLabel;
    removalCategories = p.Results.RemovalCategories;
    brainComponentOnlyMode = p.Results.BrainComponentOnlyMode;
    componentsToKeep = p.Results.ComponentsToKeep;
    manualComponentsToRemove = p.Results.ComponentsToRemove;
    
    if rerunICLabel
        try
            EEG = iclabel(EEG);
        catch ME
            error('Error running IC Label: %s', ME.message);
        end
    end

    if ~exist('iclabel', 'file')
        error('iclabel function is not available');
    end

    if ~isempty(EEG.icaweights)
        no_of_components = size(EEG.icawinv, 2);
    else
        error('ICA weights not available.');
    end

    % Initialize a table to store component numbers and variance accounted for
    compTable = table('Size', [no_of_components 2], 'VariableTypes', {'double', 'double'}, 'VariableNames', {'ComponentNumber', 'VarianceAccountedFor'});

    % Loop through components and calculate variance accounted for
    % source: https://github.com/sccn/viewprops
    for ic = 1:no_of_components
        icaacttmp  = eeg_getdatact(EEG, 'component', ic);

        maxsamp = 1e5;
        n_samp = min(maxsamp, EEG.pnts*EEG.trials);
        try
            samp_ind = randperm(EEG.pnts*EEG.trials, n_samp);
        catch
            samp_ind = randperm(EEG.pnts*EEG.trials);
            samp_ind = samp_ind(1:n_samp);
        end
        if ~isempty(EEG.icachansind)
            icachansind = EEG.icachansind;
        else
            icachansind = 1:EEG.nbchan;
        end
        datavar = mean(var(EEG.data(icachansind, samp_ind), [], 2));
        projvar = mean(var(EEG.data(icachansind, samp_ind) - ...
            EEG.icawinv(:, ic) * icaacttmp(1, samp_ind), [], 2));
        pvafval = 100 *(1 - projvar/ datavar);

        % Add the component number and variance accounted for to the table
        compTable.ComponentNumber(ic) = ic;
        compTable.VarianceAccountedFor(ic) = pvafval;
    end

    classification_table = array2table(EEG.etc.ic_classification.ICLabel.classifications, 'VariableNames', EEG.etc.ic_classification.ICLabel.classes);

    ictable = [compTable classification_table];

    % Determine the maximum classification value for each component and label it
    [maxValues, maxLabelIndices] = max(table2array(ictable(:, 3:end)), [], 2);
    maxLabels = ictable.Properties.VariableNames(maxLabelIndices + 2); % Offset by 2 to account for the first two columns
    ictable.MaxComponentLabel = maxLabels';

    % Calculate the ratio of the max value to the mean of the other values for each component
    allValues = table2array(ictable(:, 3:end-1)); % Exclude the last column which is cell type
    meanOtherValues = (sum(allValues, 2) - maxValues) ./ (size(allValues, 2) - 1);
    ratioMaxToMeanOthers = maxValues ./ meanOtherValues;
    ictable.RatioMaxToMeanOthers = ratioMaxToMeanOthers;

    % Create a new column called 'remove' initialized to false
    ictable.remove = false(height(ictable), 1);

    % Filter components with variance greater than the specified threshold
    highVarianceComponents = ictable.VarianceAccountedFor > varianceThreshold;

    % Mark components for removal based on category and ratio
    for i = 1:height(ictable)
        if highVarianceComponents(i)
            category = ictable.MaxComponentLabel{i};
            ratio = ictable.RatioMaxToMeanOthers(i);
            if brainComponentOnlyMode
                if ~strcmp(category, 'Brain') || ~(ratio >= thresholdRatio)
                    ictable.remove(i) = true;
                end
            else
                if any(strcmp(category, removalCategories)) && ratio > thresholdRatio
                    ictable.remove(i) = true;
                end
            end
        end
    end

    % Apply manual overrides for components to keep or remove
    ictable.remove(componentsToKeep) = false;
    ictable.remove(manualComponentsToRemove) = true;

    componentsToRemove = ictable.remove;

    % Process high variance components, save images without displaying them if enabled, and give progress status
    if saveComponentImages
        highVarianceComponentsIndices = find(highVarianceComponents);
        numHighVarComps = length(highVarianceComponentsIndices);
        fprintf('Saving images for %d high variance components...\n', numHighVarComps);
        % Initialize a column to store the filenames of the saved images
        ictable.ImageFilenames = repmat({''}, height(ictable), 1);
        for componentIndex = highVarianceComponentsIndices'
            fprintf('Processing component %d/%d...\n', find(componentIndex == highVarianceComponentsIndices), numHighVarComps);
            % Generate a filename using EEG structure, component number, and label
            label = ictable.MaxComponentLabel{componentIndex};

            % Extract the base filename without extension and add prefix
            [~, baseFileName, ~] = fileparts(EEG.filename);
            newFileName = sprintf('autopc_%s_component_%d_label_%s.png', baseFileName, componentIndex, label);

            % Create a new subfolder within EEG.filepath for storing images
            imageFolderPath = fullfile(EEG.filepath, 'autopostcomps');
            if ~exist(imageFolderPath, 'dir')
                mkdir(imageFolderPath);
            end

            % Full filename including path
            filename = fullfile(imageFolderPath, newFileName);
            ictable.ImageFilenames{componentIndex} = filename; % Store the filename in the table

            fh = pop_prop_extended(EEG, 0, componentIndex, NaN, {'limits',[0 80]});
            % Add a title to the figure based on component rejection status
            componentStatus = ictable.remove(componentIndex);
            componentRatio = ictable.RatioMaxToMeanOthers(componentIndex);
            if componentStatus
                titleText = sprintf('IC %d Rejected - Ratio: %.2f', componentIndex, componentRatio);
                titleColor = 'r'; % Red text for rejected components
                borderColor = 'r'; % Red border for rejected components
            else
                titleText = sprintf('IC %d Retained - Ratio: %.2f', componentIndex, componentRatio);
                titleColor = [0, 0.5, 0]; % Dark green text for retained components
                borderColor = 'g'; % Green border for retained components
            end
            title(fh.Children(end), titleText, 'Color', titleColor, 'FontSize', 18, 'FontWeight', 'bold');
            % There is no 'EdgeColor' property for the figure in MATLAB. Instead, we can use annotation to create a border effect.
            % Create a rectangle annotation the same size as the figure to simulate a border
            annotation(fh, 'rectangle', [0, 0, 1, 1], 'EdgeColor', borderColor, 'LineWidth', 30);
            % exportgraphics(fh, filename, 'Resolution', 300); % Save the figure as a PNG with 300 DPI resolution
            saveas(fh, filename); % Use saveas to save the figure as a PNG
            close(fh); % Close the figure after saving
            fprintf('Component %d image saved.\n', componentIndex);
        end
        fprintf('Image saving process completed.\n');
        % Save the updated table to a CSV file in the image folder
        csvFilename = fullfile(imageFolderPath, sprintf('%s_component_images.csv', baseFileName));
        writetable(ictable, csvFilename);
        fprintf('Component table with image filenames saved to %s\n', csvFilename);
    end

    % Stitch images together into a single image in two columns, skipping missing files
    imageFiles = ictable.ImageFilenames;
    validImageFiles = imageFiles(~cellfun('isempty', imageFiles)); % Filter out empty filenames
    numImages = numel(validImageFiles);
    if numImages > 0
        % Read the first valid image to get the dimensions
        firstImage = imread(validImageFiles{1});
        [imgHeight, imgWidth, imgDepth] = size(firstImage);
        % Calculate the number of rows needed for two columns
        numRows = ceil(numImages / 2);
        % Initialize a blank canvas
        stitchedImg = zeros(imgHeight * numRows, imgWidth * 2, imgDepth, 'like', firstImage);
        % Place each valid image onto the canvas in two columns
        for i = 1:numImages
            currentImage = imread(validImageFiles{i});
            % Calculate row and column for current image
            row = ceil(i / 2);
            col = 2 - mod(i, 2);
            stitchedImg((row-1)*imgHeight+1:row*imgHeight, (col-1)*imgWidth+1:col*imgWidth, :) = currentImage;
        end
        % Save the stitched image
        % Generate a concise filename using the base filename, threshold ratio, and brain only mode
        brainComponentModeText = 'Full';
        if brainComponentOnlyMode
            brainComponentModeText = 'BrainOnly';
        end
        specificStitchedFilename = sprintf('%s_stitched_TR%d_%s.png', baseFileName, thresholdRatio, brainComponentModeText);
        stitchedFilename = fullfile(imageFolderPath, specificStitchedFilename);
        imwrite(stitchedImg, stitchedFilename);
        fprintf('Stitched components image saved to %s\n', stitchedFilename);
        % Remove individual component images after successful stitching
        for i = 1:numImages
            delete(validImageFiles{i});
        end
        fprintf('Individual component images removed after stitching.\n');
    else
        fprintf('No valid images to stitch together.\n');
    end
    % Remove the marked components from the EEG dataset if enabled
    if performComponentRemoval && any(componentsToRemove)
        EEG_postcomps = pop_subcomp(EEG, find(componentsToRemove), 0);
    else
        EEG_postcomps = EEG;
    end

end
