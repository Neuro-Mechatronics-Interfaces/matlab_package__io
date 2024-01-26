function C = parse_cursor(filename)
%PARSE_CURSOR Import data from a text file
%  C = io.parse_cursor(FILENAME) reads data from text file FILENAME for the
%  default selection.  Returns the data as a timetable.
%
%  Example:
%  C = io.parse_cursor("R:\NMLShare\raw_data\primate\Spencer\Behavior\Spencer_2024_01_25_cursor.log");
%
% Inputs:
%   filename {mustBeTextScalar, mustBeFile}
%
%  See also: Contents, load_cursor

arguments
    filename {mustBeTextScalar, mustBeFile}
end

% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 4);

% Specify range and delimiter
opts.DataLines = [1,Inf];
opts.Delimiter = "::";

% Specify column names and types
opts.VariableNames = ["Time", "LogType", "DataType", "Data"];
opts.VariableTypes = ["datetime", "categorical", "categorical", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, "Data", "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["LogType", "DataType", "Data"], "EmptyFieldRule", "auto");
opts = setvaropts(opts, "Time", "InputFormat", "yyyy-MM-dd HH:mm:ss,SSS");

% Import the data
C = readtable(filename, opts);
C.Time.TimeZone = 'America/New_York';
C.Time.Format = "yyyy-MM-dd HH:mm:ss.SSS";
C = table2timetable(C,'RowTimes',"Time");
end