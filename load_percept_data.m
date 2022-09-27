function sens_data = load_percept_data(SUBJ, YYYY, MM, DD, BLOCK, varargin)
%LOAD_PERCEPT_DATA  Load percept yaml data for a given subject collected using perceptMapper variant for N3 analyses.
%
% Syntax:
%   sens_data = io.load_percept_data(SUBJ, YYYY, MM, DD, BLOCK, varargin)
%
% Inputs:
%   SUBJ  - Subject name (char or string)
%   YYYY  - Year (numeric)
%   MM    - Month (numeric)
%   DD    - Day (numeric)
%   BLOCK - Experiment number or "index"
%   varargin - (Optional) 'Name', value pairs found  in parameters struct.
%
% Output:
%   sens_data - Struct with sensory data info fields for a given block
%
% See also: Contents, io.yaml

pars = struct;
pars.raw_data_folder  = parameters('raw_data_folder');
pars = utils.parse_parameters(pars, varargin{:});

if numel(BLOCK) > 1
    sens_data = cell(size(BLOCK));
    for ii = 1:numel(BLOCK)
        sens_data{ii} = io.load_percept_data(SUBJ, YYYY, MM, DD, BLOCK(ii), varargin{:});
    end
    sens_data = vertcat(sens_data{:});
    return;
end

[YYYY, MM, DD] = utils.parse_date_args(YYYY, MM, DD);
tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
pixel_str = sprintf('%s_imPixel_%d.yaml', tank, BLOCK);
gui_str = sprintf('%s_RadioCheckSlider_%d.yaml', tank, BLOCK);
img_str = sprintf('%s_Sensation*_%d.png', tank, BLOCK);

sens_data = struct;
sens_data.tank = tank;
sens_data.block = BLOCK;
sens_data.fname.pixel = fullfile(pars.raw_data_folder, SUBJ, tank, 'notes', tank, pixel_str);
sens_data.fname.gui = fullfile(pars.raw_data_folder, SUBJ, tank, 'notes', tank, gui_str);
sens_data.fname.img = fullfile(pars.raw_data_folder, SUBJ, tank, 'notes', tank, img_str);


if exist(sens_data.fname.pixel, 'file')==0
    sens_data.pixel = [];
else
    fid = fopen(sens_data.fname.pixel, 'r');
    s = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    sens_data.pixel = io.yaml.load(strjoin(s{1}, '\n'), "ConvertToArray", true);
end

if exist(sens_data.fname.gui, 'file')==0
    sens_data.gui = [];
else
    fid = fopen(sens_data.fname.gui, 'r');
    s = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    idx = [find(startsWith(s{1}, 'Sensation')); numel(s{1})+1];
    sens_data.gui = cell(numel(sens_data.fname.gui), 1);
    for ii = 1:(numel(idx)-1)
        vec = (idx(ii)+1):(idx(ii+1)-1);
        sens_data.gui{ii, 1} = io.yaml.load(strjoin(s{1}(vec), '\n')); 
    end
end

sens_data.img = dir(sens_data.fname.img);
if isempty(sens_data.img)
    sens_data.imread = @()[];
else
    sens_data.imread = @()imread(fullfile(sens_data.img(end).folder, sens_data.img(end).name));
end
end