function [annotation, operator, recording] = parse_polybench_data_manager_notes(block_path)
%PARSE_POLYBENCH_DATA_MANAGER_NOTES  Parse notes taken in Polybench Data Manager.
%
% Syntax:
%   [annotation, operator, recording] = io.parse_polybench_data_manager_notes(block_path);
%
% Example:
%   [Annotation, Operator, Recording] = io.parse_polybench_data_manager_notes('R:\NMLShare\raw_data\primate\Frank\Frank_2021_11_18');
%   my_notes = table(Recording, Operator, Annotation);
%   updated_meta_table = innerjoin(existing_meta_table, my_notes, 'Keys', {'Recording'});
%
% Inputs:
%   block_path -- String or character array of the file path where the recording block is saved.
%
% Output:
%   annotation -- Vector of strings that were manually added in Polybench
%                   Data Manager during the recording/experiment.
%   operator -- Vector of strings with initials for who was operating the
%                   Polybench Data Manager during recording.
%   recording -- Matched vector of strings with names of each recording
%                   block corresponding to each element of annotation.
%
% See also: Contents, getMetadata, parseXML, load_tmsi_raw

% Try to be OS agnostic here:
block_path = strrep(block_path, '\', filesep);
block_path = strrep(block_path, '/', filesep);


f_info = strsplit(block_path, filesep);
block_name = f_info{end};
if contains(block_name, ' - ')
    F = struct(...
        'folder', strjoin(f_info(1:(end-1)), filesep), ...
        'name', block_name, ...
        'isdir', true ...
        );
else
    F = dir(fullfile(block_path, strcat(block_name, "_*")));
end
F = F([F.isdir]);
N = numel(F);
annotation = strings(N, 1);
operator = strings(N, 1);
recording = strings(N, 1);
for iF = 1:N
    tmp = strsplit(F(iF).name, '-');
    recording(iF) = string(strip(tmp{1}, ' '));
    annotation_file = fullfile(F(iF).folder, F(iF).name, 'Record.xses');
    C = utils.parse_xml(annotation_file);
    annotation(iF) = C.Annotation;
    operator(iF) = C.Operator;
end

end