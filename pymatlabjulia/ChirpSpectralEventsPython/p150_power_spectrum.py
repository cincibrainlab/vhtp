# ==============================================================================
# EEG Data Power Spectral Density Analysis
# ==============================================================================
# This script performs Power Spectral Density (PSD) analysis on EEG data using
# both the Welch and Multitaper methods. It processes both continuous and epoched
# EEG data to extract relevant spectral features.
#
# Main Functions Used:
# 1. mne.io.read_raw_eeglab - Reads EEG data from .set files.
# 2. mne.make_fixed_length_epochs - Creates epochs from continuous EEG data.
# 3. raw.compute_psd - Computes PSD for continuous EEG data using the Welch method.
# 4. epochs.compute_psd - Computes PSD for epoched EEG data using the Welch method.
# ==============================================================================

import mne
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
# Power Spectral Density (PSD) Computation for EEG Data
# ==============================================================================
# This script section computes the Power Spectral Density (PSD) for both continuous
# and epoched EEG data using the Welch method. It begins by loading .set files from
# a specified directory, then reads the EEG data, creates epochs, and finally computes
# the PSD for both continuous and epoched data. Output is to CSV table.

# Compute PSD for the continuous EEG data using the Welch method
psd_cont = raw.compute_psd(method="welch",  fmin=.5, fmax=80, picks="eeg")  # PSD for continuous data
psd_cont.shape  # Shape of the PSD array for continuous data

# Compute PSD for the epoched EEG data using the Welch method
psd_epoch = epochs.compute_psd(method="welch",  fmin=.5, fmax=80, picks="eeg")  # PSD for epoched data
psd_epoch.shape  # Shape of the PSD array for epoched data


# ==============================================================================
# Gamma Band Power Spectral Density Calculation using Multitaper Method
# ==============================================================================
# For the analysis of continuous EEG data, we employ the Multitaper method to calculate the Power Spectral Density (PSD)
# within the gamma frequency band (30-80 Hz). The choice of the Multitaper method is motivated by its ability to provide
# a more accurate and reliable estimate of the PSD. This is achieved through the utilization of multiple tapering windows,
# which, in turn, allows for the averaging of spectra from these windows. Such an approach is particularly advantageous
# for continuous data series, as it enables the extraction of a denser frequency spectrum. Consequently, the Multitaper
# method is superior in revealing a broader range of frequencies within the gamma band, as opposed to the Welch method,
# especially in the context of unepoched (longer) data series.
psd_mt_cont = raw.compute_psd(method="multitaper",  fmin=30, fmax=80, picks="eeg")  # Calculating PSD for continuous data within the gamma band
psd_mt_cont.shape  # Shape of the PSD array for continuous data

# Similarly, for the epoched EEG data, we utilize the Multitaper method to calculate the PSD within the gamma frequency band.
psd_mt_epoch = epochs.compute_psd(method="multitaper",  fmin=30, fmax=80, picks="eeg")  # Calculating PSD for epoched data within the gamma band
psd_mt_epoch.shape  # Shape of the PSD array for epoched data


# ==================================================================================
# Conversion of Power Spectral Density (PSD) Data to DataFrames and Data Aggregation
# ==================================================================================
# This section of the code is responsible for converting the PSD data obtained from both continuous
# and epoched EEG data, using both Welch and Multitaper methods, into pandas DataFrames. 
# It then adds metadata columns to each DataFrame to specify the data source (Continuous or Epoched),
# the method used (Welch or Multitaper), and the filename. Finally, it combines all individual DataFrames 
# into a single DataFrame and exports it to a CSV file for further analysis.

# Convert PSD data from numpy arrays to pandas DataFrames for easier manipulation and analysis
psd_cont_df = psd_cont.to_data_frame()  # PSD data from continuous EEG using Welch method
psd_epoch_df = psd_epoch.to_data_frame()  # PSD data from epoched EEG using Welch method
psd_mt_cont_df = psd_mt_cont.to_data_frame()  # PSD data from continuous EEG using Multitaper method
psd_mt_epoch_df = psd_mt_epoch.to_data_frame()  # PSD data from epoched EEG using Multitaper method

# Convert PSD data to dataframes
psd_cont_df = psd_cont.to_data_frame()
psd_epoch_df = psd_epoch.to_data_frame()
psd_mt_cont_df = psd_mt_cont.to_data_frame()
psd_mt_epoch_df = psd_mt_epoch.to_data_frame()

# Add columns to specify data source, method, and filename at the beginning of the dataframe
filename = file_basename  # Assuming the filename is static for this example
for df, source, method in zip([psd_cont_df, psd_epoch_df, psd_mt_cont_df, psd_mt_epoch_df], 
                              ['Continuous', 'Epoched', 'Continuous', 'Epoched'], 
                              ['Welch', 'Welch', 'Multitaper', 'Multitaper']):
    df.insert(0, 'Filename', filename)
    df.insert(1, 'Data Source', source)
    df.insert(2, 'Method', method)
# Combine all dataframes into a single dataframe
combined_psd_df = pd.concat([psd_cont_df, psd_epoch_df, psd_mt_cont_df, psd_mt_epoch_df], ignore_index=True)

# Display the combined dataframe
print(combined_psd_df.head())

# Export the combined dataframe to a CSV file
script_name = os.path.basename(__file__).replace('.py', '_pow_spectrum.csv')
combined_psd_df.to_csv(script_name, index=False)






