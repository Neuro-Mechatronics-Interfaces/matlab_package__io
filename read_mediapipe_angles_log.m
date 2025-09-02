function [T, TT] = read_mediapipe_angles_log(csvFile, metaFile)
%READ_MEDIAPIPE_ANGLES_LOG  Load logger CSV (+ meta) into a labeled table.
%
% Usage
%   T = io.read_mediapipe_angles_log(csvFile)
%   [T, TT] = io.read_mediapipe_angles_log(csvFile, metaFile)
%
% Inputs
%   csvFile : path to logger CSV with columns: Time, Sample
%   metaFile (optional) : path to matching .meta.json for channel names/types
%
% Outputs
%   T  : table with variables:
%          - Timestamp (double, seconds as logged)
%          - Time (duration, seconds since first sample)
%          - one variable per channel (double)
%   TT : timetable version of T (using 'Time' as row times), or [] if you don't need it
%
% Notes
% - Very fast: avoids JSON parsing; just tokenizes numbers/NaN with regexp.
% - Robust to whitespace and scientific-notation numbers.
% - Will fall back to generic names if meta is missing or mismatched.

arguments
    csvFile (1,1) string
    metaFile (1,1) string = ""
end

% --- Resolve meta path ---
if metaFile == ""
    % Try "<csv>.meta.json" and "<basename>.meta.json"
    guess1 = csvFile + ".meta.json";
    [p,n] = fileparts(csvFile);
    guess2 = fullfile(p, n + ".meta.json");
    if isfile(guess1)
        metaFile = guess1;
    elseif isfile(guess2)
        metaFile = guess2;
    else
        metaFile = "";
    end
end

% --- Read CSV quickly (Time as double, Sample as string) ---
opts = detectImportOptions(csvFile, 'NumHeaderLines', 0, 'TextType', 'string');
% Ensure we only bring in the two columns with correct types
opts.SelectedVariableNames = {'Time','Sample'};
% Coerce variable types explicitly
ixTime   = strcmpi(opts.VariableNames, 'Time');   opts = setvartype(opts, opts.VariableNames(ixTime), 'double');
ixSample = strcmpi(opts.VariableNames, 'Sample'); opts = setvartype(opts, opts.VariableNames(ixSample), 'string');

raw = readtable(csvFile, opts);

% --- Tokenize each Sample row into numeric vector (22 channels expected) ---
% Match floats (incl. scientific) OR the literal NaN
pat = "-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|NaN";
tok = regexp(raw.Sample, pat, 'match');         % N-by-1 cell, each cell is 1-by-C string tokens
if isempty(tok) || ~iscell(tok)
    error('Failed to parse Sample column from %s', csvFile);
end

% Convert tokens to doubles row-wise
C = numel(tok{1});
vals = cellfun(@(m) str2double(m), tok, 'UniformOutput', false);
A = vertcat(vals{:});   % N-by-C numeric

% --- Get channel labels from meta (if available) ---
varNames = strings(1, size(A,2));
if metaFile ~= ""
    meta = jsondecode(fileread(metaFile));
    if isfield(meta, "channels") && ~isempty(meta.channels)
        labs = string({meta.channels.label});
        % Guard against mismatch
        if numel(labs) == size(A,2)
            varNames = labs;
        else
            warning('Channel count mismatch: meta has %d, CSV parsed %d. Using generic names.', numel(labs), size(A,2));
        end
    end
end
if any(varNames == "")
    varNames = "Ch" + string(1:size(A,2));
end
varNames = matlab.lang.makeValidName(varNames, 'ReplacementStyle','delete');

% --- Build output table ---
T = array2table(A, 'VariableNames', cellstr(varNames));
% Add time columns: absolute (as logged) and relative (duration)
T.Timestamp = raw.Time;                                % seconds in logger’s clock
T.Time = seconds(T.Timestamp - T.Timestamp(1));        % duration since start
% T.Timestamp
% Reorder so Time cols are first
T = movevars(T, {'Timestamp','Time'}, 'Before', 1);

% --- Optional timetable ---
try
    TT = table2timetable(T, 'RowTimes', 'Time', 'DropVariableNames','Time');
catch
    TT = [];
end
end
