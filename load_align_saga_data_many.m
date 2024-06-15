function [data,sync,ch_name] = load_align_saga_data_many(poly5_files, options)
%LOAD_ALIGN_SAGA_DATA_MANY Loads synchronized data from multiple SAGAs (for the same session). Since filenames are typically adhoc/differ by acquisition pipeline, supply poly5_files as an array of strings with the full filename in each element.
%
% Syntax:
%   [data,sync,ch_name] = io.load_align_saga_data_many(poly5_files,'Name',value,...);
%
% Inputs:
%   poly5_files - N x M array of strings which are the full file path for
%                   individual poly5 recordings to load. N indicates the
%                   number of Poly5 files used in each recording, while M
%                   indicates the number of recordings to "concatenate."
%                   The resultant `samples` field of `data` output will
%                   contain the individual file samples concatenated
%                   vertically (for N, along columns/time-samples) and 
%                   horizontally (for M, along rows/channels).
% 
% Options:
%   ApplyFilter (1,1) logical = true;
%   HighpassFilterCutoff (1,1) double = 100;
%   ApplyRMSCutoff (1,1) logical = false;
%   RMSCutoff (1,2) double = [1, 100];
%   ApplyGridInterpolation (1,1) logical = true;
%   ApplySpatialLaplacian (1,1) logical = true;
%   InitialPulseOffset (1,1) {mustBeInteger} = 0; % Samples prior to first rising pulse, to include.
%   SampleRate (1,1) double {mustBeMember(options.SampleRate, [2000, 4000])} = 4000;
%   TriggerChannelIndicator {mustBeTextScalar} = 'TRIG';
%   TriggerBitMask = [];
%   ExcludedPulseIndices (1,:) {mustBeInteger,mustBePositive} = [];
% 
% Output:
%   data - struct with fields: 
%               + `samples` (the [filtered] data array)
%               + `channels` (the channel information struct array)
%               + `sample_rate` (the shared sample rate from all files)
%   sync - N x M array of struct with fields `rising` and `falling` which
%           are the relative sample instants parsed from the TRIGGERS sync
%           bit of each recording/SAGA combination. 
%
% See also: Contents, io.load_align_saga_data, ckc.template__pre_process

arguments
    poly5_files (:,:) string
    options.ApplyFilter (1,1) logical = true;
    options.HighpassFilterCutoff (1,1) double = 100;
    options.ApplyRMSCutoff (1,1) logical = false;
    options.RMSCutoff (1,2) double = [1, 100];
    options.ApplyGridInterpolation (1,1) logical = true;
    options.ApplySpatialLaplacian (1,1) logical = true;
    options.ApplyCAR (1,1) logical = true;
    options.ZeroMissing (1,1) logical = false;
    options.InitialPulseOffset (1,1) {mustBeInteger} = 0; % Samples prior to first rising pulse, to include.
    options.InvertLogic logical = [];
    options.SampleRate (1,1) double {mustBeMember(options.SampleRate, [2000, 4000])} = 4000;
    options.TriggerChannelIndicator {mustBeTextScalar} = 'TRIG';
    options.TriggerBitMask = [];
    options.ExcludedPulseIndices (1,:) {mustBeInteger,mustBePositive} = [];
    options.IsTextile64 (1,1) logical = true;
    options.ManualSyncIndex = [];
end
data = struct('samples',[],'channels',[],'sample_rate',options.SampleRate);
n = size(poly5_files,1);
m = size(poly5_files,2);
raw = cell(n,m);
for ik = 1:m
    for ii = 1:n % Loads all files
        raw{ii,ik} = TMSiSAGA.Poly5.read(poly5_files(ii,ik));
    end
end

[b_hpf,a_hpf] = butter(3,options.HighpassFilterCutoff/(options.SampleRate/2),'high');

