function data = load_tablet_data(filename)
%LOAD_TABLET_DATA  Loads .bin file data used to save tablet pressure
%
% Syntax:
%   data = io.load_tablet_data(filename);

% Open the file for reading
fileID = fopen(filename, 'r');

% Read the header lines
creationTime = fgetl(fileID);
syncDevice = fgetl(fileID);
columnNames = fgetl(fileID);
columnNames = strsplit(columnNames,' | ');

% Read the binary data
data = fread(fileID, [4, inf], 'uint32')';

% Close the file
fclose(fileID);

% Convert data to table for easier viewing
data = array2table(data, 'VariableNames', columnNames);
data.Properties.UserData = struct('CreationTime', creationTime, 'SyncDeviceTag', syncDevice);
end
