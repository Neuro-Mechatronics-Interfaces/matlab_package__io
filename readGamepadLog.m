function logData = readGamepadLog(filename)
% READGAMEPADLOG Reads a binary gamepad log file and parses its contents into a MATLAB table.
%
% INPUT:
%   filename - Path to the binary log file (e.g., 'log.bin').
%
% OUTPUT:
%   logData - A table containing parsed log data with columns:
%       - Timestamp: The timestamp from performance.now() (ms)
%       - AssertionState: The gamepad assertion state (0 or 1)
%       - TaskState: The task state (int8)
%
% Example Usage:
%   logData = io.readGamepadLog('log.bin');
%   disp(logData);

% Define the structure of each log entry
entrySize = 14; % 8 bytes for timestamp, 1 byte for assertionState, 1 byte for taskState, 4 bytes for curFrameIndex
[p,f,e] = fileparts(filename);
if isempty(e)
    filename = fullfile(p,sprintf('%s.reactions', f));
end
% Open the file for reading in binary mode
fid = fopen(filename, 'rb');
if fid == -1
    error('Failed to open file: %s', filename);
end

try
    % Read the entire file as bytes
    fileData = fread(fid, '*uint8'); % Read as unsigned 8-bit integers

    % Ensure file size is a multiple of the entry size
    if mod(numel(fileData), entrySize) ~= 0
        error('Corrupted file: File size is not a multiple of the entry size.');
    end

    % Calculate the number of entries
    numEntries = numel(fileData) / entrySize;

    % Preallocate arrays for efficiency
    timestamps = zeros(numEntries, 1, 'double');
    assertionStates = zeros(numEntries, 1, 'uint8');
    taskStates = zeros(numEntries, 1, 'int8');
    frameIndex = zeros(numEntries, 1, 'uint32');

    % Parse the binary data
    for i = 1:numEntries
        offset = (i - 1) * entrySize;

        % Extract and typecast the timestamp (8 bytes, explicitly little-endian)
        rawTimestamp = fileData(offset + (1:8));
        timestamps(i) = typecast(rawTimestamp(:)', 'double'); % Interpret as float64

        % Extract the assertionState (1 byte)
        assertionStates(i) = fileData(offset + 9);

        % Extract the taskState (1 byte)
        taskStates(i) = typecast(uint8(fileData(offset + 10)), 'int8');

        % Extract the current frame index (4 bytes)
        rawFrameBytes = fileData(offset + (14:-1:11));
        frameIndex(i) = typecast(rawFrameBytes, 'uint32'); 
    end
    dt = datetime(timestamps./1000,'ConvertFrom','posixtime','TimeZone','UTC');
    dt.TimeZone = 'America/New_York';
    dt.Format = 'dd-MMM-uuuu HH:mm:ss.SSSSSS';

    % Create a MATLAB table for easy access
    logData = table(dt, frameIndex, assertionStates, taskStates, ...
        'VariableNames', {'Timestamp', 'Frame', 'AssertionState', 'TaskState'});

catch ME
    % Ensure the file is closed if an error occurs
    fclose(fid);
    rethrow(ME);
end
fclose(fid);

end
