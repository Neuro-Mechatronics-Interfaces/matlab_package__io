function [T,fname] = load_uevt(fname, options)
%LOAD_UEVT  Load .uevt file (which contains wrist task behavior events)
%
% Syntax:
%   T = io.load_uevt(fname, 'Name', value, ...);
%   [T,fname] = ...
%
% Inputs:
%   fname - Filename for the .uevt file. If not supplied, then user is
%               prompted via dialog selection.
%   options:
%     CommentCharacter {mustBeTextScalar} = '#';
%     StartingRow (1,1) double = 4;
%
% Output:
%   T - Timetable with columns 'Time' | 'Event' | 'Data' --> related to
%           Jetson wrist task logs.
%   fname - Name of the opened file.
%
% See also: Contents

arguments
    fname {mustBeTextScalar} = 'none'
    options.CommentCharacter {mustBeTextScalar} = '#';
    options.DataShareRoot {mustBeFolder} = "R:\NMLShare\raw_data\primate";
    options.EventsSubFolder {mustBeTextScalar} = 'EVENTS';
    options.MaxCommentRows (1,1) double = 20; % Max number of rows in file that can be commented
    options.UseHeuristic (1,1) logical = true; % Set false to use standard file selector when no filename is provided
    options.UTCOffset (1,1) double = -4; % Pittsburgh during daylight savings time
end

if strcmpi(fname, 'none')
    if options.UseHeuristic
        [SUBJ, YYYY, MM, DD, ~, ~] = io.quick_selector_gui();
        ornt = questdlg('Select task orientation.', 'Orientation', 'MID', 'PRO', 'Cancel', 'Cancel');
        if isempty(ornt) || strcmpi(ornt, 'Cancel')
            T = [];
            disp("Canceled load of .uevt file.");
            return;
        end
        tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
        events_folder = sprintf('%s_%s', tank, options.EventsSubFolder);
        fname = fullfile(options.DataShareRoot, SUBJ, tank, events_folder, sprintf('%s_%s.uevt', tank, ornt));
        if exist(fname,'file')==0
            error("No such file (%s) exists.", fname);
        end
    else
        fname = uigetfile({'*.uevt','UDP Event Files';'*.*','Any File Type'}, ...
            'Select event file', ...
            options.DataShareRoot);
        if fname == 0
            T = [];
            disp("Canceled load of .uevt file.");
            return;
        end
    end
end

fid = fopen(fname, 'r');
s = textscan(fid,'%s', 'Delimiter', {'\n', '\r'});
fclose(fid);
iComment = cellfun(@(c)startsWith(c, options.CommentCharacter), s{1});
iHeader = find(iComment(1:options.MaxCommentRows),1,'last')+1; % 1 after last comment line.
iStart = [iHeader+1, inf];
opts = delimitedTextImportOptions(...
    'NumVariables',3, ...
    'VariableNamesLine', iHeader, ...
    'VariableTypes', {'double', 'string', 'int16'}, ...
    'DataLines', iStart, ...
    'Delimiter', ',', ...
    'CommentStyle', options.CommentCharacter);
T = readtable(fname, opts);
T.Time = datetime(T.Time,'ConvertFrom','posixtime', ...
    'TimeZone','America/New_York', ...
    'Format', 'uuuu-MM-dd''T''HH:mm:ss.SSS');
T.Time = T.Time - hours(options.UTCOffset);
T = table2timetable(T,'RowTimes','Time');
end