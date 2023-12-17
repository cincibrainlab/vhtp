function EEG = eeg_htpEegCalcDipfit(EEG, varargin)
    % This function calculates the dipole fitting for EEG data.
    % It takes as input an EEG structure and optional parameters.
    % The optional parameters are:
    % - 'hdmfile': the head model file (default is 'standard_vol.mat')
    % - 'mrifile': the MRI file (default is 'standard_mri.mat')
    % - 'coord_transform': the coordinate transformation (default is [0.05476 -17.3653 -8.1318 0.075502 0.0031836 -1.5696 11.7138 12.7933 12.213])
    % The function returns the EEG structure with the calculated dipole fitting.

    p = inputParser;
    addParameter(p, 'hdmfile', missing, @ischar);
    addParameter(p, 'mrifile', missing, @ischar);
    addParameter(p, 'plot', false, @islogical);
    addParameter(p, 'coord_transform', [0.05476 -17.3653 -8.1318 0.075502 0.0031836 -1.5696 11.7138 12.7933 12.213], @isnumeric);
    addParameter(p, 'dipoles', 2, @isnumeric);
    addParameter(p, 'threshold', 100, @isnumeric);
    parse(p, varargin{:});
    
    dipfit.hdmfile = p.Results.hdmfile;
    dipfit.mrifile = p.Results.mrifile;
    dipfit.plot = p.Results.plot;
    dipfit.chanfile = missing;
    dipfit.no_of_components = missing;
    dipfit.threshold = p.Results.threshold;
    dipfit.dipoles = p.Results.dipoles;
    dipfit.coordformat = 'MNI';
    dipfit.coord_transform = p.Results.coord_transform;

    [EEG, dipfit] = check_requirements(EEG, dipfit);

    [EEG, dipfit] = calculate_dipfit(EEG, dipfit);

    [EEG, dipfit] = calculate_two_dipoles(EEG, dipfit);

    [EEG, dipfit] = plotDipolePlot(EEG, dipfit);


    function [EEG, dipfit] = check_requirements(EEG, dipfit)
        default_coord_transform = [0.05476 -17.3653 -8.1318 0.075502 0.0031836 -1.5696 11.7138 12.7933 12.213];
        if isequal(dipfit.coord_transform, default_coord_transform) && ~contains(EEG.chaninfo.filename, 'HydroCel-129')
            error('The default coord_transform is made for HydroCel-129 net. Please provide a different coord_transform for other nets.');
        end
        if ~exist('pop_dipfit_settings', 'file')
            logMessage('error', 'Dipfit plugin is not available');
        else
            logMessage('info', 'Dipfit plugin is available.');
            dipfit.dipfit_plugin_dir = fileparts(which('pop_dipfit_settings'));
            if ismissing(dipfit.hdmfile)
                dipfit.hdmfile = fullfile(dipfit.dipfit_plugin_dir, 'standard_BEM', 'standard_vol.mat');
            end
            if ismissing(dipfit.mrifile)
                dipfit.mrifile = fullfile(dipfit.dipfit_plugin_dir, 'standard_BEM', 'standard_mri.mat');
            end
            if ismissing(dipfit.chanfile)
                dipfit.chanfile = fullfile(dipfit.dipfit_plugin_dir, 'standard_BEM',  'elec', 'standard_1005.elc');
            end
            logMessage('info', sprintf('Dipfit plugin directory: %s', dipfit.dipfit_plugin_dir));    
        end
        if ~exist('fitTwoDipoles', 'file')
            logMessage('error', 'fitTwoDipoles plugin is not available');
        else
            logMessage('info', 'fitTwoDipoles plugin is available.');
        end
        if ~isfield(EEG, 'icaweights')
            logMessage('error', 'EEG does not contain ICA weights. Please run ICA first.');
        else
            logMessage('info', 'ICA weights found.');
        end
        files = {'hdmfile', 'mrifile', 'chanfile'};
        for i = 1:length(files)
            file = dipfit.(files{i});
            if ismissing(file)
                logMessage('error', sprintf('File is missing: %s', files{i}));
            elseif ~exist(file, 'file')
                logMessage('error', sprintf('File not found: %s', file));
            else
                logMessage('info', sprintf('File found: %s', file));
            end
        end

    end

    function [EEG, dipfit] = calculate_dipfit(EEG, dipfit)

        [EEG, dipfit] = computeNumComponents(EEG, dipfit);

        EEG = pop_dipfit_settings(EEG, ...
            'hdmfile', dipfit.hdmfile, ...
            'mrifile',dipfit.mrifile, ...
            'chanfile',dipfit.chanfile, ...
            'coordformat','MNI', ...
            'coord_transform', dipfit.coord_transform);
        
        EEG = pop_multifit(EEG, 1:dipfit.no_of_components, ...
            'threshold', dipfit.threshold , ...
            'dipoles', 1,...
            'plotopt',{'normlen','on'});
    end

    function [EEG, dipfit] = calculate_two_dipoles(EEG, dipfit)
        if dipfit.dipoles == 2
            logMessage('info', 'Calculating two dipoles.');
            EEG = fitTwoDipoles(EEG, 'LRR', 35);
        end
    end

    function [EEG, dipfit] = plotDipolePlot(EEG, dipfit)
        if dipfit.plot
            pop_dipplot( EEG, 1:dipfit.no_of_components ,'mri',dipfit.mrifile,'normlen','on');
        end
    end


    function [EEG, dipfit] = computeNumComponents(EEG, dipfit)

        logMessage('info', 'Computing component metrics.');
        dipfit.no_of_components = size(EEG.icawinv, 2);

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
end


