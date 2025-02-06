function EEG = eeg_htpEegFixChirpStartStop(EEG, csvFilename, expected_stim_duration_sec, tol_sec)
% fix_EEG_events  Recode the EEG.event structure based on a 2-second expected interval.
%
%   EEG = fix_EEG_events(EEG) examines the EEG.event structure and uses the
%   latency differences to determine which events form a valid trial pair.
%   A valid pair is one in which the difference between consecutive events
%   is approximately 2 seconds (within a specified tolerance). In a valid pair,
%   the first event is marked as TTL_event_start and the second as TTL_event_end.
%   All other events are classified as "extra".
%
%   EEG = fix_EEG_events(EEG, csvFilename, expected_stim_duration_sec, tol_sec)
%   allows you to specify:
%       - csvFilename: the CSV file name for the summary table (default: 'EEG_events_recoded.csv')
%       - expected_stim_duration_sec: the expected time difference (in seconds) between a start and an end event (default: 2 seconds)
%       - tol_sec: the allowed tolerance (in seconds) for pairing events (default: 0.2 seconds)
%
%   Input:
%       EEG - EEGLAB EEG structure with EEG.event and EEG.srate defined.
%       csvFilename - (Optional) CSV file name to save the summary table.
%       expected_stim_duration_sec - (Optional) Expected interval between a trial's start and end (default: 2 sec).
%       tol_sec - (Optional) Tolerance for pairing events (default: 0.2 sec).
%
%   Output:
%       EEG - EEG structure with updated event types.
%
%   Example:
%       EEG = fix_EEG_events(EEG, 'recoded_events.csv', 2, 0.2);
%
% Check that EEG.srate exists
if ~isfield(EEG, 'srate') || isempty(EEG.srate)
    error('EEG.srate is not defined. Please set the sampling rate in EEG.srate.');
end

if nargin < 2 || isempty(csvFilename)
    csvFilename = 'EEG_events_recoded.csv';
end
if nargin < 3 || isempty(expected_stim_duration_sec)
    expected_stim_duration_sec = 2; % expected interval in seconds
end
if nargin < 4 || isempty(tol_sec)
    tol_sec = 0.05; % tolerance in seconds
end

nEvents = length(EEG.event);
if nEvents < 1
    warning('No events found in EEG.event.');
    return;
end

% Preallocate arrays to hold new event types, original types, and latencies.
newEventType = cell(1, nEvents);
originalType = cell(1, nEvents);
latencies = zeros(1, nEvents);

for j = 1:nEvents
    originalType{j} = EEG.event(j).type;
    latencies(j) = EEG.event(j).latency;
end

% Convert latencies from samples to seconds.
latencySec = latencies / EEG.srate;
% Compute the time difference between consecutive events (in seconds).
diffSecAll = [NaN, diff(latencySec)];

% Initialize trial assignment (if desired) for paired events.
trialAssign = nan(1, nEvents);

i = 1;
trialNum = 0;
while i <= nEvents
    % If there is a next event, check the interval
    if i < nEvents
        diffSec = latencySec(i+1) - latencySec(i);
        % Check if the difference is approximately equal to the expected interval
        if abs(diffSec - expected_stim_duration_sec) <= tol_sec
            trialNum = trialNum + 1;
            newEventType{i}   = 'START';
            newEventType{i+1} = 'END';
            trialAssign(i)   = trialNum;
            trialAssign(i+1) = trialNum;
            i = i + 2; % Skip to the event after the pair.
        else
            % Not a valid pair; mark this event as "extra"
            newEventType{i} = 'EXTRA';
            trialAssign(i)  = NaN;
            i = i + 1;
        end
    else
        % Last event with no following event; mark as extra.
        newEventType{i} = 'EXTRA';
        trialAssign(i)  = NaN;
        i = i + 1;
    end
end

% Update the EEG.event structure with the new event types.
for j = 1:nEvents
    EEG.event(j).type = newEventType{j};
end

% Create a summary table with event details.
T = table((1:nEvents)', originalType', newEventType', latencies', latencySec', diffSecAll', trialAssign', ...
    'VariableNames', {'Index', 'OriginalType', 'RecodedType', 'LatencySamples', 'LatencySec', 'DiffSec', 'TrialNumber'});

% Display the table in the MATLAB command window.
disp(T);

% Save the summary table to a CSV file.
try
    writetable(T, csvFilename);
    fprintf('Recoding summary table saved as %s\n', csvFilename);
catch ME
    warning('Could not write table to CSV: %s', ME.message);
end

fprintf('EEG.event structure updated: %d events processed.\n', nEvents);
end
