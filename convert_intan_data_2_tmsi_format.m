function x = convert_intan_data_2_tmsi_format(data)
%CONVERT_INTAN_DATA_2_TMSI_FORMAT  Convert Intan data to TMSi format
%
% Syntax:
%   x = io.convert_intan_data_2_tmsi_format(data);
%
% Inputs:
%   data - Data struct as returned by io.load_Intan_RHD2000_file
%   
% Output:
%   x - Data struct as returned by io.load_tmsi
%       -> 'channels' -- cell array of channel objects
%       -> 'sample_rate' -- Sampling frequency
%       -> 'samples' -- Actual data samples (nChannels x nSamples)
%       -> 'time' -- Datetime at start of recording
%       -> 'name' -- Name of recording block (file)
%       -> 'num_samples' -- size(samples,2)
%
% See also: Content

map = [32:95; ...
       32:-1:1, 64:-1:33];

[data.amplifier_channels.alternative_name] = data.amplifier_channels.custom_channel_name; 
data.amplifier_channels = orderfields(data.amplifier_channels,[1:1,12,2:11]); 
data.amplifier_channels = rmfield(data.amplifier_channels,'custom_channel_name');

x.channels = num2cell(data.amplifier_channels);
for ii = 1:numel(x.channels)
    imap = x.channels{ii}.native_order == map(1,:);
    x.channels{ii}.alternative_name = sprintf('UNI %02d', map(2,imap));
end
x.channels{end+1} = x.channels{end};
x.channels{end}.alternative_name = 'TRIGGERS';

x.sample_rate = data.frequency_parameters.board_adc_sample_rate;
x.samples = [data.amplifier_data; data.board_dig_in_data];
finfo = strsplit(data.filename, '_');

YYYY = str2double(finfo{2});
MM = str2double(finfo{3});
DD = str2double(finfo{4});
dtstr = char(finfo{end});
hh = str2double(dtstr(1:2));
mm = str2double(dtstr(3:4));
ss = str2double(dtstr(5:6));
x.time = datetime(YYYY,MM,DD,hh,mm,ss);
x.name = data.filename;
x.num_samples = size(x.samples,2);

end