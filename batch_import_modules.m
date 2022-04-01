function status = batch_import_modules(repos)
%BATCH_IMPORT_MODULES  Use `repos` struct to init a bunch of git submodules.
%
% Must have git installed and on system PATH for this to work.
%
% Syntax:
%   io.batch_import_repos(repos, destination_folder);
%
% Inputs:
%   repos - Struct array returned by `io.read_repos_list`
%
%   Will clone each of the remote repos to local destination as specified
%   by each of the subfolder names directly under the "repositories:" level
%   of the yaml-like `*.repos` file.
%
% See also: Contents, io.read_repos_list

CMD_EXPR = 'git submodule add --force %s "%s"';

fprintf(1, '\t--\tInitializing <strong>%d</strong> repos as submodules\t--\n\n', numel(repos));

% Iterate on repos

for repo = repos
%     dest = fullfile(pwd, repo.name);
%     if exist(dest, 'dir') == 0
%         try %#ok<TRYNC>
%             mkdir(dest);
%         end
%     end
    status = system(sprintf(CMD_EXPR, repo.url, repo.name), '-echo');
end

end