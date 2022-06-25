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

%  1. note - usage: note( string ); display 'string' to screen
%  2. pickdir - usage: pickdir(); select folder and copy to clipboard
%  3. projcode - usage: projcode(); enter details and paste code
%  4. add_path_without_subfolders - usage: add_path_without_subfolders( path )
%  5. add_path_with_subfolders - usage: add_path_with_subfolders( path )
%  6. is_interactive - MATLAB mode - sections or running whole script true/false

%% 1. COMPLETE DATASET INFORMATION ----
%  Run section, enter details, and paste below
if is_interactive()    
    codegen_details();
else
    % Complete template or use Detail Helper and paste from clipboard
	project_name	='Test Data';
	author_name		='Ernie';
	description		='Comments here';
end
note(sprintf('Proj. Name: %s\n\t\t\t Author: %s\n\t\t\t Description: %s', project_name, author_name, description));

%% 2. UPDATE DATASET PATHS AND TOOLBOXES
% Run section multiple times to copy and paste dir below
if is_interactive(), codegen_pickdir; end

% Project Directories
set_dir      = fullfile('C:\srv\RAWDATA\MEA');  % *.SET input to process; subfolders OK
temp_dir     = fullfile('C:\srv\Analysis\MEA\tempfiles\'); % empty temporary folder for large output
results_dir  = fullfile('C:\srv\Analysis\MEA\analysis\'); % folder for final outputs

%%  Load filelist (generate error if no files found)
input_filelist = util_htpDirListing(set_dir, 'ext', '.set', 'subdirOn', true );

if isempty(input_filelist), error('No files found')
else
    note(sprintf('Searching %s', set_dir));
    note(sprintf('%d Files loaded.', height(input_filelist))); 
    note(sprintf('Temp Dir: %s', temp_dir,results_dir));
    note(sprintf('Results Dir: %s', temp_dir,results_dir));
end

%% Toolbox Directories
eeglab_dir     = 'C:\srv\TOOLKITS\eeglab'; % EEGLAB installation
brainstorm_dir = 'C:\srv\TOOLKITS\brainstorm3'; % Brainstorm3 installation
vhtp_dir       = 'C:\srv\vhtp'; % vHTP installation

% Load toolkits - reset matlab paths
restoredefaultpath;  
add_path_without_subfolders( eeglab_dir );
add_path_without_subfolders( brainstorm_dir );
add_path_without_subfolders( vhtp_dir );

try eeglab nogui; catch, error('Check EEGLAB install'); end
try brainstorm nogui; catch, error('Check Brainstorm install'); end
note('Loaded EEG Toolkits.');

%% RUN ANALYSIS LOOPS
number_of_input_files = height( input_filelist );
waitf = progress_bar('create');

for i = 1 : number_of_input_files

    % active SET file
    current_set = input_filelist.filename{i};
    current_subfolder = input_filelist.filepath{i};

    % load EEG (EEGLAB)
    EEG = pop_loadset('filename', current_set, ...
        'filepath', current_subfolder);

    % begin function chain, i.e. EEG in and EEG out
    EEG = eeg_htpCalcRestPower( EEG, 'gpuOn', true, 'outputdir', results_dir );

    % update progress bar
    progress_bar('update',waitf, i, number_of_input_files)

end

close(waitf); % waitbar

%%
create_r_project( fullfile( results_dir, [genvarname(project_name) '.Rproj'] ))


%% HELPER FUNCTIONS =======================================================

function [ note, pickdir, projcode, add_path_without_subfolders, ...
    add_path_with_subfolders, is_interactive] = load_helper_functions()

    note        = @(msg) fprintf('%s: %s\n', 'htpAnalysis', msg );
    pickdir     = @() clipboard('copy', uigetdir);
    projcode    = @create_project_details;
    add_path_without_subfolders = @( filepath ) addpath(fullfile( filepath ));
    add_path_with_subfolders    = @( filepath ) addpath(fullfile( filepath ));
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

function create_r_project( proj_file )
    % Create R Project in Results Directory
    fid = fopen( proj_file, 'wt' );
    fprintf(fid, "Version: 1.0\n\n" + ...
        "RestoreWorkspace: Default\n" + ...
        "SaveWorkspace: Default\n" + ...
        "AlwaysSaveHistory: Default\n\n" + ...
        "EnableCodeIndexing: Yes\n" + ...
        "UseSpacesForTab: Yes\n" + ...
        "NumSpacesForTab: 2\n" + ...
        "Encoding: UTF-8\n\n" + ...
        "RnwWeave: Sweave\n" + ...
        "LaTeX: pdfLaTeX\n");
    fclose(fid);
end



