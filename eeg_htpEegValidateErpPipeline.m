function EEG = eeg_htpEegValidateErpPipeline( EEG, varargin )
% Description: Validate Erp Paradigms
% Source Input
timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output
fprintf('%s: Processing %s (Size: %s)...\n', functionstamp, EEG.setname, num2str(size(EEG.data)));

% EEG inputs
defaultOutputDir = EEG.filepath;
defaultTag = [];
defaultMethod = 'none';

ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'outputdir', defaultOutputDir, @isfolder)
addParameter(ip, 'method', defaultMethod, @ischar);
addParameter(ip, 'tag', defaultTag, @ischar);

parse(ip, EEG, varargin{:});

EEG = eeg_htpEegIcaEeglab(EEG)

% Cleaning Routines
switch ip.Results.method
    case 'asr'
    case 'wt'
    otherwise
        fprintf('Cleaning Methods Available\n');
        fprintf('\t''wt'' wavelet thresholding\n');
        fprintf('\t''asr'' artifact subspace reconstruction\n');
        % list methods
end
pop_runica
% Epoching (Optional)
EEG_Post = eeg_emptyset;

% Create output filename
[~, outputfile, ~] = fileparts(EEG.filename);
post_outputfile = fullfile([outputfile '_' ip.Results.method '.set']);
post_setname = post_outputfile;

% Set Tagging
EEG_Post.setname  = post_setname;
EEG_Post.filename = post_outputfile;
EEG_Post.filepath = ip.Results.outputdir;

% Save dataset
pop_saveset(EEG_Post, ...
    'filename', EEG_Post.filename, ...
    'filepath', EEG_Post.filepath );

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});

qi_temp = struct2table(ip.Results, 'AsArray',true);
qi_table = [qi_table qi_temp];

end