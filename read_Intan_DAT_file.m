function results = read_Intan_DAT_file(folderPath)
% READ_INTAN_DAT_FILE Reads Intan .dat files using settings.xml metadata.
%
% OUTPUT:
%   results: struct with fields compatible with downstream processing.

if nargin < 1 || isempty(folderPath)
    folderPath = uigetdir(pwd, 'Select the Intan data folder');
    if isequal(folderPath, 0)
        disp('User cancelled folder selection.');
        results = [];
        return;
    end
end

% Load settings.xml
settingsFile = fullfile(folderPath, 'settings.xml');
if ~isfile(settingsFile)
    error('settings.xml not found.');
end

xmlDoc = xmlread(settingsFile);
rootNode = xmlDoc.getDocumentElement;
sampleRate = str2double(rootNode.getAttribute('SampleRateHertz'));
fprintf('Sample Rate: %.2f Hz\n', sampleRate);

% Parse GeneralConfig
generalConfigNode = rootNode.getElementsByTagName('GeneralConfig').item(0);
generalAttributes = generalConfigNode.getAttributes;
generalConfig = struct();
for i = 0:generalAttributes.getLength-1
    attr = generalAttributes.item(i);
    name = char(attr.getName);
    value = char(attr.getValue);
    numValue = str2double(value);
    nameParts = strsplit(name, '.');
    if ~isnan(numValue)
        generalConfig = setNestedField(generalConfig, nameParts, numValue);
    elseif strcmpi(value, 'True')
        generalConfig = setNestedField(generalConfig, nameParts, true);
    elseif strcmpi(value, 'False')
        generalConfig = setNestedField(generalConfig, nameParts, false);
    else
        generalConfig = setNestedField(generalConfig, nameParts, value);
    end
end

% Parse channels
channelNodes = rootNode.getElementsByTagName('Channel');
nChannels = channelNodes.getLength;
channels = cell(nChannels, 1);
ampIndices = [];
auxIndices = [];
adcIndices = [];

for i = 0:nChannels-1
    chNode = channelNodes.item(i);
    attributes = chNode.getAttributes;
    chStruct = struct();
    for j = 0:attributes.getLength-1
        attr = attributes.item(j);
        name = char(attr.getName);
        value = char(attr.getValue);
        numValue = str2double(value);
        if ~isnan(numValue)
            chStruct.(name) = numValue;
        elseif strcmpi(value, 'True')
            chStruct.(name) = true;
        elseif strcmpi(value, 'False')
            chStruct.(name) = false;
        else
            chStruct.(name) = value;
        end
    end
    channels{i+1} = chStruct;

    nativeName = chStruct.NativeChannelName;
    if isfield(chStruct, 'Enabled') && chStruct.Enabled
        if ~isempty(regexp(nativeName, '^[AB]-\d{3}$', 'once'))
            ampIndices(end+1) = i+1;
        elseif ~isempty(regexp(nativeName, '^[AB]-AUX[1-6]$', 'once'))
            auxIndices(end+1) = i+1;
        elseif contains(nativeName, 'ADC')
            adcIndices(end+1) = i+1;
        end
    end
end

% Read amplifier.dat
amplifierFile = fullfile(folderPath, 'amplifier.dat');
amplifier_data = [];
nSamples = 0;
if isfile(amplifierFile)
    fprintf('Reading amplifier.dat...\n');
    fid = fopen(amplifierFile, 'rb');
    amplifier_raw = fread(fid, 'int16');
    fclose(fid);
    nAmpChannels = length(ampIndices);
    nSamples = floor(length(amplifier_raw) / nAmpChannels);
    amplifier_raw = amplifier_raw(1:nAmpChannels * nSamples);
    amplifier_data = reshape(amplifier_raw, nAmpChannels, nSamples);
    amplifier_data = 0.195 * (amplifier_data - 32768); % uV
else
    warning('amplifier.dat not found.');
end

% Read auxiliary.dat
auxiliaryFile = fullfile(folderPath, 'auxiliary.dat');
auxiliary_data = [];
if isfile(auxiliaryFile)
    fprintf('Reading auxiliary.dat...\n');
    fid = fopen(auxiliaryFile, 'rb');
    aux_raw = fread(fid, 'int16');
    fclose(fid);
    nAuxChannels = length(auxIndices);
    nSamplesAux = floor(length(aux_raw) / nAuxChannels);
    aux_raw = aux_raw(1:nAuxChannels * nSamplesAux);
    auxiliary_data = reshape(aux_raw, nAuxChannels, nSamplesAux);
    auxiliary_data = 0.0000374 * auxiliary_data; % V
end

% Read board-ADC.dat
adcFile = fullfile(folderPath, 'board-ADC.dat');
adc_data = [];
if isfile(adcFile)
    fprintf('Reading board-ADC.dat...\n');
    fid = fopen(adcFile, 'rb');
    adc_raw = fread(fid, 'int16');
    fclose(fid);
    nAdcChannels = length(adcIndices);
    nSamplesAdc = floor(length(adc_raw) / nAdcChannels);
    adc_raw = adc_raw(1:nAdcChannels * nSamplesAdc);
    adc_data = reshape(adc_raw, nAdcChannels, nSamplesAdc);
    adc_data = 0.000050354 * adc_data; % V
end

% Read time.dat
timeFile = fullfile(folderPath, 'time.dat');
time = [];
if isfile(timeFile)
    fprintf('Reading time.dat...\n');
    fid = fopen(timeFile, 'rb');
    timestamps_raw = fread(fid, 'uint32');
    fclose(fid);
    if mod(length(timestamps_raw), 2) == 0
        timestamps = timestamps_raw(1:2:end);
    else
        timestamps = timestamps_raw;
    end
    time = double(timestamps) / sampleRate;
    % Interpolate if time length doesn't match nSamples
    if length(time) ~= nSamples
        fprintf('Interpolating time vector from %d to %d samples...\n', length(time), nSamples);
        time = linspace(time(1), time(end), nSamples)';
    end
elseif nSamples > 0
    time = (0:nSamples-1)' / sampleRate;
    fprintf('Warning: time.dat not found. Using linear time vector.\n');
end

% Compile results struct
results = struct();
results.samplingRate = sampleRate;
results.generalConfig = generalConfig;
results.channels = channels;
results.frequency_parameters.amplifier_sample_rate = sampleRate;
results.frequency_parameters.aux_input_sample_rate = sampleRate / 4;
results.t_amplifier = time;
results.amplifier_data = amplifier_data;
results.aux_input_data = auxiliary_data;
results.board_adc_data = adc_data;

fprintf('Finished reading data.\n');
end

% Helper function
function s = setNestedField(s, nameParts, value)
if isscalar(nameParts)
    s.(nameParts{1}) = value;
else
    if ~isfield(s, nameParts{1}) || ~isstruct(s.(nameParts{1}))
        s.(nameParts{1}) = struct();
    end
    s.(nameParts{1}) = setNestedField(s.(nameParts{1}), nameParts(2:end), value);
end
end
