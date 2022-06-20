function target = load_aligned_target_data(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, ALIGNMENT, TARGET, DIRECTION, varargin)
%LOAD_ALIGNED_TARGET_DATA  Loads target-aligned data
%
% Syntax:
%   sync = io.load_aligned_target_data(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, ALIGNMENT, TARGET, DIRECTION, 'Name', value, ...)
%
% Example:
%   emg = io.load_aligned_target_data('Spencer', 2022, 3, 31, "B", 0, "MOVE_ONSET", 7);
%   This would return a sync struct for block 0 for array "B" from
%   Spencer behavior dataset on 3/31/2022, aligned to movement onset for
%   any movements from the center to target 7.
%
% Inputs:
%   SUBJ - String: should be name of subject (e.g. "Rupert" or "Frank")
%   YYYY - year (numeric scalar)
%   MM - month (numeric scalar)
%   DD - day (numeric scalar)
%   ARRAY - String: "A" or "B" etc. for array identifier
%   BLOCK - Recording block index (numeric scalar)
%   ALIGNMENT - The type of alignment. Default if not specified is
%                   'MOVE_ONSET'. See values in TaskAlignment enumeration
%                   class for valid values -- can be TaskAlignment value,
%                   the string representation, or corresponding integer
%                   key.
%   TARGET  - Integer index for target (0 - 7) see enumerations in TaskTarget
%   DIRECTION - Integer value 0 or 1, see enumerations in TaskDirection
%
%   'Name', value pairs (see top of code, each field of pars):
%       force       - Force re-extraction of generated data?
%                       This is normally false. 
%       rootdir_raw - The root folder where raw data lives.
%                       This should normally stay the same unless we move
%                       our data share.
%       rootdir_gen - The root folder where generated data will be saved. 
%                       This should normally stay the same unless we move 
%                       our data share. 
%
% Output:
%   target - Target alignment data struct
%
% See also: Contents, io.load_tmsi_raw, io.load_tmsi_triggers

pars = struct;
pars.fc = 10;  % Hz
pars.ford = 4; % Highpass butterworth filter order
pars.n_max = inf; % Set to scalar value to limit max number imported
pars.filters = struct; % Set to struct with field names that match fields of `T` (the indexing variable in mat file of corresponding ".aligned" folder).
% -> "Target" and "Direction" are added to this struct automatically using
%       the input arguments TARGET and DIRECTION.
[pars.rootdir_raw, pars.rootdir_gen, pars.raw_matfiles_folder, ...
    pars.raw_matfiles_expr, pars.events_file_expr, pars.meta_file_expr,...
    pars.alignment_parent_folder, pars.alignment_folder] = parameters(...
        'raw_data_folder', 'generated_data_folder', 'raw_matfiles_folder', ...
        'raw_matfiles_expr', 'events_file_expr', 'meta_file_expr', ...
        'alignment_parent_folder', 'alignment_folder');
pars = utils.parse_parameters(pars, varargin{:});


if (numel(ARRAY) > 1) || (numel(BLOCK) > 1)
    target= cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            target{iB, iA} = io.load_aligned_target_data(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB), ALIGNMENT, TARGET, DIRECTION, pars);
        end
    end
    return;
end

[YYYY, MM, DD] = utils.parse_date_args(YYYY, MM, DD);
if ~isnumeric(BLOCK)
    BLOCK = str2double(BLOCK);
end
f = utils.get_block_name(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, pars);
if ~isfield(f.Generated.Aligned, ALIGNMENT)
    error("Export:UnhandledState", "This alignment state is not yet handled: <strong>%s</strong>\n\n", string(ALIGNMENT));
end

% Load events for selected alignment
T = getfield(load(fullfile(f.Generated.Aligned.(ALIGNMENT), ...
    sprintf("%s.mat", f.Block)), 'T'), 'T');

% Get subset of all aligned events
idx = true(1, numel(T));
pars.filters.Target = TARGET;
pars.filters.Direction = DIRECTION;
filter_fields = fieldnames(pars.filters);
for iF = 1:numel(filter_fields)
    idx = idx & ismember([T.(filter_fields{iF})], pars.filters.(filter_fields{iF}));
end
iTrial = find(idx);

load(f.Generated.Meta, 'header', 'channels');
[b, a] = butter(pars.ford, pars.fc/(header.sample_rate/2), 'high'); % emg
[bp, ap] = butter(pars.ford, pars.fc/(header.sample_rate/2), 'low'); % potentiometers

iUni = contains(channels.alternative_name, 'UNI');
iBip = contains(channels.alternative_name, 'BIP');
iPot = contains(channels.alternative_name, 'ISO');


nTrial = min(numel(iTrial), pars.n_max);
if nTrial == 0
    target = [];
    fprintf(1, 'No trials identified; <strong>loading skipped</strong>...\n');
    return;
end
fprintf(1, 'Loading target-aligned data...  0%%\n');
iTrial = iTrial(1:nTrial);
events = T(iTrial);
trial = reshape(iTrial, nTrial, 1);

array = cell(size(events));
array_sd = cell(size(events));
array_dd = cell(size(events));
pot = cell(size(events));
pot_raw = cell(size(events));
pot_hpf = cell(size(events));
bip = cell(size(events));
e = cell(size(events));
tc = repmat(datetime('now', 'TimeZone', 'America/New_York'), size(events));
m = cell(size(events));
t = [];
for ii = 1:nTrial
    fname = fullfile(f.Generated.Aligned.(ALIGNMENT), sprintf("%s_%04d.mat", f.Block, iTrial(ii)));
    load(fname, 'data', 't', 'event', 'tCur', 'movement');
    
    array{ii} = filtfilt(b, a, data(:, iUni));
    array{ii} = array{ii} - mean(array{ii}, 2);
    
    % Permute into grid
    ns = numel(t);
    tmp_grid = reshape(array{ii}, ns, 8, 8);
    g_sd = cat(2, nan(ns, 1, 8), diff(tmp_grid, 1, 2));
    g_dd = cat(2, nan(ns, 1, 8), diff(tmp_grid, 2, 2), nan(ns, 1, 8));
    
    array_sd{ii} = reshape(g_sd, ns, 64);
    array_dd{ii} = reshape(g_dd, ns, 64);
    
    if sum(iBip) > 0
        bip{ii} = filtfilt(b, a, data(:, iBip));
    end
    
    if sum(iPot) > 0
        pot_raw{ii} = data(:, iPot);
        pot{ii} = filtfilt(bp, ap, pot_raw{ii});
        pot_hpf{ii} = filtfilt(b, a, pot_raw{ii});
    end
    e{ii} = event;
    tc(ii) = tCur;
    m{ii} = movement;
    fprintf(1, '\b\b\b\b\b%3d%%\n', round(ii * 100 / nTrial));
end
outcome = reshape([events.Outcome], numel(events), 1);
event = events;
target = table(tc, trial, outcome, event, e, m, array, array_sd, array_dd, bip, pot, pot_hpf, pot_raw);
target.Properties.UserData = struct('header', header, 't', t, 'channels', channels);
          
end