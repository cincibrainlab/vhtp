function reader = allegoXDatFileReaderR2018()
    % ALLEGOXDATFILEREADER Reads signal and timestamp data from xdat files recorded by allego
    %  For use with Matlab R2018a or above
    %
    %   Returns a struct with the following methods:
    %   signalStruct = getAllegoXDatAllSigs(datasourceName, timeRange)
    %   signalStruct = getAllegoXDatPriSigs(datasourceName, timeRange)
    %   signalStruct = getAllegoXDatAuxSigs(datasourceName, timeRange)
    %   signalStruct = getAllegoXDatDinSigs(datasourceName, timeRange)
    %   signalStruct = getAllegoXDatDoutSigs(datasourceName, timeRange)
    %   timeRange = getAllegoXDatTimeRange(datasourceName)
    %
    %   timeRange: [1 2] array with the start and end time in seconds
    %   timeRange is optional for all get*Sigs methods, with the default being the full time range
    %
    %   datasourceName: string. The full data source name, including the path & excluding file extensions
    %
    %   signalStruct: struct with three fields: signals, timeStamps, timeSamples
    %   signals: [M N] matrix, where M is the number of channels, and N is the number of time samples
    %   timeStamps: [1 N] array with timeStamp data
    %   timeSamples: [1 N] array with time samples (seconds)

    % Copyright (c) 2019 NeuroNexus
    % 
    % Permission is hereby granted, free of charge, to any person obtaining a copy
    % of this file and associated documentation files (the "Software"), to deal
    % in the Software without restriction, including without limitation the rights
    % to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    % copies of the Software, and to permit persons to whom the Software is
    % furnished to do so, subject to the following conditions:
    % 
    % The above copyright notice and this permission notice shall be included in all
    % copies or substantial portions of the Software.
    % 
    % THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    % IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    % FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    % AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    % LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    % OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    % SOFTWARE.

    reader.getAllegoXDatAllSigs=@getAllegoXDatAllSigs;
    reader.getAllegoXDatPriSigs=@getAllegoXDatPriSigs;
    reader.getAllegoXDatAuxSigs=@getAllegoXDatAuxSigs;
    reader.getAllegoXDatDinSigs=@getAllegoXDatDinSigs;
    reader.getAllegoXDatDoutSigs=@getAllegoXDatDoutSigs;
    reader.getAllegoXDatTimeRange=@getAllegoXDatTimeRange;
end

function signalStruct = getAllegoXDatPriSigs(datasourceName, timerange) 
    signalStruct = getAllegoXDatAllSigs(datasourceName, timerange);
    shape = size(signalStruct.signals);
    if shape(1) > 32
        signalStruct.signals = signalStruct.signals(1:shape(1) - 6, :);
    end
end

function signalStruct = getAllegoXDatAuxSigs(datasourceName, timerange) 
    signalStruct = getAllegoXDatAllSigs(datasourceName, timerange);
    shape = size(signalStruct.signals);
    auxBegin = shape(1) - 5;
    auxEnd = auxBegin + 1;
    signalStruct.signals = signalStruct.signals(auxBegin:auxEnd, :);
end

function signalStruct = getAllegoXDatDinSigs(datasourceName, timerange) 
    signalStruct = getAllegoXDatAllSigs(datasourceName, timerange);
    shape = size(signalStruct.signals);
    dinBegin = shape(1) - 3;
    dinEnd = dinBegin + 1;
    signalStruct.signals = signalStruct.signals(dinBegin:dinEnd, :);
end

function signalStruct = getAllegoXDatDoutSigs(datasourceName, timerange) 
    signalStruct = getAllegoXDatAllSigs(datasourceName, timerange);
    shape = size(signalStruct.signals);
    doutBegin = shape(1) - 1;
    doutEnd = shape(1);
    signalStruct.signals = signalStruct.signals(doutBegin:doutEnd, :);
end

function signalStruct = getAllegoXDatAllSigs(datasourceName, timerange) 
    meta = readMeta(datasourceName);
    sampFreq = meta.status.samp_freq;

    timeStart = timerange(1);
    if (timeStart == -1)
        timeStart = meta.status.t_range(1);
    end

    timeEnd = timerange(2);
    if (timeEnd == -1)
        timeEnd = meta.status.t_range(2);
    end

    numSamples = timeEnd * sampFreq - timeStart * sampFreq;
    
    numSamples=floor(numSamples);
    tstampOffset = timeStart * sampFreq - meta.status.timestamp_range(1);

    shape = [meta.status.shape(2), numSamples];
    skipData = tstampOffset * shape(1) * 4;
    skipTstamp = tstampOffset * 8;

    fData = strcat(datasourceName, '_data.xdat');
    fTstamps = strcat(datasourceName, '_timestamp.xdat');

    fid = fopen(fData);
    fseek(fid, skipData, 'bof');
    %sigs = fread(fid, shape, '*single');
    sigs = zeros(32,shape(2),'single');
    %parfor i=1:32
    for i=1:32
        sigs(i,:) = fread(fid,shape(2),'*single',(shape(1)-1)*4)';
        fseek(fid,skipData+(i*4),'bof');
    end
    fclose(fid);

    fid = fopen(fTstamps);
    fseek(fid, skipTstamp, 'bof');
    timeStamps = fread(fid, [1, numSamples], '*int64');
    fclose(fid);

    timeSamples = cast(timeStamps, 'double') / sampFreq;

    signalStruct.signals = sigs;
    signalStruct.timeStamps = timeStamps;
    signalStruct.timeSamples = timeSamples;
end

function timerange = getAllegoXDatTimeRange(datasourceName)
    meta = readMeta(datasourceName);
    timerange = meta.status.t_range;
end

function meta = readMeta(datasourceName)
    fMeta = strcat(datasourceName, '.xdat.json');
    json = fileread(fMeta);
    meta = jsondecode(json);
end
