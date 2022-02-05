function [EEG, results] = eeg_htpCalcPli( EEG, varargin )
% eeg_htpCalcPli() - calculates phase lag index on EEG set
%      Add 'help' comments here to be viewed on command line.
%
% Usage:
%    >> [ EEG, results ] = eeg_htpFunctionTemplate( EEG )
%
% Require Inputs:
%     EEG       - EEGLAB Structure
% Function Specific Inputs:
%     'option1' - description
%
% Common Visual HTP Inputs:
%     'bandDefs'   - cell-array describing frequency band definitions
%     {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 'alpha2', 10.5, 12.5;
%     'beta', 13, 30;'gamma1', 30, 55; 'gamma2', 65, 80; 'epsilon', 81, 120;}
%     'outputdir' - path for saved output files (default: tempdir)
%     
% Outputs:
%     EEG       - EEGLAB Structure with modified .etc.htp field
%     results   - etc.htp results structure or customized
%
%  This file is part of the Cincinnati Visual High Throughput Pipeline,
%  please see http://github.com/cincibrainlab
%    
%  Contact: kyle.cullion@cchmc.org

timestamp    = datestr(now,'yymmddHHMMSS');  % timestamp
functionstamp = mfilename; % function name for logging/output

% Inputs: Function Specific

% Inputs: Common across Visual HTP functions
defaultOutputDir = tempdir;
defaultBandDefs = {'delta', 2 ,3.5;'theta', 3.5, 7.5; 'alpha1', 8, 10; 
                   'alpha2', 10, 12; 'beta', 13, 30;'gamma1', 30, 55; 
                   'gamma2', 65, 80; 'epsilon', 81, 120; };

% MATLAB built-in input validation
ip = inputParser();   
addRequired(ip, 'EEG', @isstruct);
addParameter(ip,'outputdir', defaultOutputDir, @isfolder)
addParameter(ip,'bandDefs', defaultBandDefs, @iscell)
parse(ip,EEG,varargin{:});

outputdir = ip.Results.outputdir;
bandDefs = ip.Results.bandDefs;

% base output file can be modified with strrep()
outputfile = fullfile(outputdir, [functionstamp '_'  EEG.setname '_' timestamp '.mat']); 

% START: Signal Processing
% calculate power from first and last frequency from banddefs
if ndims(EEG.data) > 2 %#ok<ISMAT>
                EEG = o.EEG;
            EEG.data = reshape(EEG.data, size(EEG.data,1), size(EEG.data,2)*size(EEG.data,3));
            EEG.pnts   = size(EEG.data,2);
            EEG.trials = 1;
            EEG.event = [];
            EEG.epoch = [];
            EEG.urevent = [];
            
            o.EEG = eeg_checkset( EEG );
    %dat = permute(detrend3(permute(EEG.data, [2 3 1])), [3 1 2]);
    dat = EEG.data;
    cdat = reshape(dat, size(dat,1), size(dat,2)*size(dat,3));
else
    cdat = EEG.data;
end

if EEG.trials==1
    EEG.pnts = EEG.srate * 2;
    EEG.trials = floor(size(EEG.data,2)/EEG.pnts);
    duration = EEG.pnts*EEG.trials;
    EEG.data = reshape(EEG.data(:,1:duration),EEG.nbchan,EEG.pnts,EEG.trials);
    EEG.times = linspace(-EEG.pnts,EEG.pnts-2,EEG.pnts);
end



    % below code is designed for 3d EEG.data:

%     nfreq = 27;

%     freqs2use  = linspace(4,30,nfreq); % 4-30 Hz linear sampling with 1Hz step

    freqs2use  = [10.5:.5:12.5 30:5:55]; % 5+6

    nfreq = length(freqs2use);

    % wavelet and FFT parameters

    time          = -1:1/EEG.srate:1; % 2-sec

    half_wavelet  = (length(time)-1)/2; 

