using Pkg
Pkg.add("NeuroAnalyzer")

using NeuroAnalyzer


na_version()
na_info()

resting_file = "/Users/ernie/Documents/ExampleData/APD/D0113_rest_postica.set"

eeg = import_recording(resting_file)
