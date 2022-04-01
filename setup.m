clc;
if exist('+io/.is_installed', 'file')~=0
    disp('Submodules have already been installed, no need to run setup.');
    return;
else
    disp('Beginning setup.');
end
system('git config --local core.sshCommand "ssh -F /c/Users/Max/.ssh/.config_passless"');
system('git config --list', '-echo');
% system('eval "$(ssh-agent -s)"');
% system('ssh-add /c/Users/Max/.ssh/.config_passless');
repos = io.read_repos_list('+io/required_modules.repos');
status = io.batch_import_modules(repos);
if status == 0
    fid = fopen('+io/.is_installed', 'w');
    fprintf(fid, 'true\n');
    fclose(fid);
    fprintf(1, 'Installation <strong>successful.</strong>\n\n'); 
else
    fprintf(1, 'Installation <strong>unsuccessful.</strong>\n\n'); 
end
