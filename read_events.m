function T = read_events(SUBJ, YYYY, MM, DD, varargin)
%READ_EVENTS  Reads in "events-export.csv" file for a given session.
%
% Syntax:
%   T = io.read_events(SUBJ, YYYY, MM, DD);

pars = struct;
pars.events_file = 'notes/events-export.csv';
pars.raw_data_folder = parameters('raw_data_folder');
pars = utils.parse_parameters(pars, varargin{:});

tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
fname = fullfile(pars.raw_data_folder, SUBJ, tank, pars.events_file);

T = readtable(fname);
T.subject = string(T.subject);
T.task = string(T.task);
T.task_info = string(T.task_info);
T = removevars(T, 'event_type');
T.session = arrayfun(@(C)strrep(C,'"',''),T.session);
T.subject = arrayfun(@(C)strrep(C,'"',''),T.subject);
T.task = arrayfun(@(C)strrep(C,'"',''),T.task);
T.task_info = arrayfun(@(C)strrep(C,'"',''),T.task_info);
T.time = datetime(T.time);
T.direction = enum.TaskDirection(T.direction);
T.target_index = enum.TaskTarget(T.target_index);
T.outcome = enum.TaskOutcome(T.outcome);
T = sortrows(T, "time", 'ascend');
T.block = (0:(size(T,1)-1))';
T.date = repmat(datetime(YYYY,MM,DD), size(T,1), 1);
T = T(:, [(end-1):end, 1:(end-2)]);

end