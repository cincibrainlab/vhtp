function [QI] = qi_Fixed_ERP()
clear QI;

QI.channel_montage.nettype = 'EGI128';
QI.file_duration.duration = 100;
QI.face_leads.present = 1;
QI.face_leads.handling = 'remove';
QI.face_leads.channelnums = [126,127];

%% PARAMETERS
QI.din_name.events = {'DIN8','KBPR'};
QI.din_interval.intervals = {1500,2000};
QI.custom_trial.event = 'DIN8';
QI.custom_trial.number = 50;
end

