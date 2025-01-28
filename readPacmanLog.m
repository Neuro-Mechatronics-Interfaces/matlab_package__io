function data = readPacmanLog(filename)
% Function to parse a binary log file from the Pac-Man logger
% Args:
%   filename (string): Path to the binary log file
% Returns:
%   data (struct): Struct containing parsed log entries

% Define the structure of the binary log format
entryFormat = {
    'double', 1;  % Timestamp (8 bytes)
    'int32', 1;  % Score (4 bytes)
    'int32', 1;  % Speed (4 bytes)
    'double', 1;
    };
fixedEntrySize = sum(cellfun(@(x) getDataTypeSize(x) * 1, entryFormat(:, 1)));

% Size of the binary chunk (logged chunk size from Lua)
chunkSize = 0x1C09B10B - 0x1C09B088 + 1; % Adjust this based on your Lua logic

% Open the binary file for reading
fid = fopen(filename, 'rb');
if fid == -1
    error('Failed to open file: %s', filename);
end

% Read the file data
data = struct('Timestamp', {}, 'Score', {}, 'Speed', {}, 'Chunk', {int8.empty});
try
    while ~feof(fid)
        % Read the fixed-size portion of the log entry
        timestamp = fread(fid, 1, 'double');
        if isempty(timestamp)
            break;
        end
        score = fread(fid, 1, 'int');
        speed = fread(fid, 1, 'int');

        % Read the binary chunk
        chunk = fread(fid, chunkSize, 'int8');
        if length(chunk) ~= chunkSize
            warning('Incomplete chunk detected at the end of the file.');
            break;
        end

        % Store the parsed entry into the struct
        entry = struct(...
            'Timestamp', timestamp, ...
            'Score', score, ...
            'Speed', speed, ...
            'Chunk', int8(chunk)' ...
            );
        data = [data; entry]; %#ok<AGROW>
    end
    % keepRow = true(numel(data),1);
    % for ii = 2:numel(data)
    %     keepRow(ii) = sum(abs(data(ii).Chunk - data(ii-1).Chunk)) > eps;
    % end
    % data = data(keepRow);
catch ME
    fclose(fid);
    rethrow(ME);
end

fclose(fid);
end

function size = getDataTypeSize(dataType)
% Helper function to get the size of a given data type in bytes
switch dataType
    case 'double'
        size = 8;
    case 'uint32'
        size = 4;
    case 'uint8'
        size = 1;
    case 'int32'
        size = 4;
    case 'int16'
        size = 2;
    case 'int8'
        size = 1;
    otherwise
        error('Unknown data type: %s', dataType);
end
end
