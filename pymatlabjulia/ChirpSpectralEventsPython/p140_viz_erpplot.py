import mne
import os 

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
# Plotting the Global Field Power (GFP)
# ==============================================================================
# This section of the code is dedicated to visualizing the Global Field Power (GFP).
# GFP is a measure of the potential field power across all electrodes, providing
# an overview of the overall brain activity in response to the stimulus.
# The 'evoked.plot' function is used with the 'gfp' argument set to 'only' to
# generate a plot exclusively for the GFP, without plotting the activity for
# individual channels.

evoked.plot(gfp="only")  # Plotting only the Global Field Power (GFP)

# ==============================================================================
# Identifying Temporal Regions
# ==============================================================================
# This section of the code is dedicated to identifying left and right temporal 
# regions based on the channel names from the evoked response data. The criteria 
# for identifying these regions include finding channel names that contain the 
# word "temporal" and end with "L" for left or "R" for right temporal regions.

# Retrieve all channel names from the evoked response data
channel_names = evoked.info["ch_names"]

# Filter channel names to find left temporal regions
# Criteria: Name contains "temporal" and ends with "L"
left_temporal_regions = [channel for channel in channel_names if "temporal" in channel and channel.endswith("L")]

# Filter channel names to find right temporal regions
# Criteria: Name contains "temporal" and ends with "R"
right_temporal_regions = [channel for channel in channel_names if "temporal" in channel and channel.endswith("R")]

# Display the identified left and right temporal regions
print("Updated Left Temporal Regions:", left_temporal_regions)
print("Updated Right Temporal Regions:", right_temporal_regions)

# ==============================================================================
# Region of Interest (ROI) Selection and Plotting
# ==============================================================================
# This section of the code is dedicated to selecting channels that belong to 
# the left and right temporal regions and plotting their evoked responses. 
# The channels are grouped by their respective regions (left or right), 
# and the mean evoked response for each group is calculated and plotted.

# Select channels corresponding to the left temporal regions
left_ix = mne.pick_channels(evoked.info["ch_names"], include=left_temporal_regions)
# Select channels corresponding to the right temporal regions
right_ix = mne.pick_channels(evoked.info["ch_names"], include=right_temporal_regions)

# Create a dictionary to map the region of interest (ROI) names to their respective channel indices
roi_dict = dict(left_ROI=left_ix, right_ROI=right_ix)
# Create a dictionary to specify the titles for the plots corresponding to each ROI
roi_titles = dict(left_ROI="Left Temporal Regions", right_ROI="Right Temporal Regions")

# Combine channels within each ROI using the mean method to get the average evoked response
roi_evoked = mne.channels.combine_channels(evoked, groups=roi_dict, method="mean")

# Print the channel names for the combined ROIs
print(roi_evoked.info["ch_names"])

# Plot the evoked responses for the ROIs with spatial colors and Global Field Power (GFP)
# 'spatial_colors=True' enables coloring of the lines by their spatial location
# 'gfp=True' enables the plotting of the Global Field Power
roi_evoked.plot(spatial_colors=True, gfp=False, titles=roi_titles)