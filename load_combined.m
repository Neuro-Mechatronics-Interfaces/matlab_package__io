function [spk, BLOCK] = load_combined(SUBJ, YYYY, MM, DD, CHANNEL, options)
%LOAD_COMBINED Load spikes that have been clustered across all trials and combined with cluster index indicator, as exported via batch pipeline.
%
% Syntax:
%   [spk, BLOCK] = io.load_combined(SUBJ, YYYY, MM, DD, 'Name', value,...);
%
% Example 1:
%   [spk,BLOCK] = io.load_combined('Spencer', 2023, 12, 1, 53, 'Block', 2:5);
%   -> Return 1x4 cell arrays and each element contains 1x56 cell arrays
%   for the 56 channels from recording with spikes (since no 'Channel' option was
%   specified.) 
%
% Example 2:
%   [spk,BLOCK] = io.load_combined('Spencer', 2023, 12, 1, 53, 'Block', 1:5);
%   -> Return 1x5 cell arrays and each element contains 1x56 cell arrays
%   for the 56 channels from recording with spikes since no 'Channel' option was
%   specified. Since block 1 is Excluded, the first cell element is just an
%   empty cell.
%
% Inputs:
%     SUBJ {mustBeTextScalar}
%     YYYY (1,1) double
%     MM (1,1) double
%     DD (1,1) double
%     CHANNEL (1,1) double
%
% Options:
%     'Block' {mustBeInteger} = [] - The block index or indices to load.
%     'Tag' {mustBeTextScalar} = 'AbsMed' - "Tag" identifier that for now just corresponds with detection method.
%     'GeneratedDataRoot' {mustBeTextScalar} = '' - Root folder in generated_data (on raptor or set for local machine).
%     'CombinedFileID' = 'Combined' - Probably not changed--identifier for "Spikes" files.
%	  'GroupingID' = 'SoftTrode' - Probably not changed--identifier that used to be "Channel", but changed to accomodate multiple channel features used for single "trode" grouping (in post).
%     'FileExpression' = '%s_%d_%s-%02d_%s.mat' - File expression for loading data files. Hard-coded to plug in 'TANK' then 'BLOCK' then 'CHANNEL' then either ClustersID or SpikesID.
%     'PipelineSubfolder' = 'processing' - Sub-folder within generated_data "tank" folder where pipeline exported .mat files live.
%     'SortedSubfolder' = '.spikes' - Sub-sub-folder within the PipelineSubfolder where 'spikes' and 'clus' exports live.
%     'OnlyLoadSpikes' (1,1) logical = false - Set this true to force-load only spikes even if second output argument is requested (will return as an empty array []).
%     'KeepSingleton' (1,1) logical = false - Specify as true to keep cell arrays even for singleton dimensions.
%     'Verbose' (1,1) logical = true - Set to false to suppress Command Window progress statements.
%
% Output:
%   spk - Cell array (1/block) of cell arrays (1/channel). Each channel cell
%           contains a struct with fields 'pks' (the peak sample index for 
%           each spike), and 'snips' (the snippet of waveform used in
%           clustering step, sampled around each peak). 
%   clus - Cell array (1/block) of cell arrays (1/channel). Each channel
%           cell contains a struct with fields 'clus' (the cluster ID of 
%           matched element in `spk`) and 's' (the silhouette or cluster
%           quality metric for determining clusters initially). 
%   BLOCK - Array indicating which block the spikes/clusters belong to.
%
% Notes:
%   + This should only be used after running `task_trials_detect_spikes.m` followed by `merge_and_sort_units.m` 
%   + The directory where files are located is specified by a combination of 'GeneratedDataRoot'/'SUBJ'/'SUBJ_YYYY_MM_DD'/'PipelineSubfolder'/'SortedSubfolder' 
%   + The directory should contain files with the corresponding identifiers in the 'CombinedFileID' and 'GroupingID' options. 
%   + The file directory does not need to contain channels in sequential order (i.e. it is okay to be "missing" channels sequentially). 
%
% See also: Contents, task_trials_detect_spikes, merge_and_sort_units

