using NeuroAnalyzer

resting_file = "D0348_rest_postica.set"
cd("/Users/ernie/Documents/ExampleData/APD")
eeg = import_recording(resting_file)
