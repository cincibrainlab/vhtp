import mne
import yasa
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
import os
import pandas as pd


sns.set(style='white', font_scale=1.2)

def get_set_files_list(path):
    """
    Get a list of all .set files in the specified directory.

    Parameters
    ----------
    path : str
        The path to the directory containing .set files.

    Returns
    -------
    list
        A list of paths to .set files found in the specified directory.
    """
    set_files = [os.path.join(path, f) for f in os.listdir(path) if f.endswith('.set')]
    return set_files
def read_eeglab_continuous(file_path):
    raw = mne.io.read_raw_eeglab(file_path, preload=True)
    return raw
def epoch_and_extract_eeg_data(raw, points_per_trial, channel_index=None):
    """
    Reshape the EEG data array to the form (n_channels, n_times, n_trials) using MNE, with an optional channel index.

    Parameters
    ----------
    raw : instance of Raw
        The raw data.
    points_per_trial : int
        The number of time points per trial.
    channel_index : int, optional
        The index of the channel to extract. If None, all channels are returned.

    Returns
    -------
    epoch_data : ndarray
        The reshaped EEG data array.
    """
    # Create epochs from the raw data (n_epochs, n_sensors, n_times)
    epochs = mne.make_fixed_length_epochs(raw, duration=points_per_trial/raw.info['sfreq'], preload=True)
    # Get the data from epochs
    if channel_index is not None:
        epoch_data = epochs.get_data(picks=[channel_index]).squeeze()
    else:
        epoch_data = epochs.get_data()
    # Ensure the data is reshaped to (n_channels, n_times, n_trials)
    assert epoch_data.shape[0] == len(epochs), "Number of trials does not match expected value."
    if channel_index is not None:
        assert epoch_data.shape[1] == points_per_trial, "Points per trial do not match expected value."
    return epoch_data, epochs

# Get a list of all .set files in the specified directory
set_files = get_set_files_list('/Users/ernie/Documents/ExampleData/Chirp')

# Define the number of channels and points per trial
no_of_channels = 68
points_per_trial = 1626
no_of_trials = 80

# Read the first .set file in the list
raw = read_eeglab_continuous(set_files[1])
sf = raw.info['sfreq']
chans = raw.info['ch_names']

# Define frequency bands
bands = [(2, 3.5, 'Delta'), (3.5, 7, 'Theta'), (7.5, 12.5, 'Alpha'), (7.5, 10.5, 'Alpha1'), 
         (10.5, 12.5, 'Alpha2'), (15, 30, 'Beta'), (30, 55, 'Gamma1'), (65, 80, 'Gamma2')]


powtable_abs = yasa.bandpower(raw, sf=sf, bandpass=True, relative=False, bands=bands)
powtable_rel = yasa.bandpower(raw, sf=sf, bandpass=True, relative=True, bands=bands)
powtable_combined = pd.concat([powtable_abs, powtable_rel], axis=0)
powtable_combined = np.round(powtable_combined, 6)  # Round the bandpower values
# Reset index to turn MultiIndex into columns for a flat format
powtable_combined.reset_index(inplace=True)

powtable_combined.insert(0, 'filename', os.path.basename(set_files[1]))
# Write to CSV
powtable_combined.to_csv('bandpower.csv')