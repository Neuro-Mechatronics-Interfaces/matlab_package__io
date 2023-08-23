function [x, info] = load_data(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, type, rootdir, options)
%LOAD_DATA  API access-point for loading TMSi or Intan HD-EMG data. 
%
% Syntax:
%   [x, info] = io.load_data(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, type, rootdir);
%
% Example:
%   x = io.load_data('Max', 2022, 12, 15, "A", 11, '.rhd', 'R:\NMLShare\raw_data\human');
%
% Inputs:
%   SUBJ - String: should be name of subject (e.g. "Rupert" or "Frank")
%   YYYY - year (numeric scalar)
%   MM - month (numeric scalar)
%   DD - day (numeric scalar)
%   ARRAY - String: "A" or "B" or "*" for array identifier
%       -> This is superfluous if using '.rhd' or other Intan option; just
%       specify as "X" or whatever.
%   BLOCK - Recording block index (numeric scalar)
%   type - Filetype: ".mat" or ".poly5" or ".rhd"
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

arguments
    SUBJ {mustBeTextScalar}
    YYYY (1,1) double {mustBeNumeric, mustBeInteger}
    MM (1,1) double {mustBeNumeric, mustBeInteger}
    DD (1,1) double {mustBeNumeric, mustBeInteger}
    ARRAY {mustBeTextScalar}
    BLOCK {mustBeNumeric, mustBeInteger}
    type {mustBeTextScalar, mustBeMember(type, {'.rhd', '.mat', '.poly5', 'rhd', 'mat', 'poly5'})} = '.mat'
    rootdir {mustBeTextScalar, mustBeFolder} = 'R:/NMLShare/raw_data/primate'
    options.Convert2TMSi (1,1) logical = false; 
    options.Tag {mustBeTextScalar} = '';
end

if (numel(BLOCK) > 1) || (numel(ARRAY) > 1)
    x = cell(numel(BLOCK), numel(ARRAY));
    info = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            [x{iB, iA}, info{iB, iA}] = io.load_data(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB), type, rootdir, ...
                'ConvertToTMSi', options.ConvertToTMSi, ...
                'Tag', options.Tag); 
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
    case ".rhd"
        data = io.load_intan(SUBJ, YYYY, MM, DD, BLOCK, '.rhd', rootdir);
        if options.Convert2TMSi
            x = io.convert_intan_data_2_tmsi_format(data);
        else
            x = data;
        end
        x.name = sprintf('%s_%04d_%02d_%02d_%d', SUBJ, YYYY, MM, DD, BLOCK);

    case ".mat"
        x = io.load_tmsi_mat(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir, 'Tag', options.Tag);
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
