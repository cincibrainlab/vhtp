function util_htpCreateRFile( action, outputdir, functionname )

[note] = htp_utilities();
note('R utilities for Visual High Throughput Pipeline');

if ~nargin ==0
    switch action
        case 'create_project'
            fname = fullfile(outputdir, 'htp_RProject.Rproj');
            % Create R Project in Results Directory
            fid = fopen( fname, 'wt' );
            fprintf(fid, "Version: 1.0\n\n" + ...
                "RestoreWorkspace: Default\n" + ...
                "SaveWorkspace: Default\n" + ...
                "AlwaysSaveHistory: Default\n\n" + ...
                "EnableCodeIndexing: Yes\n" + ...
                "UseSpacesForTab: Yes\n" + ...
                "NumSpacesForTab: 2\n" + ...
                "Encoding: UTF-8\n\n" + ...
                "RnwWeave: Sweave\n" + ...
                "LaTeX: pdfLaTeX\n");
            fclose(fid);
        case 'create_import'
            % Create R Project in Results Directory
            if isempty(functionname)
                [fpath, ~, ~] = fileparts(outputfile);
                fpattern = sprintf('*%s.csv', functionname);

                str <- sprintf('pow_data_raw <- dir(path=%s, pattern = ''*eeg_htpCalcRestPower.csv'', full.names=TRUE) %>% map(read_csv) %>% reduce(rbind)', results_dir)

                outputfile = fullfile(fpath,fpattern);

                fid = fopen( outputfile, 'wt' );
                fprintf(fid, "library(tidyverse)\n\n" + ...
                    str);

                fclose(fid);
            end
        otherwise
            fprintf('\nutil_htpCreateRFile - vhtp R utilities\n');
            fprintf('--------------------------------------\n');
            fprintf('Invalid action. See comments. \n\n')
    end
else
    note('usage: util_htpCreateRFile( action, outputdir, functionname);');
    note(sprintf('\taction 1: ''create_project'''));
    note(sprintf('\taction 2: ''create_import'''));
end

    function note = htp_utilities()
            note        = @(msg) fprintf('%s: %s\n', mfilename, msg );
    end

end