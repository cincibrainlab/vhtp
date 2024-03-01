# ==============================================================================
# Bandpower Calculation for Continuous EEG Data
# ==============================================================================
# This script calculates the absolute and relative bandpower of EEG data from a .set file.
# It involves reading EEG data, defining frequency bands, and calculating bandpower using YASA.
# The results are saved to a CSV file for further analysis.
# ==============================================================================

# Main Functions Used:
# 1. mne.io.read_raw_eeglab - Reads EEG data from .set files.
# 2. yasa.bandpower - Calculates the bandpower for predefined frequency bands.
# 3. pd.concat - Concatenates pandas DataFrames.
# 4. np.round - Rounds the values in an array to the given number of decimals.
# 5. DataFrame.reset_index - Resets the index of the DataFrame, and use the default one.
# 6. DataFrame.insert - Inserts a column into the DataFrame.
# 7. DataFrame.to_csv - Writes the DataFrame to a CSV file.


import mne
import yasa
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
import os
import pandas as pd

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

# Define frequency bands
bands = [(2, 3.5, 'Delta'), (3.5, 7, 'Theta'), (7.5, 12.5, 'Alpha'), (7.5, 10.5, 'Alpha1'), 
         (10.5, 12.5, 'Alpha2'), (15, 30, 'Beta'), (30, 55, 'Gamma1'), (65, 80, 'Gamma2')]

powtable_abs = yasa.bandpower(raw, sf=sf, bandpass=True, relative=False, bands=bands)
powtable_rel = yasa.bandpower(raw, sf=sf, bandpass=True, relative=True, bands=bands)
powtable_combined = pd.concat([powtable_abs, powtable_rel], axis=0)
powtable_combined = np.round(powtable_combined, 6)  # Round the bandpower values

# Reset index to turn MultiIndex into columns for a flat format
powtable_combined.reset_index(inplace=True)
powtable_combined.insert(0, 'filename', file_basename)

# Write to CSV
csv_filename = os.path.basename(__file__).replace('.py','.csv')
powtable_combined.to_csv(csv_filename)
