function [EEG] = eeg_htpEegIcaEeglab(EEG,varargin)
%EEG_HTPEEGBINICA Summary of this function goes here
%   Detailed explanation goes here

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

EEG.vhtp.ICA.timestamp = datestr(now,'yymmddHHMMSS'); % timestamp
EEG.vhtp.ICA.functionStamp = mfilename; % function name for logging/output

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
    
    EEG.vhtp.ICA.completed = 1;
    EEG.vhtp.ICA.method = ip.Results.method;
    EEG.vhtp.ICA.rank = ip.Results.rank;
    cd(scriptdir)
    
catch e
    throw(e)
end

EEG = eeg_checkset(EEG);

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
