function params = load_wrist_task_parameters(SUBJ, YYYY, MM, DD, SESSION)
%LOAD_WRIST_TASK_PARAMETERS Import logging parameters for a given subject.
%
% Syntax:
%   params = io.load_wrist_task_parameters(SUBJ, YYYY, MM, DD);
%   params = io.load_wrist_task_parameters(SUBJ, YYYY, MM, DD, SESSION);
%   params = io.load_wrist_task_parameters(U);
%
% Inputs:
%   SUBJ - Subject name
%   YYYY - Year (numeric or string)
%   MM   - Month (numeric or 2-digit zero-leading string)
%   DD   - Day   (numeric or 2-digit zero-leading string)
%   SESSION - (Optional) Session identifier (alphanumeric random string)
%
%   -- or --
%
%   U    - TrialData.Properties.UserData (see:
%               io.load_wrist_task_trial_data output table)
%
% Output:
%   log_params - Parameters associated with given behavioral logging on
%                   wrist task.
%
% See also: Contents, io.load_wrist_task_trial_data

if nargin < 5
    if nargin == 1
        U = SUBJ;
        if size(U, 1) > 1
            error("Import:BadArgumentSyntax", "U should only have one row. Input table had %d rows.", size(U, 1));
        end 
        SUBJ = U.Subject;
        SESSION = U.Session;
        YYYY = U.Year;
        MM = U.Month;
        DD = U.Day;
    else
        SESSION = "*";
    end
else
    SESSION = string(SESSION);
end

if numel(SESSION) > 1
    params = cell(size(SESSION));
    for ii = 1:numel(SESSION)
        params{ii} = io.load_wrist_task_parameters(SUBJ, YYYY, MM, DD, SESSION(ii));
    end
    return;
end

f_expr = 'R:/NMLShare/raw_data/primate/%s/Behavior/%s_%s_params-*.txt';

if strcmpi(SESSION, "*")
    [YYYY, MM, DD] = utils.parse_date_args(YYYY, MM, DD);
    TrialData = io.load_wrist_task_trial_data(SUBJ, YYYY, MM, DD);
    meta = TrialData.Properties.UserData;
    SESSION = string(meta.Session);
    params = io.load_wrist_task_parameters(SUBJ, YYYY, MM, DD, SESSION);
    return;
end

f_str = sprintf(f_expr, SUBJ, SUBJ, SESSION);
F = dir(f_str);

params = cell(numel(F), 1);
opts = delimitedTextImportOptions('NumVariables', 3, ...
    'Encoding', 'UTF-8', ...
    'Delimiter', '\t', ...
    'DataLines', [2 inf], ...
    'VariableNames', {'Parameter', 'Value', 'Units'});
opts = setvartype(opts, ...
    {'Parameter', 'Value', 'Units'}, ...
    {'string', 'string', 'string'});

for iF = 1:numel(params)
    params{iF} = readtable(fullfile(F(iF).folder, F(iF).name), opts);
end

end
