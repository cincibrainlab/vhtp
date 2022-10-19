function [EEG, results] = util_htpSaveOutput(EEG,outputDir,step)

    prior_file = EEG.filename;
    if ~isempty(EEG.subject)
        EEG.filename = [regexprep(EEG.subject,'.set','') '_' step '.set'];
    else
        EEG.subject = EEG.filename;
        EEG.filename = [regexprep(EEG.filename,'.set','') '_' step '.set'];
    end
    if isfield(EEG.vhtp,'stepPreprocessing')
        EEG.vhtp.stepPlacement = find(strcmp(step,fieldnames(EEG.vhtp.stepPreprocessing)));
        EEG.vhtp.stepPreprocessing.(step) = true;
        EEG.vhtp.prior_file = prior_file;
    else
        EEG.vhtp.stepPlacement = 1;
    end
    if ~exist(outputDir,'dir')
        mkdir(outputDir);
    end
    EEG.etc.lastOutputDir = outputDir;
    pop_saveset(EEG,'filename', EEG.filename, 'filepath', outputDir);
    results = fullfile(EEG.filename, EEG.filepath);
end

