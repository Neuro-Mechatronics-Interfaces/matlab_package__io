function h = parse_wrist_task_txt_header(fname)
%PARSE_WRIST_TASK_TXT_HEADER Parse header of TrialData.txt file.
%
% Syntax:
%   h = io.parse_wrist_task_txt_header(fname);
%
% Inputs:
%   fname - Full filename of txt file to parse. First row of this file
%           should be 'UTF-8' encoded sets of <variable>:<value> with
%           whitespace delimiter between each pair.
%           e.g. 
%           Version:5.1 Session:uRfVdkFCAGZKsBqW Subject:Spencer ...
%
% Output:
%   h     - Header struct with version information and then each of the
%               fields (the first part of colon-delimited pairs) and their
%               corresponding value.
%
% See also: Contents, io.import_wrist_task_trial_data

fid = fopen(fname);
txt = fgets(fid);
header_vars = strsplit(txt, '\t');
try
    txt = fgets(fid);
catch
    h.Version = 0.1;
    h.var_line = 1;
    h.start_line = 2;
    h.num_vars = numel(header_vars);
    h.var_names = string(header_vars);
    return;
end
next_vars = strsplit(txt, '\t');
fclose(fid);
h = struct;
if contains(header_vars{1}, 'Version')
    for iV = 1:numel(header_vars)
        tmp = strsplit(header_vars{iV}, ':');
        data = str2double(tmp{2});
        if ~isnan(data)
            val = data;
        else
            val = tmp{2};
        end
        h.(tmp{1}) = val;
    end
    h.num_vars = numel(next_vars);
    h.var_names = string(next_vars);
    h.var_line = 2;
    h.start_line = 3;
else
    h.Version = struct;
    h.Version.Major = 0;
    h.Version.Minor = 1;
    h.num_vars = numel(header_vars);
    h.var_names = string(header_vars);
    h.var_line = 1;
    h.start_line = 2;
end
if ~isstruct(h.Version)
    tmp = num2str(h.Version);
    h.Version = struct;
    tmp_parts = strsplit(tmp, '.');
    h.Version.Major = str2double(tmp_parts{1});
    if numel(tmp_parts) == 1
        h.Version.Minor = 0;
    else
        h.Version.Minor = str2double(tmp_parts{2});
    end
end
end
