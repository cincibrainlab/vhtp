%Class:
% Use as
%    define EEG system in config/cfg_htpEeegSystems.txt
%    see [ electrodeConfigClass( n ) ] = htp_readEegSystems( filename )
%     for text file format and import instructions.
%
% Copyright © 2019  Cincinnati Children's (Pedapati Lab)
%
%Methods:
% electrodeConfigClass
% Use as
%    [ o ] = electrodeConfigClass
%
%    The output is the electrodeConfigClass object with the default EEG 
%    system configuration set.
%
% setSystemProperties
% Use as
%    [ o ] = setSystemProperties( o, xmlData )
%
%    The input parameter xmlData is an xmlfile that was converted into a 
%    list object with various EEG system configuration  options as 
%    properties.  The output, if the function is not self-invoked, is the 
%    electrodeConfigClass object with each EEG system configuration property
%    updated according to the properties of the xml list originally 
%    passed in.
%
% This file is part of High Throughput Pipeline (HTP), see 
% https://bitbucket.org/eped1745/htp_stable/src/master/
% Contact: ernest.pedapati@cchmc.org

% Copyright (C) 2019  Cincinnati Children's (Pedapati Lab)

classdef electrodeConfigClass < handle
    %Class to define electrode configuration
    %based upon user's specific needs.
    %Electrode configuration can be loaded from a CSV file.
    properties
        
        cfgfile;
        
        
        net_displayname;
        net_name;
        net_modelno;
        net_graphic;
        net_file;
        net_filter;
        net_regions;
        net_nochans;
        net_desc;
        net_notes;
        net_hdmfile;
        net_mrifile;
        net_elcfile;
        net_coord_transform;
        net_bst_channelreplace;
        net_bst_filetype;
        net_surficeMni;
        
    end
    
    methods
        %Constructor of electrodeConfigClass that sets the default
        %EEG system configuration as the cfg_htpEegSystems.xml file
        function o = electrodeConfigClass
            
            o.cfgfile = 'config/cfg_htpEegSystems.xml';
            
        end
        
        %Sets the electrodeConfigClass object's various properties
        %regarding the Eeg system such as name, filtering, regions, etc.
        function o = setSystemProperties( o, xmlData )
            
            o.net_displayname = xmlData.net_displayname;
            o.net_name = xmlData.net_name;
            o.net_modelno;
            o.net_graphic;
            o.net_file = xmlData.net_file;
            o.net_filter = xmlData.net_filter;
            o.net_regions = xmlData.net_regions;
            o.net_nochans = xmlData.net_regions;
            o.net_desc;
            o.net_notes;
            o.net_hdmfile = xmlData.hdmfile;
            o.net_mrifile = xmlData.mrifile;
            o.net_elcfile = xmlData.elcfile;
            o.net_coord_transform = xmlData.coord_transform; 
            o.net_bst_channelreplace = xmlData.bst_channelreplace;
            o.net_bst_filetype = xmlData.bst_filetype;
            o.net_surficeMni = xmlData.surficeMNI;
        end
        
    end
end

