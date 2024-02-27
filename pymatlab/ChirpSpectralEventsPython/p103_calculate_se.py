# Execute another script and access its variables
from p100_load_chirp_data import *
import os, sys
import numpy as np
import mne
from matplotlib import pyplot as plt

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

# Extract EEG data from the raw data
epochs = epoch_and_extract_eeg_data(raw, points_per_trial)[1]

# Extract the number of channels from the epochs object
channel_count = epochs.info['nchan']
print(f"Number of channels in epochs: {channel_count}")

# Define the number of channels and points per trial
no_of_channels = 68
points_per_trial = 1626
no_of_trials = 80

samp_freq = raw.info['sfreq']

# Extract EEG data from the raw data
channel_no = 1
chan_data = epoch_and_extract_eeg_data(raw, points_per_trial, channel_index=channel_no, num_trials=no_of_trials)[0]
print(f"Channel {channel_no} data shape: {chan_data.shape}")

# Spectral Events Parameters
freqs = np.arange(1, 60+1, 1)  # Hz
times = np.arange(points_per_trial) / samp_freq  # seconds
event_band = [7.5, 12.5]  # beta band (Hz)
thresh_FOM = 4.0  # factor-of-the-median threshold

# calculate TFR (trials by time)
tfrs = se.tfr(chan_data, freqs, samp_freq)

fig = se.plot_avg_spectrogram(tfr=tfrs, times=times, freqs=freqs,
                              event_band=event_band)
#plt.show()

# find spectral events!!
spec_events = se.find_events(tfr=tfrs, times=times, freqs=freqs,
                             event_band=event_band, threshold_FOM=thresh_FOM)
import pandas as pd

# Convert the nested list of dictionaries into a pandas DataFrame and add filename and channel number columns
filename = os.path.basename(set_files[1])
channel_number = channel_no
spec_events_df = pd.DataFrame([event for sublist in spec_events for event in sublist])
spec_events_df['Filename'] = filename
spec_events_df['Channel_Number'] = channel_number

# Display the first few rows of the DataFrame to verify
print(spec_events_df.head())

# Optionally, save the DataFrame to a CSV file
spec_events_df.to_csv('spectral_events.csv', index=False)
