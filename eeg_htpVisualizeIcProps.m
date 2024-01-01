function [EEG, opts] = eeg_htpVisualizeIcProps( EEG, varargin )
% eeg_htpVisualizeIcProps() - Visualize IC properties
%
% Usage:
%   >> [EEG, opts] = eeg_htpVisualizeIcProps( EEG, varargin )
%
% Inputs:
%   EEG - EEGLAB EEG structure
%
% Optional Inputs:
%   'ic' - Integer value to indicate the IC to visualize (default: 0)
%   'ic_classifier' - String value to indicate the IC classifier to use (default: 'ICLabel')
%   'scroll_event' - Boolean flag to indicate whether to display the scroll event (default: 1)
%   'display_image' - Boolean flag to indicate whether to display the image (default: 1)
%    'parallel' - Boolean flag to indicate whether to run the calculations in parallel (default: false)
%    'recalculate_fooof' - Boolean flag to indicate whether to recalculate fooof (default: false)

% Outputs:
%   EEG - EEGLAB EEG structure
%   opts - Options structure

% Authors: Ernest Pedapati

p = inputParser;
addRequired(p, 'EEG');
addOptional(p, 'ic', 0, @isnumeric);
addParameter(p, 'ic_classifer', 'ICLabel', @ischar);
addParameter(p, 'scroll_event', 1, @isnumeric);
addParameter(p, 'display_image', 1, @mustBeNumericOrLogical);
addParameter(p, 'parallel', false, @islogical);
addParameter(p, 'recalculate_fooof', false, @islogical);


parse(p, EEG, varargin{:});

opts.selected_ic = p.Results.ic;
opts.ic_classifer = p.Results.ic_classifer;
opts.scroll_event = p.Results.scroll_event;
opts.display_image = p.Results.display_image;
opts.parallel = p.Results.parallel;
opts.recalculate_fooof = p.Results.recalculate_fooof;

