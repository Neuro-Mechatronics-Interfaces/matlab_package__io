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
    options.EdgeDebounceSamples (1,1) double = 100;
    options.FileType {mustBeMember(options.FileType, [".mat", ".poly5", ".rhd", ".edf"])} = ".mat";
    options.Tag {mustBeTextScalar} = '';
    options.PulseSampleWidthTolerance (1,1) double = 10; % Tolerance considered acceptable for width of first sync pulse in each record.
    options.SagaID (1,:) string = ["A", "B"]; % Identifier for SAGA units
    options.SyncBit (1,1) double = 1;
    options.SyncPulseIndex (1,1) double = 1; % Can try changing this if the first sync pulse isn't in both records but multiple pulses exist in each record (i.e. so you can check later ones).
    options.TriggerChannel (1,1) string = "TRIGGER"; % identifies the trigger channel based on channel name
end



x = io.load_tmsi(SUBJ, YYYY, MM, DD, options.SagaID(1), ...
    BLOCK, ...
    options.FileType, ...
    'Tag', options.Tag);
i_sync_channel = parse_sync_channel(x.channels, options.TriggerChannel, options.SagaID(1));
bit_mask = 2^options.SyncBit;
[pw_fixed, rising_fixed] = get_sync_pulse_samples(x.samples(i_sync_channel,:), ...
    bit_mask, options.EdgeDebounceSamples, options.SyncPulseIndex);

saga = x;
saga.name = strrep(saga.name, sprintf('_%s_', options.SagaID(1)), '_*_');

for ii = 2:numel(options.SagaID)
    x = io.load_tmsi(SUBJ, YYYY, MM, DD, options.SagaID(ii), ...
        BLOCK, ...
        options.FileType, ...
        'Tag', options.Tag);
    i_sync_channel = parse_sync_channel(x.channels, options.TriggerChannel, options.SagaID(ii));
    [pw_shift, rising_shift] = get_sync_pulse_samples(x.samples(i_sync_channel,:), ...
        bit_mask, options.EdgeDebounceSamples, options.SyncPulseIndex);
    if abs(pw_fixed - pw_shift) > options.PulseSampleWidthTolerance
        error("Pulse width for SAGA-%s is different from SAGA-%s by > %d samples--is it encapsulated by both records?\n\t(You can try changing 'SyncPulseIndex' option if multiple sync pulses should exist in each SAGA record, which may fix this issue).", ...
            options.SagaID(ii), options.SagaID(1), options.PulseSampleWidthTolerance)
    end

    delta_rising = rising_shift - rising_fixed;
    if delta_rising > 0
        saga.samples = [nan(size(saga.samples,1), delta_rising), saga.samples];
        saga.time = x.time;
    elseif delta_rising < 0
        x.samples = [nan(size(x.samples,1), -delta_rising), x.samples];
    end

    delta_samples = size(x.samples,2) - size(saga.samples,2);
    if delta_samples > 0
        saga.samples = [saga.samples, nan(size(saga.samples,1), delta_samples)];
    elseif delta_samples < 0
        x.samples = [x.samples, nan(size(x.samples,1), -delta_samples)];
    end
    
    saga.samples = [saga.samples; x.samples];
    saga.channels = [saga.channels, x.channels];
end

saga.num_samples = size(saga.samples,2);
saga.t = 0:(1/saga.sample_rate):((saga.num_samples-1)/saga.sample_rate);
saga.uni = find(cellfun(@(C)contains(upper(C.name),'UNI'),saga.channels));
saga.bip = find(cellfun(@(C)contains(upper(C.name),'BIP'),saga.channels));
saga.aux = find(cellfun(@(C)contains(upper(C.name),'AUX'),saga.channels));
saga.triggers = find(cellfun(@(C)contains(upper(C.name), upper(options.TriggerChannel)),saga.channels));

    function [pw, rising] = get_sync_pulse_samples(trigger_data, bit_mask, debounce_samples, sync_pulse_index)
        %GET_SYNC_PULSE_SAMPLES Helper to get sync pulse width and rising edge index for the indexed synchronization pulse.
        sync = bitand(trigger_data, bit_mask)==0;
        all_high = find(sync > 0);
        if isempty(all_high)
            error("Could not find any sync pulse HIGH values--was sync pulse set and/or bit configuration and channel ID correct?");
        end
        all_low = setdiff(1:numel(sync), all_high);
        if isempty(all_high)
            error("Could not find any sync pulse LOW values--was sync pulse set and/or bit configuration and channel ID correct?");
        end
        rising = all_high([false, (diff(all_high) > debounce_samples)]);
        rising = rising(sync_pulse_index);
        falling = all_low([false, (diff(all_low) > debounce_samples)]);
        falling = falling(sync_pulse_index);
        pw = falling - rising;
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