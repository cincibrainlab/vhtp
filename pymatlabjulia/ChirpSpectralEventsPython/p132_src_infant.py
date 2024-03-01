import os.path as op

import numpy as np

import mne
from mne.datasets import fetch_fsaverage
from mne.datasets import sample
from mne.coreg import Coregistration
from mne.io import read_info

# ------------------------------------------------------------------------------
# Introduction - MNE Source Localization for Infant Auditory Evoked Data
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# Defining Resting State EEG Data File Path
# ------------------------------------------------------------------------------
# Define the path to the resting state EEG data file
# This file is expected to be in EEGLAB .set format
eeg_file = '/Users/ernie/Documents/ExampleData/Chirp/128_Chirp_D0657_DIN8.set'

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
# Exporting the current montage information to a file
montage_file = '/Users/ernie/Documents/ExampleData/Chirp/montage_info.txt'
with open(montage_file, 'w') as f:
    for ch in montage.ch_names:
        pos = montage.get_positions()['ch_pos'][ch]
        f.write(f"{ch}: {pos}\n")
print(f"Montage information exported to {montage_file}")

# Saving the preprocessed epochs data to a FIFF file
fif_file_path = '/Users/ernie/Documents/ExampleData/Chirp/processed_epochs.fif'
epochs.save(fif_file_path, overwrite=True)
print(f"Preprocessed epochs data saved to {fif_file_path}")


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
# Low-Pass Filtering of Epochs
# ------------------------------------------------------------------------------
# Applying a low-pass filter to the epochs to reduce high-frequency noise.
# The cutoff frequency is set to 30 Hz, which is commonly used in EEG analysis
# to focus on the brain's electrical activity within the most relevant frequency range.
epochs.filter(None, 30., fir_design='firwin')
# ------------------------------------------------------------------------------


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
# Setting Template Subject
# ------------------------------------------------------------------------------
# Setting the subject to 'fsaverage'. 'fsaverage' is a standard MRI subject 
# used in MNE for template MRI data.
subject = mne.datasets.fetch_infant_template("2mo", subjects_dir, verbose=True)


# ------------------------------------------------------------------------------
# Setting Template Transformation File
# ------------------------------------------------------------------------------
# Setting the transformation file to 'fsaverage'. This is a built-in 
# transformation in MNE that aligns EEG data to the 'fsaverage' brain.
fname_1020 = op.join(subjects_dir, subject, "montages", "10-20-montage.fif")
mon = mne.channels.read_dig_fif(fname_1020)
mon.rename_channels({f"EEG{ii:03d}": ch_name for ii, ch_name in enumerate(ch_names, 1)})
trans = mne.channels.compute_native_head_t(mon)
raw.set_montage(mon)


print(trans)
trans = mne.channels.compute_native_head_t(montage)
print(trans)

# ------------------------------------------------------------------------------
# Constructing Source Space File Path
# ------------------------------------------------------------------------------
# Constructing the source space file path. The source space defines 
# the locations of the dipoles in the brain volume.
# Here, 'fsaverage-ico-5-src.fif' is used, which is a standard source 
# space file for 'fsaverage'.
bem_dir = op.join(subjects_dir, subject, "bem")
fname_src = op.join(bem_dir, f"{subject}-oct-6-src.fif")
src = mne.read_source_spaces(fname_src)

#src = mne.read_source_spaces(op.join(fs_dir, "bem", "fsaverage-ico-5-src.fif"))


print(src)



# ------------------------------------------------------------------------------
# Constructing BEM File Path
# ------------------------------------------------------------------------------
# Constructing the boundary element model (BEM) file path. The BEM 
# model is used for forward modeling in MEG/EEG.
# 'fsaverage-5120-5120-5120-bem-sol.fif' is a high-resolution BEM 
# solution file for 'fsaverage'.
#bem = op.join(fs_dir, "bem", "fsaverage-5120-5120-5120-bem-sol.fif")
fname_bem = op.join(bem_dir, f"{subject}-5120-5120-5120-bem-sol.fif")
bem = mne.read_bem_solution(fname_bem)

# ------------------------------------------------------------------------------
# EEG Electrode and MRI Alignment Check
# ------------------------------------------------------------------------------

fiducials = "auto"  # get fiducials from fsaverage
coreg = Coregistration(epochs.info, subject, subjects_dir, fiducials=fiducials)


coreg = Coregistration(epochs.info, subject, subjects_dir, fiducials="auto")
coreg.set_scale_mode("uniform")
coreg.set_scale([144.23, 144.23 ,144.23])
coreg.fit_fiducials(verbose=True)
coreg.fit_icp(n_iterations=20, nasion_weight=10.0, verbose=True)
coreg.fit_icp(n_iterations=20, nasion_weight=10.0, verbose=True)


fig = mne.viz.plot_alignment(
    epochs.info,
    subject=subject,
    subjects_dir=subjects_dir,
    eeg=["original"],
    trans=coreg.trans,
    src=src,
    bem=bem,
    coord_frame="mri",
    mri_fiducials=True,
    show_axes=True,
    surfaces=("white", "outer_skin", "inner_skull", "outer_skull"),
)

