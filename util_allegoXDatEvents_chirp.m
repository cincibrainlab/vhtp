function [newEEG] = util_allegoXDatEvents_chirp(char_filepath)
%ALLEGOXDATADDEVENTS Summary of this function goes here
%   This function takes in an allegoXDat file and will add events for the
%   chirp paradigm and return the updated eeg
%   Detailed explanation goes here
    % Signal Processing Code Below
    
    % mouse assr 40hz
     args.char_filepath = char_filepath;
    
    
    args.char_netType = 'MEAXDAT';
    
    % Get the folder path, file name, and file extension
    [folderPath, ~, fileExtension] = fileparts(args.char_filepath);        
    % Add the folder path to the search path
    addpath(folderPath);
    % Load the file using pop_loadset if it has a .set extension
    if strcmp(fileExtension, '.xdat')
        
        % Code for import 
        % EEG = util_htpImportAndRemapMea(args.char_filepath);
        note = @(msg) fprintf('%s: %s\n', mfilename, msg );
        dataFile = args.char_filepath;
        if ~endsWith(dataFile, '_data.xdat')
            note(['Skipping file (does not end with _data.xdat): ' dataFile]);
            EEG = []; % Return empty to indicate no processing
            return;
        else
            xdatFile = true;
        end
        
        if xdatFile
            % Xdat import code from manufacturer
            % [signalStruct,timeRange,jsonData] = xdatImport(extractBefore(dataFile,'_data'));  
            xdat_filename = extractBefore(dataFile,'_data');
            % x=allegoXDatFileReaderR2018a_new();
            x=allegoXDatFileReaderR2019b();
            % x=allegoXDatFileReaderR2018a();
            timeRange = x.getAllegoXDatTimeRange(xdat_filename);
            signalStruct.PriSigs = x.getAllegoXDatPriSigs(xdat_filename,timeRange);
            signalStruct.AuxSigs = x.getAllegoXDatAuxSigs(xdat_filename,timeRange);
            signalStruct.DinSigs = x.getAllegoXDatDinSigs(xdat_filename,timeRange);
            signalStruct.DoutSigs = x.getAllegoXDatDoutSigs(xdat_filename,timeRange);
            signalStruct.AllSigs = x.getAllegoXDatAllSigs(xdat_filename,timeRange);
            str = fileread([xdat_filename '.xdat.json']); % dedicated for reading files as text
            jsonData = jsondecode(str);
    
            % Assuming signalStruct.DinSigs.signals contains your data
            % Din Sigs
            % Can see lines but still messy
            % signal = signalStruct.DinSigs.signals(1,:);
            % Can see lines but still messy
            % signal = signalStruct.DinSigs.signals(2,:);
            % Dout Sigs
            % signal = signalStruct.DoutSigs.signals(1,:);
            % signal = signalStruct.DoutSigs.signals(2,:);
            % Aux sigs
            % signal = signalStruct.AuxSigs.signals(1,:);
            signal = signalStruct.AuxSigs.signals(2,:);
    
            signal = double(signal);
            
            % Define the sampling rate
            fs = 1000; % Hz
            
            % Generate a time vector based on the length of the signal
            t = (0:length(signal)-1) / fs;
            % t = signalStruct.AuxSigs.timeStamps;
            
    
    
            % Design a lowpass filter with a cutoff frequency of 100 Hz
            lowpassFilter = designfilt('lowpassiir', 'FilterOrder', 8, ...
                               'HalfPowerFrequency', 100, ...
                               'DesignMethod', 'butter', 'SampleRate', fs);
    
            highpassFilter = designfilt('highpassiir', 'FilterOrder', 8, ...
                                'HalfPowerFrequency', 2, ...
                                'DesignMethod', 'butter', 'SampleRate', fs);
            
            % Design notch filters for 60 Hz, 120 Hz, and 180 Hz
            notch60 = designfilt('bandstopiir', 'FilterOrder', 2, ...
                                 'HalfPowerFrequency1', 55, 'HalfPowerFrequency2', 65, ...
                                 'DesignMethod', 'butter', 'SampleRate', fs);
            
            notch120 = designfilt('bandstopiir', 'FilterOrder', 2, ...
                                  'HalfPowerFrequency1', 115, 'HalfPowerFrequency2', 125, ...
                                  'DesignMethod', 'butter', 'SampleRate', fs);
            
            notch180 = designfilt('bandstopiir', 'FilterOrder', 2, ...
                                  'HalfPowerFrequency1', 175, 'HalfPowerFrequency2', 185, ...
                                  'DesignMethod', 'butter', 'SampleRate', fs);
            
            % Apply the filters sequentially to the signal
            filtered_signal = filtfilt(notch60, signal);
            filtered_signal = filtfilt(notch120, filtered_signal);
            filtered_signal = filtfilt(notch180, filtered_signal);
            
            % lowpass
            filtered_signal = filtfilt(lowpassFilter, filtered_signal);
    
            % highpass
            filtered_signal = filtfilt(highpassFilter, filtered_signal);
    
    
