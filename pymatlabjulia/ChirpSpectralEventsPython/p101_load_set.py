# ==============================================================================
# Loading Resting State EEG Data
# ==============================================================================
# This script section is dedicated to loading resting state EEG data for further analysis.
# The data is expected to be in the EEGLAB .set format, which is a common format for EEG data storage.
# The MNE-Python library is utilized here to read the epochs directly from the .set file.

import mne

# Path to the resting state EEG data file
# Arguments:
#   resting_file: A string representing the full path to the EEG data file in EEGLAB .set format.
resting_file = '/Users/ernie/Documents/ExampleData/APD/D0113_rest_postica.set'

# Reading epochs from the EEGLAB .set file using MNE-Python
# The function `read_epochs_eeglab` is specifically designed to handle .set files.
# It loads the data into an Epochs object for easy manipulation and analysis within the MNE environment.
# Arguments:
#   resting_file: The path to the .set file to be loaded.
epochs = mne.io.read_epochs_eeglab(resting_file)

# This code block is not used in the script. It shows how to load
# continuous EEG data from a .set file with preload=True. Preloading
# is useful for preprocessing that needs the full dataset before epoching.
try:
    raw = mne.io.read_raw_eeglab(resting_file, preload=True)
except Exception as e:
    print(f"Failed to read raw EEG data: {e}")
