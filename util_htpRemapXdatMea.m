function EEG =  util_htpRemapXdatMea( EEG )
    % Dictionary for correct mappings 
    mappingDict = containers.Map('KeyType', 'int32', 'ValueType', 'int32');
    % Current location : Correct location 
    mappingDict(1)  = 29;
    mappingDict(2)  = 27;
    mappingDict(3)  = 25;
    mappingDict(4)  = 23;
    mappingDict(5)  = 21;
    mappingDict(6)  = 19;
    mappingDict(7)  = 17;
    mappingDict(8)  = 30;
    mappingDict(9)  = 28;
    mappingDict(10) = 26;
    mappingDict(11) = 24;
    mappingDict(12) = 22;
    mappingDict(13) = 20;
    mappingDict(14) = 18;
    mappingDict(15) = 16;
    mappingDict(16) = 14;
    mappingDict(17) = 12;
    mappingDict(18) = 10;
    mappingDict(19) = 8;
    mappingDict(20) = 6;
    mappingDict(21) = 4;
    mappingDict(22) = 2;
    mappingDict(23) = 1;
    mappingDict(24) = 15;
    mappingDict(25) = 13;
    mappingDict(26) = 11;
    mappingDict(27) = 9;
    mappingDict(28) = 7;
    mappingDict(29) = 5;
    mappingDict(30) = 3;
    
    %Remapping the data to correct locations 
    % Create a temporary cell array to hold the reordered values
    reorderedArray = zeros(size(EEG.data), 'single');
    
    % Reorder the values based on the mapping
    for currentIdx = 1:size(EEG.data, 1)
        correctIdx = mappingDict(currentIdx);
        reorderedArray(correctIdx,:) = EEG.data(currentIdx,:);
    end
    EEG.data = reorderedArray;
end