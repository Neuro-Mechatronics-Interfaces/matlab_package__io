function batch_import_repos(repos, destination_folder)
%BATCH_IMPORT_REPOS  Use `repos` struct to clone bunch of git repos.
%
% Must have git installed and on system PATH for this to work.
%
% Syntax:
%   io.batch_import_repos(repos, destination_folder);
%
% Inputs:
%   repos - Struct array returned by `io.read_repos_list`%
%   destination_folder - The output folder where repos should be cloned.
%
%   Will clone each of the remote repos to local destination as specified
%   by each of the subfolder names directly under the "repositories:" level
%   of the yaml-like `*.repos` file.
%
% See also: Contents, io.read_repos_list

CMD_EXPR = "git clone %s %s";

if nargin < 2
    % This should also be specified so things go where you want them.
    destination_folder = "C:\dev\ros2\galactic\src";
end

fprintf(1, '\t--\tCloning <strong>%d</strong> repos into <strong>%s</strong>\t--\n\n', ...
    numel(repos), destination_folder);
if exist(destination_folder, 'dir') == 0
    try %#ok<TRYNC>
        mkdir(destination_folder);
    end
end

% Iterate on repos
for repo = repos
    dest = fullfile(destination_folder, repo.name);
    if exist(dest, 'dir') == 0
        try %#ok<TRYNC>
            mkdir(dest);
        end
    end
    system(sprintf(CMD_EXPR, repo.url, dest), '-echo');
end

end