function [Trial, State, Header, Target, Outcome, Haptics, Logs] = parse_wrist_task_trials(Logs)
%PARSE_WRIST_TASK_TRIALS  Return Trial timetable from Logs timetable.
%
% Note:
%   This function requires enumeration classes to work and should be run
%   from within the NHP_Center_Out repo workspace folder that contains the
%   enumeration classes:
%       * MotorCode
%       * TaskState
%       * TaskOutcome
%       * TaskDirection
%       * TaskTarget
%       * TaskOrientation
%       * TaskType
%
% Syntax:
%   [Trial, State, Header, Target, Outcome, Haptics, Logs] = io.parse_wrist_task_trials(Logs)
%
% Inputs:
%   Logs    - Timetable that is directly from the saved wrist task `.log` file
%
% Outputs:
%   Trial   - Timetable with columns related to Trial outcome/type info.
%   State   - Timetable with columns related to task State info.
%   Header  - Header struct with metaparameters about the behavior session.
%   Target  - Timetable with columns related to the Target angle.
%   Outcome - Timetable with columns related to the Outcome for each trial.
%   Haptics - Timetable with columns that have are related to any haptic buzz events.
%   Logs    - Formatted version of input timetable.
%
% See also: Contents, io.load_wrist_task_trial_logs

iHeader = Logs.var_type == "header";
H = Logs(iHeader, :);
Logs(iHeader, :) = [];
Header = struct;
for iH = 1:size(H, 1)
    var_name = H.var_name(iH);
    if ismember(var_name, ["Year", "Month", "Day", "Start_ns", "X_Center", "Y_Center", "Left_In", "Left_Out", "Right_In", "Right_Out", "Top_In", "Top_Out", "Bottom_In", "Bottom_Out"])
        Header.(var_name) = str2double(H.value(iH));
    elseif var_name == "Version"
        tmp = strsplit(H.value(iH), ".");
        Header.Version.major = str2double(tmp{1});
        Header.Version.minor = str2double(tmp{2});
        if numel(tmp) > 2
            Header.Version.patch = strjoin(tmp(3:end), ".");
        else
            Header.Version.patch = "base"; 
        end
    else
        Header.(var_name) = H.value(iH); 
    end
end

Outcome = Logs(Logs.var_name == "outcome.last", {'value'});
Outcome.trial_last = enum.TaskState(str2double(Outcome.value));
Outcome.value = [];
Outcome.trial_overshoots = str2double(Logs.value(Logs.var_name == "outcome.overshoots"));
Outcome.trial_duration = seconds(str2double(Logs.value(Logs.var_name == "outcome.duration_ns")));
Outcome.trial_result = strcmp(Logs.value(Logs.var_name == "outcome.result"), 'SUCCESSFUL');
Outcome.Properties.VariableContinuity = {'step', 'step', 'step', 'step'};

Haptics = Logs(Logs.var_name == "haptics.index", {'value'});
Haptics.pulse_code = enum.MotorCode(str2double(Haptics.value));
Haptics.value = [];
Haptics.state = repmat(TaskState.T2_INSTRUCT_H1, size(Haptics, 1), 1);
Haptics.pulse_duration = str2double(Logs.value(Logs.var_name == "haptics.duration"));
Haptics.pulse_duty_cycle = str2double(Logs.value(Logs.var_name == "haptics.duty_cycle"));
Haptics.pulse_n = str2double(Logs.value(Logs.var_name == "haptics.n_pulse"));
Haptics.pulse_ipi = str2double(Logs.value(Logs.var_name == "haptics.ipi"));
Haptics.Properties.VariableContinuity = {'step', 'step', 'step', 'step', 'step', 'step'};

% Do it this way to sync up the timestamps
hState = Haptics(:, {'state'});
Haptics.state = [];

State = Logs(Logs.var_name == "state", {'value'});
if isnan(str2double(State.value(1)))
    State.state = string(State.value);
    State.state(State.state == "IN_TARGET_1") = "IN_T1";
    State.state(State.state == "IN_TARGET_2") = "IN_T2";
    State.state(State.state == "T2_VISUAL") = "INSTRUCT_2";
    State.state(State.state == "OVERSHOOT") = "MISTAKE";
    hState.state = string(TaskState(hState.state));
else
    State.state = enum.TaskState(str2double(State.value)); 
end
State.value = [];
State.Properties.VariableContinuity = {'step'};
State = sortrows([State; hState], 'ts', 'ascend');

Target = Logs(Logs.var_name == "angle", {'value'});
Target.angle = str2double(Target.value);
Target.value = [];
Target.Properties.VariableContinuity = {'step'};

Running = Logs(Logs.var_name == "running", {'value'});
Running.running = strcmp(Running.value, '1');
Running.value = [];
Running = unique(Running);
Running.Properties.VariableContinuity = {'step'};

Counter = Logs(Logs.var_name == "number", {'value'});
Counter.trial_number = str2double(Counter.value);
Counter.value = [];
Counter.Properties.VariableContinuity = {'step'};

Direction = Logs(Logs.var_name == "direction", {'value'});
Direction.direction = enum.TaskDirection(uint32(string(Direction.value) == "TaskDirection.OUT_TO_IN"));
Direction.value = [];
Direction.Properties.VariableContinuity = {'step'};

Trial = synchronize(Counter, Running);
Trial = synchronize(Direction, Trial);
Trial.session_index = ones(size(Trial, 1), 1);
Trial.Properties.VariableContinuity = repmat({'step'}, 1, 4);
session_index = 1;
for ii = 2:size(Trial, 1)
    if Trial.trial_number(ii) < Trial.trial_number(ii-1)
        session_index = session_index + 1;
    end
    Trial.session_index(ii) = session_index;
end
Trial(isnan(Trial.trial_number), :) = [];

[G, TID] = findgroups(Trial(:, {'trial_number', 'session_index'}));
TID.direction = splitapply(@mode, Trial.direction, G);
% TID.trial_overshoots = splitapply(@max, Trial.trial_overshoots, G);
for ii = 1:size(TID, 1)
    idx = G == ii;
    Trial.direction(idx) = TID.direction(ii);
%     Trial.trial_overshoots(idx) = TID.trial_overshoots(ii);
end
% Trial = Trial(Trial.running, :);
end