iStart = nan(n,m);
nTotal = nan(n,m);
sync = cell(n,m);
all_samples = cell(n,m);
ch_name = cell(n,1);
for ik = 1:m
    for ii = 1:n
        if raw{ii,ik}.sample_rate < options.SampleRate
            samples = resample(raw{ii,ik}.samples,2,1,Dimension=2);
            n_samp = size(samples,2);
        elseif raw{ii,ik}.sample_rate > options.SampleRate
            samples = resample(raw{ii,ik}.samples,1,2,Dimension=2);
            n_samp = size(samples,2);
        else
            samples = raw{ii,ik}.samples;
            n_samp = raw{ii,ik}.num_samples;
        end
        if iscell(raw{ii,ik}.channels)
            ch_tmp = vertcat(raw{ii,ik}.channels{:});
            ch_name{ii} = {ch_tmp.name};
        else
            ch_name{ii} = {raw{ii,ik}.channels.name};
        end
        iUni = (contains(ch_name{ii},'R') & contains(ch_name{ii},'C') & ~contains(ch_name{ii},'E')) | (contains(ch_name{ii},'UNI'));
        iBip = contains(ch_name{ii},'BIP');
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
        end

        if options.ApplyFilter
            samples(iUni | iBip,:) = filtfilt(b_hpf,a_hpf,samples(iUni | iBip,:)')';
        end
        
        % Apply grid-specific sampling, if specified:
        iUniIndex = find(iUni);
        if options.IsTextile64
            iUniIndex = iUniIndex([17	16	15	14	13	9	5	1	22	21	20	19	18	10	6	2	27	26	25	24	23	11	7	3	32	31	30	29	28	12	8	4	33	34	35	36	37	53	57	61	38	39	40	41	42	54	58	61	43	44	45	46	47	55	59	63	48	49	50	51	52	56	60	64]);
        end
        uni = samples(iUniIndex,:);
        
        r = rms(uni,2);
        rms_bad = (r < options.RMSCutoff(1)) | (r >= options.RMSCutoff(2));
        if options.ApplyRMSCutoff
            uni(rms_bad,:) = missing;
            if options.ApplyGridInterpolation
                uni = reshape(uni,8,8,[]);
                for ij = 1:size(uni,3)
                    uni(:,:,ij) = fillmissing2(uni(:,:,ij),'linear');
                end
                uni = reshape(uni,64,[]);
            end
        end
        if options.ApplySpatialLaplacian
            uni = reshape(del2(reshape(uni,8,8,[])),64,[]);
        elseif options.ApplyCAR
            uni(~rms_bad,:) = uni(~rms_bad,:) - median(uni(~rms_bad,:),1);
        end
        if options.ZeroMissing
            uni(any(ismissing(uni),2),:) = 0;
        end
        samples(iUni,:) = uni;
    
        if isempty(options.ManualSyncIndex)
            iTrig = contains(ch_name{ii},options.TriggerChannelIndicator);
            if sum(iTrig) == 0
                error("No channel name contains %s--were triggers saved?", options.TriggerChannelIndicator);
            end
            trigdata = round(samples(iTrig,:)); % Have to round due to interpolation
            samples(iTrig,:) = trigdata;
            if isempty(options.TriggerBitMask)
                trigMax = max(trigdata);
                trigMin = min(trigdata);
                trigBitMask = trigMax - trigMin;
            else
                if isscalar(options.TriggerBitMask)
                    trigBitMask = options.TriggerBitMask;
                else
                    trigBitMask = options.TriggerBitMask(ii);
                end
            end
            if isempty(options.InvertLogic)
                trigmasked = bitand(trigdata,trigBitMask)==trigBitMask;
            else
                if isscalar(options.InvertLogic)
                    if options.InvertLogic
                        trigmasked = bitand(trigdata,trigBitMask)~=trigBitMask;
                    else
                        trigmasked = bitand(trigdata,trigBitMask)==trigBitMask;
                    end
                else
                    if options.InvertLogic(ii)
                        trigmasked = bitand(trigdata,trigBitMask)~=trigBitMask;
                    else
                        trigmasked = bitand(trigdata,trigBitMask)==trigBitMask;
                    end
                end
            end
            rising = find(trigmasked);
            if isempty(rising)
                error("io:load_align_saga_data_many:no_sync","No rising pulses detected (trigBitMask = %s)",dec2bin(trigBitMask));
            end
            rising = rising([rising(1)~=1, diff(rising) > 1]);
            if isempty(rising)
                error("io:load_align_saga_data_many:no_sync","No rising pulses detected (trigBitMask = %s)",dec2bin(trigBitMask));
            end
            falling = find(~trigmasked);
            if isempty(falling)
                error("io:load_align_saga_data_many:no_sync","No rising pulses detected (trigBitMask = %s)",dec2bin(trigBitMask));
            end
            falling = falling([falling(1)~=1, diff(falling) > 1]);
            if ~isempty(falling)
                if (falling(1)) < rising(1)
                    tmp = falling;
                    falling = rising;
                    rising = tmp;
                end
            end
            rising(options.ExcludedPulseIndices) = [];
            if ~isempty(falling)
                falling(options.ExcludedPulseIndices) = [];
            end
            iStart(ii,ik) = rising(1) - options.InitialPulseOffset;
        else
            iStart(ii,ik) = options.ManualSyncIndex(ii,ik);
        end
        sync{ii,ik} = struct('rising',rising - iStart(ii,ik) + 1,'falling',falling - iStart(ii,ik) + 1);
        if iStart(ii,ik) < 1
            error("InitialPulseOffset value may be too large, cannot start indexing from %d.", iStart(ii,ik));
        end
        nTotal(ii,ik) = n_samp - iStart(ii,ik) + 1;
        all_samples{ii,ik} = samples(:,iStart(ii,ik):end);
    end
end
n_min = min(nTotal,[],1);
for ik = 1:m
    cat_samples = [];
    for ii = 1:n
        if ik == 1
            data.channels = [data.channels; raw{ii,ik}.channels];
        end
        cat_samples = [cat_samples; all_samples{ii,ik}(:,1:n_min(ik))]; %#ok<AGROW>
    end
    data.samples = [data.samples, cat_samples];
end
ch_name = horzcat(ch_name{:});
end