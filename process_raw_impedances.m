function process_raw_impedances(input_imp_files, output_imp_filename)
%PROCESS_RAW_IMPEDANCES  Process impedances from "raw" format.
%
% Syntax:
%   io.process_raw_impedances(input_imp_files, output_imp_filename);
%
% Inputs:
%   input_imp_files - Scalar or array of strings with filenames to load.
%   output_imp_filename - Scalar string/name of the single output file.
%
% Call this at least once to "process" the raw impedance data and put it in
% the correct format in the corresponding generated data location on
% raptor.
%
% See also: Contents, io.read_events

impedance = struct('Units', 'kΩ');
for ii = 1:numel(input_imp_files)
    f_info = strsplit(input_imp_files(ii), '_');
    i_tag = contains(f_info, '-impedance');
    f_info = char(f_info{i_tag});
    tag = f_info(1);
    impedance.(tag) = median(getfield(load(input_imp_files(ii), 'impedance'), 'impedance'),2);
end

save(output_imp_filename, '-struct', 'impedance');
fprintf(1,'Saved median impedance data to file: <strong>%s</strong>\n', output_imp_filename);

end