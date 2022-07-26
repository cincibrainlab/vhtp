function [QI] = qi_Resting()
clear QI;

%%REQUIRED COMMON QI PARAMETERS
QI.channel_montage.nettype = 'EGI128';
QI.channel_montage.netfile = 'chanfiles/GSN-HydroCel-129.sfp';
QI.file_duration.duration = 100;
QI.face_leads.present = 1;
QI.face_leads.handling = 'remove';
QI.face_leads.channelnums = [126,127];

%% PARAMETERS
QI.din_name.events = {'DIN8','DIN6'};
QI.din_interval.events = {'DIN8','DIN6'};
QI.din_interval.intervals = {2000,1750};
QI.din_interval.threshold = 60;

QI.saveoutput = 1;

end

