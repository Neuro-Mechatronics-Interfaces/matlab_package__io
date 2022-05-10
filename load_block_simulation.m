function F = load_block_simulation(SUBJ, YYYY, MM, DD, BLOCK)
%LOAD_BLOCK_SIMULATION  Loads simulated field data associated with a given experimental block.
%
% Syntax:
%   F = io.load_block_simulation(SUBJ, YYYY, MM, DD, BLOCK)
%
% Example:
%   F = io.load_block_simulation('Frank', 2021, 11, 18, 97);
%   % This would return a struct with simulated field values for Frank
%   % 2021-11-18 block 97.
%
% Inputs:
%   SUBJ - String: should be name of subject (e.g. "Rupert" or "Frank")
%   YYYY - year (numeric scalar)
%   MM - month (numeric scalar)
%   DD - day (numeric scalar)
%   BLOCK - Recording block index (numeric scalar)
%
% Output:
%   F - Struct with data related to field simulation/visualization.
%   Specifically, the fields:
%       - .X  X-Meshgrid at which values were computed
%       - .Y  Y-Meshgrid at which values were computed
%       - .Z  Actual current density values from simulation
%
% See also: Contents

if numel(BLOCK) > 1
    F = cell(numel(BLOCK), 1);
    for iB = 1:numel(BLOCK)
        F{iB, 1} = io.load_block_simulation(SUBJ, YYYY, MM, DD, BLOCK(iB));
    end
    return;
end

[yyyy, mm, dd] = utils.parse_date_args(YYYY, MM, DD);
if ~isnumeric(BLOCK)
    BLOCK = str2double(BLOCK);
end

gen_data_loc = parameters('generated_data_folder');
tank = sprintf('%s_%04d_%02d_%02d', SUBJ, yyyy, mm, dd);
block = sprintf('%s_%d', tank, BLOCK);
in_files = dir(fullfile(gen_data_loc, SUBJ, tank, num2str(BLOCK), sprintf('%s_Simulated_Field.mat', block)));
if isempty(in_files)
    F = [];
    warning('No simulated field data for <strong>%s</strong>.\n\t\t->\tDid you run `export_specific_simulation` for that block yet?\n', block);
    return;
end
F = load(fullfile(in_files(1).folder, in_files(1).name));
end