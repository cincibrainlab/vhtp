function [signalStruct,timeRange,jsonData] = xdatImport(xdat_filename)
    % x=allegoXDatFileReaderR2018a();
    x=allegoXDatFileReader();
    timeRange = x.getAllegoXDatTimeRange(xdat_filename);
     signalStruct.PriSigs = x.getAllegoXDatPriSigs(xdat_filename,timeRange);
    %signalStruct.PriSigs = x.getAllegoXDatAllSigs(xdat_filename, timesRange);
    str = fileread([xdat_filename '.xdat.json']); % dedicated for reading files as text
    jsonData = jsondecode(str);

    H32Map = jsonData.sapiens_base.biointerface_map;
    H32Map = rmfield(H32Map, 'samp_freq');
    H32Map = rmfield(H32Map, 'sig_units');
    
    % writetable(struct2table(H32Map),'NeuroNexusMouseEEGv2H32_Map.csv');

    clear x;
    clear str;
end

