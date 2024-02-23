# Execute another script and access its variables
import os, sys
sys.path.append('/Users/ernie/Documents/GitHub/vhtp/pymatlab/ChirpSpectralEventsPython')
from p100_load_chirp_data import *
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
from joblib import Parallel, delayed
import pandas as pd

chan_data_full = epoch_and_extract_eeg_data(raw, points_per_trial, channel_index=None, num_trials=no_of_trials)[0]
spec_events_df = pd.DataFrame()
def process_channel(channel_no, chan_data_full, points_per_trial, no_of_trials, freqs, samp_freq, times, event_band, thresh_FOM, filename):
    # Extract EEG data for the specified channel
    chan_data = chan_data_full[:, channel_no, :]
    print(f"Processing Channel {channel_no}: Data Shape - {chan_data.shape}")
    
    # Perform time-frequency representation (TFR) analysis
    tfrs = se.tfr(chan_data, freqs, samp_freq)
    
    # Identify spectral events within the specified frequency band and threshold
    spec_events = se.find_events(tfr=tfrs, times=times, freqs=freqs, event_band=event_band, threshold_FOM=thresh_FOM)
    
    # Structure spectral events data into a DataFrame
    spec_events_df = pd.DataFrame([event for sublist in spec_events for event in sublist])
    spec_events_df['Filename'] = filename
    spec_events_df['Channel_Number'] = channel_no
    
    return spec_events_df

# Parallelize the processing of each EEG channel
processed_channels = Parallel(n_jobs=-1)(delayed(process_channel)(channel_no, chan_data_full, points_per_trial, no_of_trials, freqs, samp_freq, times, event_band, thresh_FOM, filename) for channel_no in range(0,no_of_channels))

# Combine the results into a single DataFrame
all_channels_spec_events_df = pd.concat(processed_channels, ignore_index=True)
print(all_channels_spec_events_df.shape)

# Save the compiled spectral events data to a CSV file
all_channels_spec_events_df.to_csv('all_channels_spectral_events_parallel.csv', index=False)
