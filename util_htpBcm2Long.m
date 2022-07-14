function long_table = util_htpBcm2Long( bcm, chan_labels, freq_vector )
% usage: longtable = util_htpBcm2Long( bcm, chan_labels, freq_vector )
% input:
%  bcm - 3d matrix in the form chan x chan x freq
%  chan_labels - cell array of channel labels
%  freq_vector - numeric vector of frequencies

% 1. setup dimension variables
nchan = numel(chan_labels); % number of channels
nfreq = numel(freq_vector); % number of frequencies
bcm_dims  = size(bcm);      % size of bcm

% 2. create reshape bcm into long format (rows:
bcm_long = reshape(bcm, [], 1);

% 3. create channel cube to reshape
chan_mat = fillChanMatrix( chan_labels );
chan_cube = repmat(chan_mat,[1 1 nfreq]);
chan_long = reshape(chan_cube, [], 1);

% 4. create frequency cube to reshape
freq_cube = makeFreqCube( freq_vector, nchan );
freq_long = reshape(freq_cube, [], 1);

long_table = table(chan_long, freq_long, bcm_long, 'VariableNames', {'chan1_chan2', 'freq', 'bcm_long'});

    function chanMatrix = fillChanMatrix( chanLabels )
        channo = numel(chanLabels);
        single_chan_square = cell(channo,channo);

        for c1 = 1 : channo
            for c2 = 1 : channo
                chanMatrix{c1,c2} =  sprintf('%s_%s', chan_labels{c1}, chan_labels{c2});
            end
        end
    end

    function freqCube = makeFreqCube( freqVector, channo )
        assert(isnumeric(freqVector));
        freqSlices = arrayfun( @(x) repmat(x, [channo channo]), freqVector,'uni',0);
        freqCube = cat(3,freqSlices{:});
    end

end

