function [data, meta] = load_wrist_event_table_trial(T, varargin)
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
pars.a = [];
pars.b = [];
pars.pot.fc = 100;
pars.pot.ord = 2;
pars.pot.a = [];
pars.pot.b = [];
pars.pot.x = 1; % Relative order of potentiometer x-channel
pars.pot.y = 2; % Relative order of potentiometer y-channel
pars.pot.offset = [0.57, 0.98]; % Center target middle (volts; x/y in MID)
pars.pot.scale  = [125,  100];  % Scales volts to degrees.
pars.pot.mov_thresh = 2.5; % Degrees/sec; threshold to consider move onset.
pars.fc = [25, 400]; % Specify as scalar to use a highpass instead of bandpass
pars.fs = 4000;      % Default TMSi sample rate
pars.ord = 2;        % Filter order for butterworth filter on generated data
[pars.generated_data_folder, pars.raw_data_folder] = ...
    parameters('generated_data_folder', 'raw_data_folder');
pars = utils.parse_parameters(pars, varargin{:});

if isempty(pars.a) || isempty(pars.b)
    if numel(pars.fc) > 1
        [pars.b, pars.a] = butter(pars.ord, pars.fc ./ (pars.fs / 2), "bandpass");
    else
        [pars.b, pars.a] = butter(pars.ord, pars.fc ./ (pars.fs / 2), "high");
    end
end

if isempty(pars.pot.a) || isempty(pars.pot.b)
    [pars.pot.b, pars.pot.a] = butter(pars.pot.ord, pars.pot.fc ./ (pars.fs / 2), "low");
end

N = size(T,1);
if N > 1
    data = cell(N,1);
    fprintf(1,'Loading <strong>%d</strong> trials...%03d%%\n', N, 0);
    for iT = 1:N
        if (nargout > 1) && (iT == 1)
            [data{iT}, meta] = io.load_wrist_event_table_trial(T(iT,:), pars);
        else
            data{iT} = io.load_wrist_event_table_trial(T(iT,:), pars);
        end
        fprintf(1,'\b\b\b\b\b%03d%%\n', floor(iT*100/N));
    end
    data(cellfun(@(C)isempty(C),data)) = [];
    return;
end

YYYY = year(T.date);
MM = month(T.date);
DD = day(T.date);
SUBJ = T.subject;
tank = sprintf("%s_%04d_%02d_%02d", SUBJ, YYYY, MM, DD);
generated_folder = fullfile(pars.generated_data_folder, SUBJ, tank);
fname_gen = fullfile(generated_folder, sprintf("%s_%d.mat", tank, T.block));

