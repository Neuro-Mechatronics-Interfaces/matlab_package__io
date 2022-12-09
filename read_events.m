function T = read_events(SUBJ, YYYY, MM, DD, varargin)
%READ_EVENTS  Reads in "events-export.csv" file for a given session.
%
% Syntax:
%   T = io.read_events(SUBJ, YYYY, MM, DD);

pars = struct;
pars.events_file_in = 'notes/events-export.csv';
pars.events_file_out = '%s_trials.mat';
pars.verbose = false;
[pars.generated_data_folder, pars.raw_data_folder] = ...
    parameters('generated_data_folder', 'raw_data_folder');
pars = utils.parse_parameters(pars, varargin{:});

tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
fname_in = fullfile(pars.raw_data_folder, SUBJ, tank, pars.events_file_in);
out_path = fullfile(pars.generated_data_folder, SUBJ, tank);
fname_out = fullfile(out_path, sprintf(pars.events_file_out, tank));

if exist(fname_out,'file')~=0
    T = getfield(load(fname_out, 'T'), 'T');
    if pars.verbose
        fprintf(1,'Loaded existing wrist trials event file: <strong>%s</strong>\n', fname_out);
    end
    return;
elseif exist(out_path,'dir')==0
    mkdir(out_path);
end

if exist(fname_in, 'file')==0
    me = MException('io:missing_file:raw', 'No file named "%s" exists.\n\n\t->\tHave you exported the events query from the SQLite Home-Assistant Database for this session?\t<-\t\n\t\t\t(Once you do, it needs to be put into the file path as shown above)\n\n', fname_in);
    throw(me);
end
T = readtable(fname_in);
T.subject = string(T.subject);
T.task = string(T.task);
T.task_info = string(T.task_info);

T.session = arrayfun(@(C)strrep(C,'"',''),T.session);
T.subject = arrayfun(@(C)strrep(C,'"',''),T.subject);
T.task = arrayfun(@(C)strrep(C,'"',''),T.task);
T.task_info = arrayfun(@(C)strrep(C,'"',''),T.task_info);
T.orientation = enum.TaskOrientation(T.task_info);
T.time = datetime(T.time);
T.direction = enum.TaskDirection(T.direction);
T.target_index = enum.TaskTarget(T.target_index);
T.outcome = enum.TaskOutcome(T.outcome);
T = removevars(T, {'event_type', 'task_info'});
T = sortrows(T, "time", 'ascend');

N = size(T,1); 
T.block = (0:(N-1))';
T.date = repmat(datetime(YYYY,MM,DD), size(T,1), 1);
T = T(:, [(end-1):end, 1:(end-2)]);

T.excluded_by_pots  = false(N,1);
T.excluded_by_noise = false(N,1);
T.excluded_by_manual= false(N,1);

save(fname_out, 'T', '-v7.3');
if pars.verbose
    fprintf(1,'Saved wrist trials event file: <strong>%s</strong>\n', fname_out);
end
end