function data = load_tmsi_channel(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, TYPE, INDEX, varargin)
%LOAD_TMSI_CHANNEL Loads TMSi channel if it has been parsed
%
% Syntax:
%   data = io.load_tmsi_channel(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, TYPE, INDEX);
%
% Example:
%   data = io.load_tmsi_channel('Frank', 2021, 12, 9, "B", 155, "UNI", 21);
%       -> Returns data struct for unipolar channel 21 (UNI21).
%
% Inputs:
%   SUBJ - Subject name (char array or string)
%   YYYY - Year (4-digit year char array or string, or double)
%   MM - Month (2-digit month char array or string, or double)
%   DD - Day (2-digit day char array or string, or double)
%   ARRAY - "A", "B", or ["A, "B"]
%   BLOCK - Numeric double scalar or vector of recording block keys.
%       --> If ARRAY or BLOCK are nonscalar, then `offset` is returned as a
%           cell array, with dimensions numel(BLOCK) x numel(ARRAY)
%   TYPE - "UNI" | "BIP" | "TRIGGERS" | "STATUS" | "EMG"
%           -> "UNI" (requires INDEX 1-64) -- HD-EMG array
%           -> "BIP" (requires INDEX 1-4)  -- Surface bipolar
%           -> "TRIGGERS" -- "Sync" data on DB26 16-bit interface
%           -> "STATUS" -- Device status indicator (see TMSi docs for bit
%               encodings)
%           -> "COUNTER" -- Device sample counter (for sanity-checks)
%           -> "POT" | "POTENTIOMETER" | "AUX" | "ISO" -- For
%                 potentiometers collected using ISO-AUX 2-channel sensor.
%           -> "EMG" -- All HD-EMG and Bipolar channels (no INDEX)
%   INDEX - (Only needed for "UNI" or "BIP") -- 1-indexed scalar value (or
%               array to return multiple channels). Alternatively, can give
%               the "muscle" name (from Muscle-Map file) e.g. "R_EDC" or
%               "ED45" etc. In this case, any channels containing that
%               string in the Muscle-Map name will be returned.
%   varargin - (Optional) 'Name',value input argument pairs.
%
% Output:
%   data - Struct or array of structs with channel data
%
% See also: Contents, io.load_tmsi_triggers, io.load_tmsi_raw

if nargin < 8
    if strcmpi(TYPE, "UNI") || strcmpi(TYPE, "BIP")
        error("LoadChannel:MissingArgument", ...
            "If loading channel of type UNI or BIP, must specify channel INDEX argument (1-indexed).");
    end
end

if numel(varargin) > 0
    if isstruct(varargin{1})
        pars = varargin{1};
        varargin(1) = [];
    else
        pars = struct;
        [pars.raw_data_folder, pars.generated_data_folder] = parameters('raw_data_folder', 'generated_data_folder');
    end
    pars = utils.parse_parameters(pars, varargin{:});
else
    pars = struct;
    [pars.raw_data_folder, pars.generated_data_folder] = parameters('raw_data_folder', 'generated_data_folder'); % Reference to LOCAL parameters function (in repo with this submodule)
end

% Iterate over ARRAY and BLOCK elements if any are non-scalar.
if (numel(ARRAY) > 1) || (numel(BLOCK) > 1)
    data = cell(numel(BLOCK));
    for iA = 1:numel(ARRAY)
        data{iA} = io.load_tmsi_channel(SUBJ, YYYY, MM, DD, ARRAY{iA}, BLOCK(iB), TYPE, INDEX, pars);
    end
    return;
end

if ischar(INDEX)
    INDEX = string(INDEX);
end

if numel(INDEX) > 1
    data = init_data(numel(INDEX));
    for ii = 1:numel(data)
        data(ii) = io.load_tmsi_channel(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, TYPE, INDEX(ii), pars);
    end
    return;
end

% Get path info
[f, args] = utils.get_block_name(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, ...
    'rootdir_raw', pars.raw_data_folder, ...
    'rootdir_gen', pars.generated_data_folder);
if exist(f.Generated.Meta, 'file')==0
    error(...
        "LoadChannels:MissingData", ...
        "The Metadata file <strong>%s</strong> is missing.\n\t->\tThis is most-likely because data has not yet been exported.", ...
        f.Generated.Meta ...
        );
else
    channels = getfield(load(f.Generated.Meta, 'channels'), 'channels');
end
if isstring(INDEX)
    M = io.load_muscle_map(args{:}, pars.raw_data_folder);
    if isempty(M)
        error(...
            "LoadChannels:MissingData", ...
            "The Muscle-Map file <strong>%s</strong> is missing.\n\t->\tThis is most-likely because it has not yet been created using the Muscle-Map Exporter app.", ...
            f.Raw.Map ...
            );
    end
end

% Handle different types of channel requests.
switch upper(TYPE)
    case "UNI"
        if isstring(INDEX)
            INDEX = handle_mapped_channel(M, INDEX, "UNI");
            if numel(INDEX) > 1
                data = init_data(numel(INDEX));
                for ii = 1:numel(data)
                    data(ii) = io.load_tmsi_channel(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, TYPE, INDEX(ii), pars);
                end
                return;
            end
        else
            if (INDEX < 1) || (INDEX > 64)
                error("LoadChannels:InvalidIndex", ...
                    "INDEX == %d is out of range for TYPE == 'UNI'", ...
                    INDEX);
            end
        end
        
        
    case "BIP"
        if isstring(INDEX)
            INDEX = handle_mapped_channel(M, INDEX, "BIP");
            if numel(INDEX) > 1
                data = init_data(numel(INDEX));
                for ii = 1:numel(data)
                    data(ii) = io.load_tmsi_channel(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, TYPE, INDEX(ii), pars);
                end
                return;
            end
        else
            if (INDEX < 1) || (INDEX > 4)
                error("LoadChannels:InvalidIndex", ...
                    "INDEX == %d is out of range for TYPE == 'BIP'", ...
                    INDEX);
            end
        end
        
    case "EMG"
        iUni = find(strcmpi(channels.type, "UNI"));
        nUni = numel(iUni);
        iBip = find(strcmpi(channels.type, "BIP"));
        nBip = numel(iBip);
        n = nUni + nBip;
        data = init_data(n);
        for ii = 1:nUni
            data(ii) = io.load_tmsi_channel(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, "UNI", iUni(ii), pars);
        end
        for ii = 1:nBip
             data(nUni+ii) = io.load_tmsi_channel(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, "BIP", iBip(ii), pars);
        end  
        return;
    case "COUNTER"
        INDEX = find(contains(channel.type, "COUNTER"), 1, 'first');
        if isempty(INDEX)
            error("LoadChannels:MissingType", ...
                "No match for TYPE == '%s' in this data record", ...
                upper(TYPE));
        end
    case "STATUS"
        INDEX = find(contains(channel.type, "STATUS"), 1, 'first');
        if isempty(INDEX)
            error("LoadChannels:MissingType", ...
                "No match for TYPE == '%s' in this data record", ...
                upper(TYPE));
        end
    case {"POT", "POTENTIOMETER", "ISO", "AUX"}
        INDEX = find(contains(channel.type, "ISO"));
        if isempty(INDEX)
            error("LoadChannels:MissingType", ...
                "No match for TYPE == '%s' in this data record", ...
                upper(TYPE));
        else
            data = init_data(numel(INDEX));
        end
        for ii = 1:numel(INDEX)
             data(ii) = load(fullfile(f.Generated.Channels, ...
                sprintf("%s_RAW_%d.mat", f.Block, INDEX)), ...
                'fs', 'name', 'samples', 'start_time', 'units');
        end        
        return;
    case {"TRIGGER", "TRIGGERS"}
        INDEX = find(contains(channels.type, "TRIGGER"), 1, 'first');
        if isempty(INDEX)
            error("LoadChannels:MissingType", ...
                "No match for TYPE == '%s' in this data record", ...
                upper(TYPE));
        end
    otherwise
        error("LoadChannel:InvalidType", ...
            "TYPE == '%s' is not currently handled.", upper(TYPE));
end

data = load(fullfile(f.Generated.Channels, ...
    sprintf("%s_RAW_%d.mat", f.Block, INDEX)), ...
    'fs', 'name', 'samples', 'start_time', 'units');

    function data = init_data(n)
        %INIT_DATA  Initialize data struct array if multiple channel indices.
        %
        % Syntax:
        %   data = init_data(n);
        %
        % Inputs:
        %   n       - Number of data array elements to initialize
        %
        % Output:
        %   data    - (n x 1) struct array with fields
        %              'fs', 'name', 'samples', 'start_time', and 'units'
        data = struct(...
            'fs', cell(n,1), ...
            'name', cell(n,1), ...
            'samples', cell(n,1), ...
            'start_time', cell(n,1), ...
            'units', cell(n,1) ...
            );
    end

    function idx = handle_mapped_channel(m, s_idx, emg_type)
        %HANDLE_MAPPED_CHANNEL  Convert channel from string/char to 1-indexed scalar or array.
        %
        % Syntax:
        %    idx = handle_mapped_channel(m, s_idx, emg_type)
        %
        % Inputs:
        %    m        - Muscle-Map io.JSON object
        %    s_idx    - "String" index (the name of channel or channel subset)
        %    emg_type - "UNI" | "BIP"
        %
        % Output:
        %    idx      - Scalar or array of 1-indexed channels
        
        switch upper(emg_type)
            case "UNI"
                ch = strings(64,1);
                for iEMG = 1:64
                    ch(iEMG) = string(m.Muscles.(sprintf("UNI%02d", iEMG)));
                end
            case "BIP"
                ch = strings(4,1);
                for iEMG = 1:4
                    ch(iEMG) = string(m.Muscles.(sprintf("BIP%02d", iEMG)));
                end
            otherwise
                error("LoadChannels:InvalidType", ...
                    "TYPE == '%s' is not currently handled.", upper(emg_type));
        end
        idx = find(contains(ch, s_idx, 'IgnoreCase', true));        
        if isempty(idx)
            disp(unique(ch));
            error("LoadChannels:InvalidIndex", ...
                "No match for INDEX == '%s' in Muscle-Map. See above-list for valid values for TYPE == '%s'.", ...
                s_idx, upper(emg_type));
        end
    end

end

