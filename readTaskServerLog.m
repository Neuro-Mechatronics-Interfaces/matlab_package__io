function [logData, header] = readTaskServerLog(filename)
%READTASKSERVERLOG Reads generic binary reaction-task server log files, parsing the correct columns using header metadata.
%
% Syntax:
%   [logData, header] = io.readTaskServerLog(filename);
%
% Inputs:
%   filename - Path to the binary log file (e.g., 
%               'default_YYYY_MM_DD_log.reactions' or 
%               'MCPXX_YYYY_MM_DD_K.survivor'). The file extension should
%               be tied to the task-type, but the actual handling is
%               dependent on the binary-encoded filetype indicated in the
%               header metadata so the extension is mostly for helping to
%               identify a file-to-task association.
%
% Outputs:
%   logData - A table containing parsed log data. Columns depend on the 
%               type of binary file, and are parsed automatically using
%               data extracted from the header. See details below.
%   header - A struct containing metadata from the file header.
%
% Details:
%   ## `Survivor 2D` task log columns ##
%    * `Timestamp` (datetime): Timestamp for each sample, converted from a Float64 POSIX timestamp (UTC).
%    * `dx` (int8): Horizontal movement control, derived from "a/d" keyboard input.
%    * `dy` (int8): Vertical movement control, derived from "w/s" keyboard input.
%    * `Primary` (int8): State of the primary action button (e.g., spacebar), where 0 indicates not pressed and 1 indicates pressed ("ATTACK").
%    * `Secondary` (int8): State of the secondary action button (e.g., "f" key), where 0 indicates not pressed and 1 indicates pressed.
%    * `Score` (uint16): Current score of the player.
%    * `Health` (uint16): Current health of the player.
%    * `State` (uint16): Current state of the player (e.g., IDLE, MOVE, ATTACK).
%    * `Action` (uint16): Current action performed by the player.
%    * `NumEnemies` (uint16): Number of enemies currently present on the game canvas.
%    * `AttackRange` (int8): Range of the player’s attack, indicating how far attacks extend beyond the player’s hitbox.
%    * `AttackCooldown` (int8): Number of frames required between successive attacks.
%    * `Speed` (int8): Movement speed of the player, controlling how many pixels the player moves per frame.
%    * `Power` (int8): The player's power stat, determining the amount of damage dealt by their attacks.
%
%  ## `Basic Reactions` task log columns ##
%    * `Timestamp` (datetime): The timestamp from performance.now() (ms)
%    * `Frame` (uint32): The current frame index
%    * `AssertionState` (int8): The gamepad assertion state (0 or 1)
%    * `TaskState` (int8): The task state
%
% See also: fopen, fread, fgetl, typecast, datetime

% Open the file for reading in binary mode
fid = fopen(filename, 'rb');
if fid == -1
    error('Failed to open file: %s', filename);
end

try
    % Read the header size
    fseek(fid, 0, 'bof');
    headerText = '';
    while true
        line = fgetl(fid);
        if line==-1  % We reached the end of the file somehow
            break;
        end
        if ~ismember(line, '=')
            fclose(fid);
            break;
        end
        headerText = strcat(headerText, line, '\n');
    end

    % Parse the header into a struct
    headerLines = strsplit(string(headerText),"\\n");
    header = struct();
    dataStart = 1;
    for i = 1:numel(headerLines)
        keyValue = split(headerLines{i}, '=');
        if length(keyValue) == 2
            dataStart = dataStart + 1;
            key = strtrim(keyValue{1});
            value = strtrim(keyValue{2});
            if isnumeric(str2double(value)) && ~isnan(str2double(value))
                header.(key) = str2double(value);  % Convert numeric values
            else
                header.(key) = value;  % Keep strings as is
            end
        end
    end
    % Validate required header fields
    requiredFields = {'LOG_VERSION', 'HEADER_SIZE', 'TASK', 'SESSION', 'FILETYPE', 'FRAMESIZE', 'FIELDS'};
    for i = 1:length(requiredFields)
        if ~isfield(header, requiredFields{i})
            error('Missing required header field: %s', requiredFields{i});
        end
    end

    % Parse the fields description
    fields = split(header.FIELDS, ',');
    fieldSizes = zeros(length(fields),1);
    fieldNames = strings(length(fields),1);
    fieldEncoding = zeros(length(fields),1);
    fieldType = cell(length(fields),1);
    offset = 0;
    for i = 1:length(fields)
        [name, type] = strtok(fields{i}, ':');
        fieldNames(i) = strtrim(name);
        switch strtrim(type(2:end))
            case 'Float64'
                fieldSizes(i) = 8;
                fieldEncoding(i) = 1;
                fieldType{i} = 'double';
            case 'Int8'
                fieldSizes(i) = 1;
                fieldEncoding(i) = 1;
                fieldType{i} = 'int8';
            case 'Uint8'
                fieldSizes(i) = 1;
                fieldEncoding(i) = 1;
                fieldType{i} = 'uint8';
            case 'Uint32'
                fieldSizes(i) = 4;
                fieldEncoding(i) = -1;
                fieldType{i} = 'uint32';
            case 'Int32'
                fieldSizes(i) = 4;
                fieldEncoding(i) = -1;
                fieldType{i} = 'int32';
            case 'Int16'
                fieldSizes(i) = 2;
                fieldEncoding(i) = -1;
                fieldType{i} = 'int16';
            case 'Uint16'
                fieldSizes(i) = 2;
                fieldEncoding(i) = -1;
                fieldType{i} = 'uint16';
            otherwise
                error('Unsupported field type: %s', type);
        end
        offset = offset + fieldSizes(i);
    end

    % Ensure FRAMESIZE matches calculated field sizes
    if offset ~= header.FRAMESIZE
        error('FRAMESIZE in header does not match calculated field sizes.');
    end

    % Read the binary data
    fid = fopen(filename, 'rb');
    fseek(fid, header.HEADER_SIZE, 'bof');
    fileData = fread(fid, '*uint8');  % Read as unsigned 8-bit integers

    % Ensure file size is a multiple of the entry size
    if mod(numel(fileData), header.FRAMESIZE) ~= 0
        error('Corrupted file: File size is not a multiple of the entry size.');
    end

    % Calculate the number of entries
    numEntries = numel(fileData) / header.FRAMESIZE;

    % Preallocate arrays for efficiency
    logDataStruct = struct();
    for i = 1:length(fieldNames)
        logDataStruct.(fieldNames{i}) = zeros(numEntries, 1);
    end

    % Parse the binary data
    for i = 1:numEntries
        offset = (i - 1) * header.FRAMESIZE;

        for j = 1:length(fieldNames)
            fieldSize = fieldSizes(j);
            if fieldEncoding(j) > 0
                byteOrder = 1:fieldSize;
            else
                byteOrder = fieldSize:-1:1;
            end
            dataBytes = fileData(offset + byteOrder);
            value = typecast(dataBytes, fieldType{j});
            logDataStruct.(fieldNames{j})(i) = value;
            offset = offset + fieldSize;
        end
    end

    if isfield(logDataStruct,'Timestamp')
        logDataStruct.Timestamp = datetime(logDataStruct.Timestamp ./ 1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
        logDataStruct.Timestamp.TimeZone = 'America/New_York';
        logDataStruct.Timestamp.Format = 'dd-MMM-uuuu HH:mm:ss.SSSSSS';
    end

    % Convert to MATLAB table
    logData = struct2table(logDataStruct);
    logData.Properties.UserData = header;

catch ME
    fclose(fid);
    rethrow(ME);
end

fclose(fid);
end
