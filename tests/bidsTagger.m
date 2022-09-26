% BIDS Tagger Unit Test File

% construct new bidsTaggerClass

bt = bidsTaggerClass();



%% File Handling Tests

% valid file
bt.loadParameterFile( "bids_parameters/bids_Resting.m");

% invalid file
bt.loadParameterFile( "bids_parameters/bids_Resting_error.m");

% file not found
bt.loadParameterFile( "bids_parameters/bids_Resting_wrong_name.m");

%%  Directory Handling
bt = bidsTaggerClass();

% load directory of set files (use GUI)
% bt.loadSetFiles;

% load parameters
bt.loadParameterFile( "bids_parameters/bids_Resting.m" );

% load directory of set files (use pathname)
bt.loadSetFiles('C:\srv\RAWDATA\P1_70FXS_71_TDC\S04_POSTCOMP\Group2');

% display SET files
bt.getSetTable();

% create UI for entry
% bt.createUIfromParams;