% Check for the "generated" file.
if exist(fname_gen, 'file')==0
    % If it does not exist, create/save it, using the raw data.
    fprintf(1,'\b...(extracting)');
    f_expr = sprintf("%s_*_%d.mat", tank, T.block);
    F = dir(fullfile(pars.raw_data_folder, SUBJ, tank, f_expr));

    % In case any impedances were taken for this block, handle saving
    % those.
    impedance_files = cellfun(@(C)contains(C, 'impedance'), {F.name});
    if sum(impedance_files) > 0
        G = F(impedance_files);
        F(impedance_files) = [];
        output_imp_filename = string(fullfile(generated_folder, sprintf("%s_impedances_%d.mat", tank, T.block)));
        if exist(output_imp_filename,'file')==0
            imp_file = strings(size(G));
            for iG = 1:numel(G)
                imp_file(iG) = string(fullfile(G(iG).folder, G(iG).name));
            end
            io.process_raw_impedances(imp_file, output_imp_filename);
        end
    end

    if isempty(F)
        data = [];
        return;
    end

    channels = struct;
    samples = struct;
    n = inf;
    for iF = 1:numel(F)
        f_info = strsplit(F(iF).name, '_');
        tag = f_info{5};
        tmp = load(fullfile(F(iF).folder, F(iF).name), ...
            'channels', 'samples', 'time');
        channels.(tag) = tmp.channels;
        samples.(tag) = tmp.samples;
        n = min(n, size(tmp.samples,2));
    end
    
    % Concatenate together data. Based on observation of the 2TMSi MATLAB
    % setup, the processing time required to start both devices "nearly"
    % synchronously is low enough that essentially both should be seeing
    % the same sample instants (on the resolution of 0.25-ms samples).
    if numel(F) > 1
        samples = vertcat(samples.A(:,1:n), samples.B(:,1:n));
        if iscell(channels.A)
            channels = vertcat(channels.A{:}, channels.B{:});
        else
            channels = vertcat(channels.A, channels.B);
        end
    else
        samples = samples.(tag);
        if iscell(channels.(tag))
            channels = vertcat(channels.(tag){:});
        else
            channels = channels.(tag);
        end
    end

    i_filter = channels.isExG() | channels.isBip();
    samples(i_filter, :) = filtfilt(pars.b, pars.a, samples(i_filter,:)')';
    data = struct;
    
    data.uni = single(samples(isExG(channels) & ~isRef(channels), :));
    data.bip = single(samples(isBip(channels), :));
    data.sync = uint8(15 - samples(isTrig(channels),:));
    iAux = find(contains({channels.name}, 'AUX'));
    if isempty(iAux)
        data.x = [];
        data.y = [];
        xg = 0;
        yg = 0;
    else
        pot_data = filtfilt(pars.pot.b, pars.pot.a, samples(iAux,:)')';
        try
            if T.orientation == enum.TaskOrientation.MID
                xg = pars.pot.scale(pars.pot.x);
                yg = pars.pot.scale(pars.pot.y);
                data.x = single((pot_data(pars.pot.x,:) - pars.pot.offset(pars.pot.x)).*xg);
                data.y = single((pot_data(pars.pot.y,:) - pars.pot.offset(pars.pot.y)).*yg);
            else
                xg = pars.pot.scale(pars.pot.y);
                yg = pars.pot.scale(pars.pot.x);
                data.x = -single((pot_data(pars.pot.y,:) - pars.pot.offset(pars.pot.y)).*xg);
                data.y = single((pot_data(pars.pot.x,:) - pars.pot.offset(pars.pot.x)).*yg);
            end
            r = sqrt(data.x.^2 + data.y.^2); 
            d_r = movmean(abs(diff(r))./0.005, 41, 'Endpoints', 0);
            i_move = find(d_r >= pars.pot.mov_thresh, 1, 'first');
            if ~isempty(i_move)
                data.sync(i_move) = data.sync(i_move) + 16;
            end
        catch me
            if strcmpi(me.identifier,'MATLAB:badsubscript')
                data.x = zeros(1,n);
                data.y = zeros(1,n);
            else
                rethrow(me);
            end
        end
    end
    data.t = tmp.time + milliseconds((0:(n-1))./4);

    % Save the generated data file for this block.
    save(fname_gen, '-struct', 'data');

    % Check for a metadata file. If that also doesn't exist, save one.
    meta = struct;
    meta.fs = pars.fs;
    meta.fc = pars.fc;
    meta.ord = pars.ord;
    meta.thresh = pars.pot.mov_thresh;
    meta.channels = channels;
    meta.gain = struct('x', xg, 'y', yg, 'uni', 1, 'bip', 1);
    fname_meta = fullfile(generated_folder, sprintf("%s_metadata.mat", tank));
    if exist(fname_meta, 'file')==0
        save(fname_meta, '-struct', 'meta');
    end
    fprintf(1,'\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\n');
else % Otherwise it exists. Load the trial data.
    data = load(fname_gen, 'uni', 'bip', 'sync', 'x', 'y', 't');
    
    % If two outputs requested, (i.e. single table row loaded with two
    % outputs explicitly requested) then return metadata also.
    if nargout > 1
        fname_meta = fullfile(generated_folder, sprintf("%s_metadata.mat", tank));
        meta = load(fname_meta, 'fs', 'fc', 'ord', 'thresh', 'channels', 'gain');
    end
end




end