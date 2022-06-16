function [Position, Logs, Header] = load_wrist_task_parsed_logs(SUBJ, YYYY, MM, DD, expr)
%LOAD_WRIST_TASK_PARSED_LOGS  Load parsed position/logs/header data
%
% Syntax:
%   [Position, Logs, Header] = io.load_wrist_task_parsed_logs(SUBJ, YYYY, MM, DD, expr);
%
% Inputs:
%   SUBJ  - Name of subject
%   YYYY  - Year
%   MM    - Month
%   DD    - Day
%   expr  - (Optional | see parameters('parsed_wrist_task_logs_expr') for
%               default value).
%
% Output:
%   Position - Table of Position data with `step` variables indicating the
%               current task state, target location, and minimal other info
%               about the task.
%
%   Logs     - Most of the relevant logging data, converted to MATLAB
%               timetable format to make it easier to handle.
%
%   Header   - Header table (in v3.2 logs and onward).
%
% See also: Contents, io.save_parsed_wrist_task_logs,
%           io.load_wrist_task_trial_logs, io.parse_wrist_task_trials


if nargin < 6
    expr = parameters('parsed_wrist_task_logs_expr');
end
[YYYY, MM, DD] = utils.parse_date_args(YYYY, MM, DD);
YYYY = num2str(YYYY, '%04d');
MM = num2str(MM, '%02d');
DD = num2str(DD, '%02d');
s = sprintf(strrep(expr, '\', '/'), SUBJ, SUBJ, YYYY, MM, DD);
fname = struct('Position', strcat(s, 'Wrist_Position.mat'), ...
               'Logs', strcat(s, 'Wrist_Logs.mat'), ...
               'Header', strcat(s, 'Wrist_Header.mat'));

tic;
fprintf(1, 'Loading <strong>Position</strong> logs (%s)...', fname.Position);
Position = getfield(load(fname.Position, 'Position'), 'Position');
fprintf(1, 'complete!\n');
if nargout > 1
    fprintf(1, 'Loading <strong>Raw</strong>-ish logs (%s)...', fname.Logs);
    Logs = getfield(load(fname.Logs, 'Logs'), 'Logs');
    fprintf(1, 'complete!\n');
end
if nargout > 2
    fprintf(1, 'Loading <strong>Header</strong> logs (%s)...', fname.Header);
    Header = getfield(load(fname.Header, 'Header'), 'Header');
    fprintf(1, 'complete!\n');
end
toc;
end