# ------------------------------------------------------------------------------
# Introduction - MNE Source Localization for Resting Data
# ------------------------------------------------------------------------------
# This script is designed to process EEG data using the MNE-Python library. It
# demonstrates a workflow for analyzing EEG data, including preprocessing,
# epoching, averaging to create evoked responses, and applying source
# localization techniques. The script utilizes the 'fsaverage' subject from
# MNE's dataset for template MRI data to align EEG data for source analysis.
# The goal is to provide a comprehensive example of EEG data analysis from
# raw data to source-level inference, highlighting the capabilities of MNE-Python
# in processing and visualizing neurophysiological data.

import os.path as op
import numpy as np
import mne
from mne.datasets import fetch_fsaverage

# ------------------------------------------------------------------------------
# Defining Resting State EEG Data File Path
# ------------------------------------------------------------------------------
# Define the path to the resting state EEG data file
# This file is expected to be in EEGLAB .set format
eeg_file = '/Users/ernie/Documents/ExampleData/APD/D0113_rest_postica.set'

# ------------------------------------------------------------------------------
# Reading Epochs from EEGLAB .set File
# ------------------------------------------------------------------------------
# Use MNE to read the epochs from the EEGLAB .set file
# The read_epochs_eeglab function is used for this purpose
epochs = mne.io.read_epochs_eeglab(eeg_file)

# ------------------------------------------------------------------------------
# Creating and Applying Montage
# ------------------------------------------------------------------------------
# Creating a standard montage for EGI 128 electrode system
montage = mne.channels.make_standard_montage('GSN-HydroCel-128')
# Applying the created montage to the epochs data
epochs.set_montage(montage)
print("Montage set to EGI 128")

# ------------------------------------------------------------------------------
# Getting Current Montage
# ------------------------------------------------------------------------------
# Get the current montage from the epochs
montage = epochs.get_montage()

# ------------------------------------------------------------------------------
# EEG Reference Setting
# ------------------------------------------------------------------------------
# Setting an EEG reference is a crucial preprocessing step in EEG analysis. 
# Here, we set the EEG reference using the projection method. This method 
# projects the EEG data onto a reference that is mathematically constructed, 
# rather than using a physical electrode as the reference. This is particularly 
# important for inverse modeling, as it ensures that the EEG data is properly 
# referenced and can be accurately mapped onto the brain model for source localization.
epochs.set_eeg_reference(projection=True)

# ------------------------------------------------------------------------------
# Starting Source Localization
# ------------------------------------------------------------------------------
# This section marks the beginning of source localization specific processes.
# Source localization involves mapping the EEG data onto the brain model to
# identify the origins of the observed electrical activity. This is crucial
# for understanding the spatial aspects of the neural signals in the context
# of resting state or task-related EEG studies.
print("Initiating source localization procedures...")


# ------------------------------------------------------------------------------
# Fetching fsaverage Files
# ------------------------------------------------------------------------------
# Fetching the fsaverage MRI subject's files from MNE's data repository.
# This includes various files like the BEM surfaces, source spaces, etc.
fs_dir = fetch_fsaverage(verbose=True)

# ------------------------------------------------------------------------------
# Determining Directory Path
# ------------------------------------------------------------------------------
# Determining the directory path where the fsaverage files are stored.
# This is typically the subjects directory in MNE's data structure.
subjects_dir = op.dirname(fs_dir)

# ------------------------------------------------------------------------------
# Setting Subject
# ------------------------------------------------------------------------------
# Setting the subject to 'fsaverage'. 'fsaverage' is a standard MRI subject 
# used in MNE for template MRI data.
subject = "fsaverage"

# ------------------------------------------------------------------------------
# Setting Transformation File
# ------------------------------------------------------------------------------
# Setting the transformation file to 'fsaverage'. This is a built-in 
# transformation in MNE that aligns EEG data to the 'fsaverage' brain.
trans = "fsaverage" 

# ------------------------------------------------------------------------------
# Constructing Source Space File Path
# ------------------------------------------------------------------------------
# Constructing the source space file path. The source space defines 
# the locations of the dipoles in the brain volume.
# Here, 'fsaverage-ico-5-src.fif' is used, which is a standard source 
# space file for 'fsaverage'.
src = mne.read_source_spaces(op.join(fs_dir, "bem", "fsaverage-ico-5-src.fif"))

# ------------------------------------------------------------------------------
# Constructing BEM File Path
# ------------------------------------------------------------------------------
# Constructing the boundary element model (BEM) file path. The BEM 
# model is used for forward modeling in MEG/EEG.
# 'fsaverage-5120-5120-5120-bem-sol.fif' is a high-resolution BEM 
# solution file for 'fsaverage'.
bem = op.join(fs_dir, "bem", "fsaverage-5120-5120-5120-bem-sol.fif")

# ------------------------------------------------------------------------------
# EEG Electrode and MRI Alignment Check
# ------------------------------------------------------------------------------
# Check that the locations of EEG electrodes is correct with respect to MRI
mne.viz.plot_alignment(
    epochs.info,
    src=src,
    eeg=["original", "projected"],
    trans=trans,
    show_axes=True,
    mri_fiducials=True,
    dig="fiducials",
)

# ------------------------------------------------------------------------------
# Forward Solution Creation
# ------------------------------------------------------------------------------
# Creating a forward solution for EEG data. This involves computing how 
# the electrical signals from the brain (modeled at the source locations 
# in 'src') project onto the EEG sensors, given the head model specified by 'bem'. 
# The 'mindist' parameter excludes sources closer 
# than 5.0 mm to the inner skull from the forward model to avoid inaccuracies. 
# 'n_jobs=None' means that the computation will not be parallelized.
fwd = mne.make_forward_solution(
    epochs.info, trans=trans, src=src, bem=bem, eeg=True, mindist=5.0, n_jobs=10
)
# Printing the forward solution object to get an overview of its contents and parameters.
print(fwd)

