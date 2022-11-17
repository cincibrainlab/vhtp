function [EEG, results] = eeg_htpPlotSingleChannel( EEG, varargin )
% eeg_htpPlotSingleChannel() - plots single channel EEG data
%      Add 'help' comments here to be viewed on command line.
%
% Usage:
%    >> [ EEG, results ] = eeg_htpPlotSingleChannel( EEG, options )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
% Function Specific Inputs:
%     'chan' - channel number
%     'outputdir' - output directory to save files
%     
% Outputs:
%     EEG       - EEGLAB Structure with modified .etc.htp field
%     results   - etc.htp results structure or customized
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%    
%  Contact: ernest.pedapati@cchmc.org

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

% Inputs: Function Specific

% Inputs: Common across Visual HTP functions
defaultOutputDir = [];
defaultChan = 1;

% MATLAB built-in input validation
ip = inputParser();   
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder)
addParameter(ip,'chan', defaultChan, @isnumeric)
parse(ip,EEG,varargin{:});

outputdir = ip.Results.outputdir;
chan = ip.Results.chan;

% base output file can be modified with strrep()
outputfile = fullfile(outputdir, [functionstamp '_'  EEG.setname '_' timestamp '.png']); 

% START: Signal Processing

times = EEG.times / 1000;  % convert to seconds

if ndims(EEG.data) > 2
    EEG = eeg_htpEegEpoch2Cont(EEG);
end

data = EEG.data(chan,:);

figure(99)
subplot(2,1,1);
plot(times, data, 'k');
title (sprintf('1-Channel (%.0f) Time Series: %s (%2.1f-%2.1f s)', chan, EEG.subject, EEG.xmin, EEG.xmax));
xlabel('Time (s)');
ylabel('Amplitude (V)')
pbaspect([5 1 1]);
subplot(2,1,2);
plot(times, data, 'k');
xlabel('Time (s)');
ylabel('Amplitude (V)')
title (sprintf('Time = 2 X sampling rate (%.0f Hz)', EEG.srate));
xlim([times(1) times(EEG.srate*2)]);
set(gca, ...
  'Box'         , 'off'     , ...
  'TickDir'     , 'out'     , ...
  'TickLength'  , [.02 .02] , ...
  'XMinorTick'  , 'on'      , ...
  'YMinorTick'  , 'on'      , ...
  'YGrid'       , 'on'      , ...
  'XColor'      , [.3 .3 .3], ...
  'YColor'      , [.3 .3 .3], ...
  'LineWidth'   , 1         );
set(gcf, 'PaperPositionMode', 'auto');
set(gcf,'color','w');

if ~isempty(outputdir)
    saveas(99, outputfile );
end
close gcf
% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, 'VariableNames', {'eegid','function','timestamp'});

% Outputs: 
results = [];


end