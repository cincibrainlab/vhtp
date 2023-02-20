function EEG = eeg_htpMiscEvent2Csv( EEG, varargin)
% Description: ?? Does this ouput a table of all the events that occured on
% a Set file and a converted SET table ?
% ShortTitle: Misc Events to CSV
% Category: ??
% Tags: 
%
%% Syntax:
%   EEG = eeg_htpMiscEvent2Csv( EEG, varargin)
%
%% Required Inputs:
%   EEG [struct]           - EEGLAB Structure
%
%% Function Specific Inputs:
%       'outputdir' - output directory to save files
%
%% Outputs:
%     EEG [struct]         - Updated EEGLAB structure
%
%% Disclaimer:
%   Part of the Cincinnati Visual High Throughput EEG Pipeline
%   
%   Please see http://github.com/cincibrainlab
%
%% Contact:
%   kyle.cullion@cchmc.org

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

% Default inputs
defaultOutputDir = tempdir;

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'outputdir', defaultOutputDir, @isfolder);

parse(ip, EEG, varargin{:});

% create filename

% File Management (create subfolder with function name)
[~, basename, ~] = fileparts(EEG.filename);
analysis_outputdir =  fullfile(ip.Results.outputdir, mfilename);
if ~exist("analysis_outputdir", "dir")
    mkdir(analysis_outputdir);
end
event_file   = fullfile(analysis_outputdir, ...
    [basename '_event2csv.csv']);

% verify EEG has an event field

assert(isstruct(EEG.event), 'EEG Event Structure Not Present.');

event_table = struct2table( EEG.event );
event_table_dim = size(event_table);

% verify Event structure can be converted to table

% add specific identifier columns to table
qi_table = cell2table({EEG.setname, EEG.filename, functionstamp, timestamp, ...
    EEG.trials, EEG.pnts, EEG.srate, EEG.xmin, EEG.xmax}, ...
    'VariableNames', {'eegid', 'filename', 'scriptname', 'timestamp', ...
    'trials', 'points', 'srate', 'xmin', 'xmax'});

gencol = @( x ) repmat(x, event_table_dim(1),1);

final_table = [gencol({EEG.setname}) gencol({EEG.filename}) event_table];

% save CSV file
writetable(final_table, event_file);

end