arguments
    SUBJ {mustBeTextScalar}
    YYYY (1,1) double {mustBePositive, mustBeInteger}
    MM (1,1) double {mustBePositive, mustBeInteger}
    DD (1,1) double {mustBePositive, mustBeInteger}
    CHANNEL (1,1) double {mustBePositive, mustBeInteger}
    options.Block {mustBeInteger} = [];
    options.GeneratedDataRoot {mustBeTextScalar} = ''
    options.CombinedFileID {mustBeTextScalar} = 'Combined';
	options.GroupingID {mustBeTextScalar} = 'SoftTrode';
    options.FileExpression {mustBeTextScalar} = '%s_%d_%s-%02d_%s.mat';
    options.PipelineSubfolder {mustBeTextScalar} = 'processing';
    options.SortedSubfolder {mustBeTextScalar} = '.sorted';
    options.KeepSingleton (1,1) logical = false;
    options.Verbose (1,1) logical = true;
end

if strlength(options.GeneratedDataRoot) == 0
    gendata_root = parameters('generated_data_folder');
else
    gendata_root = options.GeneratedDataRoot;
end
TANK = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
gendata_tank = fullfile(gendata_root, SUBJ, TANK, options.PipelineSubfolder);

task_trials_file = fullfile(gendata_tank, sprintf('%s_trials.mat', TANK));
if exist(task_trials_file,'file')==0
    task_trials = [];
else
    task_trials = getfield(load(task_trials_file,'task_trials'),'task_trials');
    if ~task_trials.Properties.UserData.HasExportedSpikes
        error("No Exported Spikes detected based on task_trials timetable. If you are sure there are Spikes, you should modify the flag in UserData of task_trials (task_trials.Properties.UserData.HasExportedSpikes).");
    end
end

if isempty(options.Block)
    if isempty(task_trials)
        error("No task_trials file (%s) and no Block specified. If no task_trials were exported you at least need to specify the Block.", task_trials_file);
    end
    BLOCK = task_trials.Plexon_Block((~task_trials.Exclude) & task_trials.ExportedPlexon);
    has_data = true(size(BLOCK));
else
    BLOCK = options.Block;
    if isempty(task_trials)
        has_data = true(size(BLOCK));
    else
        idx = ismember(task_trials.Plexon_Block, BLOCK);
        has_data = (~task_trials.Exclude(idx)) & task_trials.ExportedPlexon(idx);
    end
end

sorted_folder = fullfile(gendata_tank, options.SortedSubfolder);


F = dir(fullfile(sorted_folder, sprintf('*%s*.mat',options.CombinedFileID)));
channel = nan(1,numel(F));
for iF = 1:numel(F)
	tmp = strsplit(F(iF).name,'_');
	tmp = strsplit(tmp{6},'-');
	channel(iF) = str2double(tmp{2});
end
i_missing = ~ismember(CHANNEL, channel);
if any(i_missing)
	ch_miss = CHANNEL(i_missing);
	error("%s-%02d was requested, but no file for this %s exists!", options.GroupingID, ch_miss(1), options.GroupingID);
end
channel = CHANNEL; % Manually assign the channels after checking that they do exist.


spk = cell(size(BLOCK));
expr = options.FileExpression;
id_c = options.CombinedFileID;
id_g = options.GroupingID;

nB = numel(BLOCK);
singleton_block = (nB == 1) && (~options.KeepSingleton);

if options.Verbose
    i_cur = 0;
	fprintf(1,'Please wait, loading %s (combined) data for 1 %s from %d blocks...000%%\n', TANK, id_g, nB);
end


for ii = 1:numel(BLOCK)
    if has_data(ii)
        in_file_combined = fullfile(sorted_folder, sprintf(expr,TANK,BLOCK(ii),id_g,channel,id_c));
        if exist(in_file_combined,'file')==0
            spk{ii} = struct('pks',[],'snips',[],'clus',[],'s',[]);
        else
            spk{ii} = load(in_file_combined,'pks','snips','clus','s');
        end
        if options.Verbose
            i_cur = i_cur + 1;
            fprintf(1,'\b\b\b\b\b%03d%%\n', round(100*i_cur/nB));
        end
    else
        if options.Verbose
            i_cur = i_cur + 1;
            fprintf(1,'\b\b\b\b\b%03d%%\n', round(100*i_cur/nB));
        end
    end
end
if singleton_block
    spk = spk{1};
end
end