function survivorLog = readSurvivorLog(filename)
% READSURVIVORLOG Reads a binary .survivor log file and parses its contents into a MATLAB table.
%
% INPUT:
%   filename - Path to the binary log file (e.g., 'MCPXX_2025_01_13_log.survivor').
%
% OUTPUT:
%   survivorLog - A table containing parsed log data with columns:
% 
%    * @param {Float64} timestamp Timestamp for this sample.
%    * @param {Int8} dx dx control from a/d keys on keyboard-input (horizontal change).
%    * @param {Int8} dy dy control from w/s keys on keyboard-input (vertical change).
%    * @param {Int8} a "primary" button state: 0 (spacebar not pressed) or 1 (spacebar pressed = "ATTACK")
%    * @param {Int8} b "secondary" button state: 0 (reserved; 'f' key not pressed) or 1 ('f' key pressed)
%    * @param {Int16} score Current score of the player.
%    * @param {Int16} health Current health of the player.
%    * @param {Int16} state Current state of the player.
%    * @param {Int16} enemies Current number of enemies on the game canvas.
%
%
% Example Usage:
%   logData = io.readSurvivorLog('MCPXX_2025_01_13_log.survivor');
%   disp(logData);

% Define the structure of each log entry
entrySize = 20; % 8 bytes for timestamp, 1 byte for dx, 1 byte for dy, 1 byte for "a", 1 byte for "b", 2 bytes for score, 2 bytes for health, 2 bytes for player-state, 2 bytes for enemy counter

% Open the file for reading in binary mode
[p,f,e] = fileparts(filename);
if isempty(e)
    filename = fullfile(p,sprintf('%s.survivor',f));
end
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
    dx = zeros(numEntries, 1, 'int8');
    dy = zeros(numEntries, 1 ,'int8');
    a = zeros(numEntries, 1, 'int8');
    b = zeros(numEntries, 1, 'int8');
    score = zeros(numEntries, 1, 'uint16');
    health = zeros(numEntries, 1, 'uint16');
    state = zeros(numEntries, 1, 'uint16');
    enemies = zeros(numEntries, 1, 'uint16');

    % Parse the binary data
    for i = 1:numEntries
        offset = (i - 1) * entrySize;

        % Extract and typecast the timestamp (8 bytes, explicitly little-endian)
        rawTimestamp = fileData(offset + (1:8));
        timestamps(i) = typecast(rawTimestamp(:)', 'double'); % Interpret as float64

        % Extract x change from user input (1 byte)
        dx(i) = typecast(uint8(fileData(offset + 9)), 'int8');

        % Extract y change from user input (1 byte)
        dy(i) = typecast(uint8(fileData(offset + 10)), 'int8');

        % Extract x change from user input (1 byte)
        a(i) = typecast(uint8(fileData(offset + 11)), 'int8');

        % Extract y change from user input (1 byte)
        b(i) = typecast(uint8(fileData(offset + 12)), 'int8');

        % Extract score (2 bytes)
        score(i) = typecast(fileData(offset + ([14,13])), 'uint16');

        % Extract player health (2 bytes)
        health(i) = typecast(uint8(fileData(offset + ([16,15]))), 'uint16');

        % Extract player "state" (2 bytes)
        state(i) = typecast(uint8(fileData(offset + ([18,17]))), 'uint16');

        % Extract number of enemies (2 bytes)
        enemies(i) = typecast(uint8(fileData(offset + ([20,19]))), 'uint16');
    end
    dt = datetime(timestamps./1000,'ConvertFrom','posixtime','TimeZone','UTC');
    dt.TimeZone = 'America/New_York';
    dt.Format = 'dd-MMM-uuuu HH:mm:ss.SSSSSS';

    % Create a MATLAB table for easy access
    survivorLog = table(dt, dx, dy, a, b, score, health, state, enemies, ...
        'VariableNames', {'Timestamp', 'dx', 'dy', 'Primary', 'Secondary', 'Score', 'Health', 'State', 'NumEnemies'});

catch ME
    % Ensure the file is closed if an error occurs
    fclose(fid);
    rethrow(ME);
end
fclose(fid);

end
