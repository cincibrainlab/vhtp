function EEG = eeg_htpCalcLaplacian( EEG )


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



% create G and H matrices
[junk,G,H] = laplacian_perrinX(rand(size(X)),X,Y,Z,[],1e-6);

end