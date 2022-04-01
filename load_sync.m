function sync = load_sync(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir)
%LOAD_SYNC  Loads processed sync data
%
% Syntax:
%   sync = io.load_sync(SUBJ, YYYY, MM, DD, ARRAY, BLOCK)
%
% Example:
%   emg = io.load_sync('Forrest', 2022, 1, 25, "A", 7);
%   % This would return a sync struct for block 7 for Forrest on 1/25/2022
%   %  that was obtained for streams on NHP-A TMSiSAGA.
%
% Inputs:
%   SUBJ - String: should be name of subject (e.g. "Rupert" or "Frank")
%   YYYY - year (numeric scalar)
%   MM - month (numeric scalar)
%   DD - day (numeric scalar)
%   ARRAY - String: "A" or "B" etc. for array identifier
%   BLOCK - Recording block index (numeric scalar)
%   rootdir - (Opt) The root folder where all the generated data is kept.
%               This should normally stay the same unless we move 
%               our data share.
% Output:
%   sync - Data struct with fields:
%           - onset : Vector of sync RISING transition sample indices
%           - offset : Vector of sync FALLING transitions (note this is
%                       typically the actual stim "onset" due to inverted
%                       logic used by TMSi).
%           - sync_data : The actual sync data vector.
%
% See also: Contents

if nargin < 7
    rootdir = utils.parameters('generated_data_folder');
end


if (numel(ARRAY) > 1) || (numel(BLOCK) > 1)
    sync = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            sync{iB, iA} = io.load_sync(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB), rootdir);
        end
    end
    return;
end

[yyyy, mm, dd] = utils.parse_date_args(YYYY, MM, DD);
if ~isnumeric(BLOCK)
    BLOCK = str2double(BLOCK);
end

name = sprintf('%s_%04d_%02d_%02d', SUBJ, yyyy, mm, dd);
sync = load(sprintf('%s/%s/%s/%d/%s_%s_%d_sync.mat', rootdir, SUBJ, name, BLOCK, name, ARRAY, BLOCK));

% Fix mismatch in pairs of stim start/stop pairs
if numel(sync.offset) > numel(sync.onset)
    if sync.offset(end) > sync.onset(end)
        sync.offset(end) = [];
    end
end

end