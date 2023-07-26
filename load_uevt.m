function [T,fname] = load_uevt(options)
%LOAD_UEVT  Load .uevt file (which contains wrist task behavior events)
%
% Syntax:
%   T = io.load_uevt('Name', value, ...);
%   [T,fname] = ...
%
% Example 1:
%   T = io.load_uevt('File',"R:/path/to/data/Subject_2023_07_26_MID.uevt");
%
% Example 2:
%   T = io.load_uevt('Subject',"Rupert"); % Loads today's MID session
%
% Example 3:
%   T = io.load_uevt('Subject',"Rupert",'Orientation',"PRO"); % Loads
%                                                               today's PRO session
%
% Inputs:
%   options:
%     File {mustBeTextScalar} = 'none' % Can be full filename of file to load
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
    options.File {mustBeTextScalar} = 'none'
    options.CommentCharacter {mustBeTextScalar} = '#';
    options.DataShareRoot {mustBeFolder} = "R:\NMLShare\raw_data\primate";
    options.EventsSubFolder {mustBeTextScalar} = 'EVENTS';
    options.MaxCommentRows (1,1) double = 20; % Max number of rows in file that can be commented
    options.UseHeuristic (1,1) logical = true; % Set false to use standard file selector when no filename is provided
    options.UTCOffset (1,1) double = -4; % Pittsburgh during daylight savings time
    options.Subject {mustBeTextScalar} = '';
    options.Year (1,1) double = year(today);
    options.Month (1,1) double = month(today);
    options.Day (1,1) double = day(today);
    options.Orientation {mustBeTextScalar, mustBeMember(options.Orientation, {'MID', 'PRO'})} = 'MID';
end

if strcmpi(options.File, 'none')
    if strlength(options.Subject) > 0
        tank = sprintf('%s_%04d_%02d_%02d', options.Subject, options.Year, options.Month, options.Day);
        events_folder = sprintf('%s_%s', tank, options.EventsSubFolder);
        fname = fullfile(options.DataShareRoot, options.Subject, tank, events_folder, sprintf('%s_%s.uevt', tank, options.Orientation));
    elseif options.UseHeuristic
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
iHeader = find(iComment(1:options.MaxCommentRows));
if isempty(iHeader)
    if startsWith(s{1}{1}, 'Time')
        opts = delimitedTextImportOptions(...
            'NumVariables',3, ...
            'VariableNamesLine', 1, ...
            'VariableTypes', {'double', 'string', 'int16'}, ...
            'DataLines', [2, inf], ...
            'Delimiter', ',', ...
            'CommentStyle', options.CommentCharacter);
    else
        opts = delimitedTextImportOptions(...
            'NumVariables',3, ...
            'VariableNames', {'Time', 'Event', 'Data'}, ...
            'VariableTypes', {'double', 'string', 'int16'}, ...
            'DataLines', [1, inf], ...
            'Delimiter', ',', ...
            'CommentStyle', options.CommentCharacter);
    end
    meta = struct;
else
    if numel(iHeader) >= 3
        meta = struct(...
            'Experiment', strrep(s{1}{1},'# ', ''), ...
            'Created', strrep(s{1}{2},'# Created: ', ''), ...
            'Version', strrep(s{1}{3},'# ', ''));
    end
    iStart = [iHeader(end)+2, inf];
    opts = delimitedTextImportOptions(...
        'NumVariables',3, ...
        'VariableNamesLine', iHeader(end)+1, ...
        'VariableTypes', {'double', 'string', 'int16'}, ...
        'DataLines', iStart, ...
        'Delimiter', ',', ...
        'CommentStyle', options.CommentCharacter);
end

T = readtable(fname, opts);
T.Time = datetime(T.Time,'ConvertFrom','posixtime', ...
    'TimeZone','America/New_York', ...
    'Format', 'uuuu-MM-dd''T''HH:mm:ss.SSS');
T.Time = T.Time - hours(options.UTCOffset);
T = table2timetable(T,'RowTimes','Time');
T.Properties.UserData = meta;
end