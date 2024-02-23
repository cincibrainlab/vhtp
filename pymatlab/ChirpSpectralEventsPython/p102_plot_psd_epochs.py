# This script reads in the .set files from the Chirp dataset and plots 
# the power spectral density (PSD) of the raw data.

import os
import mne
import matplotlib.pyplot as plt

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
fig, ax = plt.subplots(figsize=(8,6))  # Make the plot square by setting equal width and height
raw.plot_psd(ax=ax, area_mode='range', fmin=0, fmax=80, show=False, average=False)
plt.show()

fig, ax = plt.subplots(figsize=(8,6))  # Make the plot square by setting equal width and height
raw.plot_psd(ax=ax, area_mode='range', fmin=0, fmax=80, show=False, average=False)
#plt.show()

# Use MNE to browse channel data interactively
raw.plot(duration=5, n_channels=10, scalings='auto')
#plt.show()

# Create epochs from the raw data
epochs = mne.make_fixed_length_epochs(raw, duration=points_per_trial/raw.info['sfreq'], preload=True)

# Plot ERP for the epochs
evoked = epochs.average()
evoked.plot(picks=[0], time_unit='s')

# Plot image of the epochs
event_related_plot = epochs.plot_image(picks=[0])