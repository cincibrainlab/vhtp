function [newEEG] = util_allegoXDatEvents_assr(char_filepath)
%ALLEGOXDATADDEVENTS Summary of this function goes here
%   This function takes in an allegoXDat file and will add events for the
%   assr paradigm and return the updated eeg
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
    if ~isempty(regexp(dataFile,'xdat','match')); xdatFile = true; else; xdatFile = false; end

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

        % Low-pass filter at 100 Hz with very steep rolloff
        lowpass300 = designfilt('lowpassiir', 'FilterOrder', 6, ... % Increased order for even sharper rolloff
            'HalfPowerFrequency', 300, ...
            'DesignMethod', 'butter', 'SampleRate', fs);

        % Notch filters for 60Hz harmonics (narrower, higher order)
        notch60 = designfilt('bandstopiir', 'FilterOrder', 8, ...
            'HalfPowerFrequency1', 57.5, 'HalfPowerFrequency2', 62.5, ...
            'DesignMethod', 'butter', 'SampleRate', fs);

        psdsignal = filtfilt(lowpass300, signal);
        psdsignal = filtfilt(notch60, psdsignal);
        [~,name,~] = fileparts(dataFile);
        [hysteresis, square_wave] = util_detectEventsWithHysteresis_samples(psdsignal, t, 'basename',name, 'outputDir', folderPath, ...
             'HIGH_THRESHOLD_PERCENTILE', 92.7, 'LOW_THRESHOLD_PERCENTILE', 30);

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

filtered_signal = square_wave;

% Revised event detection using the binary square wave

% Assume square_wave is a binary vector (0s and 1s) and time is defined as:
time = 0:length(square_wave)-1;  % sample indices

min_duration = 2500;  % Minimum valid event duration (samples)

% Find rising (0->1) and falling (1->0) edges.
sq_diff = diff([0; square_wave(:)]);
rising_edges = find(sq_diff == 1);
falling_edges = find(sq_diff == -1);

% If the signal starts high, treat index 1 as a rising edge.
if isempty(rising_edges) && square_wave(1)==1
    rising_edges = 1;
end

% If the signal ends high, append the last index as the falling edge.
if ~isempty(rising_edges) && (isempty(falling_edges) || falling_edges(end) < rising_edges(end))
    falling_edges(end+1,1) = length(square_wave);
end

% Build events using transitions that meet the minimum duration.
events = [];
for i = 1:length(rising_edges)
    event_start = rising_edges(i);
    event_end = falling_edges(i);
    duration = event_end - event_start;
    if duration >= min_duration
        event.latency  = event_start;
        event.duration = duration;
        event.end_time = event_end;
        events = [events, event];
    end
end

% Add events to the EEG structure.
for i = 1:length(events)
    EEG.event(end+1).type     = 'TTL_pulse_start';
    EEG.event(end).latency      = events(i).latency;
    EEG.event(end).duration     = events(i).duration;

    EEG.event(end+1).type     = 'TTL_pulse_end';
    EEG.event(end).latency      = events(i).end_time;
    EEG.event(end).duration     = 0;
end

EEG = eeg_checkset(EEG, 'eventconsistency');

% Quality Control Check for ASSR Events
fprintf('\n=== ASSR Event Quality Control Check ===\n');

% Expected parameters
EXPECTED_EVENT_COUNT = 50;
EXPECTED_START_END_DURATION = 2980;  % Duration of each pulse
EXPECTED_START_START_INTERVAL = 5000; % Time between starts of consecutive pulses
EXPECTED_END_START_INTERVAL = 2020;   % Time between end of one pulse and start of next
ALLOWED_DEVIATION = 3;  % Samples of allowed deviation
LARGE_DEVIATION_THRESHOLD = 250; % Threshold to detect likely false positives

% Initialize QC results
qc_passed = true;
qc_messages = {};

% Initialize error pattern tracking
timing_errors = struct();

% 1. Check total number of TTL_pulse_start events
start_events = find(strcmp({EEG.event.type}, 'TTL_pulse_start'));
end_events = find(strcmp({EEG.event.type}, 'TTL_pulse_end'));
num_start_events = length(start_events);
num_end_events = length(end_events);

