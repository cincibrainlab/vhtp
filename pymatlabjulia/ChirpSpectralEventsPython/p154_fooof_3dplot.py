# FOOOF - Fitting Oscillations & One Over F
# FOOOF is a Python package designed to parameterize neural power spectra, 
# decomposing them into periodic (oscillatory) and aperiodic (1/f) components.
# It is particularly useful for analyzing electrophysiological data such as EEG, MEG, or LFPs.
# For more information, visit: https://fooof-tools.github.io/fooof/

# ==============================================================================
# Import Required Libraries
# ==============================================================================
import mne
import yasa
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
import os

# Set Seaborn style for plots
sns.set(style='white', font_scale=1.2)

# ==============================================================================
# File Loading and Processing Stage
# ==============================================================================
# Brief on MNE file types: raw, epoched, evoked
# Raw: Continuous EEG data, unsegmented.
# Epoched: Data segmented into trials/events.
# Evoked: Averaged data over trials for specific conditions.

# Define file path
chirp_file = '/Users/ernie/Documents/ExampleData/Chirp/D0179_chirp-ST_postcomp_MN_EEG_Constr_2018.set'

# Extract the basename of the file for reporting and logging
file_basename = os.path.basename(chirp_file)
print(f"Processing file: {file_basename}")

# Read EEG data from the .set file
raw = mne.io.read_raw_eeglab(chirp_file, preload=True)

# Extract sampling frequency and channel names from the data
sf = raw.info['sfreq']  # Sampling frequency (Hz)
chans = raw.info['ch_names']  # List of EEG channel names

# Define EEG data parameters
no_of_channels = len(raw.info['ch_names'])  # Total number of EEG channels
points_per_trial = 1626  # Number of time points per trial
no_of_trials = 80  # Total number of trials

# Create epochs from raw data
epochs = mne.make_fixed_length_epochs(raw, duration=points_per_trial/raw.info['sfreq'], preload=True)
epochs = epochs[:no_of_trials]

# Compute average over epochs
evoked = epochs.average()

# ==============================================================================
# Power Spectral Density Analysis
# ==============================================================================

from neurodsp.spectral import compute_spectrum

# Function to compute PSD using Welch method
def compute_psd_welch(raw):
    """
    Computes the Power Spectral Density (PSD) of EEG data using the Welch method.

    Parameters:
    - raw (mne.io.Raw): The raw EEG data.
    - sf (float): The sampling frequency of the data.

    Returns:
    - freqs (ndarray): Array of sample frequencies.
    - psd_chans (ndarray): PSD values for each channel. Shape is (channels x power).
    """
    data = raw.get_data(units="uV")
    sf = raw.info['sfreq']
    freqs, psd_chans = compute_spectrum(data, sf, method='welch', avg_type='mean', nperseg=sf*2)
    chan_names = raw.info['ch_names']
    return freqs, psd_chans, chan_names

# Function to plot PSD comparison between two channels
def plot_psd_comparison(channel_1, channel_2, freqs, psd_chans):
    """
    Plots the Power Spectral Density (PSD) comparison between two EEG channels.

    Parameters:
    - channel_1 (int): Index of the first channel to compare.
    - channel_2 (int): Index of the second channel to compare.
    - freqs (array): Frequency vector.
    - psd_chans (2D array): Power spectrum channels x power.
    """
    plt.figure(figsize=(7, 5))
    # Limit frequency range to 0-30 Hz
    freq_limit = (freqs >= 0) & (freqs <= 30)

    # Exclude 55-65 Hz for the notch filter with dotted line
    notch_filter = (freqs >= 55) & (freqs <= 65)

    # Plot solid lines for frequencies outside 55-65 Hz for both channels
    plt.plot(freqs[freq_limit & ~notch_filter], 10 * np.log10(psd_chans[channel_1, freq_limit & ~notch_filter]), label=chan_names[channel_1], color='blue')
    plt.plot(freqs[freq_limit & ~notch_filter], 10 * np.log10(psd_chans[channel_2, freq_limit & ~notch_filter]), label=chan_names[channel_2], color='red')

    plt.xlabel('Frequency (Hz)')
    plt.ylabel('Power Spectral Density (dB)')
    plt.title(f'PSD Comparison: {chan_names[channel_1]} vs {chan_names[channel_2]} (0-30 Hz, excluding 55-65 Hz)')
    plt.legend()
    plt.tight_layout()
    plt.show()

# Example usage of PSD functions
freqs, psd_chans, chan_names = compute_psd_welch(raw)

# ==============================================================================
# Spectral Parameterization using FOOOF
# ==============================================================================

# Import the model object
from specparam import SpectralModel, SpectralGroupModel

# Define frequency range across which to model the spectrum
freq_range = [3, 40]

# Initialize a SpectralGroupModel object, specifying some parameters
fg = SpectralGroupModel(peak_width_limits=[1.0, 8.0], aperiodic_mode='knee', max_n_peaks=5)

# Fit models across the matrix of power spectra
fg.report(freqs, psd_chans, freq_range)

# Create and save out a report summarizing the results across the group of power spectra
fg.save_report(file_name='group_results')

# Save out results for further analysis later
fg.save(file_name='group_results_export', save_results=True)

group_results = fg.get_results()

import pandas as pd


# Aperiodic parameters result
tidy_table = []
channel_no = 1
for result in group_results:
    offset = result.aperiodic_params[0]
    if len(result.aperiodic_params) == 3:
        knee = result.aperiodic_params[1]
        exponent = result.aperiodic_params[2]
    if len(result.aperiodic_params) == 2:
        knee = 0
        exponent = result.aperiodic_params[1]
    error = result.error
    r_squared = result.r_squared
    tidy_table.append({'filename': file_basename, 
                       'channel': channel_no, 
                       'label': chans[channel_no-1],
                       'freq_range': f"{fg.freq_range[0]}-{fg.freq_range[1]} Hz",
                       'freq_res': fg.freq_res,
                       'max_peaks': fg.max_n_peaks,
                        'aperiodic_mode': fg.aperiodic_mode,
                        'peak_width_limits': f"{fg.peak_width_limits[0]}-{fg.peak_width_limits[1]}",
                        'min_peak_height': fg.min_peak_height,
                        'peak_threshold': fg.peak_threshold,
                       'measure': 'aperiodic', 
                       'offset': offset, 
                       'knee': knee, 
                       'exponent': exponent, 
                       'error': error, 
                       'r_squared': r_squared})
channel_no += 1
aperiodic_df = pd.DataFrame(tidy_table)
aperiodic_df.to_csv('aperiodic.csv')

# Periodic parameters result
tidy_table = []
channel_no = 1
for result in group_results:
    peak_no = 1
    for peak, gauss in zip(result.peak_params, result.gaussian_params):
        center = peak[0]
        power = peak[1]
        width = peak[2]
        mean = gauss[0]
        height = gauss[1]
        sd = gauss[2]
        tidy_table.append({'filename': file_basename, 'channel': channel_no, 'label': chans[channel_no-1], 'measure': 'periodic', 'peak_no': peak_no, 'peak_center': center, 'peak_power': power, 'peak_width': width, 'fit_mean': mean, 'fit_height': height, 'fit_sd': sd})
        peak_no += 1
    channel_no += 1
pd.DataFrame(tidy_table)
periodic_df = pd.DataFrame(tidy_table)
periodic_df.to_csv('periodic.csv')