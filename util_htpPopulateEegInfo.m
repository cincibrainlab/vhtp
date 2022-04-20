function [EEG, results] = util_htpPopulateEegInfo( EEG, varargin )
% util_htpPopulateEegInfo() - Extract EEG info to create detail row for
% reporting functions.
%
% Usage:
%    >> [ EEG, results ] = util_htpPopulateEegInfo( EEG, varargin )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
% Function Specific Inputs:
%     'outputdir' - 
%     'resave' - save EEG file with new info structure (default:
%     false). If same output directory will replace file.
%
% Outputs:
%     EEG       - EEGLAB Structure with modified .etc.htp field
%     results   - etc.htp results structure or customized
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

% Inputs: Function Specific
defaultOutputDir = EEG.filepath;
defaultResave = false;

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder)
addParameter(ip,'resave', defaultResave, @isfolder)
parse(ip,EEG,varargin{:});

outputdir = ip.Results.outputdir;

% base output file can be modified with strrep()
outputfile = fullfile(outputdir, EEG.filename);

% START: Signal Processing

% Populate EEG SET File
% Populate EEG SET structure
if ~isempty(EEG.event)
    has_events = true;
    event_codes = strjoin(unique({EEG.event.type}),'__');
else
    has_events = false;
    event_codes = [];
end

inforow_add = table();
inforow_add.setname         = EEG.setname;
inforow_add.set_nettype     = EEG.chaninfo.filename;
inforow_add.set_fmt         = '.set';
inforow_add.set_date        = timestamp;
inforow_add.set_nbchan      = EEG.nbchan;
inforow_add.set_trials      = EEG.trials;
inforow_add.set_pnts        = EEG.pnts;
inforow_add.set_srate       = EEG.srate;
inforow_add.set_xmin        = EEG.xmin;
inforow_add.set_xmax        = EEG.xmax;
inforow_add.set_ref         = EEG.ref;
inforow_add.set_has_events  = has_events;
inforow_add.set_no_events   = numel(EEG.event);
inforow_add.set_event_codes = event_codes;
inforow_add.set_filename    = EEG.filename;
inforow_add.set_filepath    = EEG.filepath;
inforow_add.set_subject     = EEG.subject;

EEG.vhtp.inforow_current = inforow_add;

if ip.Results.resave
    EEG = pop_saveset( EEG, 'filename', output_file );
end

% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});

% Outputs:
results = inforow_add;

end