%             % Plot the original and filtered signals
%             figure;
%             plot(t, signal);
%             xlabel('Time (seconds)');
%             ylabel('Amplitude');
%             title('Original Signal');
%             xlim([0 20]); % Zoom in to the first 20 seconds
%             grid on;
%             
%             figure;
%             plot(t, filtered_signal);
%             xlabel('Time (seconds)');
%             ylabel('Amplitude');
%             title('Filtered Signal (60 Hz Notch)');
%             xlim([0 20]); % Zoom in to the first 20 seconds
%             grid on;
%             
%             % Generate the spectrogram of the filtered signal
%             figure;
%             spectrogram(filtered_signal, 256, 250, 256, fs, 'yaxis');
%             title('Spectrogram of the Filtered Signal');
%             xlabel('Time (seconds)');
%             ylabel('Frequency (Hz)');
%             colorbar;
    
            % --------------------------------------------------------------------
            stage1_map = readtable("MouseEEGv2H32_Import_Stage1.csv");
            stage2_map = readtable("MouseEEGv2H32_Import_Stage2.csv");
        
            EEG = eeg_emptyset;
            EEG.data = signalStruct.PriSigs.signals; % 32 Channels X N samples
            % EEG.event 
        
            % Please Check TODO
            [~,name,~] = fileparts(dataFile);
            EEG.setname = strcat(name,'.set');
            EEG.subject = strcat(name,'.set');
            EEG.filename = strcat(name,'.set');
        
            EEG.pnts = jsonData.status.num_smpl;
            EEG.nbchan = jsonData.status.signals.pri;
            EEG.srate = jsonData.status.samp_freq;
            EEG.x_min = timeRange(1);
            EEG.x_max = timeRange(2);
        
            EEG.pnts = size(EEG.data,2);
            EEG.nbchan = size(EEG.data,1);
        
            for i = 1 : numel(jsonData.sapiens_base.biointerface_map.chan_type)
                current_type = jsonData.sapiens_base.biointerface_map.chan_type(i);
                if strcmp(current_type{1}, 'ai0')
                    EEG.chanlocs(i).labels = jsonData.sapiens_base.biointerface_map.chan_name{i};
                end
            end
            EEG = eeg_checkchanlocs(EEG);
            EEG = eeg_checkset(EEG);
        
            EEG = pop_select(EEG, 'nochannel', [2, 32]);
        
        
            % start index at one, not zero
            getChanName = @(T, og_name) T.mea_formatted_name(strcmp(T.og_amplifier_pin, og_name));
        
            % temporary use of old coordinates
            try
                load('mea3d.mat', 'chanlocs');
            catch
                error('mea3d.mat file missing');
            end
                
            EtoCh = @(E) sprintf('Ch %02d', str2double(E(2:end)));
            getIdx = @( key ) find(strcmp({chanlocs.labels}, EtoCh(key)));
        
            note('Load unordered chanlocs.')
        
            for i = 1 : numel(EEG.chanlocs)
                EEG.chanlocs(i).urchan = EEG.chanlocs(i).labels;
                EEG.chanlocs(i).labels = char(getChanName(stage2_map,  EEG.chanlocs(i).urchan));
                EEG.chanlocs(i).type = "EEG";
                EEG.chanlocs(i).ref = '';
        
                j = getIdx(EEG.chanlocs(i).labels);
        
                EEG.chanlocs(i).X = chanlocs(j).X;
                EEG.chanlocs(i).Y = chanlocs(j).Y*-1;
                EEG.chanlocs(i).Z = chanlocs(j).Z;
            end
            % Remap Channel Locations
            EEG =  util_htpRemapXdatMea( EEG );
        
            EEG = eeg_checkset(EEG);
            EEG = eeg_checkchanlocs(EEG);
    
        end
        
        if ~xdatFile  % EDF workflow
            if EEG.nbchan == 33
                EEG = pop_select( EEG, 'nochannel', [2,32,33]);
            elseif EEG.nbchan == 32
                EEG = pop_select( EEG, 'nochannel', [2,32]);
            end
        
            note('Remove irrelevant channels (reference and Piezo).')
            
            try
                load('mea3d.mat', 'chanlocs');
            catch
                error('mea3d.mat file missing');
            end
        
            note('Load unordered chanlocs.')
            
            if xdatFile
                searchSubstring = 'E%d';
            else
                searchSubstring = 'Chan %d'; 
            end
        
            note('Look up correct channel order. Create new ordered index.')
            
            chanlocs = chanlocs(new_chanlocs_index);
            
            note('Reorder channel map.')
            
            % chanlocs(31) = [];
            EEG.chanlocs = chanlocs;
            EEG = eeg_checkset( EEG );
        
        end
        
        note('Assign chanlocs to imported EDF and check set.')
    
    else 
        EEG = [];
    end
    
    data = filtered_signal;
    time = 0:length(data)-1;
    % time = signalStruct.AuxSigs.timeStamps;
     
    % Parameters
    threshold = 0.4;  % Voltage threshold for detecting events (adjust as needed)
    min_duration = 200;  % Minimum duration to consider an event valid (samples)
    
    % Find events
    events = [];
    in_event = false;
    
    for i = 1:length(time)
        amplitude = data(i);
        
        if amplitude >= threshold && ~in_event && i > 1000
            event_start = time(i);
            in_event = true;
        elseif amplitude < -threshold && in_event
            event_duration = time(i) - event_start;
            if event_duration >= min_duration
                events(end+1).latency = event_start;
                events(end).duration = event_duration;
                in_event = false;
            end
        end
    end
     
     
    % Add events to the EEG structure
    for i = 1:length(events)
        % Add event start
        EEG.event(end+1).type = 'TTL_pulse_start';
        EEG.event(end).latency = events(i).latency;
        EEG.event(end).duration = events(i).duration;

        % Add event end
        EEG.event(end+1).type = 'TTL_pulse_end';
        EEG.event(end).latency = events(i).latency + events(i).duration;
        EEG.event(end).duration = 0;
    end
    
    % Sort events by latency
    EEG = eeg_checkset(EEG, 'eventconsistency');
    
    % Plot the event detection results
    fs = 1000; % Sampling frequency in Hz
    time_sec = (0:length(data)-1) / fs; % Convert samples to seconds
    
    figure;
    subplot(2,1,1);
    plot(time_sec, data, 'k', 'LineWidth', 1); hold on;
    
    % Plot event markers
    event_times = [events.latency] / fs; % Convert to seconds
    event_durations = [events.duration] / fs; % Convert to seconds
    event_ends = event_times + event_durations;
    
    % Create square wave for visualization
    square_wave = zeros(size(data));
    for i = 1:length(events)
        start_idx = events(i).latency;
        end_idx = min(start_idx + events(i).duration, length(data));
        square_wave(start_idx:end_idx) = max(abs(data)) * 0.8;
    end
    
    % Plot square wave and event markers
    plot(time_sec, square_wave, 'b--', 'LineWidth', 1.5);
    scatter(event_times, ones(size(event_times)) * max(abs(data)) * 0.9, 50, 'g', 'filled');
    scatter(event_ends, ones(size(event_ends)) * max(abs(data)) * 0.85, 50, 'r', 'filled');
    
    xlabel('Time (s)'); ylabel('Amplitude');
    title('Full Signal View with Detected Events');
    legend('Filtered Signal', 'Event Windows', 'Event Start', 'Event End', 'Location', 'Best');
    grid on;
    
    % Zoomed view of first event
    subplot(2,1,2);
    if ~isempty(events)
        first_event = events(1).latency;
        zoom_start = max(1, first_event - fs); % 1 second before
        zoom_end = min(length(data), first_event + 3*fs); % 3 seconds after
        zoom_window = zoom_start:zoom_end;
        zoom_time = time_sec(zoom_window);
        
        plot(zoom_time, data(zoom_window), 'k', 'LineWidth', 1); hold on;
        plot(zoom_time, square_wave(zoom_window), 'b--', 'LineWidth', 1.5);
        
        % Plot events in zoom window
        zoom_event_times = event_times(event_times >= time_sec(zoom_start) & event_times <= time_sec(zoom_end));
        zoom_event_ends = event_ends(event_times >= time_sec(zoom_start) & event_times <= time_sec(zoom_end));
        
        if ~isempty(zoom_event_times)
            scatter(zoom_event_times, ones(size(zoom_event_times)) * max(abs(data(zoom_window))) * 0.9, 50, 'g', 'filled');
            scatter(zoom_event_ends, ones(size(zoom_event_ends)) * max(abs(data(zoom_window))) * 0.85, 50, 'r', 'filled');
        end
        
        xlabel('Time (s)'); ylabel('Amplitude');
        title('Zoomed View of First Event');
        legend('Filtered Signal', 'Event Windows', 'Event Start', 'Event End', 'Location', 'Best');
        grid on;
    end
    
    % Save the updated EEG dataset
    % pop_saveset(EEG, 'filename', "updated_eeglab_file.set");
    
    % pop_eegplot(EEG, 1, 1, 1);

    newEEG = EEG;
end
         
