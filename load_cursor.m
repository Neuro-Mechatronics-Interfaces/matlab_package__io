function [C, C_raw] = load_cursor(SUBJ, YYYY, MM, DD, options)
%LOAD_CURSOR Loads timetable with TREC drive depth information.
%
% Syntax:
%   [C, C_raw] = io.load_cursor(SUBJ, YYYY, MM, DD, 'Name', value, ...);
%
% Inputs:
%   SUBJ - Name of subject 
%   YYYY - Year (numeric)
%   MM   - Month (numeric)
%   DD   - Day (numeric)
%
% Options:
%     AutoSaveGenerated (1,1) logical = true;
%     CursorFileIdentifier {mustBeTextScalar} = "cursor";
%     CursorFileExtension {mustBeTextScalar} = ".log";
%     ForceRawParsing (1,1) logical = false;
%     MetadataVariableDelimiter {mustBeTextScalar} = "|";
%     MetadataEqualityDelimiter {mustBeTextScalar} = "=";
%     ParameterEqualityDelimiter {mustBeTextScalar} = ".";
%     RawDataRoot {mustBeTextScalar} = "";
%     RawDataBehaviorSubfolders cell = {'Behavior'};
%     ThrowErrorOnUnhandledDataType (1,1) logical = true;
%     ThrowErrorOnUnhandledParameterType (1,1) logical = true;
%     TrialDataDelimiter {mustBeTextScalar} = "/";
%     Verbose (1,1) logical = true;
%     XYDelimiter {mustBeTextScalar} = ",";
%
% Output:
%   C - timetable with Cursor x/y pixel position and metadata
%   C_raw - Original raw timetable as returned by `io.parse_cursor`
%
% See also: Contents, io.parse_cursor

arguments
    SUBJ {mustBeTextScalar}
    YYYY (1,1) double = year(today);
    MM (1,1) double = month(today);
    DD (1,1) double = day(today);
    options.AutoSaveGenerated (1,1) logical = true;
    options.CursorFileIdentifier {mustBeTextScalar} = "cursor";
    options.CursorFileExtension {mustBeTextScalar} = ".log";
    options.ForceRawParsing (1,1) logical = false;
    options.GeneratedDataRoot {mustBeTextScalar} = "";
    options.GeneratedDataBehaviorSubfolders cell = {'Behavior'};
    options.MetadataVariableDelimiter {mustBeTextScalar} = "|";
    options.MetadataEqualityDelimiter {mustBeTextScalar} = "=";
    options.ParameterEqualityDelimiter {mustBeTextScalar} = ".";
    options.RawDataRoot {mustBeTextScalar} = "";
    options.RawDataBehaviorSubfolders cell = {'Behavior'};
    options.ThrowErrorOnUnhandledDataType (1,1) logical = true;
    options.ThrowErrorOnUnhandledParameterType (1,1) logical = true;
    options.TrialDataDelimiter {mustBeTextScalar} = "/";
    options.Verbose (1,1) logical = true;
    options.XYDelimiter {mustBeTextScalar} = ",";
end

if datetime(YYYY,MM,DD) < datetime(2024,1,25)
    error("[io.load_cursor]::This type of cursor log handling only available for logs generated on or after 2024-01-25.");
end

% Handle folder name generation at the begining.
TANK = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
if strlength(options.RawDataRoot) == 0
    rawdata_root = parameters('raw_data_folder');
else
    rawdata_root = options.RawDataRoot;
end
rawdata_fullroot = fullfile(rawdata_root, SUBJ, options.RawDataBehaviorSubfolders{:});

if strlength(options.GeneratedDataRoot) == 0
    gendata_root = parameters('generated_data_folder');
else
    gendata_root = options.GeneratedDataRoot;
end
gendata_tank = fullfile(gendata_root, SUBJ, TANK, options.GeneratedDataBehaviorSubfolders{:});
gendata_file = sprintf('%s_%s.mat', TANK, options.CursorFileIdentifier);

if options.Verbose
    fprintf(1,'[io.load_cursor]::RawData::%s\n', rawdata_fullroot);
    fprintf(1,'[io.load_cursor]::GenData::%s\n', gendata_tank);
    fprintf(1,'[io.load_cursor]::Tank   ::%s\n', TANK);
end

gendata_fullfile = fullfile(gendata_tank, gendata_file);
if (~options.ForceRawParsing) && (exist(gendata_fullfile,'file')~=0) 
    if options.Verbose
        fprintf(1,'[io.load_cursor]::Found generated file. Loaded %s %s data directly from matfile.\n', ...
            TANK, options.CursorFileIdentifier);
    end
    if nargout < 2
        C = getfield(load(gendata_fullfile,'C'),'C');
        return;
    else
        in = load(gendata_fullfile,'C','C_raw');
        C = in.C;
        C_raw = in.C_raw;
        return;
    end
elseif options.ForceRawParsing
    if options.Verbose
        if options.AutoSaveGenerated
            fprintf(1,'[io.load_cursor]::Raw parsing forced via ForceRawParsing option. Parsing raw %s %s logs (will be auto-saved).\n', ...
                TANK, options.CursorFileIdentifier);
        else
            fprintf(1,'[io.load_cursor]::Raw parsing forced via ForceRawParsing option. Parsing raw %s %s logs. (AUTO-SAVE IS OFF - no file will be saved in generated tank).\n', ...
                TANK, options.CursorFileIdentifier);
        end
    end
