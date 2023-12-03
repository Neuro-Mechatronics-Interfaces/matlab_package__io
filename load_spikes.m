function [spk, clus] = load_spikes(SUBJ, YYYY, MM, DD, options)
%LOAD_SPIKES Load spikes that have been exported via batch pipeline.
%
% Syntax:
%   [spk, clus] = io.load_spikes(SUBJ, YYYY, MM, DD, 'Name', value,...);
%
% Example 1:
%   [spk,clus] = io.load_spikes('Spencer', 2023, 12, 1, 'Block', 2:5);
%   -> Return 1x4 cell arrays and each element contains 1x56 cell arrays
%   for the 56 channels from recording with spikes (since no 'Channel' option was
%   specified.) 
%
% Example 2:
%   [spk,clus] = io.load_spikes('Spencer', 2023, 12, 1, 'Block', 1:5);
%   -> Return 1x5 cell arrays and each element contains 1x56 cell arrays
%   for the 56 channels from recording with spikes since no 'Channel' option was
%   specified. Since block 1 is Excluded, the first cell element is just an
%   empty cell.
%
% Example 3: 
%   [spk,clus] = io.load_spikes('Spencer', 2023, 12, 1, 'Block', 2, 'Channel', [1, 33]);
%   -> Returns 1x2 cell, corresponding to spikes on
%       channels 1 and 33. 
%       Note 1: The "top-level" BLOCK cell array gets squeezed out since it
%       is a singleton cell, unless 'KeepSingleton' option flag is set to
%       true.
%       Note 2: These channels are after any
%       re-ordering of channel indices that would have occurred in the
%       initial export step. In general for TC data this means that 1:16
%       are the "Thal-L" column, 17:32 are "Thal-R" column, 33:48 are
%       "M1-L" column, and 49:64 are "M1-R" column.
%
% Example 4: 
%   [spk,clus] = io.load_spikes('Spencer', 2023, 12, 1, 'Block', 2, 'Channel', 1);
%   -> Returns scalar structs corresponding to Block-2, channel-1 spikes and clusters.
%       Note 1: The "top-level" BLOCK cell array gets squeezed out since it
%       is a singleton cell, unless 'KeepSingleton' option flag is set to
%       true.
%       Note 2: The "2nd-level" CHANNEL cell array gets squeezed out since it
%       is a singleton cell, unless 'KeepSingleton' option flag is set to
%       true.
%
% Example 5: 
%   [spk,clus] = io.load_spikes('Spencer', 2023, 12, 1, 'Block', 2:4, 'Channel', 1);
%   -> Returns 1x3 cell array containing scalar structs corresponding to 
%       channel-1 spikes and clusters.
%       Note 1: The "2nd-level" CHANNEL cell array gets squeezed out since it
%       is a singleton cell, unless 'KeepSingleton' option flag is set to
%       true.
%
% Example 6:
%   spk = io.load_spikes('Spencer', 2023, 12, 1);
%   -> Returns all detected spikes from all channels on every valid block
%   from the Spencer 2023-12-1 recordings. It will run slightly faster than
%   if called with [spk, clus] because the loop does not load from the
%   'Clus' file if no second argument is specified. 
%
% Inputs:
%     SUBJ {mustBeTextScalar}
%     YYYY (1,1) double
%     MM (1,1) double
%     DD (1,1) double
%
% Options:
%     'Block' {mustBeInteger} = [] - The block index or indices to load.
%     'Channel' {mustBePositive, mustBeInteger} = [] - Channel indices to load.
%     'Tag' {mustBeTextScalar} = 'AbsMed' - "Tag" identifier that for now just corresponds with detection method.
%     'GeneratedDataRoot' {mustBeTextScalar} = '' - Root folder in generated_data (on raptor or set for local machine).
%     'SpikesFileID' = 'Spikes' - Probably not changed--identifier for "Spikes" files.
%     'ClustersFileID' = 'Clus' - Probably not changed--identifier for "Clusters" files.
%     'FileExpression' = '%s_%d_Channel-%02d_%s.mat' - File expression for loading data files. Hard-coded to plug in 'TANK' then 'BLOCK' then 'CHANNEL' then either ClustersID or SpikesID.
%     'PipelineSubFolder' = 'processing' - Sub-folder within generated_data "tank" folder where pipeline exported .mat files live.
%     'SpikesSubFolder' = '.spikes' - Sub-sub-folder within the PipelineSubFolder where 'spikes' and 'clus' exports live.
%     'AllChannels' double {mustBePositive, mustBeInteger} = [] - All possible channels, for if 'Channel' option is not explicitly specified. 
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
%
% See also: Contents

arguments
    SUBJ {mustBeTextScalar}
    YYYY (1,1) double
    MM (1,1) double
    DD (1,1) double
    options.Block {mustBeInteger} = [];
    options.Channel {mustBePositive, mustBeInteger} = [];
    options.Tag {mustBeTextScalar} = 'AbsMed';
    options.GeneratedDataRoot {mustBeTextScalar} = ''
    options.SpikesFileID = 'Spikes';
    options.ClustersFileID = 'Clus';
    options.FileExpression = '%s_%d_Channel-%02d_%s.mat';
    options.PipelineSubFolder = 'processing';
    options.SpikesSubFolder = '.spikes';
    options.AllChannels double {mustBePositive, mustBeInteger} = [];
    options.KeepSingleton (1,1) logical = false;
    options.Verbose (1,1) logical = true;
