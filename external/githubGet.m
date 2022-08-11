function [Output, GetRequest] = githubGet(UserName, RepoName, FilePath, OutputType, Optn)
% Reads or downloads a file from a GitHub repo, even a private one. 
% Uses MATLAB built-in functions called webread and websave that rely on REST API.
% 
% Required arguments
%     UserName (1,:) char   : GitHub's username
%     RepoName (1,:) char   : The repo name
%     FilePath (1,:) char   : The file name or its relative path if it resides in a folder
%     OutputType (1,:) char : 'read' (default), 'save' or 'status'; 'read' returns contents of the file, 'save' downloads the file.
%                              'status' returns whether the repo (FilePath = '') or a file in the repo (FilePath = <FileName>) exists (logical)
% 
% Optional arguments (name-value pair)   
%     Token (1,:) char      : Personal Access Token (PAT), generate from https://github.com/settings/tokens. Required for a private repo. 
%     Branch (1,:) char     : If left blank, the default branch will be used (main or master)
%
% Written by Adib Yusof (2022) | adib.yusof@upm.edu.my
arguments
    UserName    (1,:) char
    RepoName    (1,:) char
    FilePath    (1,:) char
    OutputType  (1,:) char {mustBeMember(OutputType, {'save', 'read', 'status'})} = 'read'
    Optn.Token  (1,:) char = ''
    Optn.Branch (1,:) char = ''
end
BaseAPI = 'https://api.github.com';
URL = [BaseAPI, '/repos/', UserName, '/', RepoName, '/contents/', FilePath];
if strcmp(OutputType, 'status') && isempty(char(FilePath))
    URL = [BaseAPI, '/repos/', UserName, '/', RepoName];
else
    if ~isempty(Optn.Branch)
        URL = [URL, '?ref=', Optn.Branch];
    end
end
HeaderFields = {};
if ~isempty(Optn.Token)
    HeaderFields = {'Authorization', ['token ', Optn.Token]};
end
HeaderFields = [HeaderFields; {'Accept', 'application/vnd.github.v3+json'}];
Options = weboptions(HeaderFields = HeaderFields);
try GetRequest = webread(URL, Options);
    switch OutputType
        case 'read'
            Output = char(matlab.net.base64decode(GetRequest.content));
        case 'save'
            Output = websave(FilePath, GetRequest.download_url, Options);
        case 'status'
            Output = true;
    end
catch
    GetRequest = false;
    Output = false;
end
end
