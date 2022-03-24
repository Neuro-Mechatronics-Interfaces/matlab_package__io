function repos = read_repos_list(repos_file)
%READ_REPOS_LIST  Get list of all repos in `.repos` file.
%
% Syntax:
%   io.read_repos_list(repos_file);
%
% Inputs:
%   repos_file - Full filename of `*.repos` file with following yaml-like
%                format:
%                   
%                   repositories:
%                       folder1/repo1>:
%                           type: git
%                           url: https://url/folder1/repo1.git
%                           version: galactic
%                       folder1/repo2:
%                           type: git
%                           url: https://url/folder1/repo2.git
%                           version: galactic
%                       folder2/another_repo:
%                           type: git
%                           url: https://another_url/another_repo.git
%                       ...etc
%
% Output:
%   repos - Struct array that is pulled in from repos list file.
%
% See also: Contents

if nargin < 1
    % This should be your local `repos` file
    repos_file = "D:\__Assets__\.lists\ros2.repos";
else
    if exist(repos_file, 'file')~=2
        error('No such file found: <strong>%s</strong>', repos_file);
    end
end

% Import data and close repos list file
fid = fopen(repos_file, 'r');
s = textscan(fid, '%s');
fclose(fid);

% Arrange data and check it's the correct syntax
data = s{1,1}(2:end);
if rem(numel(data), 7) ~= 0
    % Should be even multiple of 7 after removing first cell
    % ("repositories:") -- order should always go
    %       "local_folder/local_repo:"
    %       then 6 cells that are pairs of "type:", "url:", and "version:"
    %       along with their corresponding value.
    error('Bad format - missing a field somewhere in repos file or delimiter for newline is incorrect?');
end

% Iterate on each field to pull in the repos struct
idx = 0;
N = numel(data) / 7;
repos = struct('name', cell(1, N), 'type', cell(1, N), 'url', cell(1, N), 'version', cell(1, N));
for k = 1:7:(numel(data)-6)
     idx = idx + 1;
     repos(idx).name = strip(data{k}, 'right', ':');
     for kk = 1:2:5
          iField = k + kk;
          f = strip(data{iField}, 'right', ':');
          repos(idx).(f) = data{iField+1};
     end
end

end