mne.viz.set_3d_view(fig, 25, 70, focalpoint=[0, -0.005, 0.01])

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
    epochs.info, trans=trans, src=src, bem=bem, eeg=True, mindist=5.0, n_jobs=6
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
# Inverse Operator Creation
# ------------------------------------------------------------------------------
# This step involves creating an inverse operator, which is essential for source 
# localization. The inverse operator maps the EEG sensor space data back to the 
# source space, allowing us to estimate the location of brain activity that 
# generated the observed EEG data. The 'verbose=True' parameter enables detailed 
# logging of the process for debugging purposes.
inv = mne.minimum_norm.make_inverse_operator(epochs.info, fwd, noise_cov, verbose=True)

# ------------------------------------------------------------------------------
# Applying the Inverse Solution
# ------------------------------------------------------------------------------
# Apply the inverse operator to the epochs (multiple EEG data segments) to 
# compute the source time courses. This operation produces a SourceEstimate 
# object ('stc'), which encapsulates the estimated time series of neural activity 
# that likely generated the observed EEG data across different epochs in the sensor space.
stc = mne.minimum_norm.apply_inverse_epochs(epochs, inv, lambda2=1.0 / 9.0 ** 2, method="MNE", verbose=True)

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
label_ts = mne.extract_label_time_course(stc, labels, src, mode='mean', return_generator=True, allow_empty='ignore')

# Creating a dictionary to store the label time series along with their associated labels.
# This structure allows for easy access to the time series data by using the label names as keys.
label_ts_dict = {label.name: ts for label, ts in zip(labels, label_ts)}

# ------------------------------------------------------------------------------
# Extracting Time Courses in Different Modes from Temporal Rregions
# ------------------------------------------------------------------------------
# This section of the code is dedicated to extracting the time courses from the source 
# estimate (stc) for each label in the source space. The extraction is performed under 
# three different modes: 'mean', 'mean_flip', and 'pca_flip'. These modes determine how 
# the time series within each label are combined. The results are stored in a dictionary 
# for easy access and manipulation.

modes = ("mean", "mean_flip", "pca_flip")  # Define the modes for time course extraction
tcs = dict()  # Initialize an empty dictionary to store the time courses

# Filtering labels to only include those with "Temporal" in their name
temporal_labels = [label for label in labels if "temporal" in label.name]
temporal_labels = temporal_labels[1]

# Loop through each mode and extract the corresponding time courses
for mode in modes:
    # Extract the time course for the current mode and store it in the dictionary
    tcs[mode] = mne.extract_label_time_course(stc, temporal_labels, src, mode=mode, return_generator=False, allow_empty='ignore')



# ------------------------------------------------------------------------------
# Evoked Object Creation and Time-Frequency Visualization
# ------------------------------------------------------------------------------
# Averaging the epochs to create an Evoked object. This step combines the EEG data across epochs (trials) 
# to produce an average waveform for each channel. This is useful for identifying event-related potentials (ERPs) 
# associated with specific stimuli or responses.
evoked = epochs.average();
# Plotting the joint time-frequency representation of the averaged EEG data. This visualization helps in 
# identifying the temporal and spectral characteristics of the evoked response across all channels.
evoked.plot_joint();

# Creating an Evoked dataset from the source localized data (stc) for each label
evoked_data = dict()
for label in labels[:-1]:
    # Extracting the time series for the current label
    label_ts = mne.extract_label_time_course(stc, label, src, mode='mean', return_generator=False, allow_empty='ignore')
    # Averaging across the time series to create an Evoked-like dataset
    evoked_data[label.name] = np.mean(label_ts, axis=0)

# Determine the type of label_ts and print it
print(f"The type of label_ts is: {type(label_ts)}")
# Getting the dimensions and structure of label_ts
if label_ts:
    # Assuming label_ts is a list of numpy arrays, we can get the dimensions of the first element as an example
    example_ts = label_ts[0]
    print(f"Example time series shape: {example_ts.shape}")
    print(f"Total number of labels: {len(label_ts)}")
    # To understand the structure, let's print the type of the first element
    print(f"Type of the elements in label_ts: {type(example_ts)}")
else:
    print("label_ts is empty or not defined.")


# Displaying the Evoked dataset for a specific label as an example
from matplotlib import pyplot as plt
import numpy as np
evoked_vector = np.array(evoked_data[example_label]).flatten()

example_label = 'superiortemporal-lh'
if example_label in evoked_data:
    plt.figure(figsize=(10, 3))
    plt.plot(epochs.times, evoked_vector, label=f'Evoked of {example_label}')  # Adjusted to use the time vector
    plt.xlabel('Time (seconds)')  # Adjusted to reflect the unit of the time vector
    plt.ylabel('Amplitude')
    plt.title(f'Evoked Dataset of the Label: {example_label}')
    plt.legend()
    plt.show()
else:
    print(f'Label {example_label} not found in evoked data.')


