function [x, info] = load_tmsi(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, type, rootdir, verbose, options)
%LOAD_TMSI  API access-point for `load_tmsi_mat` or `load_tmsi_raw`. 
%
% Syntax:
%   [x, info] = io.load_tmsi(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, type, rootdir, verbose);
%   x = io.load_tmsi(__,'Name', value, ...); 
%
% Example 1:
%   x = io.load_tmsi('Ollie', 2021, 11, 4, "B", 16);
%   % This would return block 97 with array "B" data. Specify "*" to return
%   %  either block.
%
% Example 2:
%   y = io.load_tmsi("Screamy",2022,5,12,"A",54,'.mat','ReturnAs','tensor')
%   figure; plot(y.t, y.samples(2,:,3)); % Plots UNI-01, 3rd trial.
%
% Inputs:
%   SUBJ - String: should be name of subject (e.g. "Rupert" or "Frank")
%   YYYY - year (numeric scalar)
%   MM - month (numeric scalar)
%   DD - day (numeric scalar)
%   ARRAY - String: "A" or "B" or "*" for array identifier
%   BLOCK - Recording block index (numeric scalar)
%   type - Filetype: ".mat" or ".poly5"
%   rootdir - (Opt) The root folder where all the raw data stuff is kept.
%               This should normally stay the same unless we move 
%               our data share.
%   verbose - (Opt) specify false to suppress Command Window debug output
%   options: 
%       * options.ReturnAs (1,1) string {mustBeMember(options.ReturnAs, ["struct", "tensor", "data"])} = "struct" 
%       
%       -- For use with ReturnAs == "tensor" 
%       * options.GeneratedFolder (1,1) string = string(parameters('generated_data_folder'))
%       * options.SyncBit (1,1) double = 9 
%       * options.TriggerChannel (1,1) string = "TRIGGER"
%       * options.TriggerEpochSamples (1,2) double = [80, 160]
%
% Output:
%   x    - struct with fields similar to TMSiSAGA.Data object
%   info - Returns annotation data from PolyBench datamanager (".poly5"
%               type only)
%
% See also: Contents, parseXML, TMSiSAGA.Poly5.read, 
%           io.load_tmsi_raw, io.load_tmsi_mat

arguments
    SUBJ (1,1) string % should be name of subject (e.g. "Rupert" or "Frank")
    YYYY (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(YYYY, 2020)} % year of recording
    MM (1,1) double {mustBeInteger, mustBeInRange(MM, 1, 12)} % month of recording
    DD (1,1) double {mustBeInteger, mustBeInRange(DD, 1, 31)} % day of recording
    ARRAY (1,1) string {mustBeMember(ARRAY, ["A", "B", "AB", "*"])} % "A" or "B" in most cases (which SAGA array)
    BLOCK (1,1) double {mustBeInteger} % integer scalar key to recording from a given session. typically 0-indexed.
    type (1,1) string {mustBeMember(type, [".mat", ".poly5", ".lsl", ".xdf", "mat", "poly5", "lsl", "xdf"])} % recording filetype
    rootdir (1,1) string = string(parameters('raw_data_folder'));
    verbose (1,1) logical = true;
    options.ReturnAs (1,1) string {mustBeMember(options.ReturnAs, ["struct", "tensor"])} = "struct" % to directly convert to other sample data format (e.g. "tensor") 
    
    % For use with "tensor" ReturnAs option:
    options.CounterChannelName {mustBeTextScalar} = 'COUNTER';
    options.InterpolateMissingSamples (1,1) logical = false;
    options.KeepCounterStartOffset (1,1) logical = false; % Set true to keep offset from counter channel in the generated .t field for timing
    options.GeneratedFolder (1,1) string = string(parameters('generated_data_folder')); % where to load previously-parsed sync from
    options.SyncBit (1,1) double = 9; % if sync not yet parsed, then use this bit with the TriggerChannel samples to parse it
    options.TriggerChannel (1,1) string = "TRIGGER"; % identifies the trigger channel based on channel name
    options.TriggerEpochSamples (1,2) double = [80, 160]; % Number of samples before and after each trigger to use when generating tensor
    options.TriggerEdge (1,1) string {mustBeMember(options.TriggerEdge, ["rising", "falling", "Rising", "Falling"])} = "Falling"; % Which edge-type to use for triggers
    options.Tag {mustBeTextScalar} = '';
