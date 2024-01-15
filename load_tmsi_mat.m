function x = load_tmsi_mat(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir, verbose, options)
%LOAD_TMSI_MAT Loads "raw" data block that was saved via TMSiServer MATLAB API.
%
% Syntax:
%   x = io.load_tmsi_mat(subj, yyyy, mm, dd, array, block, rootdir, verbose);
%
% Example:
%   x = io.load_tmsi_mat('Ollie', 2021, 11, 4, "B", 16);
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
%   x - struct with fields similar to TMSiSAGA.Data object
%
% See also: Contents, parseXML, TMSiSAGA.Poly5.read, io.load_tmsi_raw

arguments
    SUBJ {mustBeTextScalar}
    YYYY (1,1) double
    MM (1,1) double
    DD (1,1) double
    ARRAY {mustBeTextScalar}
    BLOCK (1,1) double
    rootdir {mustBeFolder, mustBeTextScalar} = parameters('raw_data_folder');
    verbose (1,1) logical = true;
    options.Tag {mustBeTextScalar} = '';
end

if (numel(BLOCK) > 1) || (numel(ARRAY) > 1)
    x = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            x{iB, iA} = io.load_tmsi_mat(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB), rootdir, verbose, 'Tag', options.Tag); 
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

f = utils.get_block_name(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, 'tag', options.Tag, 'rootdir_raw', rootdir);

if exist(strcat(f.Raw.Block, '.mat'),'file')==0
    me = MException('io:missing_file:raw', ...
        'No file named "%s" exists.', ...
        f.Raw.Block);
    throw(me);
end

if verbose
    tic;
    fprintf(1, 'Reading <strong>%s</strong>...', f.Block);
end
x = load(f.Raw.Block);
x.name = f.Block;
x.num_samples = size(x.samples, 2);
if ~isfield(x, 'sample_rate')
    x.sample_rate = 4000; % Default sample rate.
end
if verbose
    fprintf(1, 'complete.\n');
    toc;
end
end

