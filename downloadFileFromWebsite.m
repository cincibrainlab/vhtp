function downloadFileFromWebsite(websitePath, unzipFolder)
    [vhtpdir, ~, ~] = fileparts(which(mfilename));
    addpath(fullfile(vhtpdir));
    % get current directory
    currentDir = vhtpdir;
    
    % create folder to save file in current directory
    folderName = '/Dependancies';
    currentDir = strcat(currentDir,folderName);
    cd(currentDir)
    if ~exist(fullfile(currentDir,'/', unzipFolder), 'dir')
        mkdir(unzipFolder);
    end
    
    % get filename from website path
    [~,filename,ext] = fileparts(websitePath);
    
    % check if file already exists in the download folder
    if exist(fullfile(currentDir, '/',unzipFolder), 'file') == 2
        disp('File already exists in download folder');
        return;
    end
    
    % download file from website
    disp('Downloading file...');
    options = weboptions('Timeout', 30);
    filename = websave(fullfile(currentDir,unzipFolder), websitePath,options);
    
    % check if file is zipped and unzip if necessary
    if strcmp(ext, '.zip')
        % create folder for unzipped files
        if ~exist(fullfile(currentDir,'/', unzipFolder), 'dir')
            mkdir(unzipFolder);
        end
        
        disp('Unzipping file...');
        unzip(filename, unzipFolder);
        delete(filename);
    end
    
    disp('Download complete!');
end