end

if (numel(BLOCK) > 1) || (numel(ARRAY) > 1)
    x = cell(numel(BLOCK), numel(ARRAY));
    info = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            [x{iB, iA}, info{iB, iA}] = io.load_tmsi(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB), type, rootdir, verbose, options); 
        end
    end
    x = vertcat(x{:});
    x = reshape(x, numel(BLOCK), numel(ARRAY));
    if nargout > 1
        info = vertcat(info{:});
        info = reshape(info, numel(BLOCK), numel(ARRAY));
    end
    return;
end

if ~startsWith(type, ".")
    type = strcat(".", type);
end

switch lower(string(type))
    case ".mat"
        x = io.load_tmsi_mat(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir, verbose, 'Tag', options.Tag);
        info = [];
    case ".poly5"
        if nargout == 1
            x = io.load_tmsi_raw(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir, verbose);
            info = [];
        else
            [x, info] = io.load_tmsi_raw(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir, verbose);
        end
    case ".lsl"
        tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
        name = sprintf('%s_%s_%03d', tank, ARRAY, BLOCK);
        if strlength(options.Tag) > 0
            in_file = dir(fullfile(rootdir, SUBJ, tank, options.Tag, sprintf('%s_%s_%s%03d.*df', tank, ARRAY, BLOCK)));
        else
            in_file = dir(fullfile(rootdir, SUBJ, tank, sprintf('%s_%s%03d.*df', tank, ARRAY, BLOCK)));
        end
        if isempty(in_file)
            error("No files matched expression <%s>", fullfile(rootdir, SUBJ, tank, sprintf('%s_%s%03d.*df', tank, ARRAY, BLOCK)));
        end
        [streams, fileheader] = io.load_xdf(fullfile(in_file(1).folder,in_file(1).name));
        info = fileheader.info;
        dt = datetime(info.datetime(1:(end-5)), 'Format', 'uuuu-MM-dd HH:mm:ss.SSS');
        n = inf;
        k = struct;
        gesture_sync = [];
        for ii = 1:numel(streams)
            tmp_name = char(streams{ii}.info.name);
            if startsWith(tmp_name, 'SAGA')
                n = min(n,streams{ii}.segments.num_samples);
                k.(tmp_name) = ii;
            elseif startsWith(tmp_name,'Gesture')
                Gesture = reshape(streams{ii}.time_series,[],1);
                Time = reshape(streams{ii}.time_stamps,[],1);
                gesture_sync = table(Time,Gesture);
            end
        end
        x = struct('t',[],'channels', [], 'sample_rate', streams{1}.info.nominal_srate, 'samples', [], 'time', dt, ...
                   'name', name, 'num_samples', [], 'markers', struct('gesture', gesture_sync));
        switch string(ARRAY)
            case "A"
                x.channels = streams{k.A}.info.desc.channels.channel;
                info.layout.A = streams{k.A}.info.desc.layout;
                info.t_begin.A = streams{k.B}.segments.t_begin;
                x.samples = streams{k.A}.time_series;
                x.num_samples = size(x.samples,2);
                x.t = streams{k.A}.time_stamps;
            case "B"
                x.channels = streams{k.B}.info.desc.channels.channel;
                info.layout.B = streams{k.B}.info.desc.layout;
                info.t_begin.B = streams{k.B}.segments.t_begin;
                x.samples = streams{k.B}.time_series;
                x.samples = size(x.samples, 2);
                x.t = streams{k.B}.time_stamps;
            otherwise % e.g. "AB" or "*"
                all_tags = fieldnames(k);
                x.channels = [];
                x.samples = [];
                info.saga = [];
                for ii = 1:numel(all_tags)
                    x.channels = [x.channels, streams{k.(all_tags{ii})}.info.desc.channels.channel];
                    info.layout.(all_tags{ii}) = streams{k.(all_tags{ii})}.info.desc.layout;
                    info.t_begin.(all_tags{ii}) = streams{k.(all_tags{ii})}.segments.t_begin;
                    info.saga = [info.saga; repmat(string(all_tags{ii}), numel(streams{k.(all_tags{ii})}.info.desc.channels.channel), 1)]; 
                    x.samples = [x.samples; streams{k.(all_tags{ii})}.time_series(:,1:n)];
                    x.t = [x.t; streams{k.(all_tags{ii})}.time_stamps(1:n)];
                end
                x.num_samples = n;
        end
        if ~options.KeepCounterStartOffset
            if ~isempty(x.markers.gesture)
                x.markers.gesture.Time = x.markers.gesture.Time - x.t(1,1);
            end
            x.t = x.t - x.t(1,1);
        end
        for iCh = 1:numel(x.channels)
            x.channels{iCh}.alternative_name = x.channels{iCh}.label; % For compatibility
        end
        x.channels = cell2mat(x.channels);
    case ".xdf"
        tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
        F = dir(fullfile(rootdir, SUBJ, tank, sprintf('%s_AB*%03d.xdf', tank, BLOCK)));
        if numel(F) ~= 1
            error("Could not find any files; did you mean to specify .LSL type instead of .xdf?");
        end
        [streams, fileheader] = io.load_xdf(fullfile(F(1).folder, F(1).name));
        info = fileheader.info;
        dt = datetime(info.datetime(1:(end-5)), 'Format', 'uuuu-MM-dd HH:mm:ss.SSS');
        n = inf;
        k = struct;
        for ii = 1:numel(streams)
            n = min(n,streams{ii}.segments.num_samples);
            tag_info = strsplit(streams{ii}.info.name, '-');
            k.(tag_info{2}) = ii;
        end
        
        name = sprintf('%s_%s_%03d', tank, ARRAY, BLOCK);
        x = struct('channels', [], 'sample_rate', streams{1}.info.nominal_srate, 'samples', [], 'time', dt, ...
                   'name', name, 'num_samples', []);
        switch string(ARRAY)
            case "A"
                x.channels = streams{k.A}.info.desc.channels.channel;
                info.layout.A = streams{k.A}.info.desc.layout;
                info.t_begin.A = streams{k.B}.segments.t_begin;
                x.samples = streams{k.A}.time_series;
                x.num_samples = size(x.samples,2);
            case "B"
                x.channels = streams{k.B}.info.desc.channels.channel;
                info.layout.B = streams{k.B}.info.desc.layout;
                info.t_begin.B = streams{k.B}.segments.t_begin;
                x.samples = streams{k.B}.time_series;
                x.samples = size(x.samples, 2);
            otherwise % e.g. "AB" or "*"
                x.channels = [streams{k.A}.info.desc.channels.channel, streams{k.B}.info.desc.channels.channel];
                info.layout.A = streams{k.A}.info.desc.layout;
                info.layout.B = streams{k.B}.info.desc.layout;
                info.t_begin.A = streams{k.B}.segments.t_begin;
                info.t_begin.B = streams{k.B}.segments.t_begin;
                x.samples = [streams{k.A}.time_series(:,1:n); streams{k.B}.time_series(:,1:n)];
                x.num_samples = n;
        end
        for iCh = 1:numel(x.channels)
            x.channels{iCh}.alternative_name = x.channels{iCh}.label; % For compatibility
        end
        x.channels = cell2mat(x.channels);
    otherwise
        error("File parsing for TMSi not handled for type == %s.", type);
