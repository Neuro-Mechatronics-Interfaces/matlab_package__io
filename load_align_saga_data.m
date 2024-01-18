function saga = load_align_saga_data(SUBJ, YYYY, MM, DD, BLOCK, options)
%LOAD_ALIGN_SAGA_DATA  Loads data from 2 TMSi-SAGA and aligns samples
%
% Syntax:
%   saga = io.load_align_saga_data(SUBJ, YYYY, MM, DD, BLOCK);
%   saga = io.load_align_saga_data(___, 'Name', value,...);
%
% Example:
%   saga = io.load_align_saga_data('Max', 2023, 11, 17, 6, 'Tag', 'Delta');
%
% Inputs:
%     SUBJ {mustBeTextScalar}
%     YYYY (1,1) double = year(today);
%     MM (1,1) double = month(today);
%     DD (1,1) double = day(today);
%     BLOCK (1,1) double = 0;
%
% Options:
%     'EdgeDebounceSamples' (1,1) double = 100; % Samples to debounce for sync
%     'FileType' {mustBeMember(options.FileType, [".mat", ".poly5", ".rhd", ".edf"])} = ".mat";
%     'Tag' {mustBeTextScalar} = '';
%     'PulseSampleWidthTolerance' (1,1) double = 10; % Tolerance considered acceptable for width of first sync pulse in each record.
%     'SagaID' (1,2) string = ["A", "B"]; % Identifier for SAGA units
%     'SyncBit' (1,1) double = 1; % 0-indexed bit used on TRIGGERS for sync pulses.
%     'SyncPulseIndex' (1,1) double = 1; % Can try changing this if the first sync pulse isn't in both records but multiple pulses exist in each record (i.e. so you can check later ones).
%     'TriggerChannel' (1,1) string = "TRIGGER"; % identifies the trigger channel based on channel name
%
% Output:
%   saga - Data structure as returned by `io.load_tmsi()` with 'ReturnAs'
%          options set to 'struct' (default setting). The primary
%          difference is that the `samples` and `channels` fields will be
%          extended to include any SAGA units from this recording. The
%          columns (sample instants) of the `samples` data (and associated
%          `t` timestamps) reflect shifted alignment based on shared data
%          on the channel containing the identifier in 'TriggerChannel' 
%          for each individual SAGA unit.
%
% See also: Contents, io.load_tmsi

arguments
    SUBJ {mustBeTextScalar}
    YYYY (1,1) double = year(today);
    MM (1,1) double = month(today);
    DD (1,1) double = day(today);
    BLOCK (1,1) double = 0;
    options.CounterChannelName {mustBeTextScalar} = 'COUNTER';
    options.EdgeDebounceSamples (1,1) double = 100;
    options.FileType {mustBeMember(options.FileType, [".mat", ".poly5", ".rhd", ".edf"])} = ".mat";
    options.InterpolateMissingSamples (1,1) logical = false;
    options.KeepCounterStartOffset (1,1) logical = false;
    options.KeepFirstPulse (1,1) logical = false; 
    options.Tag {mustBeTextScalar} = '';
    options.PulseSampleWidthTolerance (1,1) double = 0.001; % Tolerance considered acceptable for width of first sync pulse in each record.
    options.RawDataRoot {mustBeTextScalar} = "";
    options.SagaID (1,:) string = ["A", "B"]; % Identifier for SAGA units
    options.SyncBit (1,1) double = 0;
    options.SyncPulseIndex (1,1) double = 1; % Can try changing this if the first sync pulse isn't in both records but multiple pulses exist in each record (i.e. so you can check later ones).
    options.SyncPulseIndexOffsetAB (1,1) double = 0; % Can set different indices for pulse in A vs pulse in B (i.e. value of -1 results in 2 for B, 1 for A if SyncPulseIndex is 1).
    options.TriggerChannel (1,1) string = "TRIGGER"; % identifies the trigger channel based on channel name
    options.ThrowErrorOnFailedAlign (1,1) logical = true;
    options.Verbose (1,1) logical = true;
