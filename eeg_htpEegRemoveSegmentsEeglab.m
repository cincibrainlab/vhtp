function [EEG, results] = eeg_htpEegRemoveSegmentsEeglab(EEG,varargin)
% eeg_htpEegRemoveSegmentsEeglab - Select and reject atifactual regions in data
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegRemoveSegmentsEeglab( EEG, varargin )
%
%% Required Inputs:
%   EEG [struct]           - EEGLAB Structure
%
%% Function Specific Inputs:
%   'saveoutput' - Boolean representing if output should be saved when executing step from VHTP preprocessing tool
%                  default: false
%% Output:
%   EEG [struct] - output structure with updated dataset
%
%   results [struct]   - Updated function-specific structure containing qi table and input parameters used
%% Disclaimer:
%   Part of the Cincinnati Visual High Throughput EEG Pipeline
%   
%   Please see http://github.com/cincibrainlab
%
%% Contact:
%   kyle.cullion@cchmc.org
defaultSaveOutput = false;

ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical)

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    
    gui.position = [0.01 0.20 0.95 0.70];
            
    EEG = eeg_checkset(EEG);
    EEG_prechan = EEG;

    global rej;

    proc_removed_regions = [];
    try
        [OUTEEG, selectedregions, precompstruct, com] = pop_rejcont(EEG, 'elecrange',[1:EEG.nbchan] ,'freqlimit',[20 40] ...
            ,'threshold',10,'epochlength',0.5,'contiguous',4, ...
            'onlyreturnselection', 'on', 'addlength',0.25,'taper','hamming', 'verbose', 'on');
        OUTEEG = [];

        winrej = zeros(size(selectedregions,1), size(selectedregions,2) + 3 + size(EEG.data, 1));
        winrej(:, 1:2) = selectedregions(:,1:2);
        winrej(:, 3:5) = repmat([0 0.9 0],size(selectedregions,1),1);
    catch
       winrej = []; 
    end
    eegplot(EEG.data,'srate',EEG.srate,'winlength',8, ...
        'plottitle', ['Continuous Artifact Rejection'], ...
        'events',EEG.event,'wincolor',[1 0.5 0.5], 'winrej', winrej, ...
        'command','global rej,rej=TMPREJ',...
        'eloc_file',EEG.chanlocs);

%     eegplot(EEG.data,'srate',EEG.srate,'winlength',8, ...
%         'plottitle', ['Continuous Artifact Rejection'], ...
%         'events',EEG.event,'wincolor',[1 0.5 0.5], 'winrej', winrej, ...
%         'eloc_file',EEG.chanlocs);

    handle = gcf;
    handle.Units = 'normalized';
    handle.Position = gui.position;


    h = findobj('tag', 'eegplottitle');
    h.FontWeight = 'Bold'; h.FontSize = 16; h.Position = [0.5000 0.93 0];
    usrStr1 = 'GREEN REGIONS: Autorejected Regions based on on Spectrum Thresholding (pop_rejcont)';
    usrStr2 = 'RED REGIONS: User Selected Regions';
    h.String = sprintf('%s\n%s\n%s',  h.String, usrStr1, usrStr2);
    h.Position(2) = 0.93;


    waitfor(gcf);

    try

        if ~isempty(rej)

            tmprej = eegplot2event(rej, -1);
            EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab.proc_tmprej_cont = tmprej(:,[3 4]);
            [EEG,~] = eeg_eegrej(EEG,tmprej(:,[3 4]));

            events = EEG.event;

            cutIndex = strcmp({events.type}, 'boundary');
            cutIndexNo = find(cutIndex);

            latencies = [events(cutIndexNo).latency];
            durations = [events(cutIndexNo).duration];

            tmpstr = '';
            finalstr = '';

            for i = 1 : length(cutIndexNo)

                tmpstr = sprintf('#%0d@%.0f(%.0f); ', cutIndexNo(i), latencies(i), durations(i));

                finalstr = [finalstr tmpstr];
            end

            EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab.proc_removed_regions = finalstr;

        else
            EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab.proc_removed_regions = '';
        end
        EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab.completed=1;

    catch

        EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab.completed=0;
        EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab.failReason = 'Issue in actual removal steps';

    end
    
    
catch e
    throw(e)
end
EEG=eeg_checkset(EEG);
qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab.qi_table = [EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegRemoveSegmentsEeglab;
end

