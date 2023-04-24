function [x, info] = load_tmsi(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, type, rootdir, verbose)
%LOAD_TMSI  API access-point for `load_tmsi_mat` or `load_tmsi_raw`. 
%
% Syntax:
%   [x, info] = io.load_tmsi(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, type, rootdir, verbose);
%
% Example:
%   x = io.load_tmsi('Ollie', 2021, 11, 4, "B", 16);
%   % This would return block 97 with array "B" data. Specify "*" to return
%   %  either block.
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
%
% Output:
%   x    - struct with fields similar to TMSiSAGA.Data object
%   info - Returns annotation data from PolyBench datamanager (".poly5"
%               type only)
%
% See also: Contents, parseXML, TMSiSAGA.Poly5.read, 
%           io.load_tmsi_raw, io.load_tmsi_mat

if nargin < 8
    rootdir = parameters('raw_data_folder');
end

if nargin < 9
    verbose = true;
end

if (numel(BLOCK) > 1) || (numel(ARRAY) > 1)
    x = cell(numel(BLOCK), numel(ARRAY));
    info = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            [x{iB, iA}, info{iB, iA}] = io.load_tmsi(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB), type, rootdir, verbose); 
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
        x = io.load_tmsi_mat(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir);
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
        [streams, fileheader] = io.load_xdf(fullfile(rootdir, SUBJ, tank, sprintf('%s_AB_LSL_%03d.xdf', tank, BLOCK)));
        info = fileheader.info;
        dt = datetime(info.datetime(1:(end-5)), 'Format', 'uuuu-MM-dd HH:mm:ss.SSS');
        n = inf;
        k = struct;
        for ii = 1:numel(streams)
            if startsWith(streams{ii}.info.name, 'SAGA')
                n = min(n,streams{ii}.segments.num_samples);
                tag_info = strsplit(streams{ii}.info.name, '-');
                k.(tag_info{2}) = ii;
            end
        end
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

end
