function [data,metadata] = load_autocleaned_muaps(trialIndex, options)
%LOAD_AUTOCLEANED_MUAPS  Loads the auto-cleaned MUAPs and associated metadata
%
% Syntax:
%   [data,metadata] = io.load_autocleaned_muaps(trialIndex,'Name',value,...);
%
% Inputs:
%   trialIndex - Of file to load
%   
% Options:
%   'BaseColormap' (:,3) double : Default is jet(256)
%
% Output:
%   data - Data struct as seen by CKC reader basically.
%   metadata - Metadata associated to experiment, such as color for
%               individual MUAPs, labeling IDs, etc.
arguments
    trialIndex (1,1) {mustBeInteger}
    options.File {mustBeTextScalar} = "";
    options.InputRoot = "C:/Data/MetaWB";
    options.InputSubfolder = "MotorUnits Decomposition/Decomposition Output/Auto";
    options.Subject = "MCP04";
    options.Year = 2024;
    options.Month = 5;
    options.Day = 16;
    options.FileTag = "synchronized*mod";
    options.BaseColormap (:,3) double {mustBeInRange(options.BaseColormap,0,1)} = double([cm.umap([166 25 46]./255,32); ...
        cm.umap([51 63 72]./255,32); ...
        cm.umap([240 90 40]./255,32); ...
        cm.umap([164 97 164]./255,32);...
        cm.umap([255 184 28]./255,32); ...
        cm.umap([0 178 169]./255,32);...
        cm.umap([124 194 66]./255,32); ...
        cm.umap([108 172 228]./255,32)])./255.0;
end
if strlength(options.File) < 1
    TANK = sprintf('%s_%04d_%02d_%02d', options.Subject, options.Year, options.Month, options.Day);
    expr = sprintf('%s_%d_%s.mat', TANK, trialIndex, options.FileTag);
    f_expr = fullfile(options.InputRoot, TANK, options.InputSubfolder, expr);
    F = dir(f_expr);
    if ~isempty(F)
        if numel(F) > 1
            warning("Multiple matches for '%s'; using first file (%s).", expr, F(1).name);
        end
        fname = fullfile(F(1).folder,F(1).name);
    else
        data = [];
        metadata = [];
        return;
    end
else
    fname = options.File;
end
if exist(fname,'file')==0
    data = [];
    metadata = [];
    return;
end
data = load(fname);
metadata = struct;
metadata.label = strrep(data.description,": ","--");
metadata.Description = repmat(string(data.description), numel(data.MUPulses), 1);
metadata.ID_NonTracked = strings(numel(data.MUPulses),1);
tmp = strsplit(data.description, ':');
tmp = strsplit(tmp{1},'Trial-');
metadata.TrialID = ones(numel(data.MUPulses),1).*str2double(tmp{2});
for ik = 1:numel(data.MUPulses)
    metadata.ID_NonTracked(ik) = sprintf("MUAP-%02d-%02d",trialIndex,ik);
end

[metadata.PNR,metadata.MUID_Label] = ckc.batch_compute_PNR_and_Label(data);
metadata.Color=options.BaseColormap(end : -floor(size(options.BaseColormap,1)/max([length(data.MUPulses),1])) :1,:);

end