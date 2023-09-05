function write_wrist_xy_2_sto(filename, x, y, options)
%WRITE_TABLE_2_STO  Write data 
% 
% Syntax:
%   io.write_wrist_xy_2_sto(filename, x, y, 'Name', value, ...);
% 
% Inputs:
%   filename - Name of file to write potentiometer signals to.
%   x - Signal from (mid) x-potentiometer. Should already be in degrees.
%   y - Signal from (mid) y-potentiomter. Should already be in degrees.
%   'Name', value pairs: 
%       'Orientation' - 'MID' (default) | 'PRO' | 'Sup'
%       'SampleRate' - (1,1) double (default is 1000, sample rate in Hz)
%
% Output:
%   Generates a new .sto file with specified filename.
%
% Notes: 
%   Example .sto file header:
%     Results
%     version=1
%     nRows=1000
%     nColumns=21
%     inDegrees=yes
%     endheader
%
% See Also: Contents, OpenSim

arguments
    filename {mustBeTextScalar}
    x (:,1) double % "X" vector from wrist potentiometers
    y (:,1) double % "Y" vector from wrist potentiometers
    options.MotionName = 'Wrist-Movement';
    options.Columns (1,:) string = ["flexion", "deviation"];
    options.Orientation {mustBeTextScalar, mustBeMember(options.Orientation, {'MID', 'PRO', 'SUP'})} = 'MID';
    options.SampleRate (1,1) double = 1000;
    options.LowPassCutoff (1,1) double = 6;
    options.EnableLowPassFilter (1,1) logical = true;
    options.Version (1,1) double {mustBeInteger, mustBePositive} = 1;
end
[p,f,~] = fileparts(filename);
if options.EnableLowPassFilter
    [b,a] = butter(4, options.LowPassCutoff/(options.SampleRate/2), 'low');
    xf = filtfilt(b,a,x)';
    yf = filtfilt(b,a,y)';
else
    xf = x';
    yf = y';
end
switch options.Orientation
    case 'MID' % Do nothing
    case 'PRO'
        tmp = -yf;
        yf = xf;
        xf = tmp;
    case 'SUP'
        tmp = -xf;
        xf = yf;
        yf = tmp;
end
nRows = numel(xf);
nColumns = numel(options.Columns)+1; % Add one since first is always "time"
t = 0:(1/options.SampleRate):((nRows-1)/options.SampleRate);
var_names = ["time", options.Columns];

fid = fopen(fullfile(p,sprintf('%s.sto', f)), 'w');
fprintf(fid,'%s\n',options.MotionName);
fprintf(fid,'version=%d\n',options.Version);
fprintf(fid,'nRows=%d\n',nRows);
fprintf(fid,'nColumns=%d\n',nColumns);
fprintf(fid,'inDegrees=yes\n');
fprintf(fid,'endheader\n');
fprintf(fid,'%s\t',var_names);
fprintf(fid,'\n%1.3f\t%3.3f\t%3.3f',[t;xf;yf]);
fclose(fid);
end