end

if strlength(options.RawDataRoot)==0
    raw_data_root = parameters('raw_data_folder');
else
    raw_data_root = options.RawDataRoot;
end

x = io.load_tmsi(SUBJ, YYYY, MM, DD, options.SagaID(1), ...
    BLOCK, ...
    options.FileType, ...
    raw_data_root, ...
    options.Verbose, ...
    'CounterChannelName', options.CounterChannelName,...
    'KeepCounterStartOffset', options.KeepCounterStartOffset, ...
    'InterpolateMissingSamples', options.InterpolateMissingSamples, ...
    'Tag', options.Tag);
i_sync_channel = parse_sync_channel(x.channels, options.TriggerChannel, options.SagaID(1));
bit_mask = 2^options.SyncBit;
[pw_fixed, rising_fixed] = get_sync_pulse_samples(x.samples(i_sync_channel,:), x.t, ...
    bit_mask, options.EdgeDebounceSamples, options.SyncPulseIndex, options.KeepFirstPulse, options.ThrowErrorOnFailedAlign);
if isempty(pw_fixed)
    saga = [];
    return;
end
saga = x;
saga.name = strrep(saga.name, sprintf('_%s_', options.SagaID(1)), '_*_');
saga.index = ones(numel(x.channels),1);

t = saga.t;
samples = saga.samples;

for ii = 2:numel(options.SagaID)
    x = io.load_tmsi(SUBJ, YYYY, MM, DD, options.SagaID(ii), ...
        BLOCK, ...
        options.FileType, ...
        raw_data_root, ...
        options.Verbose, ...
        'CounterChannelName', options.CounterChannelName, ...
        'KeepCounterStartOffset', options.KeepCounterStartOffset, ...
        'Tag', options.Tag);
    i_sync_channel = parse_sync_channel(x.channels, options.TriggerChannel, options.SagaID(ii));
    [pw_shift, rising_shift] = get_sync_pulse_samples(x.samples(i_sync_channel,:), x.t, ...
        bit_mask, options.EdgeDebounceSamples, options.SyncPulseIndex - options.SyncPulseIndexOffsetAB, options.KeepFirstPulse, options.ThrowErrorOnFailedAlign);
    if isempty(rising_shift)
        saga = [];
        return;
    end
    if abs(pw_fixed - pw_shift) > options.PulseSampleWidthTolerance
        if options.ThrowErrorOnFailedAlign
            error("Pulse width for SAGA-%s (%5.1fms) is different from SAGA-%s (%5.1fms) by > %4.1fms--is it encapsulated by both records?\n\t(You can try changing 'SyncPulseIndex' option if multiple sync pulses should exist in each SAGA record, which may fix this issue).", ...
                options.SagaID(ii), round(pw_shift*1e3,1), options.SagaID(1), round(pw_fixed*1e3,1), round(options.PulseSampleWidthTolerance*1e3,1))
        else
            saga = [];
            return;
        end
    end

    delta_rising = rising_shift - rising_fixed;
    if delta_rising > 0
        samples = [nan(size(samples,1), delta_rising), samples]; %#ok<*AGROW> 
        t = [nan(size(t,1), delta_rising), t];
        saga.time = x.time;
    elseif delta_rising < 0
        x.samples = [nan(size(x.samples,1), -delta_rising), x.samples];
        x.t = [nan(1, -delta_rising), x.t];
    end

    delta_samples = size(x.samples,2) - size(samples,2);
    if delta_samples > 0
        samples = [samples, nan(size(samples,1), delta_samples)];
        t = [t, nan(size(t,1), delta_samples)];
    elseif delta_samples < 0
        x.samples = [x.samples, nan(size(x.samples,1), -delta_samples)];
        x.t = [x.t, nan(1, -delta_samples)];
    end
    
    samples = [samples; x.samples];
    saga.channels = [saga.channels, x.channels];
    t = [t; x.t];
    saga.index = [saga.index; ones(numel(x.channels),1).*ii];
