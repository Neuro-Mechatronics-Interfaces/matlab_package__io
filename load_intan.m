function data = load_intan(SUBJ, YYYY, MM, DD, BLOCK, type, rootdir)
%LOAD_INTAN  Reader entry point for INTAN data files.
%
% Syntax:
%   data = io.load_intan(SUBJ, YYYY, MM, DD, BLOCK, type, rootdir);
%
% Inputs:
%   SUBJ - String: should be name of subject (e.g. "Rupert" or "Frank")
%   YYYY - year (numeric scalar)
%   MM - month (numeric scalar)
%   DD - day (numeric scalar)
%   BLOCK - Recording block index (numeric scalar)
%   type    - '.rhd' | (leaving extensible for other future filetypes)
%   rootdir - (Opt) The root folder where all the raw data stuff is kept.
%               This should normally stay the same unless we move 
%               our data share.
%
% Output:
%   data - Data struct with basically all the fieldnames that would
%           normally be returned to the base workspace as variables using
%           the default Intan reader functions, except now they're in a
%           data struct.
%
% See also: Contents

tank = sprintf("%s_%04d_%02d_%02d", SUBJ, YYYY, MM, DD);
root_input = fullfile(rootdir, SUBJ);
root_meta = fullfile(root_input, sprintf('%s.xlsx', tank));
if exist(root_meta,'file')==0
    error("No such file: %s\n\t->\tNeed a spreadsheet with 2 columns (Block | File) where first is the block index and second is the file location relative to the data tank folder in the same folder where this spreadsheet exists (e.g. Max_2022_12_15_221215_135949/Max_2022_12_15_221215_144440.rhd", root_meta);
end
T = readtable(root_meta);

iRow = T.Block == BLOCK;
if sum(iRow) ~= 1
    error("BLOCK:%d matched %d rows (should only match 1).", BLOCK, sum(iRow));
end
fname = fullfile(root_input, tank, T.File{iRow});

switch type
    case {'rhd', '.rhd'}
        data = io.read_Intan_RHD2000_file(fname);
    case {'rhs', '.rhs'}
        data = io.read_Intan_RHS2000_file(fname);
    otherwise
        error("Not setup to handle loading .rhs (need to download reader).");
end

end