[EEG, opts] = check_requirements(EEG, opts);
[EEG, opts] = init_opts(EEG, opts);
[EEG, opts] = handler(EEG, opts);
% Load ICADEFS
% %try icadefs; catch, warning('Could not load icadefs. Please make sure EEGLAB is in your path.'); end
% [EEG, opts] = visualize_create_canvas(EEG, opts);
% [EEG, opts] = add_ic_barplot(EEG, opts);
% [EEG, opts] = add_time_series(EEG, opts);
% [EEG, opts] = add_ic_topography(EEG, opts);
% [EEG, opts] = add_aperiodic_rsquared(EEG, opts);
% [EEG, opts] = add_pvaf(EEG, opts);
% [EEG, opts] = add_erp_image(EEG, opts);
% [EEG, opts] = add_psd_plot(EEG, opts);
% [EEG, opts] = add_dipole_image(EEG, opts);
% [EEG, opts] = create_savename(EEG, opts);

    function [EEG, opts] = check_requirements(EEG, opts)

        % Check for ICA weights
        if isfield(EEG, 'icaweights')
            logMessage('info', 'ICA weights found.');
        else
            logMessage('error', 'EEG does not contain ICA weights. Please run ICA first.');
        end
        % Check for ic_classification field
        if isfield(EEG.etc, 'ic_classification')
            logMessage('info', 'ic_classification field found.');
        else
            logMessage('error', 'EEG does not contain ic_classification field. Please run ICA first.');
        end

        if ~isfield(EEG, 'icaact') || isempty(EEG.icaact)
            logMessage('warning', 'ICA activations not found or components are required. Calculating...');
            EEG.icaact = eeg_getica(EEG);
        end
        if opts.selected_ic ~= 0
            opts.display_image = true;
        else
            opts.display_image = false;
        end
        if isfield(EEG.etc, 'FOOOF_results')
            if isempty(EEG.etc.FOOOF_results)
                calculate_fooof = true;
            else
                calculate_fooof = false;
                logMessage('info', 'Field FOOOF_results exists in EEG.etc');
            end
        else
            calculate_fooof = true;
        end

        if calculate_fooof || opts.recalculate_fooof
            logMessage('warning', 'Running eeg_htpCalcFooof().');
            if license('test', 'Distrib_Computing_Toolbox') && opts.parallel
                EEG = eeg_htpCalcFooof(EEG, 'ic_assessment', true, 'parallel', true);
            else
                EEG = eeg_htpCalcFooof(EEG, 'ic_assessment', true);
            end
        end

    end

    function [EEG, opt] = handler(EEG, opt)
        if opts.selected_ic == 0
            ic_bitmaps = cell(1, opts.no_of_components);
            gen_image = @generate_image;

            % Check if parallel computing toolbox is available and opts.parallel is true
            if license('test', 'Distrib_Computing_Toolbox') && opts.parallel
                parfor ic = 1:10 %opts.no_of_components
                    ic_bitmaps{ic} = feval(gen_image, EEG, opts, ic); %#ok<FVAL>
                end
            else
                for ic = 1:opts.no_of_components
                    ic_bitmaps{ic} = feval(gen_image, EEG, opts, ic); %#ok<FVAL>
                end
            end

            EEG.ic_bitmaps = ic_bitmaps;

        elseif opts.selected_ic > 0 && opts.selected_ic <= opts.no_of_components
            opts.display_image = true;
            [EEG, opts] = init_ica_data(EEG, opts);
            [EEG, opts] = visualize_create_canvas(EEG, opts);
            [EEG, opts] = add_ic_barplot(EEG, opts);
            [EEG, opts] = add_time_series(EEG, opts);
            [EEG, opts] = add_ic_topography(EEG, opts);
            [EEG, opts] = add_aperiodic_rsquared(EEG, opts);
            [EEG, opts] = add_pvaf(EEG, opts);
            [EEG, opts] = add_erp_image(EEG, opts);
            %[EEG, opts] = add_psd_plot(EEG, opts);
            [EEG, opts] = add_dipole_image(EEG, opts);
            [EEG, opts] = add_fooof_psd_plot(EEG, opts);
            %[EEG, opts] = create_savename(EEG, opts);
        end
    end

    function bitmap = generate_image(EEG, opts, ic)
        opts.selected_ic = ic;
        [EEG, opts] = init_ica_data(EEG, opts);
        [EEG, opts] = visualize_create_canvas(EEG, opts);
        [EEG, opts] = add_ic_barplot(EEG, opts);
        [EEG, opts] = add_time_series(EEG, opts);
        [EEG, opts] = add_ic_topography(EEG, opts);
        [EEG, opts] = add_aperiodic_rsquared(EEG, opts);
        [EEG, opts] = add_pvaf(EEG, opts);
        [EEG, opts] = add_erp_image(EEG, opts);
        %[EEG, opts] = add_psd_plot(EEG, opts);
        [EEG, opts] = add_dipole_image(EEG, opts);
        [EEG, opts] = add_fooof_psd_plot(EEG, opts);
        %[EEG, opts] = create_savename(EEG, opts);

        % Step 1: Save figure to a temporary file
        tempFileName = [tempname, '.tif'];  % Generate temporary filename
        exportgraphics(opts.fh, tempFileName, 'ContentType', 'image','Resolution',200,'BackgroundColor',[0.9300 0.9600 1.0000]);

        % tempFileName = [tempname, '.gif'];  % Generate temporary filename
        % exportgraphics(opts.fh, tempFileName, 'ContentType', 'vector');

        % Step 2: Read the image back into MATLAB
        bitmap = imread(tempFileName);

        % Step 4: Clean up temporary file
        delete(tempFileName);


        %frame = getframe(opts.fh);
        %bitmap = frame2im(frame);

    end


    function [EEG, opts] = create_savename(EEG, opts)

        selected_ic = opts.selected_ic;

        % Convert the figure to a bitmap and store it in a cell array
        frame = getframe(opts.fh);
        bitmap = frame2im(frame);
        opts.ic_bitmaps{selected_ic} = bitmap;

    end

    function [EEG, opts] = init_opts(EEG, opts)
        logMessage('info', 'Initializing Options.');

        [EEG, opts]= computeNumComponents(EEG, opts);
        logMessage('info', sprintf('Number of components (%d) computed and added to options.', opts.no_of_components));

        opts.basename = ['IC' int2str(opts.selected_ic) ];
    end

    function [EEG, opts] = init_ica_data(EEG, opts)
        % initialize ica data
        if ~isempty(EEG.icaact)
            opts.icaacttmp  = EEG.icaact( opts.selected_ic, :, :);
        else
            opts.icaacttmp  = eeg_getdatact(EEG, 'component', opts.selected_ic);
        end
    end

    function [EEG, opts] = computeNumComponents(EEG, opts)
        logMessage('info', 'Computing component metrics.');
        opts.no_of_components = size(EEG.icawinv, 2);
    end

    function [EEG, opts] = visualize_create_canvas(EEG, opts)
        logMessage('info', 'Creating canvas.');
        basename = opts.basename;

        visibility = 'off';
        if opts.display_image
            visibility = 'on';
        end

        opts.fh = [];

        fh = figure('name', [basename ' - eeg_htpVisualizeIcProps()'],...
            'color', [0.9300 0.9600 1.0000],...
            'numbertitle', 'off',...
            'PaperPositionMode','auto',...
            'Visible', visibility, ...
            'ToolBar', 'none',...
            'MenuBar','none');
        pos = get(fh,'position');
        set(fh,'Position', [pos(1)-1200+pos(3) pos(2)-700+pos(4) 1200 700]);
        opts.fh = fh;
    end

    function [EEG, opts] = add_ic_barplot(EEG, opts)

        classifier_name = opts.ic_classifer;
        fh = opts.fh;
        selected_ic = opts.selected_ic;

        % check for labels. if they exist, shorten scroll and plot them
        if size(EEG.etc.ic_classification.(classifier_name).classifications, 1) ...
                ~= opts.no_of_components
            logMessage('warning', ['The number of ICs do not match the number of IC classifications. This will result in incorrectly plotted labels. Please rerun ' classifier_name])
        end

        nclass = length(EEG.etc.ic_classification.(classifier_name).classes);
        labelax = axes('Parent', fh, 'Position', [0.32 0.6389 0.035 0.28]);
        yoffset = 0.5;
        xoffset = 0.01;
        barh(EEG.etc.ic_classification.(classifier_name).classifications(selected_ic, end:-1:1), 'y')
        axis(labelax, [-xoffset, 1, 1 - yoffset, nclass + yoffset])
        set(labelax, 'YTickLabel', EEG.etc.ic_classification.(classifier_name).classes(end:-1:1), ...
            'XGrid', 'on', 'XTick', 0:0.5:1)
        xlabel 'Probability'
        title(classifier_name)

        for it = 1:nclass
            text(0.5, it, sprintf('%.1f%%', EEG.etc.ic_classification.(classifier_name).classifications(selected_ic, end - it + 1) * 100), ...
                'fontsize', 11, 'HorizontalAlignment', 'center', ...
                'Parent', labelax)
        end


    end

    function [EEG, opts] = add_time_series(EEG, opts)

        fh = opts.fh;
        selected_ic = opts.selected_ic;
        scroll_event = opts.scroll_event;
        icaacttmp = squeeze(opts.icaacttmp);
        scroll_position = [0.4 0.7389 0.5929 0.18];

        % plot time series
        datax = axes('Parent', fh, 'Position',scroll_position,'units','normalized');
        scrollax = uicontrol('Parent', fh, 'Style', 'Slider', ...
            'Units', 'Normalized', 'Position', [scroll_position(1) 0.6389 scroll_position(3) 0.025]);
        if ~scroll_event
            EEG.event = []; end

        % % Show only 2 epochs in terms of length
        % epoch_length = size(EEG.data, 2);
        % two_epochs_length = 2 * epoch_length;
        % icaacttmp = icaacttmp(:, 1:2);

        scrollplot(EEG.times, single(icaacttmp), 5, EEG.event, fh, datax, scrollax);
        tstitle_h = title(['Scrolling IC' int2str(selected_ic) ' Activity'], 'fontsize', 14, 'FontWeight', 'Normal');
        set(tstitle_h,'FontSize',14, 'Position', get(tstitle_h, 'Position'), 'units', 'normalized');
        set(datax,'FontSize',12);
        xlabel(datax,'Time (ms)','fontsize', 14);
        ylabel(datax,'uV');

        opts.fh = fh;

    end

    function [EEG, opts] = add_ic_topography(EEG, opts)

        fh = opts.fh;
        selected_ic = opts.selected_ic;

        % plot scalp map
        axes('Parent', fh, 'position',[0.0143 0.6331 0.3121 0.3267],'units','normalized');

        topoplot(EEG.icawinv(:,selected_ic), EEG.chanlocs, ...
            'chaninfo', EEG.chaninfo, 'electrodes','on'); axis square;
        title(['IC' num2str(selected_ic)], 'fontsize', 14, 'FontWeight', 'Normal');

        opts.fh = fh;
    end

    function [EEG, opts] = add_aperiodic_rsquared(EEG, opts)

        selected_ic = opts.selected_ic;

        try
            FOOOF_results_table = EEG.etc.FOOOF_results.channel(selected_ic);
            opts.aperiodic_fitting = num2str(round(FOOOF_results_table.r_squared,2));
            %FOOOF_results_table = EEG.etc.FOOOF_results.summary_table;
            %selected_ic_row = FOOOF_results_table(FOOOF_results_table.chan == selected_ic, :);
            logMessage('info', ['Aperiodic Oscillation Fitting R2 for IC' num2str(selected_ic) ': ' num2str(opts.aperiodic_fitting)]);
        catch ME
            logMessage('error', ['Error in calculating Aperiodic Oscillation Fitting R2 for IC' num2str(selected_ic) ': ' ME.message]);
            opts.aperiodic_fitting = 'N/A';
        end

    end

    function [EEG, opts] = add_pvaf(EEG, opts)

        fh = opts.fh;
        selected_ic = opts.selected_ic;
        icaacttmp = opts.icaacttmp;
        aperiodic_fitting = opts.aperiodic_fitting;

        % plot pvaf
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
            EEG.icawinv(:, selected_ic) * icaacttmp(1, samp_ind), [], 2));
        pvafval = 100 *(1 - projvar/ datavar);
        pvaf = num2str(pvafval, '%3.1f');

        text(0.5, -0.12, {['{% scalp data var. accounted for}: ' pvaf '%']}, ...
            'fontsize', 13,'Units','Normalized', 'HorizontalAlignment', 'center');
        text(0.5, -0.24, {['{IC Aperiodic Fit Quality: R-squared}: ' aperiodic_fitting  '']}, ...
            'fontsize', 13,'Units','Normalized', 'HorizontalAlignment', 'center');

        opts.fh = fh;
    end

    function [EEG, opts] = add_erp_image(EEG, opts)
        % Uses modified erpplot that can generate image in the background

        fh = opts.fh;
        selected_ic = opts.selected_ic;
        icaacttmp = opts.icaacttmp;
        erp_opt = {};

        herp = axes('Parent', fh, 'position',[0.0643 0.1102 0.2421 0.3850],'units','normalized');
        %eeglab_options;
        if EEG.trials > 1 % epoched data
            axis(herp, 'off')
            EEG.times = linspace(EEG.xmin, EEG.xmax, EEG.pnts);
            ei_smooth = 1;

            offset     = nan_mean(icaacttmp(:));
            era        = nan_mean(squeeze(icaacttmp)')-offset;
            era_limits = get_era_limits(era);
            [t1,t2,t3,t4,axhndls] = erpimage_ic( icaacttmp-offset, ones(1,EEG.trials)*10000, EEG.times*1000, ...
                '', ei_smooth, 1, 'caxis', 2/3, 'cbar','erp','erp_vltg_ticks',era_limits, erp_opt{:});

            title(['Epoched IC' int2str(selected_ic) ' Activity'], 'fontsize', 14, 'FontWeight', 'Normal');
            lab = text(1.27, .95,'RMS uV per scalp channel');

        else % continuoous data
            ERPIMAGELINES = 200; % show 200-line erpimage
            while size(EEG.data,2) < ERPIMAGELINES*EEG.srate
                ERPIMAGELINES = 0.9 * ERPIMAGELINES;
            end
            ERPIMAGELINES = round(ERPIMAGELINES);
            if ERPIMAGELINES > 2   % give up if data too small
                if ERPIMAGELINES < 6
                    ei_smooth = 1;
                else
                    ei_smooth = 3;
                end


                erpimageframes = floor(size(EEG.data,2)/ERPIMAGELINES);
                erpimageframestot = erpimageframes*ERPIMAGELINES;
                eegtimes = linspace(0, erpimageframes-1, length(erpimageframes));

                offset = nan_mean(icaacttmp(:));
                [t1,t2,t3,t4,axhndls] = erpimage_ic(reshape(icaacttmp(:,1:erpimageframestot),erpimageframes,ERPIMAGELINES)-offset,ones(1,ERPIMAGELINES)*10000, eegtimes ,'', ei_smooth, 1, 'caxis', 2/3, 'cbar', erp_opt{:});


                try
                    ylabel(axhndls{1}, 'Data');
                catch
                    ylabel(axhndls(1), 'Data');
                end
                title('Continuous Data', 'fontsize', 14, 'FontWeight', 'Normal');
                lab = text(1.27, .85,'RMS uV per scalp channel');
            else
                axis off;
                text(0.1, 0.3, [ 'No erpimage plotted' 10 'for small continuous data']);
            end
        end

        if exist('axhndls', 'var')
            try
                % 2014+
                axhndls{1}.FontSize = 12;
                axhndls{1}.YLabel.FontSize = 14;
                set(axhndls{2},'position', get(axhndls{2},'position') - [0.01 0 0.02 0]);
                try
                    axhndls{3}.FontSize = 12;
                    axhndls{3}.XLabel.FontSize = 14; %#ok<NASGU>
                catch
                    axhndls{1}.XLabel.FontSize = 14; %#ok<NASGU>
                end
            catch
                % 2013-
                set(axhndls(1), 'FontSize', 12)
                set(get(axhndls(1), 'Ylabel'), 'FontSize', 14)
                set(axhndls(2),'position', get(axhndls(2),'position') - [0.01 0 0.02 0], ...
                    'Fontsize', 12)
                if ~isnan(axhndls(3))
                    set(axhndls(3), 'FontSize', 12)
                    set(get(axhndls(3), 'Xlabel'), 'FontSize', 14)
                else
                    set(get(axhndls(1), 'Xlabel'), 'FontSize', 14)
                end
            end
            set(lab, 'rotation', -90, 'FontSize', 12)
        end
        opts.fh = fh;
    end

    function [EEG, opts] = add_psd_plot(EEG, opts)
        fh = opts.fh;
        selected_ic = opts.selected_ic;
        icaacttmp = opts.icaacttmp;
        spec_opt = {};

        try
            hfreq = axes('Parent', fh, 'position', [0.5765 0.1109 0.3587 0.4336], 'units', 'normalized');
            spectopo_ic( icaacttmp(1, :), EEG.pnts, EEG.srate, 'freqrange', [1 80], 'mapnorm', EEG.icawinv(:,selected_ic), spec_opt{:});
            title(hfreq,['IC' int2str(selected_ic) ' Activity Power Spectrum'],'units','normalized', 'fontsize', 14, 'FontWeight', 'Normal');

            set(get(hfreq, 'ylabel'), 'string', 'Power 10*log_{10}(uV^2/Hz)', 'fontsize', 14);
            set(get(hfreq, 'xlabel'), 'string', 'Frequency (Hz)', 'fontsize', 14, 'fontweight', 'normal');
            set(hfreq, 'fontsize', 14, 'fontweight', 'normal');
            xlims = xlim;
            hfreqline = findobj(hfreq, 'type', 'line');
            xdata = get(hfreqline, 'xdata');
            ydata = get(hfreqline, 'ydata');
            ind = xdata >= xlims(1) & xdata <= xlims(2);
            axis on;
            axis([xlims min(ydata(ind)) max(ydata(ind))])
            box on;
            grid on;
        catch e
            cla(hfreq);
            disp(e)
            text(0.1, 0.3, [ 'Error: no spectrum plotted' 10 ' make sure you have the ' 10 'signal processing toolbox']);
        end
        opts.fh = fh;
    end


    function [EEG, opts] = add_fooof_psd_plot(EEG, opts)
        fh = opts.fh;
        selected_ic = opts.selected_ic;
        icaacttmp = opts.icaacttmp;
        spec_opt = {};

        try
            hfreq = axes('Parent', fh, 'position', [0.50 0.053 0.4842 0.5854], 'units', 'normalized');
            imshow(EEG.etc.FOOOF_results.channel(selected_ic).fooof_img)
        catch e
            cla(hfreq);
            disp(e)
            text(0.1, 0.3, [ 'Error: no spectrum plotted' 10 ' make sure you have the ' 10 'signal processing toolbox']);
        end
        opts.fh = fh;
    end

    function [EEG, opts] = add_dipole_image(EEG, opts)
        % Uses modified erpplot that can generate image in the background

        fh = opts.fh;
        selected_ic = opts.selected_ic;
        icaacttmp = opts.icaacttmp;
        erp_opt = {};


        % Defining path for system
        eeglabpath = which('eeglab.m');
        pathtmp = fileparts(eeglabpath);
        dipfits = dir(fullfile(pathtmp, 'plugins', 'dipfit*'));
        [~, dipfit_order] = sort(cellfun(@(c) str2double(c(7:end)), {dipfits.name}), 'descend');
        for it_dipfit_version = dipfit_order
            dipfit_folder = fullfile(pathtmp, 'plugins', dipfits(it_dipfit_version).name);
            meshdatapath = fullfile(dipfit_folder, 'standard_BEM', 'standard_vol.mat');
            mripath = fullfile(dipfit_folder, 'standard_BEM', 'standard_mri.mat');

            % dipplot
            if isfield(EEG, 'dipfit') && ~isempty(EEG.dipfit)
                try
                    rv = num2str(EEG.dipfit.model(selected_ic).rv*100, '%.1f');
                catch
                    rv = 'N/A';
                end
                dip_background = axes('Parent', fh, 'position', [0.41 0.1 0.1 0.1557*3+0.0109], ...
                    'units', 'normalized', 'XLim', [0 1], 'Ylim', [0 1]);
                patch([0 0 1 1], [0 1 1 0], 'k', 'parent', dip_background)
                axis(dip_background, 'off')
                colors = {'g', 'm', 'y'};

                % axial
                ax(1) = axes('Parent', fh, 'position', [0.41 0.1109 0.1 0.1557], 'units', 'normalized');
                axis equal off
                dipplot(EEG.dipfit.model(selected_ic), ...
                    'meshdata', meshdatapath, ...
                    'mri', mripath, ...
                    'normlen', 'on', 'coordformat', 'MNI', 'axistight', 'on', 'gui', 'off', 'view', [0 0 1], 'pointout', 'on');
                temp = axes('Parent', fh, 'position', [0.41 0.1109 0.1 0.1557], 'units', 'normalized');
                copyobj(allchild(ax(1)),temp);
                delete(ax(1))
                ax(1) = temp;
                axis equal off
                temp = get(ax(1),'children');
                ind = find(strcmp('line', get(temp, 'type')));
                for it = 1:length(ind)
                    if mod(it, 2)
                        set(temp(ind(it)), 'markersize', 15, 'color', colors{ceil(it / 2)})
                    else
                        set(temp(ind(it)), 'linewidth', 2, 'color', colors{ceil(it / 2)})
                    end
                end

                % coronal
                ax(2) = axes('Parent', fh, 'position', [0.41 0.2666 0.1 0.1557], 'units', 'normalized');
                axis equal off
                copyobj(allchild(ax(1)),ax(2));
                view([0 -1 0])
                axis equal off
                temp = get(ax(2),'children');
                ind = find(strcmp('line', get(temp, 'type')));
                for it = 1:length(ind)
                    if mod(it, 2)
                        set(temp(ind(it)), 'markersize', 15, 'color', colors{ceil(it / 2)})
                    else
                        set(temp(ind(it)), 'linewidth', 2, 'color', colors{ceil(it / 2)})
                    end
                end

                % sagital
                ax(3) = axes('Parent', fh, 'position', [0.41 0.4223 0.1 0.1557], 'units', 'normalized');
                axis equal off
                copyobj(allchild(ax(1)),ax(3));
                view([1 0 0])
                axis equal off
                temp = get(ax(3),'children');
                ind = find(strcmp('line', get(temp, 'type')));
                for it = 1:length(ind)
                    if mod(it, 2)
                        set(temp(ind(it)), 'markersize', 15, 'color', colors{ceil(it / 2)})
                    else
                        set(temp(ind(it)), 'linewidth', 2, 'color', colors{ceil(it / 2)})
                    end
                end

                % dipole text
                dip_title = title(dip_background, 'Dipole Position', 'FontWeight', 'Normal');
                set(dip_title,'FontSize',14);
                set(fh, 'CurrentAxes', ax(1))
                if size(EEG.dipfit.model(selected_ic).momxyz, 1) == 2
                    dmr = norm(EEG.dipfit.model(selected_ic).momxyz(1,:)) ...
                        / norm(EEG.dipfit.model(selected_ic).momxyz(2,:));
                    if dmr<1
                        dmr = 1/dmr; end
                    text(-50,-173,{['RV: ' rv '%']; ['DMR:' num2str(dmr,'%.1f')]})
                else
                    text(-50,-163,['RV: ' rv '%'])
                end
                set(fh, 'color', [0.9300 0.9600 1.0000]);
                opts.fh = fh;

            end

        end

    end

end

function era_limits=get_era_limits(era)
% from pop_props_extended
%function era_limits=get_era_limits(era)
%
% Returns the minimum and maximum value of an event-related
% activation/potential waveform (after rounding according to the order of
% magnitude of the ERA/ERP)
%
% Inputs:
% era - [vector] Event related activation or potential
%
% Output:
% era_limits - [min max] minimum and maximum value of an event-related
% activation/potential waveform (after rounding according to the order of
% magnitude of the ERA/ERP)

mn=min(era);
mx=max(era);
mn=orderofmag(mn)*round(mn/orderofmag(mn));
mx=orderofmag(mx)*round(mx/orderofmag(mx));
era_limits=[mn mx];

end


function ord=orderofmag(val)
% from pop_props_extended
%function ord=orderofmag(val)
%
% Returns the order of magnitude of the value of 'val' in multiples of 10
% (e.g., 10^-1, 10^0, 10^1, 10^2, etc ...)
% used for computing erpimage trial axis tick labels as an alternative for
% plotting sorting variable

val=abs(val);
if val>=1
    ord=1;
    val=floor(val/10);
    while val>=1,
        ord=ord*10;
        val=floor(val/10);
    end
    return;
else
    ord=1/10;
    val=val*10;
    while val<1,
        ord=ord/10;
        val=val*10;
    end
    return;
end
end

function logMessage(type, message)
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



