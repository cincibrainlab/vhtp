function [EEG, results] = eeg_htpGraphBraphWU( EEG, A, chanlabels, freqlabels )
% eeg_htpGraphBraphWU() - Comprehensive graph measures using
%       Braph 1.0 toolbox. G is defined as a chan x chan x freq
%       matrix of WEIGHTED UNDIRECTED graphs.
%
% Dependencies:
%    Braph 1.0 Toolbox     https://github.com/softmatterlab/BRAPH
%       instructions: download source code and add to matlab path

% Usage:
%    >> [ EEG, results ] = eeg_htpGraphBraphWU( EEG, A, chanlabels, freqlabels )
%
% Require Inputs:
%     EEG           - EEG struct for table labels
%     A             - A is chan x chan x frequencies
%     chanlabels    - cell array of channel labels
%     freqlabels    - frequency vector
%
% Outputs:
%     EEG            - results stored in vhtp.eeg_htpGraphBraphWU struct
%     results.G       - G structure with graph features
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%
%  Contact: ernest.pedapati@cchmc.org

timestamp = datestr(now, 'yymmddHHMMSS'); % timestamp
functionstamp = mfilename; % function name for logging/output

% MATLAB built-in input validation
ip = inputParser();
addRequired(ip, 'EEG', @isstruct);
addRequired(ip, 'A', @isnumeric);
addRequired(ip, 'chanlabels', @iscell);
addRequired(ip, 'freqlabels', @isnumeric);

parse(ip, EEG, A, chanlabels, freqlabels);

G = struct();
G.chanlabels = chanlabels;
G.freqlabels = freqlabels;

nbchans                 = size(A,1);
nbfreqs                 = size(A,3);

prealloc_node           = @() zeros(nbchans, nbfreqs);
prealloc_global         = @() zeros(1,nbfreqs);

strength_node           = prealloc_node();
strength_global         = prealloc_global();

degree_node             = prealloc_node(); 
degree_global           = prealloc_global();

eccentricity_node       = prealloc_node(); 
eccentricity_global     = prealloc_global();
eccentricity_radius     = prealloc_global();
eccentricity_diameter   = prealloc_global();

pathlength_nodal        = prealloc_node(); 
pathlength_global       = prealloc_global();

triangles_nodal         = prealloc_node(); 

clustercoef_nodal       = prealloc_node(); 
clustercoef_global      = prealloc_global();

transitivity_global     = prealloc_global();

closeness_nodal         = prealloc_node();

betweeness_nodal        = prealloc_node();
betweeness_norm_nodal   = prealloc_node();

globaleff_nodal         = prealloc_node();
globaleff_global        = prealloc_global();

localeff_nodal          = prealloc_node();
localeff_global         = prealloc_global();

modularity_global       = prealloc_global();

structure_community     = prealloc_node();
structure_modularity    = prealloc_global();

part_coef               = prealloc_node();
assort_coef             = prealloc_global();
zscore                  = prealloc_node();
smallworld              = prealloc_global();

parfor ib = 1 : size( A, 3)

    WUgraph = GraphWU( A(:,:,ib) );

    % Calculate the strength using Braph methods

    % Strength
    strength_node(:,ib)  = WUgraph.strength();
    strength_global(ib) = WUgraph.measure(Graph.STRENGTHAV);

    % Degree
    degree_node(:,ib) = WUgraph.degree()';

    % Eccentricity
    eccentricity_node(:,ib)  = WUgraph.eccentricity();
    eccentricity_global(ib) = WUgraph.measure(Graph.ECCENTRICITYAV);
    eccentricity_radius(ib) = WUgraph.measure(Graph.RADIUS);
    eccentricity_diameter(ib) = WUgraph.measure(Graph.DIAMETER);

    % Path Length
    pathlength_nodal(:,ib)  = WUgraph.pl();
    pathlength_global(ib) = WUgraph.measure(Graph.CPL);

    % Triangles
    triangles_nodal(:,ib) = WUgraph.triangles();

    % Clustering coefficient
    [clustercoef_global(ib) , clustercoef_nodal(:,ib)] = WUgraph.cluster;

    % Transitivity
    transitivity_global(ib) = WUgraph.transitivity();

    % Closeness Centrality
    closeness_nodal(:,ib) = WUgraph.closeness();

    % Betweeness Centrality
    betweeness_nodal(:,ib) = WUgraph.betweenness();
    betweeness_norm_nodal(:,ib) = WUgraph.betweenness(true);

    % Global efficiency
    globaleff_nodal(:,ib) = WUgraph.geff();
    globaleff_global(ib) = WUgraph.measure(Graph.GEFF);

    % Local efficiency
    localeff_nodal(:,ib) = WUgraph.leff();
    localeff_global(ib) = WUgraph.measure(Graph.LEFF);

    % Modularity
    modularity_global(ib) = WUgraph.modularity();

    % Optimal Structure
    [structure_community(:,ib),  structure_modularity(ib)] = WUgraph.structure();

    % Within-module z-score
    zscore(:,ib) = WUgraph.zscore();

    % Participation coefficient
    part_coef(:,ib) = WUgraph.participation();

    % Assortativity coefficient
    assort_coef(ib) = WUgraph.assortativity();

    % Small-worldness
    smallworld(ib) = WUgraph.smallworldness();

