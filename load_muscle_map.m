function m = load_muscle_map(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir)
%LOAD_MUSCLE_MAP  Loads JSON muscle map object
%
% Syntax:
%   m = io.load_muscle_map(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir);
%
% Inputs:
%   SUBJ - String: should be name of subject (e.g. "Rupert" or "Frank")
%   YYYY - year (numeric scalar)
%   MM - month (numeric scalar)
%   DD - day (numeric scalar)
%   ARRAY - String: "A" or "B" or "*" for array identifier
%   BLOCK - Recording block index (numeric scalar)
%   rootdir - (Opt) The root folder where all the raw data stuff is kept.
%               This should normally stay the same unless we move 
%               our data share.
%
% Output:
%   m - io.JSON object with fields corresponding to unipolar/bipolar
%       channel names/impedances.
%
% See also: Contents, JSON

if nargin < 7
    rootdir = utils.parameters('raw_data_folder');
end

if (numel(BLOCK) > 1) || (numel(ARRAY) > 1)
    m = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            m{iB, iA} = io.load_muscle_map(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB), rootdir); 
        end
    end
    m = vertcat(m{:});
    m = reshape(m, numel(BLOCK), numel(ARRAY));
    return;
end

[YYYY, MM, DD] = utils.parse_date_args(YYYY, MM, DD);
if ~isnumeric(BLOCK)
    BLOCK = str2double(BLOCK);
end

f = utils.get_block_name(SUBJ, YYYY, MM, DD, ARRAY, BLOCK);
% Check a couple ways it could be named by default:
mname = fullfile(f.Raw.Subj, sprintf("%s_Muscle-Map.json", f.Block));
if exist(mname, 'file') == 0
    mname = fullfile(f.Raw.Subj, sprintf("%s_%s_Muscle-Map.json", f.Tank, ARRAY));
    if exist(mname, 'file') == 0
        mname = fullfile(f.Raw.Subj, sprintf("%s_Muscle-Map_%s.json", f.Tank, ARRAY));
        if exist(mname, 'file') == 0
            warning("No muscle map found (looked for file: <strong>%s</strong>)\n", mname);
            m = [];
            return;
        end
    end
end
tic;
fprintf(1, 'Reading <strong>%s</strong>...', mname);
m = io.JSON(mname);
fprintf(1, 'complete.\n');
toc;
end
