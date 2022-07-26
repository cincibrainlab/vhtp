function [QI] = qi_Fixed_ERP()
clear QI;

QI.channel_montage.nettype = 'EGI128';
QI.channel_montage.netfile = 'chanfiles/GSN-HydroCel-129.sfp';
QI.file_duration.duration = 100;
QI.face_leads.present = 1;
QI.face_leads.handling = 'remove';
QI.face_leads.channelnums = [126,127];

%% PARAMETERS
QI.din_name.events = {'DIN6','DIN8'};
QI.din_interval.events = {'DIN8','DIN6'};
QI.din_interval.intervals = {1750,2000};
QI.din_interval.threshold = 60;
end

