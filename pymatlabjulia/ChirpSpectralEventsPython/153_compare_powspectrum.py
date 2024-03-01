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
# Power Spectral Density Analysis
# ==============================================================================

from neurodsp.spectral import compute_spectrum
import specparam as sp

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
plot_psd_comparison(1, 2, freqs, psd_chans)

# ==============================================================================
# Plot Spectra
# ==============================================================================
sp.plts.plot_spectra(freqs, [psd_chans[2,:], psd_chans[7,:], psd_chans[10,:]], 
                  freq_range=[0, 80],  # Frequency range to plot [Hz
                  log_freqs=False, log_powers=True, colors=['blue', 'green', 'red'], 
                  labels=[chan_names[2], chan_names[7], chan_names[10]])
plt.show()
