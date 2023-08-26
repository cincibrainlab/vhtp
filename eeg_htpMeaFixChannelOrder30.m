% This function is used to fix the channel order of Neuronexus H32 MEA in SET format EEG data structure.
% The problem arises due to the incorrect order of probe channels in the data structure.
% This function reorders the probe channels in the EEG data structure.

function EEG = eeg_htpMeaFixChannelOrder30( EEG )

    % Save the original data in a temporary variable.
    tempData = EEG.data;
    
    % Create a valid channel location structure in JSON format.
    valid_chanlocs_json = '[{"labels":"Ch 01","sph_radius":1,"sph_theta":134,"sph_phi":-11.999999999999996,"theta":-134,"radius":0.56666666666666665,"X":-0.67947841839412348,"Y":0.70362049981358643,"Z":-0.22495105434386489,"ref":"","type":"","urchan":[]},{"labels":"Ch 02","sph_radius":1,"sph_theta":153,"sph_phi":8.0000000000000018,"theta":-153,"radius":0.45555555555555555,"X":-0.88233530994415432,"Y":0.44957229540410149,"Z":0.13917310096006547,"ref":"","type":"","urchan":[]},{"labels":"Ch 03","sph_radius":1,"sph_theta":171,"sph_phi":16.000000000000004,"theta":-171,"radius":0.41111111111111109,"X":-0.949426969338986,"Y":0.15037445916777609,"Z":0.27563735581699922,"ref":"","type":"","urchan":[]},{"labels":"Ch 04","sph_radius":1,"sph_theta":123,"sph_phi":0.99999999999999645,"theta":-123,"radius":0.49444444444444446,"X":-0.544556083851976,"Y":0.83854283435573385,"Z":0.017452406437283449,"ref":"","type":"","urchan":[]},{"labels":"Ch 05","sph_radius":1,"sph_theta":135,"sph_phi":20.999999999999996,"theta":-135,"radius":0.38333333333333336,"X":-0.66014105035920045,"Y":0.66014105035920057,"Z":0.35836794954530016,"ref":"","type":"","urchan":[]},{"labels":"Ch 06","sph_radius":1,"sph_theta":163,"sph_phi":40,"theta":-163,"radius":0.27777777777777779,"X":-0.73257194423373362,"Y":0.22396971972807536,"Z":0.64278760968653925,"ref":"","type":"","urchan":[]},{"labels":"Ch 07","sph_radius":1,"sph_theta":107,"sph_phi":13.000000000000004,"theta":-107,"radius":0.42777777777777776,"X":-0.2848782368720626,"Y":0.93179472702213151,"Z":0.20791169081775929,"ref":"","type":"","urchan":[]},{"labels":"Ch 08","sph_radius":1,"sph_theta":115,"sph_phi":36,"theta":-115,"radius":0.3,"X":-0.3419053558814254,"Y":0.7332184018470006,"Z":0.57357643635104594,"ref":"","type":"","urchan":[]},{"labels":"Ch 09","sph_radius":1,"sph_theta":146,"sph_phi":62.999999999999993,"theta":-146,"radius":0.15000000000000002,"X":-0.37637518186712421,"Y":0.2538682656974926,"Z":0.88294759285892688,"ref":"","type":"","urchan":[]},{"labels":"Ch 10","sph_radius":1,"sph_theta":81,"sph_phi":27.000000000000004,"theta":-81,"radius":0.35,"X":0.1393841289587629,"Y":0.88003675533505055,"Z":0.40673664307580026,"ref":"","type":"","urchan":[]},{"labels":"Ch 11","sph_radius":1,"sph_theta":74,"sph_phi":54,"theta":-74,"radius":0.2,"X":0.16201557273012504,"Y":0.56501544846619534,"Z":0.80901699437494745,"ref":"","type":"","urchan":[]},{"labels":"Ch 12","sph_radius":1,"sph_theta":40,"sph_phi":41.000000000000007,"theta":-40,"radius":0.27222222222222214,"X":0.578141080098311,"Y":0.485117967078927,"Z":0.65605902899050739,"ref":"","type":"","urchan":[]},{"labels":"Ch 13","sph_radius":1,"sph_theta":10,"sph_phi":51,"theta":-10,"radius":0.21666666666666667,"X":0.61975960023455456,"Y":0.10928033907444426,"Z":0.77714596145697079,"ref":"","type":"","urchan":[]},{"labels":"Ch 14","sph_radius":1,"sph_theta":23,"sph_phi":17,"theta":-23,"radius":0.40555555555555556,"X":0.88028316924362582,"Y":0.37365803647709639,"Z":0.29237170472273671,"ref":"","type":"","urchan":[]},{"labels":"Ch 15","sph_radius":1,"sph_theta":6,"sph_phi":22,"theta":-6,"radius":0.37777777777777777,"X":0.92210464439862283,"Y":0.09691710348444578,"Z":0.374606593415912,"ref":"","type":"","urchan":[]},{"labels":"Ch 16","sph_radius":1,"sph_theta":-6,"sph_phi":22,"theta":6,"radius":0.37777777777777777,"X":0.92210464439862283,"Y":-0.09691710348444578,"Z":0.374606593415912,"ref":"","type":"","urchan":[]},{"labels":"Ch 17","sph_radius":1,"sph_theta":-21,"sph_phi":17,"theta":21,"radius":0.40555555555555556,"X":0.89278740193327311,"Y":-0.3427089745348918,"Z":0.29237170472273671,"ref":"","type":"","urchan":[]},{"labels":"Ch 18","sph_radius":1,"sph_theta":-10,"sph_phi":51,"theta":10,"radius":0.21666666666666667,"X":0.61975960023455456,"Y":-0.10928033907444426,"Z":0.77714596145697079,"ref":"","type":"","urchan":[]},{"labels":"Ch 19","sph_radius":1,"sph_theta":-39,"sph_phi":41.000000000000007,"theta":39,"radius":0.27222222222222214,"X":0.58651950234301287,"Y":-0.47495412815485349,"Z":0.65605902899050739,"ref":"","type":"","urchan":[]},{"labels":"Ch 20","sph_radius":1,"sph_theta":-77,"sph_phi":54,"theta":77,"radius":0.2,"X":0.1322229122309666,"Y":-0.57272035435602286,"Z":0.80901699437494745,"ref":"","type":"","urchan":[]},{"labels":"Ch 21","sph_radius":1,"sph_theta":-83,"sph_phi":24.000000000000004,"theta":83,"radius":0.36666666666666664,"X":0.11133318509365875,"Y":-0.90673602833257383,"Z":0.4539904997395468,"ref":"","type":"","urchan":[]},{"labels":"Ch 22","sph_radius":1,"sph_theta":-146,"sph_phi":62,"theta":146,"radius":0.15555555555555556,"X":-0.38920956479563679,"Y":-0.26252516629119138,"Z":0.89100652418836779,"ref":"","type":"","urchan":[]},{"labels":"Ch 23","sph_radius":1,"sph_theta":-114,"sph_phi":34.999999999999993,"theta":114,"radius":0.30555555555555558,"X":-0.3331791526627837,"Y":-0.74833262917885923,"Z":0.58778525229247314,"ref":"","type":"","urchan":[]},{"labels":"Ch 24","sph_radius":1,"sph_theta":-106,"sph_phi":11.999999999999996,"theta":106,"radius":0.43333333333333335,"X":-0.26961401826500792,"Y":-0.9402558215593757,"Z":0.22495105434386506,"ref":"","type":"","urchan":[]},{"labels":"Ch 25","sph_radius":1,"sph_theta":-162,"sph_phi":40,"theta":162,"radius":0.27777777777777779,"X":-0.72855155939999616,"Y":-0.23672075137025703,"Z":0.64278760968653925,"ref":"","type":"","urchan":[]},{"labels":"Ch 26","sph_radius":1,"sph_theta":-133,"sph_phi":20.999999999999996,"theta":133,"radius":0.38333333333333336,"X":-0.63670031985753939,"Y":-0.68277750067793253,"Z":0.35836794954530016,"ref":"","type":"","urchan":[]},{"labels":"Ch 27","sph_radius":1,"sph_theta":-121,"sph_phi":0.99999999999999645,"theta":121,"radius":0.49444444444444446,"X":-0.51495963211660256,"Y":-0.85703674997043233,"Z":0.017452406437283449,"ref":"","type":"","urchan":[]},{"labels":"Ch 28","sph_radius":1,"sph_theta":-171,"sph_phi":16.000000000000004,"theta":171,"radius":0.41111111111111109,"X":-0.949426969338986,"Y":-0.15037445916777609,"Z":0.27563735581699922,"ref":"","type":"","urchan":[]},{"labels":"Ch 29","sph_radius":1,"sph_theta":-153,"sph_phi":8.0000000000000018,"theta":153,"radius":0.45555555555555555,"X":-0.88233530994415432,"Y":-0.44957229540410149,"Z":0.13917310096006547,"ref":"","type":"","urchan":[]},{"labels":"Ch 30","sph_radius":1,"sph_theta":-132,"sph_phi":-12.999999999999993,"theta":132,"radius":0.57222222222222219,"X":-0.65198083226766412,"Y":-0.72409807174522123,"Z":-0.20791169081775929,"ref":"","type":"","urchan":[]}]';
    
    % Decode the JSON format to a MATLAB structure.
    valid_chanlocs = jsondecode(valid_chanlocs_json)';
    
    % Replace the EEG channel locations with the valid channel locations.
    EEG.chanlocs = valid_chanlocs;
    
    % Loop through all channels in the EEG data structure.
    for i = 1: EEG.nbchan
        % Get the index of the corrected channel location.
        fixed_chanlocsIndex = str2num( edf2meaLookupTest ( (i) ));
        
        % Reorder the data using the corrected channel location index.
        EEG.data(fixed_chanlocsIndex,:) = tempData(i,:);
    end

end


% This function creates a mapping between the EDF channel and the MEA channel.
% The mapping is based on the table provided by Carrie Jonak (Binder Lab at UC Riverside, California) 
% on March 2nd 2020.

function meachan = edf2meaLookupTest( edfchan )

    % Define the MEA channel values.

    meaValueSet = {'1', '2','3','4','5','6','7','8','9', ...
    '10', '11', '12', '13','14','15','16','17','18','19', ...
    '20','21','22','23','24','25','26','27','28','29', ...
    '30'};

    % Define the EDF channel keys.

    edfKeySet = {23,22,30,21,29,20,28,19,27,18,26,17,25,...
    16,24,15,7,14,6,13,5,12,4, ...
    11,3,10,2,9,1,8};

    % Create a mapping between the EDF channel and the MEA channel.
    chanMap = containers.Map(edfKeySet, meaValueSet);

    % Get the MEA channel value from the EDF channel key.
    meachan = chanMap ( edfchan);

end