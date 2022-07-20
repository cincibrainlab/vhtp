function [QI] = qi_Resting()
clear QI;

%%REQUIRED COMMON QI PARAMETERS
QI.channel_montage.nettype = 'MEA30';
QI.channel_montage.netfile = 'chanfiles/Mea_atlas-30_dict.csv';
QI.file_duration.duration = 100;
QI.face_leads.present = 1;
QI.face_leads.handling = 'remove';
QI.face_leads.channelnums = [126,127];

%% PARAMETERS
QI.din_name.events = {'DIN7','DIN6'};
QI.din_interval.events = {'DIN8','DIN6'};
QI.din_interval.intervals = {1750,1750};
QI.din_interval.threshold = 60;

end

