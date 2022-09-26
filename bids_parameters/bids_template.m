% Brain Imaging Data Structure (BIDS) v1.7.0 Template File
% MATLAB Parameter Template
% Version 0.5 Pre-release
% Authors: Kyle Cullion, Ernest Pedapati
% Source: http://github.com/cincibrainlab/vhtp
% Distributed as part of the Cincinnati Visual High-throughput Pipeline
%
% Summary: Convert EEGLAB SET Files to BIDS formatted folders and files.
%          Dependency on bids_export by Arno Delorme (EEGLAB).
%
% Description: This template preloads parameter values for use during
%     BIDS export. The template should be imported into the BIDS Tagger
%     application. Following import values can be modified if needed.
%     Specification are included from https://bids-specification.readthedocs.io/
%     This is a batch GUI wrapper for the bids_export function. Given the
%     effort and complexities in maintaining compliance with BIDS validation
%     we have opted to rely on the toolkit function for the actual conversion
%     which will be maintained by Arno and USCD. This package greatly increases
%     the ability to batch process and template for multi-center trials.
%
%  Pernet, C. R., Appelhoff, S., Gorgolewski, K.J., Flandin, G., Phillips, C., 
%  Delorme, A., Oostenveld, R. (2019). EEG-BIDS, an extension to the 
%  brain imaging data structure for electroencephalography. Scientific 
%  data, 6 (103). doi:10.1038/s41597-019-0104-8

function PARAMS = bids_template()
    
    % dataset_description.json
    % The file dataset_description.json is a JSON file describing the 
    % dataset. 
    % -----------------------------------------------------
    PARAMS.ginfo.Name = 'Paradigm';
    PARAMS.ginfo.taskName = 'ShortTaskName';   % task name for all datasets. No spaces/special chars.
    PARAMS.ginfo.ReferencesAndLinks = { "Reference 1" }; %[ "String 1", "String 2", "String 3" ];

    % participant column description for participants.json file
    % ---------------------------------------------------------
      PARAMS.pInfoDesc.gender.Description = 'Sex of the participant';
      PARAMS.pInfoDesc.gender.Levels.M = 'Male';
      PARAMS.pInfoDesc.gender.Levels.F = 'Female';
      PARAMS.pInfoDesc.participant_id.Description = 'Unique participant identifier';
      PARAMS.pInfoDesc.age.Description = 'Age of the participant';
      PARAMS.pInfoDesc.age.Units       = 'Years';

    % Content for README file
    % -----------------------
    PARAMS.README = sprintf( [ 'The README is usually the starting point for researchers using your data and serves as a guidepost for users of your data. A clear and informative README makes your data much more usable.']);

    % Content for CHANGES file
    % ------------------------
    PARAMS.CHANGES = sprintf([ 'Change log for dataset.' ]);                    

    % List of script to run the experiment
    % ------------------------------------
    %code = { '/data/matlab/tracy_mw/run_mw_experiment6.m' mfilename('fullpath') };

    % Task information for xxxx-eeg.json file
    % ---------------------------------------
    PARAMS.tinfo.TaskDescription = {"Longer description of the task."};
    PARAMS.tinfo.Instructions ='Text of the instructions given to participants before the recording. ';
    PARAMS.tinfo.InstitutionName = 'Site Identifier';
    PARAMS.tinfo.ManufacturersModelName = 'NetAmp 400';
    PARAMS.tinfo.Manufacturer = 'EGI';
    PARAMS.tinfo.DeviceSerialNumber = 'SN###########';
    
    % channel location file
    % ---------------------
    % PARAMS.chanlocs = 'chanfiles\GSN-HydroCel-129.sfp';
end