%     num_cycles    = linspace(3,10,length(freqs2use));

    num_cycles    = [3:.5:5,7.5:.5:10];

    n_wavelet     = length(time);

    n_data        = EEG.pnts*EEG.trials; % same with duration

    n_convolution = n_wavelet+n_data-1;



    combos = combnk({EEG.chanlocs(:).labels}',2); % channel pairs (unique)



    %% initialize

    dwpli_pair   = zeros(EEG.nbchan, EEG.nbchan, length(freqs2use)); 

    % wpli_pair   = zeros(EEG.nbchan, EEG.nbchan, length(freqs2use)); 

    tic % ~264 sec/4 min

    for pairi=1:length(combos)

        channel1 = combos{pairi,1};

        channel2 = combos{pairi,2};



        chanidx = zeros(1,2); 

        chanidx(1) = find(strcmpi(channel1,{EEG.chanlocs.labels}));

        chanidx(2) = find(strcmpi(channel2,{EEG.chanlocs.labels}));



        % data FFTs (1d for performance - Cohen's convention)

        data_fft1 = fft(reshape(EEG.data(chanidx(1),:,:),1,n_data),n_convolution); % 1x41000

        data_fft2 = fft(reshape(EEG.data(chanidx(2),:,:),1,n_data),n_convolution);



        for fi=1:length(freqs2use)  

            % create wavelet and take FFT

            s = num_cycles(fi)/(2*pi*freqs2use(fi));

            complex_wavelet = exp(2*1i*pi*freqs2use(fi).*time).*exp(-time.^2./(2*(s^2)));

            wavelet_fft = fft(complex_wavelet, n_convolution);



            % complex signal 1 from channel 1 via convolution

            convolution_f1 = wavelet_fft.*data_fft1;

            convolution_result1 = ifft(convolution_f1, n_convolution);

            convolution_result1 = convolution_result1(half_wavelet+1:end-half_wavelet); % 1x40000

            sig1 = reshape(convolution_result1, EEG.pnts, EEG.trials); % 1000(pnts)*40(trials)

            [y,f2,c] = cwt(reshape(EEG.data(chanidx(2),:,:),1,n_data),EEG.srate,'wavetype','morlet','s0',1);

            sigz = reshape(y, EEG.pnts, EEG.trials); % 1000(pnts)*40(trials)

            % complex signal 2 from channel 2 via convolution

            convolution_f2 = wavelet_fft.*data_fft2;

            convolution_result2 = ifft(convolution_f2, n_convolution);

            convolution_result2 = convolution_result2(half_wavelet+1:end-half_wavelet);

            sig2 = reshape(convolution_result2, EEG.pnts, EEG.trials); 



            % WPLIs (over time per trial)

            cdd = sig1 .* conj(sig2); % cross-spectrum: 1000(pnts)*133(trial)

            cdi = imag(cdd); % imaginary part of cross-spectrum: 1000(pnts)*133(trial)    



            imagsum = sum(cdi); % average (~sum) imaginary component: 1x133

            imagsumW = sum(abs(cdi)); % average (~sum) magnitude of the imaginary component: 1x133

            diagsum = sum(cdi.^2); % sum from diagonal entries only 1x133



            dwpli_pair(chanidx(1),chanidx(2),fi) = mean((imagsum.^2 - diagsum)./(imagsumW.^2 - diagsum), 2); 

    %         wpli_pair(chanidx(1),chanidx(2),fi) = mean((imagsum.^2) ./(imagsumW.^2), 2);

        end

    end

    toc

    % visual check

    % figure;imagesc(dwpli_pair(:,:,1))



    %% output csv - channel-wise dbwpli

    nbchan = EEG.nbchan; npair = (nbchan*nbchan-nbchan)/2; % 2278

    pair1 =[]; pair2 =[]; region1 = []; region2 =[];

    for q=2:nbchan

        pair2 = [pair2; repmat({num2str(q)},q-1,1)];

        region2 = [region2; repmat({EEG.chanlocs(q).labels},q-1,1)];

        for p=1:q-1

            pair1 = [pair1; {num2str(p)}];

            region1 = [region1; {EEG.chanlocs(p).labels}];

        end

    end

    Pair1 =[]; Pair2 =[];

    Pair1 = repmat(pair1,nfreq,1); Region1 = repmat(region1,nfreq,1);

    Pair2 = repmat(pair2,nfreq,1); Region2 = repmat(region2,nfreq,1);



    freq = []; 

    for i=1:length(freqs2use)

        freq = [freq;repmat(freqs2use(i),npair,1)];

    end



    dwpli = [];

    for k=1:nfreq 

        temp = dwpli_pair(:,:,k); 

        dwpli = [dwpli;temp(triu(true(size(temp)),1))];

    end



    ID = repmat({IDlist{n}}, npair*nfreq, 1);

    Group = repmat({EEG.group}, npair*nfreq, 1);

    

    sheet = [ID, Group, Pair1, Pair2, Region1, Region2, num2cell(freq), num2cell(dwpli)];

    header = ["ID" "Group" "label1" "label2" "region1" "region2" "freq_Hz" "dwpli"];

    T = cell2table(num2cell(sheet),'VariableNames',cellstr(header));

    filename = ['C:\data\2_P1_70FXS_71_TDC\signal\csv_storage\P1_',IDlist{n},'_signal_dwpli.csv'];

    writetable(T, filename,'WriteRowNames',true);

% END: Signal Processing

% QI Table
qi_table = cell2table({EEG.setname, functionstamp, timestamp}, 'VariableNames', {'eegid','function','timestamp'});

% Outputs: 
results = [];


end