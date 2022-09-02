function [P, log_params, Position] = parse_wrist_task_position_parameters(Position)
%PARSE_WRIST_TASK_POSITION_PARAMETERS  Returns parameters table associated with `Position` timetable.
%
% Syntax:
%   [P, log_params, Position] = io.parse_wrist_task_position_parameters(Position);
%
% Inputs:
%   Position - Timetable with position data (see `example_processing_logs`)
%
% Output:
%   P - Parameters table, which has data from the Header written to the
%           position logs table (but is from the TrialData file since
%           initially this was not included as rows in the position logs).
%
%           This is just a header parameter-set; each row of this table
%           corresponds to some change in session or parameter key index
%           that references a new parameters json file.
%
%   log_params - Cell array where each cell corresponds to a different
%                   session ID (random alphanumeric string). Typically this
%                   is a 1x1 cell at the "top" level. Within each
%                   "top-level" cell there is a number of cells
%                   corresponding to the total number of unique "parameter"
%                   files for a given session (which are generated when
%                   parameters are changed during a run). This value should
%                   always correspond to the `
%
%   Position - Same as input timetable, with added variable for session.
%
% See also: Content, importTrialData, importRawLogs, importTrialLogs

id = Position.Properties.CustomProperties.Recording_Metadata;
SUBJ = id.Subject;
YYYY = str2double(id.Year);
MM = str2double(id.Month);
DD = str2double(id.Day);
TrialData = io.load_wrist_task_trial_data(SUBJ, YYYY, MM, DD);
P = TrialData.Properties.UserData;
SESSION = string(P.Session);
[~, ~, P.session_index] = unique(SESSION);

log_params = io.load_wrist_task_parameters(SUBJ, YYYY, MM, DD, SESSION);

iSession = 1;
iTrial = -inf;
Position.parameters_index = nan(size(Position, 1), 1);
for iRow = 1:size(Position, 1)
    if Position.trial_number(iRow) < iTrial
        iSession = iSession + 1;
    end
    iTrial = Position.trial_number(iRow);
    session_key = SESSION(P.session_index == iSession);
    idx = (TrialData.Session == session_key) & (TrialData.Trial_Number == iTrial);
    if sum(idx) == 0
        continue;
    elseif sum(idx) > 1
        idx = find((TrialData.Session == session_key) & (TrialData.Trial_Number == iTrial) & (TrialData.Trial_Outcome == 1), 1, 'last');
        if numel(idx) == 0
             idx = find((TrialData.Session == session_key) & (TrialData.Trial_Number == iTrial), 1, 'last');
        end
%         if sum(idx) > 1
%             warning('Multiple matches for Session-%s::Trial-%d... using last one.', session_key, iTrial);
%             idx = find(idx, 1, 'last');
%         end
    else
        idx = find(idx,1,'first');
    end
    Position.parameters_index(iRow) = TrialData.Parameters_ID(idx);
end
Position(isnan(Position.parameters_index), :) = []; % Remove bad entries.

end