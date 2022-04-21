function data = load_tmsi_potentiometers(SUBJ, YYYY, MM, DD, ARRAY, BLOCK, varargin)
%LOAD_TMSI_RAW Loads raw data block
%
% Syntax:
%   data = io.load_tmsi_potentiometers(SUBJ, YYYY, MM, DD, ARRAY, BLOCK);
%   __ = io.load_tmsi_potentiometers(__, "Name", value, ...);
%
% Example:
%   x = io.load_tmsi_raw('Ollie', 2021, 11, 4, "B", 16);
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
%
%   'Name', value pairs (see top of code, each field of pars):
%       rootdir_gen - The root folder where all the raw data stuff is kept.
%                       This should normally stay the same unless we move 
%                       our data share.
%
% Output:
%   x - TMSiSAGA.Data object
%   info - Information about the file.
%
% See also: Contents, parseXML, TMSiSAGA.Poly5.read,
%               parse_polybench_data_manager_notes

% % Handle parameters % %
pars = struct;
[pars.rootdir_gen, pars.raw_matfiles_folder, pars.raw_matfiles_expr, ...
    pars.meta_file_expr] = ...
    utils.parameters('generated_data_folder', 'raw_matfiles_folder', ...
                     'raw_matfiles_expr', 'meta_file_expr'); % Filename of the *.json file defining MSB and LSB for each piece of information encoded in the task bit output.
pars = utils.parse_parameters(pars, varargin{:});

if (numel(BLOCK) > 1) || (numel(ARRAY) > 1)
    data = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            data{iB, iA} = io.load_tmsi_potentiometers(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB), pars); 
        end
    end
    data = vertcat(data{:});
    return;
end

[YYYY, MM, DD] = utils.parse_date_args(YYYY, MM, DD);
if ~isnumeric(BLOCK)
    BLOCK = str2double(BLOCK);
end

f = utils.get_block_name(SUBJ, YYYY, MM, DD, ARRAY, BLOCK);
meta_file = fullfile(f.Generated.Block, sprintf(pars.meta_file_expr, f.Block));
load(meta_file, 'channels');

data_channels = find(strcmpi(channels.alternative_name, 'ISO aux'));
if numel(data_channels)~=2
    error("LoadPotentiometers:WrongNumberChannels", "Should exist 2 channels with name ISO aux, instead found %d channels with that name!", numel(data_channels));
end

data = [];
dims = ["x", "y"];
for ii = 1:2
    in = load(fullfile(f.Generated.Block, pars.raw_matfiles_folder, channels.name(data_channels(ii))));
    in.dimension = dims(ii);
    in.block = f.Block;
    in.samples = in.samples - mean(in.samples);
    data = [data; in]; %#ok<AGROW>
end
end
