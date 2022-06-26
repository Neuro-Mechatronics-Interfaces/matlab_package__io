function save_wrist_task_trial_data(TrialData, expr)
%SAVE_WRIST_TASK_TRIAL_DATA  Saves trial data to generated data location on server
%
% Syntax:
%   io.save_wrist_task_trial_data(TrialData, expr);
%
% Inputs:
%   TrialData - Table of metadata for each trial.
%   expr      - (Optional | default is in `parameters` file in
%                   pars.wrist_trial_save_expr)
%
% Output:
%   (None)   - Saves the 'TrialData' table on raptor.
%
% See also: Contents, io.load_wrist_task_trial_data, parameters

if nargin > 1
    SAVE_EXPR = expr;
else
    SAVE_EXPR = parameters('wrist_trial_save_expr');
end
meta = TrialData.Properties.UserData(1, :);

fname = sprintf(strrep(SAVE_EXPR, "\", "/"), meta.Subject, meta.Subject, meta.Year, meta.Month, meta.Day);

tic;
fprintf(1, 'Saving <strong>TrialData</strong> table (%s)...', fname);
save(fname, 'TrialData', '-v7.3');
fprintf(1, 'complete!\n');
toc;

end