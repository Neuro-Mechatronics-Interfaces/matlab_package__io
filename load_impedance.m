function impedance = load_impedance(SUBJ, YYYY, MM, DD, ARRAY, options)
%LOAD_IMPEDANCE  Load impedance if it's been parsed in generated_data
%
% Syntax:
%   impedance = io.load_impedance(SUBJ, YYYY, MM, DD, varargin);
%
% Inputs:
%   SUBJ - Subject name (e.g. "Spencer")
%   YYYY - Year (numeric e.g. 2022)
%   MM   - Month (numeric e.g. 12)
%   DD   - Day (numeric e.g. 2)
%   ARRAY - Array (e.g. "A" or "B")
%   varargin - (Optional) 'Name',value input argument pairs
%   -> 'generated_data_folder' : Location of generated_data

arguments
    SUBJ {mustBeTextScalar} % Subject name (string or char)
    YYYY (1,1) double % Year (numeric)
    MM (1,1) double % Month (numeric)
    DD (1,1) double % Day (numeric)
    ARRAY {mustBeTextScalar}
    options.generated_data_folder {mustBeTextScalar} = ''
    options.raw_data_folder {mustBeTextScalar} = '';
    options.impedances_tag {mustBeTextScalar} = 'impedance';
    options.sub_folder {mustBeTextScalar} = '';
    options.block (1,1) double = nan;
    options.raw (1,1) logical = false;
end

if options.raw
    if strlength(options.raw_data_folder) == 0
        data_folder = parameters('raw_data_folder');
    else
        data_folder = options.raw_data_folder;
    end
else
    if strlength(options.generated_data_folder) == 0
        data_folder = parameters('generated_data_folder');
    else
        data_folder = options.generated_data_folder;
    end
end

tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
fname = fullfile(data_folder, SUBJ, tank, options.sub_folder, sprintf("%s*%s-%s*.mat", tank, ARRAY, options.impedances_tag));
F = dir(fname);
if isempty(F)
    if options.raw
        error('io:missing_file:generated', ...
            'No such file: "%s"\n\t->\tIs impedance file in the main tank folder or in a sub-folder? If the latter, you may need to set the "subfolder" option.', ...
            fname);
    else
        error('io:missing_file:generated', ...
            'No such file: "%s"\n\t->\tHave you parsed raw impedances yet? Try again with <"raw",true> setting.', ...
            fname);
    end
elseif numel(F) > 1
    if ~isnan(options.block)
        parsed_block = nan(numel(F),1);
        for ii = 1:numel(F)
            [~,name,~] = fileparts(F(ii).name);
            tmp = strsplit(name, '_');
            parsed_block(ii) = str2double(tmp{end});
        end
        [~,idx] = nanmin(abs(parsed_block - options.block)); %#ok<NANMIN> 
        fname = fullfile(F(idx).folder, F(idx).name);
    else
        fname = fullfile(F(1).folder, F(1).name);
    end
else
    fname = fullfile(F.folder, F.name);
end
impedance = getfield(load(fname, 'impedance'),'impedance');

end