end

G.strength_node           = strength_node        ;
G.strength_global         = strength_global      ;

G.degree_node             = degree_node          ;
G.degree_global           = degree_global        ;

G.eccentricity_node       = eccentricity_node    ;
G.eccentricity_global     = eccentricity_global  ;
G.eccentricity_radius     = eccentricity_radius  ;
G.eccentricity_diameter   = eccentricity_diameter;

G.pathlength_nodal        = pathlength_nodal     ;
G.pathlength_global       = pathlength_global    ;

G.triangles_nodal         = triangles_nodal      ;

G.clustercoef_nodal       = clustercoef_nodal    ;
G.clustercoef_global      = clustercoef_global   ;

G.transitivity_global     = transitivity_global  ;

G.closeness_nodal         = closeness_nodal      ;

G.betweeness_nodal        = betweeness_nodal     ;
G.betweeness_norm_nodal   = betweeness_norm_nodal;

G.globaleff_nodal         = globaleff_nodal      ;
G.globaleff_global        = globaleff_global     ;

G.localeff_nodal          = localeff_nodal       ;
G.localeff_global         = localeff_global      ;

G.modularity_global       = modularity_global    ;

G.structure_community     = structure_community  ;
G.structure_modularity    = structure_modularity ;

G.part_coef               = part_coef            ;
G.assort_coef             = assort_coef          ;

G.zscore                  = zscore               ;

G.smallworld              = smallworld           ;

csvout = {};
Gfields = fieldnames(G);
rowcount = 1;

CsvFields = {'setname','measure', 'type', 'chan', 'freq', 'value'};

for i = 1:numel(Gfields)

    current_field = Gfields{i};

    if ~ismember(current_field, {'chanlabels','freqlabels'})
        current_results = G.(current_field);
        vectorTest = isvector(current_results);

        if vectorTest
            % global results
            for gi = 1 : length(current_results)
                csvout{rowcount, 1} = EEG.setname;
                csvout{rowcount, 2} = current_field;
                csvout{rowcount, 3} = 'global';
                csvout{rowcount, 4} = 'global';
                csvout{rowcount, 5} = G.freqlabels(gi);
                csvout{rowcount, 6} = current_results(gi);
                rowcount = rowcount + 1;
            end

        else
            % nodal results
            for ci = 1 : size(current_results,1)
                for fi = 1 : size(current_results,2)
                    csvout{rowcount, 1} = EEG.setname;
                    csvout{rowcount, 2} = current_field;
                    csvout{rowcount, 3} = 'nodal';
                    csvout{rowcount, 4} = G.chanlabels{ci};
                    csvout{rowcount, 5} = G.freqlabels(fi);
                    csvout{rowcount, 6} = current_results(ci,fi);
                    rowcount = rowcount + 1;
                end
            end
        end
    end
end

EEG.vhtp.eeg_htpGraphBraphWU.summary_table = cell2table(csvout, "VariableNames", CsvFields);
EEG.vhtp.eeg_htpGraphBraphWU.G = G;
end
