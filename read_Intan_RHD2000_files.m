function data = read_Intan_RHD2000_files(folderPath, options)
%READ_INTAN_RHD2000_FILES Reads multiple Intan RHD data files from a folder.
%
% This function allows for reading multiple RHD files and provides an
% option to concatenate their data into a single structure.
%
% Example:
% >> data = read_Intan_RHD2000_files('C:\DataFolder', struct('Concatenate', true));
% >> whos
%
% Version 4.0, 15 March 2025

arguments
    folderPath {mustBeTextScalar} = ""
    options.Verbose (1,1) logical = true;
    options.Concatenate (1,1) logical = false;
end

if strlength(folderPath) == 0
    folderPath = uigetdir('', 'Select a Folder Containing RHD Files');
    if folderPath == 0
        return;
    end
end

rhdFiles = dir(fullfile(folderPath, '*.rhd'));
if isempty(rhdFiles)
    error('No RHD files found in the specified folder.');
end

data = struct([]); % Initialize output

for i = 1:length(rhdFiles)
    filename = fullfile(rhdFiles(i).folder, rhdFiles(i).name);
    if options.Verbose
        fprintf('Loading file: %s\n', filename);
    end
    fileData = io.read_Intan_RHD2000_file(filename, "Verbose", options.Verbose);
    
    if options.Concatenate
        if isempty(data)
            data = fileData; % Initialize with first file
        else
            data = concatenateSelectedFields(data, fileData);
        end
    else
        if isempty(data)
            data = fileData;
        else
            data(end+1) = fileData; %#ok<AGROW>
        end
    end
end

if options.Verbose
    fprintf('Finished loading %d files.\n', length(rhdFiles));
end
end

function combined = concatenateSelectedFields(struct1, struct2)
% Helper function to concatenate only selected fields

fieldsToConcatenate = {"t_amplifier", "amplifier_data", "t_aux_input", "aux_input_data", "t_board_adc", "board_adc_data"};
combined = struct1;

for i = 1:numel(fieldsToConcatenate)
    field = fieldsToConcatenate{i};
    if isfield(struct1, field) && isfield(struct2, field)
        if isnumeric(struct1.(field)) && isnumeric(struct2.(field))
            combined.(field) = [struct1.(field), struct2.(field)];
        else
            warning('Field %s has incompatible types; skipping concatenation.', field);
        end
    end
end
end