function [x, info] = load_tmsi(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, type, rootdir)
%LOAD_TMSI  Loads "raw" data block that was saved via TMSiServer MATLAB API
%
% Syntax:
%   [x, info] = io.load_tmsi(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, type, rootdir);
%
% Example:
%   x = io.load_tmsi_mat('Ollie', 2021, 11, 4, "B", 16);
%   % This would return block 97 with array "B" data. Specify "*" to return
%   %  either block.
%
% Inputs:
%   SUBJ - String: should be name of subject (e.g. "Rupert" or "Frank")
%   YYYY - year (numeric scalar)
%   MM - month (numeric scalar)
%   DD - day (numeric scalar)
%   ARRAY - String: "A" or "B" or "*" for array identifier
%   BLOCK - Recording block index (numeric scalar)
%   type - Filetype: ".mat" or ".poly5"
%   rootdir - (Opt) The root folder where all the raw data stuff is kept.
%               This should normally stay the same unless we move 
%               our data share.
%
% Output:
%   x    - struct with fields similar to TMSiSAGA.Data object
%   info - Returns annotation data from PolyBench datamanager (".poly5"
%               type only)
%
% See also: Contents, parseXML, TMSiSAGA.Poly5.read, 
%           io.load_tmsi_raw, io.load_tmsi_mat

if nargin < 8
    rootdir = utils.parameters('raw_data_folder');
end

if (numel(BLOCK) > 1) || (numel(ARRAY) > 1)
    x = cell(numel(BLOCK), numel(ARRAY));
    info = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            [x{iB, iA}, info{iB, iA}] = io.load_tmsi(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB), type, rootdir); 
        end
    end
    x = vertcat(x{:});
    x = reshape(x, numel(BLOCK), numel(ARRAY));
    if nargout > 1
        info = vertcat(info{:});
        info = reshape(info, numel(BLOCK), numel(ARRAY));
    end
    return;
end

if ~startsWith(type, ".")
    type = strcat(".", type);
end

switch lower(type)
    case ".mat"
        x = io.load_tmsi_mat(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir);
        info = [];
    case ".poly5"
        if nargout == 1
            x = io.load_tmsi_raw(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir);
            info = [];
        else
            [x, info] = io.load_tmsi_raw(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir);
        end
    otherwise
        error("File parsing for TMSi not handled for type == %s.", type);
end

end
