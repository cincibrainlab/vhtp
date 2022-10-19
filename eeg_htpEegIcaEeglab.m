function [EEG, results] = eeg_htpEegIcaEeglab(EEG,varargin)
% Description: Perform Independent Component Analysis on data
% ShortTitle: Independent Component Analysis
% Category: Preprocessing
% Tags: Artifact
%
%% Syntax:
%   [ EEG, results ] = eeg_htpEegIcaEeglab( EEG, varargin )
%
%% Required Inputs:
%     EEG [struct]           - EEGLAB Structure
%
%% Function Specific Inputs:
%   'method'  - Text representing method utilized for ICA
%               default: 'binica' e.g. {'binica', cudaica', 'runica'}
%
%   'rank' - Number representing the data rank of input data
%            default: getrank(double(EEG.data))
%
%            getrank is local function to obtain effective rank of data.
%
%   'icadir' - Directory to store weight-related output files generated during ICA
%              default: fullfile(pwd,'icaweights')
%
%   'saveoutput' - Boolean representing if output should be saved when executing step from VHTP preprocessing tool
%                  default: false
%               
%   'outputdir' - text representing the output directory for the function
%                 output to be saved to
%                 default: '' 
%
%% Outputs:
%     EEG [struct]         - Updated EEGLAB structure
%
%     results [struct]   - Updated function-specific structure containing qi table and input parameters used
%
%% Disclaimer:
%  This file is part of the Cincinnati Visual High Throughput Pipeline
%  
%  Please see http://github.com/cincibrainlab
% 
%% Contact:
%   kyle.cullion@cchmc.org

if length(size(EEG.data))==3; defaultRank = getrank(double(reshape(EEG.data,EEG.nbchan,[]))); else; defaultRank = getrank(double(EEG.data)); end
defaultMethod = 'binica';
defaultIcaDir = fullfile(dir(which('vhtpPreprocessGui')).folder,'icaweights');
defaultSaveOutput = false;
defaultOutputDir = '';

% MATLAB built-in input validation
ip = inputParser();
ip.StructExpand = 0;
addRequired(ip, 'EEG', @isstruct);
addParameter(ip, 'method',defaultMethod,@ischar);
addParameter(ip,'rank',defaultRank,@isnumeric);
addParameter(ip,'icadir',defaultIcaDir,@ischar);
addParameter(ip, 'saveoutput', defaultSaveOutput,@islogical);
addParameter(ip,'outputdir', defaultOutputDir, @ischar);

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

if isfield(EEG,'vhtp') && isfield(EEG.vhtp,'inforow')
    EEG.vhtp.inforow.proc_ica_method = ip.Results.method;
    EEG.vhtp.inforow.proc_ica_dataRank = ip.Results.rank;
end

qi_table = cell2table({EEG.filename, functionstamp, timestamp}, ...
    'VariableNames', {'eegid','scriptname','timestamp'});
if isfield(EEG.vhtp.eeg_htpEegIcaEeglab,'qi_table')
    EEG.vhtp.eeg_htpEegIcaEeglab.qi_table = [EEG.vhtp.eeg_htpEegIcaEeglab.qi_table; qi_table];
else
    EEG.vhtp.eeg_htpEegIcaEeglab.qi_table = qi_table;
end
results = EEG.vhtp.eeg_htpEegIcaEeglab;

if ip.Results.saveoutput && ~isempty(ip.Results.outputdir)
    if isfield(EEG.vhtp, 'currentStep')
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,EEG.vhtp.currentStep);
    else
        EEG = util_htpSaveOutput(EEG,ip.Results.outputdir,'ica');
    end
elseif ip.Results.saveoutput && isempty(ip.Results.outputdir)
    fprintf('File was NOT SAVED due to no output directory parameter specified\n\n');
else
    fprintf('File was NOT SAVED due to save out parameter being false\n\n');
end

end

function tmprank2 = getrank(tmpdata)
 
    tmprank = rank(tmpdata);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Here: alternate computation of the rank by Sven Hoffman
    covarianceMatrix = cov(tmpdata', 1);
    [E, D] = eig (covarianceMatrix);
    rankTolerance = 1e-6; % Per Makoto Miyakoshi recommendation for potential stability
    tmprank2=sum (diag (D) > rankTolerance);
    if tmprank ~= tmprank2
        fprintf('Warning: fixing rank computation inconsistency (%d vs %d) most likely because running under Linux 64-bit Matlab\n', tmprank, tmprank2);
        %tmprank2 = max(tmprank, tmprank2);
        tmprank2 = min(tmprank, tmprank2);
    end
end

