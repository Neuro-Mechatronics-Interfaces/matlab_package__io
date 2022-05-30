function T = load_wrist_task_raw_logs(filename)
%LOAD_WRIST_TASK_RAW_LOGS  Import data from a text file.
%
% Syntax:
%  T = io.load_wrist_task_raw_logs(FILENAME) 
%
% Description:
%   Reads data from text file FILENAME for the default selection.  
%   Returns the data as a table.
%
% Example:
%  T = importfile("R:\NMLShare\raw_data\primate\Spencer\Behavior\Spencer_2021_10_17_Trial-Data_10-29-12.log", [1, Inf]);
%
% See also: Contents, READTABLE, DELIMITEDTEXTIMPORTOPTIONS, 
%   io.load_wrist_task_trial_logs

% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 5);

% Specify range and delimiter
opts.DataLines = [1, inf];
opts.Delimiter = " ";

% Specify column names and types
opts.VariableNames = ["Date", "Time", "log_type", "var_category", "raw"];
opts.VariableTypes = ["string", "string", "string", "string", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts.ConsecutiveDelimitersRule = "join";
opts.LeadingDelimitersRule = "ignore";

% Specify variable properties
opts = setvaropts(opts, ["Date", "Time", "var_category", "log_type", "raw"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Date", "Time", "var_category", "log_type", "raw"], "EmptyFieldRule", "auto");

% Import the data
T = readtable(filename, opts);

% % % --> Added by MM <-- % % %
% Remove brackets.
T.var_category = strrep(T.var_category, "[", "");
T.var_category = strrep(T.var_category, "]", ""); 

T.ts = datetime(strcat(T.Date, " ", T.Time), ...
            'TimeZone','America/New_York', ...
            'InputFormat', 'yyyy-MM-dd HH:mm:ss,SSS', ...
            'Format', 'yyyy-MM-dd HH:mm:ss.SSS');
T.Date = [];
T.Time = [];
T = movevars(T, 'ts', 'Before', 1);
T = table2timetable(T, 'RowTimes', 'ts');
end