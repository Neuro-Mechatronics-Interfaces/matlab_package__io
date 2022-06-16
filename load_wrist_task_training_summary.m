function T = load_wrist_task_training_summary(filename)
%LOAD_WRIST_TASK_TRAINING_SUMMARY  Reads table of training history
%
% Basically just calls readtable on the input filename or uses default file
% if none is provided, and then assigns correct values to VariableUnits,
% VariableDescriptions, and typing of table columns. Also sorts rows by
% date in descending order.
%
% Syntax:
%   T = io.load_wrist_task_training_summary(filename);
%
% Inputs:
%   filename - (Optional | default uses value in `parameters`).
%
% Output:
%   T - Table summarizing training on wrist center-out task.
%
% See also: Contents

if nargin < 1
    filename = parameters('default_training_log_file');  % Default 
end

T = readtable(filename, 'Sheet', 'Wrist');
T.Subject = string(T.Subject);
T.Session = string(T.Session);
T.Properties.VariableUnits = {'n/a', 'n/a', 'n/a', 'n/a', 'n/a', 'trials', 'trials', '%', 'seconds', 'seconds', 'breaks', 'tantrums', '%', 'n/a', 'n/a', 'n/a'};
T.Properties.VariableDescriptions = { ...
    'Name of subject', ...
    'Experiment date', ...
    'Session identifier string', ...
    'Major version integer', ...
    'Minor version integer', ...
    'Total successful trials (center -> out PLUS out -> center).', ...
    'Total number of CENTER -> OUT ONLY trials.', ...
    'Success rate (0 to 1).', ...
    'Median duration of successful trials.', ...
    'Average number of overshoots on successful trials.', ...
    'Total number of "breaks" ( > 30 s between trials ).', ...
    'Total number of "tantrums" ( > 5 minutes between trials ).', ...
    'Variance of success rate time-series using sliding window of 50 trials.', ...
    'Macro precision score (for buzzy task)', ...
    'Macro recall score (for buzzy task)', ...
    'Macro F1 score (for buzzy task)' };
T = unique(T, 'rows');
T = sortrows(T, 'Date', 'descend');

end