else
    if options.Verbose
        if options.AutoSaveGenerated
            fprintf(1,'[io.load_cursor]::No generated cursor file detected. Parsing raw %s %s logs (will be auto-saved).\n', ...
                TANK, options.CursorFileIdentifier);
        else
            fprintf(1,'[io.load_cursor]::No generated cursor file detected. Parsing raw %s %s logs. (AUTO-SAVE IS OFF - no file will be saved in generated tank).\n', ...
                TANK, options.CursorFileIdentifier);
        end
    end
end
fname_raw = fullfile(rawdata_fullroot, ...
    sprintf('%s_%s.%s', TANK, options.CursorFileIdentifier, strrep(options.CursorFileExtension,'.','')));
C_raw = io.parse_cursor(fname_raw);


i_position = C_raw.DataType == "pos";
i_meta = C_raw.DataType == "metadata";

n_message_raw = sum(i_position);

tmp = C_raw.Data(i_meta);
tmp_ts = C_raw.Time(i_meta);
if isempty(tmp)
    meta = [];
else
    meta = [];
    for ii = 1:numel(tmp)
        meta_row = struct('Time', tmp_ts(ii));
        meta_vars = strsplit(tmp(ii),options.MetadataVariableDelimiter);
        for ik = 1:numel(meta_vars)
            var_info = strsplit(meta_vars(ik), options.MetadataEqualityDelimiter);
            meta_row.(var_info(1)) = var_info(2);
        end
        meta = [meta; meta_row]; %#ok<AGROW> 
    end
end

% Initialize data for parsed version of raw logs:
Time = C_raw.Time(i_position);
Orientation = enum.TaskOrientation(ones(n_message_raw,1).*-1);
NSuccessful = zeros(n_message_raw,1,'uint16');
NTotal = zeros(n_message_raw,1,'uint16');
MetaIndex = zeros(n_message_raw,1,'uint16');
X = zeros(n_message_raw,1,'uint16');
Y = zeros(n_message_raw,1,'uint16');

% Iterate over all rows of C_raw, updating Orientation, MetaIndex, 
% NSuccessful, and NTotal as appropriate based on 'param' and 'trial' 
% messages (C_raw.DataType). 
metaIndex = 0;
nSuccess = 0;
nTotal = 0;
orientation = enum.TaskOrientation.UNDEFINED;
rowIndex = 0;
NRaw = size(C_raw,1);
if options.Verbose
    fprintf(1,'[io.load_cursor]::Please wait, parsing raw cursor log from %s...000%%\n', TANK);
end
for ii = 1:NRaw
    switch C_raw.DataType(ii)
        case "metadata"
            metaIndex = metaIndex + 1;
        case "param"
            d_info = strsplit(C_raw.Data(ii),options.ParameterEqualityDelimiter);
            switch d_info(1)
                case "orientation"
                    orientation = enum.TaskOrientation.(d_info(2));
                otherwise
                    if options.ThrowErrorOnUnhandledParameterType
                        error("[io.load_cursor]::Unhandled Parameter: %s", d_info(ii));
                    elseif options.Verbose
                        warning('io:unhandled:bad_parameter', "[io.load_cursor]::Unhandled Parameter: %s", d_info(ii));
                    end
            end
        case "trial"
            d_info = strsplit(C_raw.Data(ii),options.TrialDataDelimiter);
            nSuccess = uint16(str2double(d_info(1)));
            nTotal = uint16(str2double(d_info(2)));
        case "pos"
            rowIndex = rowIndex + 1;
            d_info = strsplit(C_raw.Data(ii),options.XYDelimiter);
            X(rowIndex) = uint16(round(str2double(d_info(1))));
            Y(rowIndex) = uint16(round(str2double(d_info(2))));
            Orientation(rowIndex) = orientation;
            MetaIndex(rowIndex) = metaIndex;
            NSuccessful(rowIndex) = nSuccess;
            NTotal(rowIndex) = nTotal;
        case "data.graphics.refresh_parameters=true" % Exception
            continue;
        otherwise
            if options.ThrowErrorOnUnhandledDataType
                error("[io.load_cursor]::Unhandled DataType: %s", C_raw.DataType(ii));
            elseif options.Verbose
                warning('io:unhandled:bad_datatype', "[io.load_cursor]::Unhandled DataType: %s", C_raw.DataType(ii));
            end
    end
    if options.Verbose
        fprintf(1,'\b\b\b\b\b%03d%%\n', round(100*ii/NRaw));
    end
end


C = timetable(Time, Orientation, MetaIndex, NSuccessful, NTotal, X, Y);
C.Properties.UserData = struct(...
    'Subject', SUBJ, ...
    'Year', YYYY, ...
    'Month', MM, ...
    'Day', DD, ...
    'Tank', TANK, ...
    'Metadata', meta, ...
    'File', gendata_fullfile, ...
    'Paths', struct('RawData', fullfile(rawdata_fullroot,TANK), ...
                    'RawDataRoot', rawdata_root, ...
                    'GenData', gendata_tank, ...
                    'GenDataRoot', gendata_root));
if options.AutoSaveGenerated
    if exist(gendata_tank,'dir')==0
        mkdir(gendata_tank);
    end
    save(gendata_fullfile, 'C', 'C_raw', '-v7.3');
end

end