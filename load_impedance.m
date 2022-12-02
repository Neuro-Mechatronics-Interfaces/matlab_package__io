function impedance = load_impedance(SUBJ, YYYY, MM, DD, varargin)
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
%   varargin - (Optional) 'Name',value input argument pairs
%   -> 'generated_data_folder' : Location of generated_data

[pars.generated_data_folder] = ...
    parameters('generated_data_folder');
pars = utils.parse_parameters(pars, varargin{:});

tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);

fname = fullfile(pars.generated_data_folder, SUBJ, tank, sprintf("%s_impedances.mat", tank));
if exist(fname,'file')==0
    error("No such file: %s\n\t->\tHave you parsed raw impedances yet?", fname);
end
impedance = getfield(load(fname, 'impedance'),'impedance');

end