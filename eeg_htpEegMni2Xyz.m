function EEG = eeg_htpEegMni2Xyz( EEG )
% Description: Converts MNI file to XYZ file(useful for source files)
% ShortTitle: Convert MNI to XYZ
% Category: Utility
% Tags:
%
% function is not generalized, specific to DK atlas from brainstorm
%
%% Syntax:
%   EEG = eeg_htpEegMni2Xyz( EEG )
%
%% Required Inputs:
%   EEG [struct]           - EEGLAB Structure
%
%% Function Specific Inputs:
%
%% Outputs:
%   EEG [struct] - output structure with updated dataset
%
%% Disclaimer:
%   Part of the Cincinnati Visual High Throughput EEG Pipeline
%   
%   Please see http://github.com/cincibrainlab
%
%% Contact:
%   kyle.cullion@cchmc.org

mnit = readtable("/chanfiles/DK_atlas-68_dict.csv");
% [mnit.x, mnit.y, mnit.z] = mni2orFROMxyz(mnit.mni_avg_x,mnit.mni_avg_y, mnit.mni_avg_z);

chanlocs = EEG.chanlocs;

for i = 1 : numel(chanlocs)
    label = chanlocs(i).labels;
    labelidx = find(strcmp(label, mnit.labelclean));
    chanlocs(labelidx).X = mnit.mni_avg_x(labelidx);
    chanlocs(labelidx).Y = mnit.mni_avg_y(labelidx);
    chanlocs(labelidx).Z = mnit.mni_avg_z(labelidx);
end

EEG.chanlocs = chanlocs;

end