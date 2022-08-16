% ========================================================================
% $filename - dynamically created from util_htpNewAnalysisTemplate
% $creation_date
% ========================================================================
% VHTP Analysis Template 1.0 (with Helper Code Generators)
% Tips:
% * Use "Run Section" or "Run" to activate inline functions
% * Use code helpers to paste
% ========================================================================

%% Helper Functions -------------------------------------------------------
[note, codegen_pickdir, codegen_details, ...
    add_path_without_subfolders, ...
    add_path_with_subfolders, ...
    is_interactive] = load_helper_functions();
note('Starting analysis template.')
note('Loading helper functions (see comments).')
%  1. note - usage: note( string ); display 'string' to screen
%  2. pickdir - usage: pickdir(); select folder and copy to clipboard
%  3. projcode - usage: projcode(); enter details and paste code
%  4. add_path_without_subfolders - usage: add_path_without_subfolders( path )
%  5. add_path_with_subfolders - usage: add_path_with_subfolders( path )
%  6. is_interactive - MATLAB mode - sections or running whole script true/false

%% 1. ADD DATASET DETAILS ------------------------------------------------|
%  Run Section, then enter details in GUI, and paste code below.
% try 
%     if is_interactive(), codegen_details(); end 
% catch
% end

%  Paste results from codegen_details() 
% start:
	project_name	= '$project_name';
	author_name		= '$author_name';
	description		= '$description';
% end

note(sprintf('Proj. Name: %s\n\t\t\t Author: %s\n\t\t\t Description: %s', ...
     project_name, author_name, description));

%% 2. ADD TOOLBOX PATHS --------------------------------------------------|
% Run section multiple times to copy and paste path name below
% if is_interactive(), codegen_pickdir(); end

eeglab_dir     = '$eeglab_dir'; % https://tinyurl.com/59h6ksjs
brainstorm_dir = '$brainstorm_dir'; % https://tinyurl.com/2f3ek5yd
vhtp_dir       = '$vhtp_dir'; % https://tinyurl.com/3fcbexp8

% user defined paths
se_dir          = '$se_dir';
braph_dir       = '$braph_dir';
bct_dir         = '$bct_dir';

%% Load toolkits - reset matlab paths
restoredefaultpath;  
add_path_without_subfolders( eeglab_dir );
add_path_without_subfolders( brainstorm_dir );
add_path_with_subfolders( vhtp_dir );
add_path_with_subfolders( braph_dir );
add_path_with_subfolders( bct_dir );

try eeglab nogui; catch, error('Check EEGLAB install'); end
try brainstorm nogui; catch, error('Check Brainstorm install'); end
note('Loaded EEG Toolkits.');

%% 3. UPDATE DATASET PATHS AND TOOLBOXES ---------------------------------|
% Run section multiple times to copy and paste path name below
% if is_interactive(), codegen_pickdir(); end

% Project Directories
set_dir      = fullfile('$set_dir');  % *.SET input to process; subfolders OK
temp_dir     = fullfile('$temp_dir'); % empty temporary folder for large output
results_dir  = fullfile('$results_dir'); % folder for final outputs

%% 3. VALIDATE AND SCAN DIRECTORY AND GENERATE FILELIST ------------------|
input_filelist = util_htpDirListing(set_dir, 'ext', '.set', 'subdirOn', true );
if isempty(input_filelist), error('No files found'), else
    note(sprintf('Scanning %s\n\t%d Files loaded.\n\tTemp Dir: %s\n\tResults Dir: %s', ...
        set_dir, height(input_filelist),temp_dir,results_dir)); 
end

%% RUN ANALYSIS LOOPS -----------------------------------------------------|
number_of_input_files = height( input_filelist );

% Main analysis loop
waitf = progress_bar('create');
for i = 1 : number_of_input_files

    % active SET file
    current_set = input_filelist.filename{i};
    current_subfolder = input_filelist.filepath{i};

    % load EEG (EEGLAB)
    EEG = pop_loadset('filename', current_set, ...
        'filepath', current_subfolder);

    EEG.data = double(EEG.data);
$select_trials
$loopcode
    % update progress bar
    progress_bar('update',waitf, i, number_of_input_files)

end
close(waitf); % waitbar

%% SUBSEQUENT ANALYSIS LOOPS
%  Description Here

% Test for Various User Function Options
assert(calc_sum(5,6) == 11, 'User function invalid.')
calc_sum_handle = get_calc_sum_handle();
assert(calc_sum_handle(5,6) == 11, 'User function invalid.')

%% CREATE R FILES FOR STATISTICS -----------------------------------------|
util_htpCreateRFile('makeProject', results_dir);
util_htpCreateRFile('makeImport', results_dir, 'useParquet', true, 'functionname', 'eeg_htpCalcRestPower')
util_htpCreateRFile('makeImport', results_dir, 'useParquet', true, 'functionname', 'eeg_htpGraphPhaseBcm')

%% GENERATING SUMMARY RESULT TABLES
%  vHTP functions create individual CSV or Parquet Files.
%  Use the generated R code to import and wrangle (filter, select, pivot).
%  Resave merged dataset for further analysis (or import back to MATLAB)

%  User created datasets:
%  Example 1: groupRestingPower.csv (source: eeg_htpCalcRestPower.R)

%% USER DEFINED FUNCTIONS ------------------------------------------------|
%  to replicability can list external or user functions here
%  Example 1: simple comment refering to external function
%  External_Function_Name:  Description
%  Example 2: define inline function (use run section or script)
function example_result = calc_sum( num1, num2)
example_result = num1 + num2;
end
% Example 3: get handle to any external function
function f_handle = get_calc_sum_handle( )
f_handle = @calc_sum;
end

%% HELPER FUNCTIONS =======================================================
%  Support code only
function [ note, pickdir, projcode, add_path_without_subfolders, ...
    add_path_with_subfolders, is_interactive] = load_helper_functions()

    note        = @(msg) fprintf('%s: %s\n', 'htpAnalysis', msg );
    pickdir     = @() clipboard('copy', uigetdir([],'Choose a directory to copy to clipboard or hit cancel.'));
    projcode    = @create_project_details;
    add_path_without_subfolders = @( filepath ) addpath(fullfile( filepath ));
    add_path_with_subfolders    = @( filepath ) addpath(genpath(fullfile( filepath )));
    is_interactive = @check_interactive;

end

function create_project_details()
    proj_details = inputdlg({'Project Name:','Author Name:','Description'}, ...
        'Paste from Clipboard after Entry', [1 40; 1 40; 4 40]);
    detail_code = '\tproject_name\t=''%s'';\n\tauthor_name\t\t=''%s'';\n\tdescription\t\t=''%s'';\n';
    clipboard('copy', sprintf(detail_code, ...
        proj_details{1}, proj_details{2},proj_details{3}));
end

function true_or_false = check_interactive()
    true_or_false = false;
    if isempty(mfilename) || contains(mfilename,'LiveEditorEvaluation') % only runs if in interactive mode
        true_or_false = true;
    end
end

function waitbar_fig = progress_bar( action, f, current, total )
    switch action
        case 'create'
            waitbar_fig = waitbar(0,'Dataset Progress');        
        case 'update'
            waitbar( current/total, f, sprintf('Progress: %1.0f of %1.0f', current, total ));
    end
end




