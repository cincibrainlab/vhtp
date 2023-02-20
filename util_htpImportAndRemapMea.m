function EEG =  util_htpImportAndRemapMea( dataFile )
% Description: Import MEA EDF file
% Category: Preprocessing
% Tags: Import

note = @(msg) fprintf('%s: %s\n', mfilename, msg );
if ~isempty(regexp(dataFile,'xdat','match')); xdatFile = true; else; xdatFile = false; end

if xdatFile
    try [signalStruct,timeRange,jsonData] = xdatImport(extractBefore(dataFile,'_data'));
        EEG = eeg_emptyset;
        EEG.data = signalStruct.PriSigs.signals;
        EEG.pnts = size(EEG.data,2);
        EEG.nbchan = size(EEG.data,1);
        EEG.srate = jsonData.status.samp_freq;
        EEG.x_min = timeRange(1);
        EEG.x_max = timeRange(2);
        note('Import XDAT.');
        EEG = eeg_checkset(EEG);
        for i = 1 : EEG.nbchan       
            EEG.chanlocs( i ).labels = jsonData.sapiens_base.biointerface_map.ntv_chan_name(i);
            EEG.chanlocs( i ).type = 'EEG';
            EEG.chanlocs( i ).urchan = jsonData.sapiens_base.biointerface_map.ntv_chan_idx(i);
        end
        EEG = eeg_checkchanlocs(EEG);
    catch, error('Check if EEGLAB is installed'); end
else
    try EEG = pop_biosig( dataFile );
        note('Import EDF.')
    catch, error('Check if EEGLAB is installed'); end
end

if EEG.nbchan == 33
    EEG = pop_select( EEG, 'nochannel', [2,32,33]);
elseif EEG.nbchan == 32
    EEG = pop_select( EEG, 'nochannel', [2,32]);
end

note('Remove irrelevant channels (reference and Piezo).')

try
    load('mea3d.mat', 'chanlocs');
catch
    error('mea3d.mat file missing');
end

note('Load unordered chanlocs.')

if xdatFile
    searchSubstring = 'E%d';
else
    searchSubstring = 'Chan %d'; 
end

for i = 1 : EEG.nbchan
    if xdatFile

        fixed_chanlocs{i} = xdat2meaLookup( num2str( ...
            sscanf(EEG.chanlocs(i).labels, searchSubstring) ) );
    else
        fixed_chanlocs{i} = edf2meaLookup( num2str( ...
            sscanf(EEG.chanlocs(i).labels, searchSubstring) ) );
    end

    new_chanlocs_index(i) = find(strcmp( fixed_chanlocs{i}, {chanlocs.labels} ));
end

note('Look up correct channel order. Create new ordered index.')

chanlocs = chanlocs(new_chanlocs_index);

note('Reorder channel map.')

% chanlocs(31) = [];
EEG.chanlocs = chanlocs;
EEG = eeg_checkset( EEG );

note('Assign chanlocs to imported EDF and check set.')

    function meachan = edf2meaLookup( edfchan )
        
        meaValueSet = {'Ch 01',	'Ch 02',	'Ch 03',	'Ch 04',	'Ch 05',	'Ch 06',	'Ch 07',	'Ch 08',	'Ch 09', ...
            'Ch 10',	'Ch 11', 'Ch 12',	'Ch 13',	'Ch 14',	'Ch 15',	'Ch 16',	'Ch 17',	'Ch 18',	'Ch 19', ...
            'Ch 20',    'Ch 21',	'Ch 22',	'Ch 23',	'Ch 24',	'Ch 25',	'Ch 26',	'Ch 27',	'Ch 28',	'Ch 29', ...
            'Ch 30'};

        edfKeySet = {'30',	'28',	'26',	'24',	'22',	'20',	'18',	'31',	'29',	'27',	'25',	'23',	'21',	'19', ...
            '17',	'15',	'13',	'11',	'9',	'7',	'5',	'3',	'1',	'16',	'14',	'12',	'10',	'8',	'6', ...
            '4'};

        chanMap = containers.Map(edfKeySet, meaValueSet);

        meachan = chanMap( edfchan );

    end

    function meachan = xdat2meaLookup(xdatchan)
        meaValueSet = {'Ch 01',	'Ch 02',	'Ch 03',	'Ch 04',	'Ch 05',	'Ch 06',	'Ch 07',	'Ch 08',	'Ch 09', ...
            'Ch 10',	'Ch 11', 'Ch 12',	'Ch 13',	'Ch 14',	'Ch 15',	'Ch 16',	'Ch 17',	'Ch 18',	'Ch 19', ...
            'Ch 20',    'Ch 21',	'Ch 22',	'Ch 23',	'Ch 24',	'Ch 25',	'Ch 26',	'Ch 27',	'Ch 28',	'Ch 29', ...
            'Ch 30'};

        xdatKeySet = {'30',	'28',	'26',	'24',	'22',	'20',	'18',	'31',	'29',	'27',	'25',	'23',	'21',	'19', ...
            '17',	'15',	'13',	'11',	'9',	'7',	'5',	'3',	'1',	'16',	'14',	'12',	'10',	'8',	'6', ...
            '4'};

        chanMap = containers.Map(xdatKeySet, meaValueSet);

        meachan = chanMap( xdatchan );
    end
end
