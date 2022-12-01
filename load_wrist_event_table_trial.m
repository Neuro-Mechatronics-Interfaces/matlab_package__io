function trial = load_wrist_event_table_trial(T, varargin)
%LOAD_WRIST_EVENT_TABLE_TRIAL  Load a wrist center-out task trial from event table.
%
% Syntax:
%   trial = io.load_wrist_event_table_trial(T);
%
% Inputs:
%   T - Table returned by io.read_events
%
% Output:
%   trial - Data struct or struct array (if T has more than one row).
%           -> Fields of struct are the variables in the matfiles for the
%               "block" files generated 1:1 with each trial.
%               Current variables (2022-12-01):
%               * channels  (1:1 correspondence metadata for rows of `samples`)
%               * sample_rate (sampling rate of data)
%               * samples (actual sample data)
%               * time (datetime; starting time of recording)
%           -> Each of these fields is sub-divided, potentially as 'A' and/or 'B'
%
% See also: Contents, io.read_events

pars = struct;
pars.raw_data_folder = parameters('raw_data_folder');
pars = utils.parse_parameters(pars, varargin{:});

N = size(T,1);
if N > 1
    trial = struct('channels', cell(N,1),'sample_rate', cell(N,1), 'samples', cell(N,1), 'time', cell(N,1));
    for iT = 1:N
        trial(iT) = io.load_wrist_event_table_trial(T(iT,:), pars);
    end
    return;
end

YYYY = year(T.date);
MM = month(T.date);
DD = day(T.date);
SUBJ = T.subject;
tank = sprintf("%s_%04d_%02d_%02d", SUBJ, YYYY, MM, DD);
f_expr = sprintf("%s_*_%d.mat", tank, T.block);
F = dir(fullfile(pars.raw_data_folder, SUBJ, tank, f_expr));
trial = struct('channels', struct, ...
               'sample_rate', struct, ...
               'samples', struct, ...
               'time', struct);
for iF = 1:numel(F)
    f_info = strsplit(F(iF).name, '_');
    tag = f_info{5};
    if contains(tag, 'impedance')
        continue;
    end
    tmp = load(fullfile(F(iF).folder, F(iF).name), ...
        'channels', 'sample_rate', 'samples', 'time');
    
    trial.channels.(tag) = tmp.channels;
    trial.sample_rate.(tag) = tmp.sample_rate;
    trial.samples.(tag) = tmp.samples;
    trial.time.(tag) = tmp.time;
end

end