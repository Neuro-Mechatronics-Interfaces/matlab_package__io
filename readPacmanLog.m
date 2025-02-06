function data = readPacmanLog(filename)
% Function to parse a binary log file from the Pac-Man logger
% Args:
%   filename (string): Path to the binary log file
% Returns:
%   data (struct): Struct containing parsed log entries


% Size of the binary chunk (logged chunk size from Lua)
% chunkSize = 0x1C09B10B - 0x1C09B088 + 1; % This is based on the Lua logger logic

% Open the binary file for reading
fid = fopen(filename, 'rb');
if fid == -1
    error('Failed to open file: %s', filename);
end

% Read the file data
nGhosts = 64;
data = struct('Timestamp', {}, 'Score', {}, 'Speed', {}, 'Bombs', {}, 'Lives', {}, 'X', {}, 'Y', {}, 'GhostX', {}, 'GhostY', {}, 'GhostVisible', {});
try
    tStart = fread(fid,1,'double');
    logVersion = fread(fid,1,'int32');
    playerName = fread(fid,8,"uint8");
    playerName = string(char(playerName(playerName>0)'));
    while ~feof(fid)
        % Read the fixed-size portion of the log entry
        timestamp = fread(fid, 1, 'double');
        if isempty(timestamp)
            break;
        end
        score = fread(fid, 1, 'int32');
        speed = fread(fid, 1, 'int32');
        bombs = fread(fid, 1, 'int32');
        lives = fread(fid, 1, 'int32');
        x = fread(fid,1,"float");
        y = fread(fid,1,"float");
        gx = zeros(1,nGhosts);
        gy = zeros(1,nGhosts);
        gv = false(1,nGhosts);
        for ik = 1:nGhosts
            tmp = fread(fid, 1, "float");
            if numel(tmp) ~= 1
                fseek(fid,-4,"cof");
                break;
            end
            gx(ik) = tmp;
            gy(ik) = fread(fid, 1, "float");
            gv(ik) = fread(fid, 1, "uint8") == 1;
        end

        % % Read the binary chunk
        % chunk = fread(fid, chunkSize, 'uint8');
        % if length(chunk) ~= chunkSize
        %     warning('Incomplete chunk detected at the end of the file.');
        %     break;
        % end

        % Store the parsed entry into the struct
        entry = struct(...
            'Timestamp', timestamp, ...
            'Score', score, ...
            'Speed', speed, ...
            'Bombs', bombs, ...
            'Lives', lives, ...
            'X', x, ...
            'Y', y, ...
            'GhostX', gx, ...
            'GhostY', gy, ...
            'GhostVisible', gv ...
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
data = struct2table(data);
data = sortrows(data,'Timestamp','ascend');
missing_ghost = false(1,nGhosts);
for ii = 1:nGhosts
    missing_ghost(ii) = all(abs(data.GhostX(:,ii))<eps) & all(abs(data.GhostY(:,ii))<eps);
end
data.GhostX(:,missing_ghost) = [];
data.GhostY(:,missing_ghost) = [];
data.GhostVisible(:,missing_ghost) = [];
data.Properties.UserData = struct('tStart', tStart, 'version', logVersion, 'player', playerName, ...
    'nGhosts', nGhosts-nnz(missing_ghost));

end

