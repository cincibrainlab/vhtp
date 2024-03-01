function [outEEG, extra] = eeg_htpEegAdvancedEpochs(EEG, main_trigger, backup_trigger, epoch_length, baseline_length, rois, varargin)
% Advanced epoching example for complex ERP paradigms
% Inputs:
% - EEG: input EEG SET file
% - main_trigger: cell array input for main trigger(s)
% - backup_trigger: cell array input for backup trigger(s)
% - epoch_length: cell array input for epoch length(s)
% Optional Inputs:
% - 'SaveCSV': whether to save the output as a CSV file (default: false)
% Outputs:
% - epochEEG: epoched EEG data
% - eventtbl_epoch: event table in CSV format (if 'SaveCSV' is true)
% Example:'
%         main_trigger = {'DIN3'};
%         backup_trigger = {'ch1+', 'ch2+'};
%         epoch_length = [-.1 .4];
%         baseline_length = [-100 0];
%         alog.addAction('epoch', 'DIN3');
% 
%         [output_set, extras]  = cellfun(@(EEG) eeg_htpEegAdvancedEpochs(EEG, main_trigger, backup_trigger, ...
%             epoch_length, baseline_length, rois, 'outputDir', results_dir ,'SaveCSV', true),...
%             input_set, 'UniformOutput',0);

% Create input parser
p = inputParser;
addRequired(p, 'EEG');
addRequired(p, 'main_trigger', @iscell);
addRequired(p, 'backup_trigger', @iscell);
addRequired(p, 'epoch_length', @isnumeric);
addRequired(p, 'baseline_length', @isnumeric);
addRequired(p, 'rois', @iscell);
addParameter(p, 'SaveCSV', false, @islogical);
addParameter(p, 'outputDir', pwd, @isfolder);
parse(p, EEG, main_trigger, backup_trigger, ...
    epoch_length, baseline_length, rois, varargin{:});

% Convert events to user-friendly table
try
    [eventout, fields] = eeg_eventformat(EEG.event, 'array');
    eventtbl_raw = array2table(eventout, 'VariableNames', fields);
catch % empty fields can crash the eventformat function, so this is a failsafe
    [eventout, fields] = eeg_eventformat(EEG.event, 'struct');
    eventtbl_raw = struct2table(eventout);
    eventtbl_raw.latency = num2cell(eventtbl_raw.latency);
    eventtbl_raw.Condition = num2cell(eventtbl_raw.Condition);
end

% Recreate new event table only using relevant columns
eventtbl = table(eventtbl_raw.trial_type, eventtbl_raw.Condition, eventtbl_raw.latency, 'VariableNames', {'type','urcondition', 'latency'});
eventtbl_select = eventtbl(ismember(eventtbl.type, [main_trigger, backup_trigger]),:);

% revise EEG event structure with relevant variables
EEG.event = table2struct(eventtbl);

% Get counts
stimcounts = cell2table(tabulate(eventtbl_select{:,'type'}), 'VariableNames', {'type','count','percentage'});
findCount = @(T, type) sum(table2array(T(ismember(T.type, type), 'count')));

% Error check if photosensor and stimulus counts match
% TODO: Add action logger for logging invalid photosensor data
%       Will "lag" condition to align with photosensor if sensor is valid

num_main_trigger = findCount(stimcounts, main_trigger);
num_backup_trigger = findCount(stimcounts, backup_trigger);

if(isequal(num_main_trigger, num_backup_trigger))
    disp('Photo sensor data is valid.')
    valid_event = main_trigger;
    eventtbl_select.condition = [eventtbl_select.urcondition(2:end); NaN];
else
    disp('# of DINs does not equal # of stimuli.');
    valid_event = backup_trigger;
    eventtbl_select.condition = [eventtbl_select.urcondition(1:end)];
end

try
    photo_delay = meanPhotoLatencyDelay(eventtbl_select, main_trigger);
catch
    photo_delay = missing;
end

eventtbl_select = removevars(eventtbl_select, 'urcondition');
inevents =  eventtbl_select(ismember(eventtbl_select.type, valid_event),:);

EEG.event = table2struct(inevents);

