function [x, info] = load_tmsi_raw(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir, verbose)
%LOAD_TMSI_RAW Loads raw data block.
%
% Syntax:
%   [x, info] = io.load_tmsi_raw(subj, yyyy, mm, dd, array, block);
%   [x, info] = io.load_tmsi_raw(subj, yyyy, mm, dd, array, block, rootdir, verbose);
%
% Example:
%   x = io.load_tmsi_raw('Ollie', 2021, 11, 4, "B", 16);
%   % This would return block 97 with array "B" data. Specify "*" to return
%   %  either block.
%
% Inputs:
%   subj - String: should be name of subject (e.g. "Rupert" or "Frank")
%   yyyy - year (numeric scalar)
%   mm - month (numeric scalar)
%   dd - day (numeric scalar)
%   array - String: "A" or "B" or "*" for array identifier
%   block - Recording block index (numeric scalar)
%   rootdir - (Opt) The root folder where all the raw data stuff is kept.
%               This should normally stay the same unless we move 
%               our data share.
%
% Output:
%   x - TMSiSAGA.Data object
%   info - Information about the file.
%
% See also: Contents, parseXML, TMSiSAGA.Poly5.read,
%               parse_polybench_data_manager_notes

if nargin < 7
    rootdir = parameters('raw_data_folder');
end

if nargin < 8
    verbose = true;
end

if (numel(BLOCK) > 1) || (numel(ARRAY) > 1)
    x = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            x{iB, iA} = io.load_tmsi_raw(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB), rootdir, verbose); 
        end
    end
    x = vertcat(x{:});
    x = reshape(x, numel(BLOCK), numel(ARRAY));
    return;
end

[YYYY, MM, DD] = utils.parse_date_args(YYYY, MM, DD);
if ~isnumeric(BLOCK)
    BLOCK = str2double(BLOCK);
end

f = utils.get_block_name(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, 'rootdir_raw', rootdir);
str = fullfile(f.Raw.Tank, sprintf('%s_%s_%d*', f.Tank, ARRAY, BLOCK));
F = dir(str);
if isempty(F)
    x = [];
    info = [];
    if verbose
        fprintf(1, 'No recording matches expression: <strong>%s</strong>\n', str);
    end
    return;
elseif numel(F) > 1
    iUse = nan;
    for iF = 1:numel(F)
        tmp = strsplit(F(iF).name, '-');
        recname = strip(tmp{1});
        if strcmpi(recname, f.Block)
            iUse = iF;
            break;
        end
    end
    if isnan(iUse)
        x = [];
        info = [];
        if verbose
            fprintf(1, 'Multiple recordings match expression, but no exact match for: <strong>%s</strong>\n', f.Block);
        end
        return;
    end
end

if verbose
    tic;
    fprintf(1, 'Reading <strong>%s</strong>...', F(1).name);
end
fname = strrep(F(1).name, ' ', '');
fname = strcat(fname, '.DATA.Poly5');
full_fname = fullfile(F(1).folder, F(1).name, fname);
if exist(full_fname, 'file')==0
    p = fullfile(F(1).folder, F(1).name);
    F2 = dir(fullfile(p, '*.Poly5'));
    if numel(F2) == 0
        throw(MException('Poly5:read', sprintf('Could not find file:  <strong>%s</strong>', b)));
    else
        full_fname = fullfile(F2(1).folder, F2(1).name);
    end
end

try
    x = TMSiSAGA.Poly5.read(full_fname);
catch me
    if strcmp(me.identifier, 'Poly5:read')
        warning('Could not open file for some reason; check if it is open elsewhere?');
        disp(me);
        x = [];
        info = [];
        return;
    else
        rethrow(me);
    end
end
x.name = f.Block;

if nargout > 1
    info = dir(full_fname);
    try
        [info.Annotation, info.Operator, info.Recording] = ...
            io.parse_polybench_data_manager_notes(info.folder);
    catch me
        disp(me);
        info.Annotation = "";
        info.Operator = "?";
        info.Recording = info.name;
    end
end
if verbose
    fprintf(1, 'complete.\n');
    toc;
end
end

