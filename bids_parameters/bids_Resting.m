function PARAMS = bids_Resting()
    
    % general information for dataset_description.json file
    % -----------------------------------------------------
    PARAMS.ginfo.Name = '128 Lead Study';
    PARAMS.ginfo.ReferencesAndLinks = { "Nothing" };

    % participant column description for participants.json file
    % ---------------------------------------------------------
      PARAMS.pInfoDesc.gender.Description = 'sex of the participant';
      PARAMS.pInfoDesc.gender.Levels.M = 'male';
      PARAMS.pInfoDesc.gender.Levels.F = 'female';
      PARAMS.pInfoDesc.participant_id.Description = 'unique participant identifier';
      PARAMS.pInfoDesc.age.Description = 'age of the participant';
      PARAMS.pInfoDesc.age.Units       = 'years';

    % Content for README file
    % -----------------------
    PARAMS.README = sprintf( [ 'This is a test message for the readme document']);

    % Content for CHANGES file
    % ------------------------
    PARAMS.CHANGES = sprintf([ 'There have been no changes so far' ]);                    

    % List of script to run the experiment
    % ------------------------------------
    %code = { '/data/matlab/tracy_mw/run_mw_experiment6.m' mfilename('fullpath') };

    % Task information for xxxx-eeg.json file
    % ---------------------------------------
    PARAMS.tinfo.InstitutionAddress = '3333 Burnet Avenue, Cincinnati, Ohio 45229-3026';
    PARAMS.tinfo.InstitutionName = 'Cincinnati Childrens Hospital Medical Center';
    PARAMS.tinfo.InstitutionalDepartmentName = 'Fragile-X Center';
    PARAMS.tinfo.PowerLineFrequency = 60;
    PARAMS.tinfo.ManufacturersModelName = 'Manufacturer';
    PARAMS.tinfo.EEGChannelCount = 128;
    
    % channel location file
    % ---------------------
    PARAMS.chanlocs = 'chanfiles\GSN-HydroCel-129.sfp';
end
