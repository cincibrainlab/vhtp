function [hysteresis, square_wave, eventTimes] = util_detectEventsWithHysteresis(signal, time, varargin)
% util_detectEventsWithHysteresis - Detect events using hysteresis and generate a square wave.
% All calculations are performed in samples for precision.

%% --- Ensure Input is Column Vector ---
signal = signal(:);
time = time(:); % Only used for final output

%% --- Parse Optional Inputs ---
p = inputParser;
addParameter(p, 'showPlot', true, @(x) islogical(x) || ismember(x, [0, 1]));
addParameter(p, 'basename', 'signal_plot', @ischar);
addParameter(p, 'outputDir', '.', @ischar);
addParameter(p, 'HIGH_THRESHOLD_PERCENTILE', 92.7, @isnumeric);
addParameter(p, 'LOW_THRESHOLD_PERCENTILE', 40, @isnumeric);
addParameter(p, 'EVENT_DURATION_SAMPLES', 2980, @isnumeric); % Exact duration in samples
addParameter(p, 'REFRACTORY_PERIOD_SAMPLES', 1976, @isnumeric); % Period after to consider for no events
addParameter(p, 'LINE_WIDTH_THIN', 1, @isnumeric);
addParameter(p, 'LINE_WIDTH_THICK', 1.5, @isnumeric);
addParameter(p, 'SCATTER_SIZE', 50, @isnumeric);
parse(p, varargin{:});
opts = p.Results;

%% --- Compute Hysteresis Thresholds ---
rectSignal = abs(signal);
highThresh = prctile(rectSignal, opts.HIGH_THRESHOLD_PERCENTILE);
lowThresh = prctile(rectSignal, opts.LOW_THRESHOLD_PERCENTILE);

%% --- Apply Hysteresis Thresholding ---
hysteresis = zeros(size(rectSignal));
active = false;
for i = 1:length(rectSignal)
    if rectSignal(i) > highThresh
        active = true;
    elseif rectSignal(i) < lowThresh
        active = false;
    end
    hysteresis(i) = active;
end

%% --- Detect Rising Edges (Event Starts) ---
eventStarts = find(diff([0; hysteresis]) == 1); % Detect transitions

%% --- Filter Event Starts Based on Refractory Period ---
validEventStarts = [];
lastEventEnd = 0;

for k = 1:length(eventStarts)
    startIdx = eventStarts(k);
    
    % Only include events that respect the refractory period
    if (startIdx - lastEventEnd) >= opts.REFRACTORY_PERIOD_SAMPLES
        validEventStarts = [validEventStarts; startIdx];
        lastEventEnd = startIdx + opts.EVENT_DURATION_SAMPLES - 1;
    end
end

eventStarts = validEventStarts; % Replace with filtered events

%% --- Debug: Verify Event Starts ---
fprintf('Event Start Indices (first 10): \n');
disp(eventStarts(1:min(10, length(eventStarts))));

%% --- Generate Square Wave with Corrected Start Points ---
square_wave = zeros(size(hysteresis));

for k = 1:length(eventStarts)
    startIdx = eventStarts(k);
    endIdx = min(startIdx + opts.EVENT_DURATION_SAMPLES - 1, length(square_wave));
    square_wave(startIdx:endIdx) = 1;
end

%% --- Debug: Verify Square Wave Alignment ---
fprintf('Square Wave Activation Indices (first 10 nonzero samples): \n');
disp(find(square_wave, 10));

%% --- Convert Event Indices to Time for Output ---
eventTimes = time(eventStarts);

%% --- Plot Results ---
if opts.showPlot
    figure;
    subplot(2,1,1);
    plot(time, signal, 'k', 'LineWidth', opts.LINE_WIDTH_THIN); hold on;
    plot(time, hysteresis, 'r--', 'LineWidth', opts.LINE_WIDTH_THICK);
    plot(time, square_wave, 'b--', 'LineWidth', opts.LINE_WIDTH_THICK);
    % Plot start markers in green
    scatter(eventTimes, ones(size(eventTimes)) * max(signal) * 0.9, opts.SCATTER_SIZE, 'g', 'filled');
    % Calculate and plot end markers in red, ensuring we dont exceed array bounds
    endIndices = min(eventStarts + opts.EVENT_DURATION_SAMPLES - 1, length(time));
    scatter(time(endIndices), ones(size(endIndices)) * max(signal) * 0.85, opts.SCATTER_SIZE, 'r', 'filled');
    xlabel('Time (s)'); ylabel('Amplitude');
    title('Full Signal View');
    legend('Original Signal', 'Hysteresis', 'Square Wave', 'Event Start', 'Event End', 'Location', 'Best');
    grid on; hold off;
    
    subplot(2,1,2);
    zoomWindow = find(time >= time(eventStarts(1)) - 1 & time <= time(eventStarts(1)) + 3);
    
    % Debug prints
    fprintf('Zoom window range: %d to %d\n', zoomWindow(1), zoomWindow(end));
    fprintf('Time range in zoom: %.3f to %.3f\n', time(zoomWindow(1)), time(zoomWindow(end)));
    
    % Filter events within zoom window
    validEvents = eventTimes(eventTimes >= time(zoomWindow(1)) & eventTimes <= time(zoomWindow(end)));
    fprintf('Number of events in zoom window: %d\n', length(validEvents));
    
    plot(time(zoomWindow), signal(zoomWindow), 'k', 'LineWidth', opts.LINE_WIDTH_THIN); hold on;
    plot(time(zoomWindow), hysteresis(zoomWindow), 'r--', 'LineWidth', opts.LINE_WIDTH_THICK);
    plot(time(zoomWindow), square_wave(zoomWindow), 'b--', 'LineWidth', opts.LINE_WIDTH_THICK);
    
    if ~isempty(validEvents)
        % Plot start events in green
        scatter(validEvents, ones(size(validEvents)) * max(signal(zoomWindow)) * 0.9, opts.SCATTER_SIZE, 'g', 'filled');
        % Plot end events in red (for events within zoom window)
        validStartIndices = eventStarts(eventTimes >= time(zoomWindow(1)) & eventTimes <= time(zoomWindow(end)));
        validEndIndices = min(validStartIndices + opts.EVENT_DURATION_SAMPLES - 1, length(time));
        validEndTimes = time(validEndIndices);
        if ~isempty(validEndTimes)
            scatter(validEndTimes, ones(size(validEndTimes)) * max(signal(zoomWindow)) * 0.85, opts.SCATTER_SIZE, 'r', 'filled');
        end
    end
    
    xlabel('Time (s)'); ylabel('Amplitude');
    title('Zoomed View of First Event Transition');
    legend('Original Signal', 'Hysteresis', 'Square Wave', 'Event Start', 'Event End', 'Location', 'Best');
    grid on; hold off;
end

end
