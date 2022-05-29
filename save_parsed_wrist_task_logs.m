function save_parsed_wrist_task_logs(Position, Logs, Header)
%SAVE_PARSED_WRIST_TASK_LOGS  Save parsed behavioral logging to generated_data on server.
%
% Syntax:
%   io.save_parsed_wrist_task_logs(Position, Logs);
%   io.save_parsed_wrist_task_logs(Position, Logs, Header);
%
% Inputs:
%   Position - Table of Position data with `step` variables indicating the
%               current task state, target location, and minimal other info
%               about the task.
%
%   Logs     - Most of the relevant logging data, converted to MATLAB
%               timetable format to make it easier to handle.
%
%   Header   - Header table (in v3.2 logs and onward).
%
% Output:
%   (None)   - Saves the 'Position', and 'Logs' tables on raptor.
%
% See also: Contents, io.load_wrist_task_trial_logs, parameters

SAVE_EXPR = parameters('parsed_wrist_task_logs_expr');
meta = Position.Properties.CustomProperties.Recording_Metadata;

s = sprintf(SAVE_EXPR, meta.Subject, meta.Subject, meta.Year, meta.Month, meta.Day);

fname = struct('Position', [s 'Wrist_Position.mat'], ...
               'Logs', [s 'Wrist_Logs.mat'], ...
               'Header', [s 'Wrist_Header.mat']);

tic;
fprintf(1, 'Saving <strong>Position</strong> logs (%s)...', fname.Position);
save(fname.Position, 'Position', '-v7.3');
fprintf(1, 'complete!\n');
fprintf(1, 'Saving <strong>Raw</strong>-ish logs (%s)...', fname.Logs);
save(fname.Logs, 'Logs', '-v7.3');
fprintf(1, 'complete!\n');
if nargin > 2
    fprintf(1, 'Saving <strong>Header</strong> logs (%s)...', fname.Header);
    save(fname.Header, 'Header', '-v7.3');
    fprintf(1, 'complete!\n');
end
toc;
end