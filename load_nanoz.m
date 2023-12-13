function E = load_nanoz(YYYY, MM, DD, options)
%LOAD_NANOZ Loads electrode impedances table struct for NanoZ measurements.
%
% Syntax:
%   E = io.load_nanoz(YYYY, MM, DD, 'Name', value, ...):
%
% Inputs:
%     YYYY {mustBePositive, mustBeInteger}
%     MM {mustBePositive, mustBeInteger}
%     DD {mustBePositive, mustBeInteger}
%
% Options:
%   'Tag' {mustBeTextScalar} = '';
%   'FileType' {mustBeTextScalar} = ".txt";
%
% Output:
%   E - Struct where fieldname corresponds with the electrode name. 
%       -> If 'Electrode' option is specified, then instead of a struct
%       with electrode names as fields, E will either be a struct with 'I'
%       and 'Tag' fields as described below, or it would be the 'I' table
%       directly if 'Tag' option is also specified.
%
%       Each electrode field has two sub-fields: 
%           + 'I' (impedance table) 
%           + 'Tag' (an identifier in the filename)
%               -> If 'Tag' option is specified, then the electrode
%               sub-field is returned as the table that would go in 'I'
%               without 'I' or 'Tag' fields.
%
% See also: Contents

arguments
    YYYY {mustBePositive, mustBeInteger}
    MM {mustBePositive, mustBeInteger}
    DD {mustBePositive, mustBeInteger}
    options.Electrode {mustBeTextScalar} = '';
    options.Tag {mustBeTextScalar} = '';
    options.FileType {mustBeTextScalar} = ".txt";
    options.RootFolder {mustBeTextScalar} = "G:/Shared drives/NML_NHP/Impedances";
    options.VariableNames (1,:) cell = {'Site', 'MOhm', 'Phase'};
end

if strlength(options.Electrode) == 0
    elec = '*';
    elec_flag = false;
else
    elec = options.Electrode;
    elec_flag = true;
end

if strlength(options.Tag) == 0
    tag = '*';
    tag_flag = false;
else
    tag = options.Tag;
    tag_flag = true;
end
vt = repmat({'double'}, 1, numel(options.VariableNames));
opts = delimitedTextImportOptions('Delimiter', '\t', 'Whitespace', '\b', 'LineEnding', {'\n', '\r', '\r\n'}, ...
    'ConsecutiveDelimitersRule', 'split', 'CommentStyle', {}, 'EmptyLineRule', 'skip', ...
    'TrailingDelimitersRule', 'ignore', 'Encoding', 'windows-1252', 'DataLines', [4 35], ...
    'VariableNames', options.VariableNames, ...
    'VariableTypes', vt, ...
    'SelectedVariableNames', options.VariableNames);

f_str = sprintf('%04d_%02d_%02d_%s_%s%s', YYYY, MM, DD, elec, tag, options.FileType);
f_expr = fullfile(options.RootFolder, f_str);
F = dir(f_expr);
if numel(F) == 0
    error("No impedance files found matching string: %s.", f_str);
end

if elec_flag
    i_elec = contains({F.name}, elec);
    F = F(i_elec);
    if tag_flag
        i_tag = contains({F.name}, tag);
        if sum(i_tag)==0
            error("No filename contains specified tag (%s)", tag);
        elseif sum(i_tag)>1
            error("Multiple filenames contain specified tag (%s)", tag);
        end
        E = readtable(fullfile(F(i_tag).folder, F(i_tag).name), opts);
    else
        E = struct('Tag', cell(numel(F),1), 'I', cell(numel(F),1));
        for iF = 1:numel(F)
            [~,cur_tag,~] = fileparts(F(iF).name);
            cur_tag = strsplit(cur_tag, '_');
            cur_tag = strjoin(cur_tag(5:end),'_');
            E(iF).Tag = cur_tag;
            E(iF).I = readtable(fullfile(F(iF).folder, F(iF).name), opts);
        end
    end
else
    E = struct;
    for iF = 1:numel(F)
        [~,finfo,~] = fileparts(F(iF).name);
        finfo = strsplit(finfo, '_');
        cur_elec = strrep(finfo{4},'-','_');
        cur_tag = strjoin(finfo(5:end),'_');
        if isfield(E, cur_elec)
            E.(cur_elec)(end+1) = struct('Tag', cur_tag, 'I', readtable(fullfile(F(iF).folder, F(iF).name), opts));
        else
            E.(cur_elec) = struct('Tag', cur_tag, 'I', readtable(fullfile(F(iF).folder, F(iF).name), opts));
        end
    end
end

end