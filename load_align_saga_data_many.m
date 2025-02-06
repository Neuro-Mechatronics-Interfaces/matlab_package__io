function [data, sync, ch_name] = load_align_saga_data_many(poly5_files, options)
%LOAD_ALIGN_SAGA_DATA_MANY Loads and aligns data from multiple SAGA devices, typically for the same session.
%
% This function processes data from multiple Poly5 files representing recordings from different
% SAGA devices. It handles file loading, synchronization, optional filtering, and alignment of data
% across sessions or devices. The function aims to concatenate these multi-device recordings along
% specified dimensions and apply various preprocessing steps based on provided options.
%
% Syntax:
%   [data, sync, ch_name] = io.load_align_saga_data_many(poly5_files, 'Name', value, ...)
%
% Inputs:
%   poly5_files - A string array with the full file paths for each Poly5 file. The dimensions of the
%                 array determine the organization of the files, where N rows indicate the number of
%                 files per session and M columns represent the number of sessions or concatenation
%                 groups.
%
% Options:
%       'ApplyCAR' - Logical indicating whether to apply Common Average Referencing.
%       'ApplyFilter' - Logical indicating whether to apply high-pass filtering.
%       'HighpassFilterCutoff' - High-pass filter cutoff frequency.
%       'ApplyGridInterpolation' - Logical indicating whether to interpolate data on a grid.
%       'ApplySpatialLaplacian' - Logical indicating whether to apply spatial Laplacian filtering.
%       'ApplyRMSCutoff' - Logical indicating whether to apply RMS cutoff thresholding.
%       'RMSCutoff' - Two-element vector specifying the lower and upper RMS thresholds.
%       'ZeroMissing' - Logical indicating whether to zero out missing data points.
%       'InitialPulseOffset' - Integer specifying initial pulse offset in samples.
%       'SampleRate' - Desired sample rate; must be one of the specified options.
%       'TriggerChannelIndicator' - Name indicator for the trigger channel.
%       'TriggerBitMask' - Bitmask to apply to trigger channel data for pulse detection.
%       'IsTextile64' - Logical indicating if data arrangement follows a 64-electrode textile configuration.
%       'TextileTo8x8GridMapping' - Mapping of electrodes from a textile configuration to a standard 8x8 grid.
%       'TabletFile' - Optional path to a tablet data file for synchronization.
%       'InputRoot' - Root directory for input files if not included in poly5_files paths.
%       'ManualSyncIndex' - Optional manual synchronization indices.
%
% Outputs:
%   data - Struct containing:
%       samples - Concatenated and possibly filtered sample data.
%       channels - Information about data channels.
%       sample_rate - Sample rate used across all files.
%       tablet - If available, tablet interaction data synchronized with neural recordings.
%
%   sync - Cell array of synchronization data structures, each containing 'rising' and 'falling'
%          fields with relative sample instants for synchronization pulses.
%
%   ch_name - Cell array of channel names.
%
% Examples:
%   files = ["path/to/session1/poly5file1.poly5", "path/to/session1/poly5file2.poly5"];
%   [data, sync, ch_name] = io.load_align_saga_data_many(files, ...
%       'ApplyFilter', true, 'HighpassFilterCutoff', 100, 'SampleRate', 4000);
%
% See also: Contents, poly5.read


