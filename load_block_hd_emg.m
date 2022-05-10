function [emg, emg_b, aux_acc] = load_block_hd_emg(SUBJ, YYYY, MM, DD, ARRAY, BLOCK)
%LOAD_BLOCK_HD_EMG  Loads processed data block
%
% Syntax:
%   emg = io.load_block_hd_emg(SUBJ, YYYY, MM, DD, ARRAY, BLOCK)
%   [emg, emg_b, aux_acc] = io.load_block_hd_emg(SUBJ, YYYY, MM, DD, ARRAY, BLOCK)
%
% Example:
%   emg = io.load_block_hd_emg('Frank', 2021, 11, 18, "B", 97);
%   % This would return block 97 with array "B" data.
%
%   [~, ~, aux_acc] = io.load_block_hd_emg('Frank', 2022, 1, 11, "A", 0:28)
%   % This returns all the accelerometer data for "A" array in 1/11/22 expt
%       -> CAUTION: making large number elements in array can cause a drag
%           on system especially on PC without upgraded RAM so be mindful
%           of that!
%
% Inputs:
%   subj - String: should be name of subject (e.g. "Rupert" or "Frank")
%   yyyy - year (numeric scalar)
%   mm - month (numeric scalar)
%   dd - day (numeric scalar)
%   array - String: "A" or "B" etc. for array identifier
%   block - Recording block index (numeric scalar)
%
% Output:
%   emg - HD_EMG object wrapper for EMG array data.
%   emg_b - BIP_EMG object wrapper (optional); only looks for it if you
%               request this second output argument.
%
% See also: Contents

if (numel(ARRAY) > 1) || (numel(BLOCK) > 1)
    emg = cell(numel(BLOCK), numel(ARRAY));
    emg_b = cell(numel(BLOCK), numel(ARRAY));
    aux_acc = cell(numel(BLOCK), numel(ARRAY));
    for iB = 1:numel(BLOCK)
        for iA = 1:numel(ARRAY)
            switch  nargout
                case 1
                    emg{iB, iA} = io.load_block_hd_emg(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB));
                case 2
                    [emg{iB, iA}, emg_b{iB, iA}] = io.load_block_hd_emg(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB));
                case 3
                    [emg{iB, iA}, emg_b{iB, iA}, aux_acc{iB, iA}] = io.load_block_hd_emg(SUBJ, YYYY, MM, DD, ARRAY(iA), BLOCK(iB));
                otherwise
                    error('Invalid number of output arguments (%d).', nargout);
            end
        end
    end
    switch nargout
        case 1
            emg = reshape(vertcat(emg{:}), numel(ARRAY), numel(BLOCK));
        case 2
            emg = reshape(vertcat(emg{:}), numel(ARRAY), numel(BLOCK));
            emg_b = reshape(vertcat(emg_b{:}), numel(ARRAY), numel(BLOCK));
        case 3
            emg = reshape(vertcat(emg{:}), numel(ARRAY), numel(BLOCK));
            emg_b = reshape(vertcat(emg_b{:}), numel(ARRAY), numel(BLOCK));
            aux_acc = reshape(vertcat(aux_acc{:}), numel(ARRAY), numel(BLOCK));
        otherwise
            error('Shouldn''t reach here.');
    end
    return;
end

[yyyy, mm, dd] = utils.parse_date_args(YYYY, MM, DD);
if ~isnumeric(BLOCK)
    BLOCK = str2double(BLOCK);
end

gen_data_loc = parameters('generated_data_folder');
name = sprintf('%s_%04d_%02d_%02d', SUBJ, yyyy, mm, dd);
emg = getfield(load(sprintf('%s/%s/%s/%d/%s_%s_%d_EMG-UNI.mat', gen_data_loc, SUBJ, name, BLOCK, name, ARRAY, BLOCK), 'data'), 'data');
if nargout < 2
    return;
end
emg_b = getfield(load(sprintf('%s/%s/%s/%d/%s_%s_%d_EMG-BIP.mat', gen_data_loc, SUBJ, name, BLOCK, name, ARRAY, BLOCK), 'emg_b'), 'emg_b');
if nargout < 3
    return;
end
aux_acc = getfield(load(sprintf('%s/%s/%s/%d/%s_%s_%d_AUX-ACC.mat', gen_data_loc, SUBJ, name, BLOCK, name, ARRAY, BLOCK), 'aux_acc'), 'aux_acc');

end