end

switch options.ReturnAs
    case "data" % Do not know why you would want this, but just to avoid confusion (since .poly5 returns TMSiSAGA.Data class instead of struct)
        if isstruct(x)
            warning("Requested TMSiSAGA.Data return-type, but data was not loaded from .poly5 file so it will be returned as a struct instead.");
        end
        return;
    case "struct"
        if ~isstruct(x)
            x = convert_to_struct(x);
        end
        TANK = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
        TankFolder = fullfile(rootdir, SUBJ, TANK);
        about_file = fullfile(TankFolder, 'about.yaml');
        x.About = struct;
        if exist(about_file, 'file')==2
            about_recordings = io.yaml.loadFile(about_file);
            plex_name = sprintf('%s_PLEX_%02d%02d%04d%03d', upper(SUBJ), MM, DD, YYYY, BLOCK);
            if strlength(options.Tag) > 0
                saga_name = sprintf('%s_%s_%d', TANK, options.Tag, BLOCK);
            else
                saga_name = sprintf('%s_%d', TANK, BLOCK);
            end
            if isfield(about_recordings, plex_name)
                x.About.Note = about_recordings.(plex_name);
            elseif isfield(about_recordings, saga_name)
                x.About.Note = about_recordings.(saga_name);
            else
                x.About.Note = "No record in `about.yaml` for this block.";
            end
            if isfield(about_recordings, "General_Notes")
                x.About.General = about_recordings.General_Notes;
            else
                x.About.General = "No `General_Notes` field in `about.yaml` for this tank.";
            end
        else
            x.About.Note = "No `about.yaml` for this tank.";
            x.About.General = "No `about.yaml` for this tank.";
        end
        if iscell(x.channels)
            i_counter = cellfun(@(C)strcmpi(C.name,options.CounterChannelName),x.channels);
        elseif isstruct(x)
            if isfield(x,'name')
                i_counter = arrayfun(@(c)strcmpi(c.name,options.CounterChannelName),x.channels);
            else
                i_counter = arrayfun(@(c)strcmpi(c.AltChanName,options.CounterChannelName),x.channels);
            end
        else
            i_counter = arrayfun(@(c)strcmpi(c.AltChanName,options.CounterChannelName),x.channels);
        end
        if ischar(x.sample_rate) || isstring(x.sample_rate)
            x.sample_rate = str2double(x.sample_rate);
        end
        if x.sample_rate > 0
            if sum(i_counter)==0
                warning('No counter channel found: using sample rate only to generate assumed time vector.');
                x.t = 0:(1/x.sample_rate):((size(x.samples,2)-1)/x.sample_rate);
                needs_time = false;
            elseif sum(i_counter) > 1
                i_counter = find(i_counter);
                needs_time = true;
            else
                needs_time = true;
            end
        else
            needs_time = false;
        end
        if needs_time
            if x.sample_rate > 0
                if options.KeepCounterStartOffset
                    x.t = x.samples(i_counter,:)./x.sample_rate;
                else
                    x.t = (x.samples(i_counter,:)-x.samples(i_counter,1))./x.sample_rate;
                end
            end
            if options.InterpolateMissingSamples
                tq = 0:(1/x.sample_rate):x.t(end);
                idx_tq = ismembertol(tq,x.t);
                if sum(idx_tq) < numel(tq)
                    if verbose
                        fprintf(1,'Missing samples will be interpolated.\n');
                    end
                    tq = sort([tq(idx_tq), x.t],'ascend');
                    samplesq = zeros(size(x.samples,1),numel(tq));
                    for ii = 1:size(x.samples,1)
                        switch x.channels{ii}.type
                            case {1, 2, 3, 4} % 'UNI', 'BIP', or 'AUX' can be interpolated using spline or polynomial
                                samplesq(ii,:) = interp1(x.t, x.samples(ii,:), tq, 'makima', 0);
                            case {5, 6} % Digital logic channels (TRIGGERS, STATUS, COUNTER) should use 'nearest'
                                samplesq(ii,:) = interp1(x.t, x.samples(ii,:), tq, 'nearest', 0);
                        end
                    end
                    x.samples = samplesq;
                    x.t = tq;
                else
                    if verbose
                        fprintf(1,'No missing samples to interpolate.\n');
                    end
                end
            end
        end
        return; % Do nothing else, this is the default.
    case "tensor"
        if ~isstruct(x)
            x = convert_to_struct(x);
        end
        try
            x.sync = io.load_sync(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, options.GeneratedFolder);
        catch me
            if strcmpi(me.identifier, 'MATLAB:load:couldNotReadFile')
                % Sync does not yet exist, so we extract it.
                if iscell(x.channels)
                    ch_name = vertcat(cellfun(@(s)string(s.alternative_name), x.channels));
                else
                    ch_name = string({x.channels.alternative_name})';
                end
                i_trig = contains(ch_name, options.TriggerChannel);
                if sum(i_trig)~=1
                    disp(ch_name);
                    error("Missing trigger channel ('%s').", options.TriggerChannel);
                end
                trig_channel_data = x.samples(i_trig,:);
                
                sync_data = (bitand(trig_channel_data, 2^options.SyncBit) == 2^options.SyncBit);
                falling = find([false, diff(sync_data) < 0]);
                rising = find([diff(sync_data) > 0, false]);

                x.sync = struct('offset', rising, 'onset', falling, 'sync_data', sync_data);
            else
                throwAsCaller(me);
            end
        end
        if strcmpi(options.TriggerEdge, "rising")
            triggers = x.sync.offset;
        else
            triggers = x.sync.onset;
        end
        [x.samples, x.triggers, x.triggers_mask] = triggered_array(x.samples', triggers, options.TriggerEpochSamples(1), options.TriggerEpochSamples(2));
        x.t = ((-options.TriggerEpochSamples(1)):options.TriggerEpochSamples(2))./x.sample_rate .* 1e3; % Return in milliseconds. 
end

    function out = convert_to_struct(in)
        %CONVERT_TO_STRUCT  Convert TMSiSAGA.Data to struct
        out = struct(...
            'channels', {in.channels}, ...
            'sample_rate', in.sample_rate, ...
            'samples', in.samples, ...
            'time', in.time, ...
            'name', in.name, ...
            'num_samples', in.num_samples);
    end

    function [Xt, triggers, iBad] = triggered_array(X, triggers, n_pre, n_post)
        %TRIGGERED_ARRAY  Convert X from array to triggered array snippets
        %
        % Syntax:
        %   Xt = grid.triggered_array(X, triggers, n_pre, n_post);
        %
        % Inputs:
        %   X - nSamples x nChannels array
        %   triggers - Sample indices array of which samples to use as triggers
        %   n_pre - Number of samples before trigger to use
        %   n_post - Number of samples after each trigger to use
        %
        % Output:
        %   Xt - nChannels x [nPre + nPost + 1] x nTriggers tensor of samples
        %        in array around each trigger (stimulus)
        %
        % See also: Contents
        
        vec = -n_pre : n_post;
        triggers = reshape(triggers, numel(triggers), 1);
        idx = (vec + triggers)';
        iBad = any(idx < 1, 1) | any(idx > size(X, 1), 1);
        idx(:, iBad) = [];
        
        nSamples = size(X, 1);
        nChannels = size(X, 2);
        nEpoch = numel(vec);
        nTrigs = sum(~iBad);
        
        idx = reshape(idx, 1, nEpoch, nTrigs);
        Xt = nan(nChannels, nEpoch, nTrigs);
        
        for ch_idx = 1:nChannels
            Xt(ch_idx, :, :) = X(idx + nSamples * (ch_idx - 1));
        end
        
    end

end