% Create epoched data
% eventIdx = find(strcmpi({EEG.event.type}, valid_event));
epochEEG_tmp = pop_epoch(EEG, valid_event, epoch_length,  'epochinfo', 'yes');

% Narrow down events
epochEEG = pop_selectevent(epochEEG_tmp, 'latency','-.1 <= .1','deleteevents','on');

% Query raw event table
[eventout_epoch, fields_epoch] = eeg_eventformat(epochEEG.epoch, 'array',  {'type','latency','condition'});

% error checking for empty epochs
assert(~isempty(eventout_epoch), 'No epochs available - check event codes or timeunit.')

% Verify event conversion with table output
eventtbl_epoch = array2table(eventout_epoch, 'VariableNames', fields_epoch);

% baseline correction
epochEEG_bl = pop_rmbase(epochEEG, baseline_length);

outEEG = epochEEG_bl;

% Save output as a CSV file
if p.Results.SaveCSV
    filename = [p.Results.outputDir, filesep EEG.filename(1:end-4) '_epoch_table.csv'];
    writetable(eventtbl_epoch, filename);
end

% Define the data as a cell array of structures
info = {
    struct('Variable', 'function', ...
    'Type', 'char', ...
    'Description', mfilename), ...
    struct('Variable', 'photo_delay', ...
    'Type', 'numeric', ...
    'Description', 'Mean latency delay of photo vs. stimulus event'), ...
    struct('Variable', 'eventtbl_epoch', ...
    'Type', 'table', ...
    'Description', 'Post-epoch table of events'), ...
    struct('Variable', 'filename', ...
    'Type', 'char', ...
    'Description', 'input filename'), ...
    struct('Variable', 'mean_erp', ...
    'Type', 'numeric', ...
    'Description', 'mean erp array') ...
    };

% Convert the cell array of structures to a structure array
info = [info{:}];

% Convert the structure array to a table
extra = [];
extra.info = struct2table(info);
extra.filename = EEG.filename;
extra.eventtbl_epoch = eventtbl_epoch;
extra.photo_delay = photo_delay;

% calculate ROI ERP mean, if no ROI default E70
erpEEG = pop_select(epochEEG_bl, 'channel', rois);
extra.mean_erp = mean(mean(erpEEG.data(:,:,:),3),1);

% save results to SRT
outEEG.vhtp.(mfilename) = extra;

end

function mean_latency = meanPhotoLatencyDelay(eventTable, photo_event)
% MEANPHOTOLATENCYDELAY Computes the average latency delay between a photo
% event and the preceding event in an event table.
%
%   mean_latency = meanPhotoLatencyDelay(eventTable, photo_event) computes
%   the average latency delay between the specified photo event and the
%   preceding event in the given event table.
%
%   Inputs:
%   -------
%   eventTable : table
%       A table containing event data. The table should have at least two
%       columns: 'type', which contains the type of each event, and
%       'latency', which contains the latency of each event in milliseconds.
%   photo_event : char
%       The type of photo event to compute the latency delay for.
%
%   Outputs:
%   --------
%   mean_latency : double
%       The average latency delay in milliseconds between the specified
%       photo event and the preceding event in the table.
%
%   Example:
%   --------
%   % Load an example event table
%   load example_event_table.mat
%
%   % Compute the mean latency delay for the 'photo' event
%   mean_latency = meanPhotoLatencyDelay(eventTable, 'photo');
%
%   % Display the result
%   fprintf('Mean latency delay for photo event: %.2f ms\n', mean_latency);

    % Extract the relevant data from the table
    event = eventTable.type;
    latency = cell2mat(eventTable.latency);

    % Find the indices of the photo event in the table
    photo_indices = find(strcmp(photo_event, event));

    % Find the indices of the preceding events
    preceding_indices = photo_indices - 1;

    % Only keep the indices that are valid (i.e., not negative)
    valid_indices = preceding_indices > 0;

    % Compute the latency delays between the photo event and the preceding events
    delay = latency(photo_indices(valid_indices)) - latency(preceding_indices(valid_indices));

    % Compute the average latency delay
    mean_latency = mean(delay, 'omitnan');
end
