function [EEG, results] = eeg_htpEegRemoveEpochsEeglab(EEG,varargin)
% eeg_htpEegCreateEpochs - Perform epoch creation for Non-ERP datasets
%
% Usage:
%    >> [ EEG, results ] = eeg_htpEegRemoveEpochsEeglab( EEG, varargin) )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%        
% Outputs:
%     EEG         - Updated EEGLAB structure
%
%     results   - Updated function-specific structure containing qi table
%                 and input parameters used
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: kyle.cullion@cchmc.org

% MATLAB built-in input validation
defaultSaveOutput = false;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical)

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try 
    global rej;


    gui.position = [0.07 0.35 0.4 0.55];

    spevent = EEG.event;
    spfilename = EEG.filename;
    titlestr = sprintf('Epoch Rejection: %s ', spfilename);

    eegplot(EEG.data,'srate',EEG.srate,'winlength',8, ...
        'events', spevent,'wincolor',[1 0.5 0.5], 'limits', [EEG.xmin EEG.xmax]*1000,...
        'plottitle', titlestr, ...
        'command','global rej,rej=TMPREJ',...
        'eloc_file',EEG.chanlocs);


    h = findobj('tag', 'eegplottitle');
    h.FontWeight = 'Bold'; h.FontSize = 16; h.Position = [0.5000 0.93 0];


    handle = gcf;
    handle.Units = 'normalized';
    handle.Position = gui.position;


    waitfor(gcf);


    if ~isempty(rej)

        tmprej = eegplot2trial(rej, EEG.pnts, EEG.trials);
        proc_tmprej_epochs = tmprej;
        EEG = eeg_checkset( EEG );

    else

        EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_badtrials = '';
        EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_badid = '';
        EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_percent = 100;

    end


    if ~exist('tmprej')

        EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_badtrials   = 0;
        EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_badid       = '[0]';
        EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_percent     = 100;
        tmprej=[];

    else
        EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_badtrials = length(find(tmprej));
        EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_badid = ['[' num2str(find(tmprej)) ']'];
        EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_percent = 100-(EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_badtrials / EEG.trials)*100;

    end
    
    EEG = pop_rejepoch( EEG, tmprej ,0);
    EEG = eeg_checkset(EEG);
    EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.completed = 1;
    EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.epoch_trials = EEG.trials;
    
catch e
    throw(e)
end
qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegRemoveEpochsEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.qi_table = [EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegRemoveEpochsEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegRemoveEpochsEeglab;
end

