import os
import mne
import matplotlib.pyplot as plt

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
# Power Spectral Density Visualization
# ==============================================================================
fig, ax = plt.subplots(figsize=(8, 6))
raw.plot_psd(ax=ax, area_mode='range', fmin=0, fmax=80, show=False, average=False)
plt.show()

# ==============================================================================
# Interactive Channel Data Browsing
# ==============================================================================
raw.plot(duration=5, n_channels=10, scalings='auto')
plt.show()

# ==============================================================================
# Event-Related Potential (ERP) Visualization
# ==============================================================================

evoked.plot(picks=[0], time_unit='s')

# ==============================================================================
# Epochs Data Visualization
# ==============================================================================
event_related_plot = epochs.plot_image(picks=[0])