% Check for false positive events after expected end
if num_start_events > EXPECTED_EVENT_COUNT
    fprintf('Checking for false positive events...\n');
    
    % Look at the interval after event 50
    if EXPECTED_EVENT_COUNT < num_start_events
        event_50_end = EEG.event(end_events(EXPECTED_EVENT_COUNT)).latency;
        next_start = EEG.event(start_events(EXPECTED_EVENT_COUNT + 1)).latency;
        interval = next_start - event_50_end - EXPECTED_END_START_INTERVAL;
        
        % If we see a very large deviation, likely a false positive
        if abs(interval) > LARGE_DEVIATION_THRESHOLD
            fprintf('Found likely false positive event after expected end. Removing...\n');
            
            % Remove the extra events
            extra_start_indices = start_events(EXPECTED_EVENT_COUNT + 1:end);
            extra_end_indices = end_events(EXPECTED_EVENT_COUNT + 1:end);
            
            % Remove from end to not mess up indices
            for idx = sort([extra_start_indices extra_end_indices], 'descend')
                EEG.event(idx) = [];
            end
            
            % Update counts
            start_events = find(strcmp({EEG.event.type}, 'TTL_pulse_start'));
            end_events = find(strcmp({EEG.event.type}, 'TTL_pulse_end'));
            num_start_events = length(start_events);
            num_end_events = length(end_events);
            
            qc_messages{end+1} = sprintf('Removed %d false positive event(s) after expected end of stimulus', ...
                length(extra_start_indices));
            fprintf('Events removed. Now have %d start events and %d end events.\n', ...
                num_start_events, num_end_events);
        end
    end
end

% 2. Check each start-end duration
fprintf('\nChecking individual pulse durations (start to end)...\n');
for i = 1:num_start_events
    start_time = EEG.event(start_events(i)).latency;
    end_time = EEG.event(end_events(i)).latency;
    duration = end_time - start_time;
    time_in_seconds = start_time / EEG.srate;
    
    if abs(duration - EXPECTED_START_END_DURATION) > ALLOWED_DEVIATION
        qc_passed = false;
        msg = sprintf('Pulse %d duration error at %.2f seconds: %.1f samples (expected %d ± %d)', ...
            i, time_in_seconds, duration, EXPECTED_START_END_DURATION, ALLOWED_DEVIATION);
        qc_messages{end+1} = msg;
        fprintf('- %s\n', msg);
    end
end

% 3. Check start-to-start intervals
fprintf('\nChecking intervals between consecutive starts...\n');
for i = 1:num_start_events-1
    start_current = EEG.event(start_events(i)).latency;
    start_next = EEG.event(start_events(i+1)).latency;
    interval = start_next - start_current;
    time_in_seconds = start_current / EEG.srate;
    
    if abs(interval - EXPECTED_START_START_INTERVAL) > ALLOWED_DEVIATION
        qc_passed = false;
        deviation = interval - EXPECTED_START_START_INTERVAL;
        if ~isfield(timing_errors, sprintf('event_%d', i+1))
            timing_errors.(sprintf('event_%d', i+1)) = struct('early_late', 0, 'time', time_in_seconds);
        end
        timing_errors.(sprintf('event_%d', i+1)).early_late = timing_errors.(sprintf('event_%d', i+1)).early_late + deviation;
        
        msg = sprintf('Start-to-start interval error at event %d (%.2f seconds): %.1f samples (expected %d ± %d) [%s]', ...
            i, time_in_seconds, interval, EXPECTED_START_START_INTERVAL, ALLOWED_DEVIATION, ...
            ternary(deviation > 0, 'longer than expected', 'shorter than expected'));
        qc_messages{end+1} = msg;
        fprintf('- %s\n', msg);
    end
end

% 4. Check end-to-start intervals
fprintf('\nChecking intervals between end and next start...\n');
for i = 1:num_end_events-1
    end_current = EEG.event(end_events(i)).latency;
    start_next = EEG.event(start_events(i+1)).latency;
    interval = start_next - end_current;
    time_in_seconds = end_current / EEG.srate;
    
    if abs(interval - EXPECTED_END_START_INTERVAL) > ALLOWED_DEVIATION
        qc_passed = false;
        deviation = interval - EXPECTED_END_START_INTERVAL;
        if ~isfield(timing_errors, sprintf('event_%d', i+1))
            timing_errors.(sprintf('event_%d', i+1)) = struct('early_late', 0, 'time', time_in_seconds);
        end
        timing_errors.(sprintf('event_%d', i+1)).early_late = timing_errors.(sprintf('event_%d', i+1)).early_late + deviation;
        
        msg = sprintf('End-to-start interval error at event %d (%.2f seconds): %.1f samples (expected %d ± %d) [%s]', ...
            i, time_in_seconds, interval, EXPECTED_END_START_INTERVAL, ALLOWED_DEVIATION, ...
            ternary(deviation > 0, 'longer than expected', 'shorter than expected'));
        qc_messages{end+1} = msg;
        fprintf('- %s\n', msg);
    end
end