end

if strlength(options.GeneratedDataRoot) == 0
    gendata_root = parameters('generated_data_folder');
else
    gendata_root = options.GeneratedDataRoot;
end
TANK = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
gendata_tank = fullfile(gendata_root, SUBJ, TANK, options.PipelineSubFolder);

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
    BLOCK = task_trials.Plexon_Block((~task_trials.Exclude) & task_trials.Exported);
    has_data = true(size(BLOCK));
else
    BLOCK = options.Block;
    if isempty(task_trials)
        has_data = true(size(BLOCK));
    else
        idx = ismember(task_trials.Plexon_Block, BLOCK);
        has_data = (~task_trials.Exclude(idx)) & task_trials.Exported(idx);
    end
end

spikes_folder_root = fullfile(gendata_tank, options.SpikesSubFolder, options.Tag);
if isempty(options.Channel)
    if isempty(options.AllChannels)
        spikes_folder = fullfile(spikes_folder_root, num2str(BLOCK(1)));
        F = dir(fullfile(spikes_folder, sprintf('*%s*.mat',options.SpikesFileID)));
        channels = nan(1,numel(F));
        for iF = 1:numel(F)
            tmp = strsplit(F(iF).name,'_');
            tmp = strsplit(tmp{6},'-');
            channels(iF) = str2double(tmp{2});
        end
    else
        channels = options.AllChannels;
    end
else
    channels = options.Channel;
end


spk = cell(size(BLOCK));
expr = options.FileExpression;
id_s = options.SpikesFileID;
id_c = options.ClustersFileID;

nB = numel(BLOCK);
singleton_block = (nB == 1) && (~options.KeepSingleton);
nCh = numel(channels);
singleton_channel = (nCh == 1) && (~options.KeepSingleton);

if options.Verbose
    NTOT = nB * nCh;
    i_cur = 0;
    fprintf(1,'Please wait, loading %s data for %d channels from %d blocks...000%%\n', TANK, nCh, nB);
end
switch nargout
    case 1
        for ii = 1:numel(BLOCK)
            if has_data(ii)
                spikes_folder = fullfile(spikes_folder_root, num2str(BLOCK(ii)));
                if singleton_channel
                    spk{ii} = load(fullfile(spikes_folder, sprintf(expr,TANK,BLOCK(ii),channels,id_s)),'pks','snips');
                    if options.Verbose
                        i_cur = i_cur + 1;
                        fprintf(1,'\b\b\b\b\b%03d%%\n', round(100*i_cur/NTOT));
                    end
                else
                    spk{ii} = cell(size(channels));
                    for iCh = 1:numel(channels)
                        spk{ii}{iCh} = load(fullfile(spikes_folder, sprintf(expr,TANK,BLOCK(ii),channels(iCh),id_s)),'pks','snips');
                        if options.Verbose
                            i_cur = i_cur + 1;
                            fprintf(1,'\b\b\b\b\b%03d%%\n', round(100*i_cur/NTOT));
                        end
                    end
                end
            else
                if options.Verbose
                    i_cur = i_cur + nCh;
                    fprintf(1,'\b\b\b\b\b%03d%%\n', round(100*i_cur/NTOT));
                end
            end
        end
        if singleton_block
            spk = spk{1};
        end
    case 2
        clus = cell(size(BLOCK));
        for ii = 1:numel(BLOCK)
            if has_data(ii)
                spikes_folder = fullfile(spikes_folder_root, num2str(BLOCK(ii)));
                if singleton_channel
                    if options.Verbose
                        spk{ii} = load(fullfile(spikes_folder, sprintf(expr,TANK,BLOCK(ii),channels,id_s)),'pks','snips');
                        clus{ii} = load(fullfile(spikes_folder,  sprintf(expr,TANK,BLOCK(ii),channels,id_c)),'clus','s');
                        i_cur = i_cur + 1;
                        fprintf(1,'\b\b\b\b\b%03d%%\n', round(100*i_cur/NTOT));
                    end
                else
                    spk{ii} = cell(size(channels));
                    clus{ii} = cell(size(channels));
                    for iCh = 1:numel(channels)
                        spk{ii}{iCh} = load(fullfile(spikes_folder, sprintf(expr,TANK,BLOCK(ii),channels(iCh),id_s)),'pks','snips');
                        clus{ii}{iCh} = load(fullfile(spikes_folder,  sprintf(expr,TANK,BLOCK(ii),channels(iCh),id_c)),'clus','s');
                        if options.Verbose
                            i_cur = i_cur + 1;
                            fprintf(1,'\b\b\b\b\b%03d%%\n', round(100*i_cur/NTOT));
                        end
                    end
                end
            else
                if options.Verbose
                    i_cur = i_cur + nCh;
                    fprintf(1,'\b\b\b\b\b%03d%%\n', round(100*i_cur/NTOT));
                end
            end
        end
        if singleton_block
            spk = spk{1};
            clus = clus{1};
        end
end
end