end

tq = 0:(1/saga.sample_rate):nanmax(t(:)); %#ok<NANMAX> 
needs_interpolation = false(size(t,1),1);
for ii = 1:size(t,1)
    needs_interpolation(ii) = any(~ismembertol(t(ii,:), tq));
end
if any(needs_interpolation)
    samplesq = zeros(size(samples,1),numel(tq));
    for ii = 1:size(samplesq,1)
        sample_mask = ~isnan(t(saga.index(ii),:));
        switch saga.channels{ii}.type
            case {1, 2, 3, 4} % 'UNI', 'BIP', or 'AUX' can be interpolated using spline or polynomial
                samplesq(ii,:) = interp1(t(saga.index(ii), sample_mask), samples(ii,sample_mask), tq, 'spline', 0);
            case {5, 6} % Digital logic channels (TRIGGERS, STATUS, COUNTER) should use 'nearest'
                samplesq(ii,:) = interp1(t(saga.index(ii), sample_mask), samples(ii,sample_mask), tq, 'nearest', 0);
        end
    end
    saga.samples = samplesq;
    saga.t = tq;
else
    tmp = cell(size(t,1),1);
    for ii = 1:size(t,1)
        tmp{ii} = samples(saga.index==ii,~isnan(t(saga.index(ii),:)));
    end
    saga.samples = vertcat(tmp{:});
    saga.t = 0:(1/saga.sample_rate):((size(saga.samples,2)-1)/saga.sample_rate);
end
saga.num_samples = size(saga.samples,2);
saga.uni = find(cellfun(@(C)contains(upper(C.name),'UNI'),saga.channels));
saga.bip = find(cellfun(@(C)contains(upper(C.name),'BIP'),saga.channels));
saga.aux = find(cellfun(@(C)contains(upper(C.name),'AUX'),saga.channels));
saga.triggers = find(cellfun(@(C)contains(upper(C.name), upper(options.TriggerChannel)),saga.channels));

    function [pw, rising] = get_sync_pulse_samples(trigger_data, t, bit_mask, debounce_samples, sync_pulse_index, keep_first_pulse,throw_error)
        %GET_SYNC_PULSE_SAMPLES Helper to get sync pulse width and rising edge index for the indexed synchronization pulse.
        sync = bitand(trigger_data, bit_mask)==0;
        all_high = find(sync > 0);
        if isempty(all_high)
            if throw_error
                error("Could not find any sync pulse HIGH values--was sync pulse set and/or bit configuration and channel ID correct?");
            else
                pw = 0;
                rising = [];
                return;
            end
        end
        all_low = setdiff(1:numel(sync), all_high);
        if isempty(all_low)
            if throw_error
                error("Could not find any sync pulse LOW values--was sync pulse set and/or bit configuration and channel ID correct?");
            else
                pw = 0;
                rising = [];
                return;
            end
        end
        rising = all_high([keep_first_pulse, (diff(all_high) > debounce_samples)]);
        rising = rising(sync_pulse_index);
        falling = all_low([keep_first_pulse, (diff(all_low) > debounce_samples)]);
        if (falling(sync_pulse_index) < rising) && any(falling > rising)
            falling = falling(find(falling > rising, 1, 'first'));
        else
            falling = falling(sync_pulse_index);
        end
        pw = t(falling) - t(rising);
    end

    function sync_idx = parse_sync_channel(channels, trigger_channel_id, saga_id)
        %PARSE_SYNC_CHANNEL Helper to get the row index for sync pulse parsing from samples array.
        sync_idx = find(cellfun(@(C)contains(upper(C.name), upper(trigger_channel_id)), channels), 1, 'first');
        if isempty(sync_idx)
            error("Could not find any sync channel (looked for names containing '%s') in SAGA-%s record. Did you sync using a different channel identifier (e.g. TRIGGERS, STATUS, etc.)?", ...
                trigger_channel_id, saga_id);
        end
    end

end