arguments
    poly5_files (:,:) string
    options.ApplyCAR (1,1) logical = true;
    options.ApplyFilter (1,1) logical = true;
    options.ApplyGridInterpolation (1,1) logical = true;
    options.ApplySpatialFilter (1,1) logical = false;
    options.ApplyRMSCutoff (1,1) logical = false;
    options.Debug (1,1) logical = false;
    options.ExcludedPulseIndices (1,:) {mustBeInteger,mustBePositive} = [];
    options.HighpassFilterCutoff (1,1) double = 100;
    options.RMSCutoff (1,2) double = [1, 100];
    options.ZeroMissing (1,1) logical = false;
    options.InitialPulseOffset (1,1) {mustBeInteger} = 0; % Samples prior to first rising pulse, to include.
    options.InvertLogic logical = [];
    options.SampleRate (1,1) double {mustBeMember(options.SampleRate, [2000, 4000])} = 4000;
    options.SpatialFilterMode {mustBeMember(options.SpatialFilterMode, {'SD Columns', 'SD Rows', 'Laplacian'})} = 'SD Rows';
    options.TriggerChannelIndicator {mustBeTextScalar} = 'TRIG';
    options.TriggerBitMask = [];
    options.IsTextile64 (:,1) logical = true;
    options.SwappedTextileCables (1,:) logical = false;
    options.TextileTo8x8GridMapping (:,64) {mustBeInteger, mustBeInRange(options.TextileTo8x8GridMapping,1,64)} = [];
    options.TabletFile {mustBeTextScalar} = "SUBJ_YYYY_MM_DD_TABLET_BLOCK.bin";
    options.InputRoot = "";
    options.UseFirstSampleIfNoSyncPulse (1,1) logical = false;
    options.ManualSyncIndex = [];
end
data = struct('samples',[],'channels',[],'sample_rate',options.SampleRate);
n = size(poly5_files,1);
m = size(poly5_files,2);
raw = cell(n,m);
for ik = 1:m
    for ii = 1:n % Loads all files
        raw{ii,ik} = TMSiSAGA.Poly5.read(fullfile(options.InputRoot,poly5_files(ii,ik)));
    end
end

[b_hpf,a_hpf] = butter(3,options.HighpassFilterCutoff/(options.SampleRate/2),'high');
% if isempty(options.ManualSyncIndex)
%     manualSync = [];
% elseif isscalar(options.ManualSyncIndex)
%     manualSync = ones(n,m).*options.ManualSyncIndex;
% else
%     manualSync = options.ManualSyncIndex;
% end
% iStart = nan(n,m);
% nTotal = nan(n,m);
sync = cell(n,m);
all_samples = cell(n,m);
ch_name = cell(n,1);
chMap = repmat(1:64,n,1);
if isscalar(options.SwappedTextileCables)
    swappedCables = repmat(options.SwappedTextileCables,1,n);
else
    swappedCables = options.SwappedTextileCables;
end
if isscalar(options.IsTextile64)
    isTextile64 = repmat(options.IsTextile64,n,1);
else
    isTextile64 = options.IsTextile64;
end
if isscalar(options.TriggerBitMask)
    trigBitMask = repmat(options.TriggerBitMask,n,1);
else
    trigBitMask = options.TriggerBitMask;
end

for ik = 1:n
    if isTextile64(ik)
        if isempty(options.TextileTo8x8GridMapping)
            chMap(ik,:) = io.textile_8x8_uni2grid_mapping(swappedCables(ii));
        else
            if size(options.TextileTo8x8GridMapping,1)==1 && (n > 1)
                chMap(ik,:) = options.TextileTo8x8GridMapping;
            else
                chMap(ik,:) = options.TextileTo8x8GridMapping(ik,:);
            end
        end
    end
end

