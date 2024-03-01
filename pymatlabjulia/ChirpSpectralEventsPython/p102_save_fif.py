# ==============================================================================
# Loading Resting State EEG Data
# ==============================================================================
# This section of the script focuses on importing resting state EEG data for subsequent analysis.
# It is assumed that the data is stored in the EEGLAB .set format, a widely used format for EEG data.
# Here, the MNE-Python library is employed to directly load the epochs from the .set file.
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

# ==============================================================================
# Saving Epochs Data to MNE FIF Format
# ==============================================================================
# This section of the script is dedicated to saving the loaded epochs data into
# a FIFF (Functional Image File Format) file. The FIFF format is commonly used
# in MNE-Python for storing processed EEG data, allowing for easy sharing and
# further analysis of the data.

# Define the path where the FIFF file will be saved
fif_file_path = '/Users/ernie/Documents/ExampleData/APD/D0113_rest_postica-epochs.fif'

# Save the epochs data to the specified FIFF file
# The `overwrite=True` argument allows for overwriting the file if it already exists
epochs.save(fif_file_path, overwrite=True)

# Print a confirmation message indicating successful saving of the epochs data
print(f"Epochs data successfully saved to {fif_file_path}")