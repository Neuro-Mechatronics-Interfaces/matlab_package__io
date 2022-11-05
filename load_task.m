function machine = load_task(task)
%LOAD_TASK  Load task state machine.
%
% Syntax:
%   machine = io.load_task(task);
%
% Example:
%   machine = io.load_task('Wrist');
%
% Note:
%   The .yaml file name pattern should be:
%       <workspace folder>/<task name>_Task_Config.yaml

% Handle input string
task = string(task);

if contains(task, ".yaml")
    if ~contains(task, "_Task_Config")
        task = strrep(task, ".yaml", "_Task_Config.yaml");
    end
else
    task = strrep(task, "_Task_Config", "");
    F = dir(strcat(string(task), "*_Task_Config.yaml"));
    if isempty(F)
        error("Could not find _Task_Config.yaml file for %s. Is it in another folder?", task);
    end
    if numel(F) > 1
        fig = uifigure(...
            'Name', 'Select TASK machine .yaml file', ...
            'Position', [350   250   350   475], ...
            'Color', 'w', ...
            'DeleteFcn', @(src,~)selection_figure_closer(src, F));
        uidropdown(fig, 'Items', {F.name}, ...
            'ItemsData', 1:numel(F), ...
            'Value', 1, ...
            'Position', [25 400 300 50], ...
            'ValueChangedFcn', @(src, ~)selection_helper(src, F));
        uibutton(fig, 'Text', "Submit", ...
            'Position', [25 25 300 50], ...
            'ButtonPushedFcn', @(src,~)selection_closer(src, F));
        waitfor(fig);
    else
        task = fullfile(F(1).folder, F(1).name);
    end
end
machine = io.TaskMachine(task);

    function selection_helper(src, F)
        k = src.Value;
        task = fullfile(F(k).folder, F(k).name);
    end

    function selection_closer(src,F)
        h = findobj(src.Parent.Children, 'Type', 'uidropdown');
        k = h.Value;
        task = fullfile(F(k).folder, F(k).name);
        close(src.Parent);
    end

    function selection_figure_closer(src, F)
        h = findobj(src.Children, 'Type', 'uidropdown');
        k = h.Value;
        task = fullfile(F(k).folder, F(k).name);
        try %#ok<TRYNC> 
            close(src);
        end
    end

end