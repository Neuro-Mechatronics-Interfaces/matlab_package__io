function offset = load_tmsi_triggers(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir)
%LOAD_TMSI_TRIGGERS Loads TMSi sync triggers if they have been parsed
%
% Syntax:
%   offset = io.load_tmsi_triggers(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, rootdir);
%
% Example:
%   offset = io.load_tmsi_triggers('Frank', 2021, 12, 9, "B", 155);
%       -> Uses default rootdir ('generated_data > primate > DARPA_N3', on
%           `raptor` data share).
% 
% Inputs:
%   SUBJ - Subject name (char array or string)
%   YYYY - Year (4-digit year char array or string, or double)
%   MM - Month (2-digit month char array or string, or double)
%   DD - Day (2-digit day char array or string, or double)
%   ARRAY - "A", "B", or ["A, "B"]
%   BLOCK - Numeric double scalar or vector of recording block keys.
%       --> If ARRAY or BLOCK are nonscalar, then `offset` is returned as a
%           cell array, with dimensions numel(BLOCK) x numel(ARRAY)
%   rootdir - The root folder where all the generated data stuff is kept.
%               This should normally stay the same unless we move 
%               our data share.
%
% Output:
%   offset - Vector of sample indices where sync signal is observed.
% 
% See also: Contents, io.load_tmsi_triggers, io.load_tmsi_raw

if nargin < 7
    rootdir = utils.parameters('generated_data_folder');
end

% Iterate over ARRAY and BLOCK elements if any are non-scalar.
if (numel(ARRAY) > 1) || (numel(BLOCK) > 1)
    offset = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            offset{iB, iA} = io.load_tmsi_triggers(SUBJ, YYYY, MM, DD, ARRAY{iA}, BLOCK(iB), rootdir);
        end
    end
    return;
end
    
% Check inputs
[YYYY, MM, DD] = utils.parse_date_args(YYYY, MM, DD);

tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
f_expr = sprintf('%s_%s_%d_sync.mat', tank, ARRAY, BLOCK);
gen_folder = fullfile(rootdir, SUBJ, tank, num2str(BLOCK));

fname = fullfile(gen_folder, f_expr);

if exist(fname, 'file')==0
    offset = [];
    warning('No sync file (<strong>%s</strong>) exists.', f_expr);
    return;
end

offset = getfield(load(fname, 'offset'), 'offset');

end