% Analyze timing error patterns
if ~qc_passed
    fprintf('\nTiming Error Analysis:\n');
    
    % Create a structure to store interval information for each event
    event_intervals = struct();
    
    % First pass: collect all interval information for each event
    for i = 1:num_start_events-1
        event_num = i + 1;  
        % Current event num the one we are analyzing
        
        % Get the intervals
        prev_end = EEG.event(end_events(i)).latency;
        curr_start = EEG.event(start_events(event_num)).latency;
        curr_end = EEG.event(end_events(event_num)).latency;
        
        % Only process if we have a next event to compare with
        if event_num < num_start_events
            next_start = EEG.event(start_events(event_num+1)).latency;
            
            % Calculate interval deviations
            interval_before = curr_start - prev_end - EXPECTED_END_START_INTERVAL;
            interval_after = next_start - curr_end - EXPECTED_END_START_INTERVAL;
            
            % Store the information
            event_intervals.(sprintf('event_%d', event_num)) = struct(...
                'time', curr_start / EEG.srate, ...
                'interval_before', interval_before, ...
                'interval_after', interval_after);
        end
    end
    
    % Second pass: analyze each event for misalignment
    event_nums = fieldnames(event_intervals);
    for i = 1:length(event_nums)
        event_num = str2double(regexp(event_nums{i}, '\d+', 'match'));
        interval_data = event_intervals.(event_nums{i});
        
        % An event is misaligned if:
        % - The interval before it is too long AND the interval after it is too short
        % - OR vice versa
        if (interval_data.interval_before > ALLOWED_DEVIATION && interval_data.interval_after < -ALLOWED_DEVIATION) || ...
           (interval_data.interval_before < -ALLOWED_DEVIATION && interval_data.interval_after > ALLOWED_DEVIATION)
            fprintf('Event %d (at %.2f seconds) is misaligned:\n', event_num, interval_data.time);
            fprintf('  - Interval before event: %+.1f samples from expected\n', interval_data.interval_before);
            fprintf('  - Interval after event: %+.1f samples from expected\n', interval_data.interval_after);
        end
    end
end


% Display final QC result
fprintf('\nQC Check Result: %s\n', ternary(qc_passed, 'PASSED', 'FAILED'));
if ~qc_passed
    fprintf('\nSummary of all issues found:\n');
    cellfun(@(msg) fprintf('- %s\n', msg), qc_messages);
    
    % Create popup message with QC results
    popup_msg = sprintf('Quality Control Issues Found in: %s\n\n', EEG.filename);
    
    % Add timing error analysis if it exists
    timing_analysis = '';
    event_nums = fieldnames(event_intervals);
    for i = 1:length(event_nums)
        event_num = str2double(regexp(event_nums{i}, '\d+', 'match'));
        interval_data = event_intervals.(event_nums{i});
        
        if (interval_data.interval_before > ALLOWED_DEVIATION && interval_data.interval_after < -ALLOWED_DEVIATION) || ...
           (interval_data.interval_before < -ALLOWED_DEVIATION && interval_data.interval_after > ALLOWED_DEVIATION)
            timing_analysis = sprintf('%sEvent %d (at %.2f seconds) is misaligned:\n  Before: %+.1f samples\n  After: %+.1f samples\n\n', ...
                timing_analysis, event_num, interval_data.time, ...
                interval_data.interval_before, interval_data.interval_after);
        end
    end
    
    if ~isempty(timing_analysis)
        popup_msg = sprintf('%s\nTiming Analysis:\n%s', popup_msg, timing_analysis);
    end
    
    % Add all other QC messages
    popup_msg = sprintf('%s\nAll Issues Found:\n', popup_msg);
    for i = 1:length(qc_messages)
        popup_msg = sprintf('%s• %s\n', popup_msg, qc_messages{i});
    end
    
    % Create a wider dialog box
    d = figure('Position',[300 300 700 500], ...
        'Name','ASSR Quality Control Results', ...
        'NumberTitle','off', ...
        'MenuBar','none', ...
        'ToolBar','none', ...
        'WindowStyle','normal');
    
    % Create text control with scrolling enabled
    txt = uicontrol('Parent',d,...
        'Style','edit',... % Use edit instead of text to get scrolling
        'Position',[20 40 660 440],...
        'String',popup_msg,...
        'HorizontalAlignment','left',...
        'Min',0,'Max',2,... % Enable multiline
        'BackgroundColor','white',...
        'Enable','inactive'); % Make read-only but still selectable
    
end
fprintf('===================================\n\n');

% pop_eegplot(EEG, 1, 1, 1);

newEEG = EEG;
end

function result = ternary(condition, if_true, if_false)
    if condition
        result = if_true;
    else
        result = if_false;
    end
end