# ------------------------------------------------------------------------------
# Noise Covariance Matrix Computation
# ------------------------------------------------------------------------------
# Computing the noise covariance matrix from the pre-stimulus period
# This matrix is essential for many inverse modeling techniques as it characterizes
# the sensor noise. The 'tmax=0.0' parameter ensures that only the pre-stimulus
# period is considered for computing this matrix.
noise_cov = mne.compute_covariance(epochs, tmax=0.0)

# ------------------------------------------------------------------------------
# Evoked Object Creation and Time-Frequency Visualization
# ------------------------------------------------------------------------------
# Averaging the epochs to create an Evoked object. This step combines the EEG data across epochs (trials) 
# to produce an average waveform for each channel. This is useful for identifying event-related potentials (ERPs) 
# associated with specific stimuli or responses.
evoked = epochs.average()  
# Plotting the joint time-frequency representation of the averaged EEG data. This visualization helps in 
# identifying the temporal and spectral characteristics of the evoked response across all channels.
evoked.plot_joint()

# ------------------------------------------------------------------------------
# Inverse Operator Creation
# ------------------------------------------------------------------------------
# This step involves creating an inverse operator, which is essential for source 
# localization. The inverse operator maps the EEG sensor space data back to the 
# source space, allowing us to estimate the location of brain activity that 
# generated the observed EEG data. The 'verbose=True' parameter enables detailed 
# logging of the process for debugging purposes.
inv = mne.minimum_norm.make_inverse_operator(epochs.info, fwd, noise_cov, verbose=True)

# ------------------------------------------------------------------------------
# Applying Inverse Solution to Epochs
# ------------------------------------------------------------------------------
# This section applies the inverse solution to the epochs data to estimate
# the source time courses. The method used is MNE (Minimum Norm Estimate).
# Arguments:
#   epochs: The epochs data to which the inverse solution is applied.
#   inv: The inverse operator computed earlier.
#   lambda2: The regularization parameter in the inverse method. Here, it is set to 1/9.
#   method: Specifies the inverse solution method to use. 'MNE' is chosen in this case.
#   verbose: If set to True, detailed information will be printed during the operation.
stc = mne.minimum_norm.apply_inverse_epochs(epochs, inv, lambda2=1.0 / 9.0, method="MNE", verbose=True)

# Fetching labels for the source space using the 'aparc' parcellation for both hemispheres.
labels = mne.read_labels_from_annot(subject, parc='aparc', hemi='both', subjects_dir=subjects_dir)
print(f"Number of labels: {len(labels)}")

# ------------------------------------------------------------------------------
# Color Extraction
# ------------------------------------------------------------------------------
# After extracting the labels, this step retrieves the color associated with each label.
# These colors are useful for visualization purposes, allowing each region to be
# distinctly identified when plotting.
label_colors = [label.color for label in labels]

# ------------------------------------------------------------------------------
# Extracting source label time series
# ------------------------------------------------------------------------------
# This step involves extracting the time series for each label in the source space. 
# This is useful for analyzing the temporal dynamics of neural activity within specific 
# brain regions defined by the labels. The 'mode' parameter specifies how the time series 
# within each label should be combined (e.g., mean, max). The 'return_generator' parameter 
# can be set to True to return a generator for iterating over the labels, which can be 
# useful for large datasets.
# A generator in Python is a special type of iterator that allows us to iterate over a sequence of values.
# Unlike a list, it does not store all the values in memory; instead, it generates the values on the fly.
# This makes generators a powerful tool for working with large datasets or streams of data where you don't
# want to load everything into memory at once.

# To use a generator, you can define a function with at least one 'yield' statement in it. When called,
# this function returns a generator object but does not start execution immediately. Iteration over the
# generator starts the execution and continues until it encounters a 'yield' statement, at which point it
# returns the yielded value and pauses. The next iteration resumes execution immediately after the 'yield'
# and continues until it either hits another 'yield' or the function completes.

# In the context of extracting label time series, setting 'return_generator=True' in the
# 'mne.extract_label_time_course' function call means that instead of returning a list of all the time series
# data at once, it will return a generator. This generator can then be iterated over to process each label's
# time series one at a time, which can be more memory efficient for large datasets.

# Example of iterating over a generator to process label time series data:
# This will print the mean of the time series for each label without loading all of them into memory at once.
label_ts = mne.extract_label_time_course(stc, labels, src, mode='mean_flip', return_generator=False, allow_empty='ignore')
# To get the size of label_ts, a generator object, we need to iterate over it and count the elements.
# However, iterating over the generator will consume the elements, making them unavailable for future use.
# Therefore, we will convert the generator to a list first, which will allow us to both count the elements
# and retain them for future use.

#for label_time_series in label_ts:
#    print(np.mean(label_time_series))


# Creating a dictionary to store the label time series along with their associated labels.
# This structure allows for easy access to the time series data by using the label names as keys.
label_ts_dict = {label.name: ts for label, ts in zip(labels, label_ts)}

# Creating a 1D time series from the label_ts_dict for "bankssts-lh"
bankssts_lh_ts = label_ts_dict["bankssts-rh"].squeeze()

# Plotting the first label time series as if it were an EEG channel
# This visualization helps in understanding the temporal dynamics of neural activity
# within a specific brain region, as estimated from the EEG data.
import matplotlib.pyplot as plt
plt.figure(figsize=(10, 3))
plt.plot(label_time_series, label='bankssts-lhs')
plt.xlabel('Time (samples)')
plt.ylabel('Amplitude')
plt.title('Time Series of the First Label')
plt.legend()
plt.show()
