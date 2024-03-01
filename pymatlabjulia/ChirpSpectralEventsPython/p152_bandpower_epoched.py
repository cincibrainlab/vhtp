# ==============================================================================
# Bandpower Calculation by Epoch for EEG Data
# ==============================================================================
# This script calculates the bandpower of EEG data for predefined frequency bands
# across different epochs and channels. The results are saved to a CSV file for
# further analysis.
#
# Main Functions Used:
# 1. mne.io.read_raw_eeglab - Reads EEG data from .set files.
# 2. yasa.sliding_window - Creates sliding windows for the data.
# 3. scipy.signal.welch - Calculates the Power Spectral Density (PSD) using Welch's method.
# 4. yasa.bandpower_from_psd_ndarray - Calculates the bandpower from the PSD array.
# 5. numpy.round - Rounds the values in an array to the given number of decimals.
# 6. pandas.DataFrame - Creates a DataFrame for storing the results.
# 7. DataFrame.to_csv - Writes the DataFrame to a CSV file.
# ==============================================================================

# Import necessary libraries
import mne  # For EEG data manipulation
import yasa  # For spectral analysis
import numpy as np  # For numerical operations
import seaborn as sns  # For plotting
import matplotlib.pyplot as plt  # For plotting
import os  # For file path operations
import pandas as pd  # For data manipulation
from scipy.signal import welch  # For PSD calculation

# Set seaborn style for plots
sns.set(style='white', font_scale=1.2)


# ==============================================================================
# File Loading Stage
# ==============================================================================
# Brief on MNE file types: raw, epoched, evoked
# Raw: Continuous EEG data, unsegmented.
# Epoched: Data segmented into trials/events.
# Evoked: Averaged data over trials for specific conditions.

chirp_file = '/Users/ernie/Documents/ExampleData/Chirp/D0179_chirp-ST_postcomp_MN_EEG_Constr_2018.set'

# Extract the basename of the file for reporting and logging
file_basename = os.path.basename(chirp_file)
print(f"Processing file: {file_basename}")

# Read EEG data from the first .set file in the list
raw = mne.io.read_raw_eeglab(chirp_file, preload=True)

# Extract sampling frequency and channel names from the data
sf = raw.info['sfreq']  # Sampling frequency (Hz)
chans = raw.info['ch_names']  # List of EEG channel names

# Define EEG data parameters
no_of_channels = len(raw.info['ch_names'])  # Total number of EEG channels
points_per_trial = 1626  # Number of time points per trial
no_of_trials = 80  # Total number of trials

epochs = mne.make_fixed_length_epochs(raw, duration=points_per_trial/raw.info['sfreq'], preload=True)
epochs = epochs[:no_of_trials]

evoked = epochs.average()
# ==============================================================================

# ==============================================================================
# YASA (Yet Another Spindle Algorithm) Package Utilization
# ==============================================================================
# This section of the script leverages the YASA package to perform spectral analysis
# on EEG data. YASA is a comprehensive library designed for sleep data analysis, 
# but its functions for calculating power spectral density (PSD) and bandpower 
# are applicable to a wide range of EEG data analysis tasks. The following steps 
# include converting EEG data to microvolts, calculating sliding windows for PSD, 
# computing PSD using Welch's method, defining frequency bands of interest, and 
# calculating bandpower for these bands. The results are then structured into a 
# pandas DataFrame for easy manipulation and export to CSV for further analysis.
# ==============================================================================

# Get data in microvolts
data = raw.get_data(units="uV")

# Calculate the sliding window for PSD calculation
_, data = yasa.sliding_window(data, sf, window=points_per_trial/sf)

# Calculate the power spectral density (PSD) using Welch's method
win = int(1 * sf)  # Window size is set to 1 second
freqs, psd = welch(data, sf, nperseg=win, axis=-1) 

# Define frequency bands of interest
bands = [(2, 3.5, 'Delta'), (3.5, 7, 'Theta'), (7.5, 12.5, 'Alpha'), (7.5, 10.5, 'Alpha1'), 
         (10.5, 12.5, 'Alpha2'), (15, 30, 'Beta'), (30, 55, 'Gamma1'), (65, 80, 'Gamma2')]

# Calculate the bandpower on 3-D PSD array
bandpower = yasa.bandpower_from_psd_ndarray(psd, freqs, bands)
bandpower = np.round(bandpower,6)  # Round the bandpower values

# Create a multi-index for rows (epochs and channels)
epochs = range(bandpower.shape[1]) 
channels = range(bandpower.shape[2]) 
multi_index = pd.MultiIndex.from_product([channels, epochs], names=['Channel','Epoch'])

# Convert the 3D bandpower array to a 2D DataFrame for easier analysis and export
bandpower_flat = bandpower.reshape(bandpower.shape[0], -1).T  # Reshape to 2D
df_bandpower = pd.DataFrame(bandpower_flat, index=multi_index)

# Add band names as column names
df_bandpower.columns = [band[2] for band in bands]

# Reset index to turn MultiIndex into columns for a flat format
df_bandpower.reset_index(inplace=True)

# Map channel labels to the channel column
channel_labels = {idx: label for idx, label in enumerate(chans)}
df_bandpower['Channel'] = df_bandpower['Channel'].map(channel_labels)

# Offset epochs by +1 to reflect actual trials
df_bandpower['Epoch'] = df_bandpower['Epoch'] + 1

df_bandpower.insert(0, 'filename', file_basename)

# Optionally, save the DataFrame to a CSV file for further analysis
script_name = os.path.basename(__file__).replace('.py', '.csv')
df_bandpower.to_csv(script_name, index=False)
