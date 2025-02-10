function [hysteresis, square_wave] = util_detectEventsWithHysteresis(signal, time, varargin)
% detectEventsWithHysteresis  Apply hysteresis thresholding and generate a square wave.
%   [HYSTERESIS, SQUARE_WAVE] = detectEventsWithHysteresis(SIGNAL, TIME)
%   processes the input SIGNAL (assumed uniformly sampled) using the TIME
%   vector (in seconds) and returns two binary vectors of the same length.
%
%   The function first computes the full-wave rectification of the signal and
%   then applies hysteresis thresholding based on the high and low percentiles.
%   Detected events are marked in a binary square wave, where each event is
%   defined by a specified duration and separated by a refractory period.
%
%   Optional name-value pair parameters:
%
%       'showPlot' (logical)  
%           If true, the function generates a figure with two subplots:
%             - A full signal view showing the original signal, hysteresis, 
%               and square wave.
%             - A zoomed view around the fifth square wave transition.
%           Default is true.
%
%       'basename' (string)
%           The base filename for saving the generated plot. The figure is saved
%           as [basename '.png'].
%           Default is 'signal_plot'.
%
%       'outputDir' (string)
%           The directory where the plot is saved. If the directory does not exist,
%           it is created.
%           Default is '.' (current directory).
%
%       'HIGH_THRESHOLD_PERCENTILE' (numeric)
%           The percentile used to determine the high threshold for hysteresis.
%           Default is 90.
%
%       'LOW_THRESHOLD_PERCENTILE' (numeric)
%           The percentile used to determine the low threshold for hysteresis.
%           Default is 50.
%
%       'EVENT_DURATION_SECONDS' (numeric)
%           The duration in seconds for which the square wave remains high to mark an
%           event.
%           Default is 3.
%
%       'REFRACTORY_PERIOD_SECONDS' (numeric)
%           The minimum time (in seconds) between consecutive events to avoid overlapping.
%           Default is 1.
%
%       'LINE_WIDTH_THIN' (numeric)
%           The line width used when plotting the original signal.
%           Default is 1.
%
%       'LINE_WIDTH_THICK' (numeric)
%           The line width used when plotting the hysteresis and square wave signals.
%           Default is 1.5.
%
%       'SCATTER_SIZE' (numeric)
%           The marker size for scatter plots indicating event start points.
%           Default is 50.
%
%   Example:
%       t = (0:0.01:10)'; 
%       s = sin(2*pi*0.5*t) + 0.1*randn(size(t));
%       [hyst, sq] = detectEventsWithHysteresis(s, t, 'showPlot', true, ...
%                     'basename', 'myPlot', 'outputDir', './plots', ...
%                     'HIGH_THRESHOLD_PERCENTILE', 90, 'LOW_THRESHOLD_PERCENTILE', 50, ...
%                     'EVENT_DURATION_SECONDS', 3, 'REFRACTORY_PERIOD_SECONDS', 1, ...
%                     'LINE_WIDTH_THIN', 1, 'LINE_WIDTH_THICK', 1.5, 'SCATTER_SIZE', 50);
%

% Ensure time is provided as a column vector.
if nargin < 2
    time = (1:length(signal))';
else
    time = time(:);
end
signal = signal(:);

% --- Parse optional inputs ---
p = inputParser;
% Plotting and file output options
addParameter(p, 'showPlot', true, @(x) islogical(x) || ismember(x, [0,1]));
addParameter(p, 'basename', 'signal_plot', @ischar);
addParameter(p, 'outputDir', '.', @ischar);
% Hysteresis thresholding parameters
addParameter(p, 'HIGH_THRESHOLD_PERCENTILE', 90, @isnumeric);
addParameter(p, 'LOW_THRESHOLD_PERCENTILE', 50, @isnumeric);
% Event duration and refractory period
addParameter(p, 'EVENT_DURATION_SECONDS', 3, @isnumeric);
addParameter(p, 'REFRACTORY_PERIOD_SECONDS', 1, @isnumeric);
% Plot formatting parameters
addParameter(p, 'LINE_WIDTH_THIN', 1, @isnumeric);
addParameter(p, 'LINE_WIDTH_THICK', 1.5, @isnumeric);
addParameter(p, 'SCATTER_SIZE', 50, @isnumeric);
parse(p, varargin{:});
opts = p.Results;

