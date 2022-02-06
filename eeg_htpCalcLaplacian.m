function EEG = eeg_htpCalcLaplacian( EEG )
% units microvolts per square mm

% compute inter-electrode distances
interelectrodedist=zeros(EEG.nbchan);
for chani=1:EEG.nbchan
    for chanj=chani+1:EEG.nbchan
        interelectrodedist(chani,chanj) = sqrt( (EEG.chanlocs(chani).X-EEG.chanlocs(chanj).X)^2 + (EEG.chanlocs(chani).Y-EEG.chanlocs(chanj).Y)^2 + (EEG.chanlocs(chani).Z-EEG.chanlocs(chanj).Z)^2);
    end
end

valid_gridpoints = find(interelectrodedist);

% extract XYZ coordinates from EEG structure
X = [EEG.chanlocs.X];
Y = [EEG.chanlocs.Y];
Z = [EEG.chanlocs.Z];

[EEG.data,G,H] = laplacian_perrinX(EEG.data,X,Y,Z);

end