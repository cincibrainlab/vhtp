function [EEG, results] = eeg_htpEegIcaEeglab(EEG,varargin)
% eeg_htpEegIcaEeglab - Perform Independent Component Analysis on data
%
% Usage:
%    >> [ EEG, results ] = eeg_htpEegIcaEeglab( EEG, varargin )
%
% Require Inputs:
%     EEG           - EEGLAB Structure
%
% Function Specific Inputs:
%   'method'  - Text representing method utilized for ICA
%               e.g. {'binica', cudaica', 'runica'}
%               default: 'binica'
%
%   'rank' - Number representing the data rank of input data
%            default: getrank(double(EEG.data(:,min(3000,1:size(EEG.data,2)))))
%
%   'icadir' - Directory to store weight-related output files generated
%              during ICA
%              default: fullfile(pwd,'icaweights')
%               
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
defaultRank = getrank(double(EEG.data(:,min(3000,1:size(EEG.data,2)))));
defaultMethod = 'binica';
defaultIcaDir = fullfile(pwd,'icaweights');
% MATLAB built-in input validation
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'method',defaultMethod,@ischar);
addParameter(ip,'rank',defaultRank,@isnumeric);
addParameter(ip,'icadir',defaultIcaDir,@ischar);

parse(ip,EEG,varargin{:});

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

try
    scriptdir = pwd;
    if ~exist(ip.Results.icadir,'dir')
        mkdir(ip.Results.icadir);
    end
    
    cd(ip.Results.icadir)
    switch ip.Results.method
        case 'binica'
            EEG = pop_runica(EEG,'icatype',ip.Results.method, 'extended',1,'interupt','on','pca',ip.Results.rank);

        case 'cudaica'
            EEG = pop_runica(EEG, 'icatype',ip.Results.method,'options',{'extended',1,'pca',ip.Results.rank}, 'chanind', 1:length(EEG.chanlocs));
        
        case 'runica'
            EEG = pop_runica(EEG,'icatype',ip.Results.method, 'extended',1,'interupt','on','pca',ip.Results.rank);
    end
                
    EEG.icaact = eeg_getdatact(EEG, 'component', [1:size(EEG.icaweights,1)]);
    
    EEG = iclabel(EEG);
    
    EEG.vhtp.eeg_htpEegIcaEeglab.completed = 1;
    EEG.vhtp.eeg_htpEegIcaEeglab.method = ip.Results.method;
    EEG.vhtp.eeg_htpEegIcaEeglab.rank = ip.Results.rank;
    cd(scriptdir)
    
catch e
    throw(e)
end

EEG = eeg_checkset(EEG);
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
EEG.vhtp.eeg_htpEegIcaEeglab.qi_table = qi_table;
results = EEG.vhtp.eeg_htpEegIcaEeglab;
end

function tmprank2 = getrank(tmpdata)
 
    tmprank = rank(tmpdata);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Here: alternate computation of the rank by Sven Hoffman
    covarianceMatrix = cov(tmpdata', 1);
    [E, D] = eig (covarianceMatrix);
    rankTolerance = 1e-7;
    tmprank2=sum (diag (D) > rankTolerance);
    if tmprank ~= tmprank2
        fprintf('Warning: fixing rank computation inconsistency (%d vs %d) most likely because running under Linux 64-bit Matlab\n', tmprank, tmprank2);
        %tmprank2 = max(tmprank, tmprank2);
        tmprank2 = min(tmprank, tmprank2);
    end
end

