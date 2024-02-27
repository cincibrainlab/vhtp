
import os
import mne

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
def epoch_and_extract_eeg_data(raw, points_per_trial, channel_index=None, num_trials=None):
    """
    Reshape the EEG data array to the form (n_channels, n_times, n_trials) using MNE, with an optional channel index and an option for a fixed number of trials.

    Parameters
    ----------
    raw : instance of Raw
        The raw data.
    points_per_trial : int
        The number of time points per trial.
    channel_index : int, optional
        The index of the channel to extract. If None, all channels are returned.
    num_trials : int, optional
        The number of trials to extract. If None, all trials are returned.

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
        if num_trials is not None:
            epoch_data = epoch_data[:num_trials]
    else:
        epoch_data = epochs.get_data()
        # If a fixed number of trials is specified, select only that number of trials
        if num_trials is not None:
            epoch_data = epoch_data[:num_trials]
    # Ensure the data is reshaped to (n_channels, n_times, n_trials)
    if channel_index is not None:
        assert epoch_data.shape[1] == points_per_trial, "Points per trial do not match expected value."
    return epoch_data, epochs

# Get a list of all .set files in the specified directory
set_files = get_set_files_list('/Users/ernie/Documents/ExampleData/Chirp')

# Define the number of channels and points per trial
no_of_channels = 68
points_per_trial = 1626
no_of_trials = 80

# Read the continuous .set file in the list
raw = read_eeglab_continuous(set_files[1])

# Extract EEG data from the raw data
epoch_data, epochs = epoch_and_extract_eeg_data(raw, points_per_trial, channel_index=0, num_trials=80)
print(epoch_data.shape) # trials, time points