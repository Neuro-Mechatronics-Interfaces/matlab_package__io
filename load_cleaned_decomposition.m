function [data, metadata, n] = load_cleaned_decomposition(k,options)
%LOAD_CLEANED_DECOMPOSITION Loads the cleaned decomposition results from DEMUSE tool.
%
% Syntax:
%   [data, metadata, n] = io.load_cleaned_decomposition(k,'Name',value,...);
%
% Inputs:
%   k - Trial index

arguments
    k (1,1) {mustBeInteger}
    options.FileNameMatchExpression = 'Trl%d*.mat';
    options.InputFolder = 'C:/Data/Shared/MCP01_2024_02_20/MotorUnits Decomposition/Decomposition Output Cleaned';
    options.Pattern = 'Trl(\d+)_([A-Za-z]{3})([A-Za-z]+)_offset([\d.]+)_length([\d.]+)_runs(\d+)'; % Regular expression pattern for parsing
    options.Tokens = {'Trial','Group','Location','Offset','Length','NumRuns'};
end


expr = sprintf(options.FileNameMatchExpression,k);
F = dir(fullfile(options.InputFolder, expr));

filenames = {F.name};

% Initialize tokens cell array
metadata = cell(length(filenames),1);
data = cell(length(filenames),1);
n = struct('Pulses',[],'Total',0);
n.Pulses = cell(numel(F),1);
for iF = 1:numel(F)
    metadata{iF} = struct;
    matches = regexp(filenames{iF}, options.Pattern, 'tokens');
    for iT = 1:numel(options.Tokens)
        metadata{iF}.(options.Tokens{iT}) = matches{1}{iT};
    end
    data{iF} = load(fullfile(F(iF).folder, F(iF).name));
    n.Total = n.Total + numel(data{iF}.MUPulses); %
    for ii = 1:numel(data{iF}.MUPulses)
        n.Pulses{iF} = [n.Pulses{iF}; ii, numel(data{iF}.MUPulses{ii})];
    end
end
if isempty(metadata)
    data = [];
    metadata = [];
    n = [];
    return;
end
metadata = vertcat(metadata{:});
groupMeta = {metadata.Group};
locMeta = {metadata.Location};
iOrder = [find(contains(lower(groupMeta),'ext') & contains(lower(locMeta),'prox'),1,'first'); ...
          find(contains(lower(groupMeta),'ext') & contains(lower(locMeta),'dist'),1,'first'); ...
          find(contains(lower(groupMeta),'flx') & contains(lower(locMeta),'prox'),1,'first'); ...
          find(contains(lower(groupMeta),'flx') & contains(lower(locMeta),'dist'),1,'first')];
data = data(iOrder); 
data = vertcat(data{:});
n.Pulses = n.Pulses(iOrder);
for iF = 1:numel(n.Pulses)
    n.Pulses{iF} = [ones(size(n.Pulses{iF},1),1).*iF, n.Pulses{iF}];
end
n.Pulses = vertcat(n.Pulses{:});

end