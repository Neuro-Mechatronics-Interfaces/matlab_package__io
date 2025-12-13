function result = read_OpenEphys_file(sessionPath, options)
%READ_OPENEHYS_FILE Loads Open Ephys session data and saves as .mat
%
%   result = read_OpenEphys_file(sessionPath, options)
%
%   Parameters:
%       sessionPath (string): Path to Open Ephys session directory. If empty, opens dialog.
%       options.Verbose (logical): Print info during loading (default: true)
%       options.SaveMat (logical): Save output as .mat file (default: true)
%
%   Returns:
%       result: struct with fields:
%           - amplifier_data (n_channels x n_samples)
%           - t_amplifier (1 x n_samples)
%           - sample_rate (scalar)
%           - recording_name (string)
%           - num_channels (scalar)
%           - file_type ('open-ephys')
%           - source_path (string)
%           - info (struct with metadata)

arguments
    sessionPath string = ""
    options.Verbose (1,1) logical = true
    options.SaveMat (1,1) logical = true
end

if sessionPath == ""
    sessionPath = uigetdir(pwd, 'Select Open Ephys Session Folder');
    if sessionPath == 0
        result = [];
        return;
    end
end

% Find a valid session directory (containing .oebin metadata)
sessionDir = find_valid_session_dir(sessionPath);
display(sessionDir);
if isempty(sessionDir)
    error('No valid Open Ephys session found in %s', sessionPath);
end

% Load metadata
metaFile = fullfile(sessionDir, 'structure.oebin');
if ~isfile(metaFile)
    error('structure.oebin not found in %s', sessionDir);
end
meta = jsondecode(fileread(metaFile));

% Find first continuous data stream
contStreams = meta.continuous;
if isempty(contStreams)
    error('No continuous data streams found in session.');
end
display(contStreams);
if iscell(contStreams)
    cont = contStreams{1};
else
    cont = contStreams;
end
contDir = fullfile(sessionDir, 'continuous');
dataFile = fullfile(contDir, cont.folder_name, 'continuous.dat');
if ~isfile(dataFile)
    error('Continuous data file not found: %s', dataFile);
end

% Extract info
sample_rate = cont.sample_rate;
num_channels = cont.num_channels;
recording_name = string(sessionDir);
file_type = 'open-ephys';
source_path = string(sessionPath);

% Get number of samples
fileInfo = dir(dataFile);
bytes_per_sample = 2; % int16
n_samples = fileInfo.bytes / (bytes_per_sample * num_channels);

% Read data
fid = fopen(dataFile, 'r');
raw = fread(fid, [num_channels, n_samples], 'int16=>double');
fclose(fid);

% Scale data (Open Ephys typically stores in microvolts, may need scaling factor)
scaling = 0.195; % microvolts per bit, adjust if needed
amplifier_data = scaling * raw;

% Load timestamps
timestampsFile = fullfile(contDir, cont.folder_name, 'timestamps.npy');
if isfile(timestampsFile)
    t_amplifier = io.readNPY(timestampsFile); % Requires npy-matlab: https://github.com/kwikteam/npy-matlab
else
    % If timestamps missing, generate based on sample rate
    t_amplifier = (0:n_samples-1) / sample_rate;
end

% Build result struct
result = struct();
result.amplifier_data = amplifier_data;
result.t_amplifier = t_amplifier;
result.board_adc_data = zeros(length(amplifier_data),3);
result.aux_input_data = zeros(length(amplifier_data),3);
result.frequency_parameters.amplifier_sample_rate = sample_rate;
result.frequency_parameters.aux_input_sample_rate = sample_rate;
result.recording_name = recording_name;
result.num_channels = num_channels;
result.file_type = file_type;
result.source_path = source_path;
result.info = meta;

if options.Verbose
    fprintf('Loaded Open Ephys session: %s\n', recording_name);
    fprintf('Sample rate: %.2f Hz, Channels: %d, Samples: %d\n', sample_rate, num_channels, n_samples);
end

% if options.SaveMat
%     matfile = fullfile(sessionDir, recording_name + ".mat");
%     save(matfile, '-struct', 'result', '-v7.3');
%     if options.Verbose
%         fprintf('Saved data to %s\n', matfile);
%     end
% end

end

function sessionDir = find_valid_session_dir(startPath)
% Recursively search upward for a directory containing 'structure.oebin'
sessionDir = '';
current = startPath;
while true
    if isfile(fullfile(current, 'structure.oebin'))
        sessionDir = current;
        return;
    end
    [parent, ~, ~] = fileparts(current);
    if parent == current
        return;
    end
    current = parent;
end
end
