# Execute another script and access its variables
from p100_load_chirp_data import *
import os, sys
import numpy as np
import mne
from matplotlib import pyplot as plt
import pandas as pd

# Add the path to the SpectralEvents package to the system path
sys.path.append('/Users/ernie/Documents/GitHub/SpectralEvents')
import spectralevents as se

# Get a list of all .set files in the specified directory
set_files = get_set_files_list('/Users/ernie/Documents/ExampleData/Chirp')

# Define the number of channels and points per trial
no_of_channels = 68
points_per_trial = 1626
no_of_trials = 80

# Read the continuous .set file in the list
raw = read_eeglab_continuous(set_files[1])
filename = os.path.basename(set_files[1])
samp_freq = raw.info['sfreq']

# Spectral Events Parameters
freqs = np.arange(1, 60+1, 1)  # Hz
times = np.arange(points_per_trial) / samp_freq  # seconds
event_band = [7.5, 12.5]  # beta band (Hz)
thresh_FOM = 4.0  # factor-of-the-median threshold

# Initialize an empty list to store spectral events data from all channels
all_channels_spec_events = []

# Loop through all channels to extract data and find spectral events
for channel_no in range(0,3): # range(1, no_of_channels + 1):
    # Extract EEG data for the current channel
    chan_data = epoch_and_extract_eeg_data(raw, points_per_trial, channel_index=channel_no, num_trials=no_of_trials)[0]
    print(f"Channel {channel_no} data shape: {chan_data.shape}")
    
    # Calculate TFR (trials by time) for the current channel
    tfrs = se.tfr(chan_data, freqs, samp_freq)
    
    # Find spectral events for the current channel
    spec_events = se.find_events(tfr=tfrs, times=times, freqs=freqs,
                                 event_band=event_band, threshold_FOM=thresh_FOM)
    
    # Convert the nested list of dictionaries into a pandas DataFrame for the current channel
    spec_events_df = pd.DataFrame([event for sublist in spec_events for event in sublist])
    spec_events_df['Filename'] = filename
    spec_events_df['Channel_Number'] = channel_no
    
    # Append the DataFrame to the list
    all_channels_spec_events.append(spec_events_df)

# Concatenate all DataFrames in the list into a single DataFrame
all_channels_spec_events_df = pd.concat(all_channels_spec_events, ignore_index=True)

# Optionally, save the concatenated DataFrame to a CSV file
all_channels_spec_events_df.to_csv('all_channels_spectral_events.csv', index=False)
