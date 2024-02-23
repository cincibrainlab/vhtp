# Execute another script and access its variables
from p100_load_chirp_data import *
import os, sys

# Get a list of all .set files in the specified directory
set_files = get_set_files_list('/Users/ernie/Documents/ExampleData/Chirp')

# Define the number of channels and points per trial
no_of_channels = 68
points_per_trial = 1626
no_of_trials = 80

# Read the continuous .set file in the list
raw = read_eeglab_continuous(set_files[1])

# Extract EEG data from the raw data
epochs = epoch_and_extract_eeg_data(raw, points_per_trial)[1]

# Extract the number of channels from the epochs object
channel_count = epochs.info['nchan']
print(f"Number of channels in epochs: {channel_count}")

# Extract EEG data from the raw data
for i in range(channel_count-1):
    epoch_data = epoch_and_extract_eeg_data(raw, points_per_trial, channel_index=i)[0]
    print(f"Channel {i} data shape: {epoch_data.shape}")