% Assign parameters from parsed options.
HIGH_THRESHOLD_PERCENTILE = opts.HIGH_THRESHOLD_PERCENTILE;
LOW_THRESHOLD_PERCENTILE  = opts.LOW_THRESHOLD_PERCENTILE;
EVENT_DURATION_SECONDS    = opts.EVENT_DURATION_SECONDS;
REFRACTORY_PERIOD_SECONDS = opts.REFRACTORY_PERIOD_SECONDS;
LINE_WIDTH_THIN           = opts.LINE_WIDTH_THIN;
LINE_WIDTH_THICK          = opts.LINE_WIDTH_THICK;
SCATTER_SIZE              = opts.SCATTER_SIZE;

% --- Full-wave rectification and threshold calculation ---
rectSignal = abs(signal);
highThresh = prctile(rectSignal, HIGH_THRESHOLD_PERCENTILE);
lowThresh  = prctile(rectSignal, LOW_THRESHOLD_PERCENTILE);

% --- Hysteresis thresholding ---
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

% --- Event detection from hysteresis ---
% A rising edge is detected where diff([0; hysteresis]) equals 1.
eventStarts = find(diff([0; hysteresis]) == 1);
samplingInterval = median(diff(time));
eventDurSamples = max(1, round(EVENT_DURATION_SECONDS / samplingInterval));
refractorySamples = max(1, round(REFRACTORY_PERIOD_SECONDS / samplingInterval));

% --- Generate square wave ---
square_wave = zeros(size(hysteresis));
for k = 1:length(eventStarts)
    startIdx = eventStarts(k);
    endIdx = min(startIdx + eventDurSamples - 1, length(square_wave));
    
    % Check for a refractory period if a previous event exists.
    if startIdx > 1
        prevOn = find(square_wave(1:startIdx-1) == 1);
        if ~isempty(prevOn)
            lastEventEnd = prevOn(end);
            if (startIdx - lastEventEnd) < refractorySamples
                continue;
            end
        end
    end
    
    % Avoid overlapping events.
    if any(square_wave(startIdx:endIdx) == 1)
        continue;
    end
    
    square_wave(startIdx:endIdx) = 1;
end

% --- Plotting ---
if opts.showPlot
    fig = figure;
    
    % Top subplot: Full signal view.
    subplot(2,1,1);
    plot(time, signal, 'k', 'LineWidth', LINE_WIDTH_THIN); hold on;
    plot(time, hysteresis, 'r--', 'LineWidth', LINE_WIDTH_THICK);
    plot(time, square_wave, 'b--', 'LineWidth', LINE_WIDTH_THICK);
    % Mark hysteresis rising edges.
    plot(time(eventStarts), hysteresis(eventStarts), 'ro', ...
         'MarkerFaceColor', 'r', 'MarkerSize', SCATTER_SIZE/10);
    xlabel('Time (s)'); ylabel('Amplitude');
    title('Full Signal View');
    legend('Original Signal', 'Hysteresis', 'Square Wave', 'Event Start', 'Location', 'Best');
    grid on; hold off;
    
    % Bottom subplot: Zoomed view around the fifth square wave start.
    subplot(2,1,2);
    sqDiff = diff([0; square_wave]);
    sqStarts = find(sqDiff == 1);
    if numel(sqStarts) >= 5
        idx5 = sqStarts(5);
        % Define a zoom window: 1 second before and 4 seconds after the event.
        zoomStartTime = max(time(1), time(idx5) - 1);
        zoomEndTime   = min(time(end), time(idx5) + 4);
        zoomMask = (time >= zoomStartTime) & (time <= zoomEndTime);
        
        plot(time(zoomMask), signal(zoomMask), 'k', 'LineWidth', LINE_WIDTH_THIN); hold on;
        plot(time(zoomMask), hysteresis(zoomMask), 'r--', 'LineWidth', LINE_WIDTH_THICK);
        plot(time(zoomMask), square_wave(zoomMask), 'b--', 'LineWidth', LINE_WIDTH_THICK);
        % Mark square wave rising edges in the zoom window.
        zoomSqStarts = sqStarts((time(sqStarts) >= zoomStartTime) & (time(sqStarts) <= zoomEndTime));
        plot(time(zoomSqStarts), square_wave(zoomSqStarts), 'ro', ...
             'MarkerFaceColor', 'r', 'MarkerSize', SCATTER_SIZE/10);
        xlabel('Time (s)'); ylabel('Amplitude');
        title('Zoomed View of Fifth Square Wave Transition');
        legend('Original Signal', 'Hysteresis', 'Square Wave', 'Square Wave Start', 'Location', 'Best');
        grid on; hold off;
    else
        title('Zoomed View: Fewer than 5 square wave events detected.');
    end
    
    % Save figure to specified directory.
    if ~exist(opts.outputDir, 'dir')
        mkdir(opts.outputDir);
    end
    saveas(fig, fullfile(opts.outputDir, [opts.basename, '.png']));
end

end