n_samp = zeros(n,m);
iTrig = cell(n,1);
for ik = 1:m
    for ii = 1:n
        if iscell(raw{ii,ik}.channels)
            ch_tmp = vertcat(raw{ii,ik}.channels{:});
            ch_name{ii} = {ch_tmp.name};
        else
            ch_name{ii} = {raw{ii,ik}.channels.name};
        end
        iTrig{ii} = contains(ch_name{ii},options.TriggerChannelIndicator);
        iUni = (contains(ch_name{ii},'R') & contains(ch_name{ii},'C') & ~contains(ch_name{ii},'E')) | (contains(ch_name{ii},'UNI'));
        iBip = contains(ch_name{ii},'BIP');
        if raw{ii,ik}.sample_rate < options.SampleRate

            samples = resample(raw{ii,ik}.samples,2,1,Dimension=2);
            if nnz(iTrig{ii})>0
                samples(iTrig{ii},:) = repelem(raw{ii,ik}.samples(iTrig{ii},:),1,2);
            end
            n_samp(ii,ik) = size(samples,2);
        elseif raw{ii,ik}.sample_rate > options.SampleRate
            samples = resample(raw{ii,ik}.samples,1,2,Dimension=2);
            if nnz(iTrig{ii})>0
                samples(iTrig{ii},:) = raw{ii,ik}.samples(iTrig{ii},1:2:end);
            end
            n_samp(ii,ik) = size(samples,2);
        else
            samples = raw{ii,ik}.samples;
            n_samp(ii,ik) = raw{ii,ik}.num_samples;
        end


        if sum(iUni) < 64
            iInsert = find(iUni,1,'first');
            samples = [samples(1:(iInsert-1),:); zeros(64-sum(iUni),size(samples,2)); samples(iInsert:end,:)];
            nameInsert = cell(1,64-sum(iUni));
            for iName = 1:sum(64-sum(iUni))
                nameInsert{iName} = sprintf('UNI%02d',iName);
            end
            iFind = find(iUni);
            for iName = 1:numel(iFind)
                ch_name{ii}{iFind(iName)} = sprintf('UNI%02d',iName+64-sum(iUni));
            end
            ch_name{ii} = [ch_name{ii}(1:(iInsert-1)), nameInsert, ch_name{ii}(iInsert:end)];
            iUni = (contains(ch_name{ii},'R') & contains(ch_name{ii},'C') & ~contains(ch_name{ii},'E')) | (contains(ch_name{ii},'UNI'));
            iBip = contains(ch_name{ii},'BIP');
            iTrig{ii} = contains(ch_name{ii},options.TriggerChannelIndicator);
        end

        if options.ApplyFilter
            samples(iUni | iBip,:) = filtfilt(b_hpf,a_hpf,samples(iUni | iBip,:)')';
        end

        % Apply grid-specific sampling, if specified:
        iUniIndex = find(iUni);
        if options.IsTextile64
            iCheck = unique(chMap(ii,:));
            if numel(iCheck)~=64
                error("Must have exactly 64 unique elements in 8x8 Grid mapping, but only detected %d unique elements.", numel(iCheck));
            end
            iUniIndex = iUniIndex(chMap(ii,:));
        end
        uni = samples(iUniIndex,:);

        r = rms(uni,2);

        if options.ApplyRMSCutoff
            rms_bad = (r < options.RMSCutoff(1)) | (r >= options.RMSCutoff(2));
            uni(rms_bad,:) = missing;
            if options.ApplyGridInterpolation
                if options.IsTextile64
                    for iGrid = 1:2
                        tmp_index = (1:32) + (iGrid-1)*32;
                        tmp = reshape(uni(tmp_index,:),8,4,[]);
                        for ij = 1:size(tmp,3)
                            tmp(:,:,ij) = fillmissing2(tmp(:,:,ij),'linear');
                        end
                        uni(tmp_index,:) = reshape(tmp,32,[]);
                    end
                else
                    uni = reshape(uni,8,8,[]);
                    for ij = 1:size(uni,3)
                        uni(:,:,ij) = fillmissing2(uni(:,:,ij),'linear');
                    end
                    uni = reshape(uni,64,[]);
                end
            end
        else
            rms_bad = false(size(r));
        end
        if options.ApplySpatialFilter
            switch options.SpatialFilterMode
                case 'SD Columns'
                    if options.IsTextile64
                        for iGrid = 1:2
                            tmp_index = (1:32) + (iGrid-1)*32;
                            tmp_grid = gradient(reshape(uni(tmp_index,:),8,4,[]));
                            uni(tmp_index,:) = reshape(tmp_grid,32,[]);
                        end
                    else
                        uni = reshape(gradient(reshape(uni,8,8,[])),64,[]);
                    end
                case 'SD Rows'
                    if options.IsTextile64
                        for iGrid = 1:2
                            tmp_index = (1:32) + (iGrid-1)*32;
                            [~,tmp_grid] = gradient(reshape(uni(tmp_index,:),8,4,[]));
                            uni(tmp_index,:) = reshape(tmp_grid,32,[]);
                        end
                    else
                        [~,tmp_grid] = gradient(reshape(uni,8,8,[]));
                        uni = reshape(tmp_grid,64,[]);
                    end
                case 'Laplacian'
                    if options.IsTextile64
                        for iGrid = 1:2
                            tmp_index = (1:32) + (iGrid-1)*32;
                            tmp_grid = del2(reshape(uni(tmp_index,:),8,4,[]));
                            uni(tmp_index,:) = reshape(tmp_grid,32,[]);
                        end
                    else
                        uni = reshape(del2(reshape(uni,8,8,[])),64,[]);
                    end
            end
        elseif options.ApplyCAR
            if options.IsTextile64
                for iGrid = 1:2
                    tmp_index = (1:32) + (iGrid-1)*32;
                    tmp_mask = tmp_index(~rms_bad(tmp_index));
                    uni(tmp_mask,:) = uni(tmp_mask,:) - median(uni(tmp_mask,:),1);
                end
            else
                uni(~rms_bad,:) = uni(~rms_bad,:) - median(uni(~rms_bad,:),1);
            end
        end
        if options.ZeroMissing
            uni(any(ismissing(uni),2),:) = 0;
        end
        samples(iUni,:) = uni;

        % if isempty(manualSync)
        %     if sum(iTrig) == 0
        %         error("No channel name contains %s--were triggers saved?", options.TriggerChannelIndicator);
        %     end
        %     % trigdata = round(samples(iTrig,:)); % Have to round due to interpolation
        %     % samples(iTrig,:) = trigdata;
        %     trigdata = raw{ii,ik}.samples(iTrig,:);
        %     if isempty(options.TriggerBitMask)
        %         trigMax = max(trigdata);
        %         trigMin = min(trigdata);
        %         trigBitMask = trigMax - trigMin;
        %     else
        %         if isscalar(options.TriggerBitMask)
        %             trigBitMask = options.TriggerBitMask;
        %         else
        %             trigBitMask = options.TriggerBitMask(ii);
        %         end
        %     end
        %     if isempty(options.InvertLogic)
        %         trigmasked = bitand(trigdata,trigBitMask)==trigBitMask;
        %     else
        %         if isscalar(options.InvertLogic)
        %             if options.InvertLogic
        %                 trigmasked = bitand(trigdata,trigBitMask)~=trigBitMask;
        %             else
        %                 trigmasked = bitand(trigdata,trigBitMask)==trigBitMask;
        %             end
        %         else
        %             if options.InvertLogic(ii)
        %                 trigmasked = bitand(trigdata,trigBitMask)~=trigBitMask;
        %             else
        %                 trigmasked = bitand(trigdata,trigBitMask)==trigBitMask;
        %             end
        %         end
        %     end
        %     rising = find(trigmasked);
        %     if raw{ii,ik}.sample_rate > options.SampleRate
        %         rising = ceil(rising/2);
        %     elseif raw{ii,ik}.sample_rate < options.SampleRate
        %         rising = min(rising*2, size(samples,2));
        %     end
        %     if isempty(rising)
        %         error("io:load_align_saga_data_many:no_sync","No rising pulses detected (trigBitMask = %s)",dec2bin(trigBitMask));
        %     end
        %     if numel(rising) > 1
        %         rising = rising([rising(1)~=1, diff(rising) > 1]);
        %     end
        %     if isempty(rising)
        %         if options.UseFirstSampleIfNoSyncPulse
        %             rising = 1;
        %         else
        %             error("io:load_align_saga_data_many:no_sync","No rising pulses detected (trigBitMask = %s)",dec2bin(trigBitMask));
        %         end
        %     end
        %     falling = find(~trigmasked);
        %
        %     if raw{ii,ik}.sample_rate > options.SampleRate
        %         falling = ceil(falling/2);
        %     elseif raw{ii,ik}.sample_rate < options.SampleRate
        %         falling = min(falling*2, size(samples,2));
        %     end
        %     if isempty(falling)
        %         if options.UseFirstSampleIfNoSyncPulse
        %             falling = size(samples,2);
        %         else
        %             error("io:load_align_saga_data_many:no_sync","No rising pulses detected (trigBitMask = %s)",dec2bin(trigBitMask));
        %         end
        %     end
        %     if numel(falling) > 1
        %         falling = falling([falling(1)~=1, diff(falling) > 1]);
        %     end
        %     if ~isempty(falling)
        %         if (falling(1)) < rising(1)
        %             tmp = falling;
        %             falling = rising;
        %             rising = tmp;
        %         end
        %     end
        %     rising(options.ExcludedPulseIndices) = [];
        %     if ~isempty(falling)
        %         falling(options.ExcludedPulseIndices) = [];
        %     end
        %     iStart(ii,ik) = rising(1) - options.InitialPulseOffset;
        % else
        %     iStart(ii,ik) = manualSync(ii,ik);
        %     rising = iStart(ii,ik);
        %     falling = iStart(ii,ik)+1;
        % end
        % sync{ii,ik} = struct('rising',rising - iStart(ii,ik) + 1,'falling',falling - iStart(ii,ik) + 1);
        % if iStart(ii,ik) < 1
        %     error("InitialPulseOffset value may be too large, cannot start indexing from %d.", iStart(ii,ik));
        % end
        % nTotal(ii,ik) = n_samp - iStart(ii,ik) + 1;
        % all_samples{ii,ik} = samples(:,iStart(ii,ik):end);
        all_samples{ii,ik} = samples;
    end
    sync_target = bitand(all_samples{1,ik}(iTrig{1},:),trigBitMask(1))==0;

    for ii = 1:n
        [rho,lags] = xcorr(sync_target, bitand(all_samples{ii,ik}(iTrig{ii},:),trigBitMask(ii))==0);
        [~,imax] = max(rho);
        if lags(imax) < 0
            % all_samples{1,ik} = [zeros(size(all_samples{1,ik},1),-lags(imax)),all_samples{1,ik}];
            sync_target = bitand(all_samples{ii,ik}(iTrig{ii},:),trigBitMask(ii))==0;
            ii = 1; %#ok<FXSET,NASGU>
        else
            all_samples{ii,ik} = [zeros(size(all_samples{ii,ik},1),lags(imax)),all_samples{ii,ik}];
        end
    end
    for ii = 1:n
        n_samp(ii,ik) = size(all_samples{ii,ik},2);
    end
end

n_min = min(sum(n_samp,2),[],1);
for ik = 1:m
    cat_samples = [];
    for ii = 1:n
        if ik == 1
            data.channels = [data.channels; reshape(raw{ii,ik}.channels,[],1)];
        end
        cat_samples = [cat_samples; all_samples{ii,ik}(:,1:n_min(ik))]; %#ok<AGROW>
    end
    data.samples = [data.samples, cat_samples];
end
ch_name = horzcat(ch_name{:});
if strlength(options.InputRoot)>0
    [p,~,~] = fileparts(options.TabletFile);
    if strlength(p) < 1
        tablet_file = fullfile(options.InputRoot,options.TabletFile);
    else
        tablet_file = options.TabletFile;
    end
else
    tablet_file = options.TabletFile;
end
if exist(tablet_file,'file')~=0

    data.tablet = io.load_tablet_data(tablet_file);
    i_sync_device = find(contains(poly5_files,data.tablet.Properties.UserData.SyncDeviceTag),1,'first');
    if ~isempty(i_sync_device)
        i_counter = find(contains(ch_name,'COUNTER'),1,'first');
        if ~isempty(i_counter)
            Index = data.samples(i_counter,:)';
            X = interp1(data.tablet.Index,data.tablet.X,Index,'linear');
            Y = interp1(data.tablet.Index,data.tablet.Y,Index,'linear');
            Pressure = interp1(data.tablet.Index,data.tablet.Pressure,Index,'linear');
            X(ismissing(X)) = 0;
            Y(ismissing(Y)) = 0;
            Pressure(ismissing(Pressure)) = 0;
            u = data.tablet.Properties.UserData;
            data.tablet = table(Index, X, Y, Pressure);
            data.tablet.Properties.UserData = u;
        end
    end

else
    data.tablet = missing;
end
end