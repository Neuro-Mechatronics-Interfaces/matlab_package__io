function [logData, trialData] = readTaskServerLog(filename, options)
%READTASKSERVERLOG Reads generic binary reaction-task server log files, parsing the correct columns using header metadata.
%
% Syntax:
%   [logData, trialData] = io.readTaskServerLog(filename);
%
% Inputs:
%   filename - Path to the binary log file (e.g.,
%               'default_YYYY_MM_DD_log.reactions' or
%               'MCPXX_YYYY_MM_DD_K.survivor'). The file extension should
%               be tied to the task-type, but the actual handling is
%               dependent on the binary-encoded filetype indicated in the
%               header metadata so the extension is mostly for helping to
%               identify a file-to-task association.
%
% Outputs:
%   logData - A table containing parsed log data. Columns depend on the
%               type of binary file, and are parsed automatically using
%               data extracted from the header. See details below.
%             The header struct parsed from the header metadata is included
%             as logData.Properties.UserData.
%
%   trialData - A struct containing metadata from the file header. The
%               format depends on the value of
%               logData.Properties.UserData.FILETYPE:
%               * 'reactions' : Requires +enum package on current path. If
%                               present, this will use
%                               `io.convertReactionLogsToTrials` to produce
%                               trialData.
%               * 'survivor' : Not yet handled.
%
% Details:
%   ## `Survivor 2D` task log columns ##
%    * `Timestamp` (datetime): Timestamp for each sample, converted from a Float64 POSIX timestamp (UTC).
%    * `dx` (int8): Horizontal movement control, derived from "a/d" keyboard input.
%    * `dy` (int8): Vertical movement control, derived from "w/s" keyboard input.
%    * `Primary` (int8): State of the primary action button (e.g., spacebar), where 0 indicates not pressed and 1 indicates pressed ("ATTACK").
%    * `Secondary` (int8): State of the secondary action button (e.g., "f" key), where 0 indicates not pressed and 1 indicates pressed.
%    * `Score` (uint16): Current score of the player.
%    * `Health` (uint16): Current health of the player.
%    * `State` (uint16): Current state of the player (e.g., IDLE, MOVE, ATTACK).
%    * `Action` (uint16): Current action performed by the player.
%    * `NumEnemies` (uint16): Number of enemies currently present on the game canvas.
%    * `AttackRange` (int8): Range of the player’s attack, indicating how far attacks extend beyond the player’s hitbox.
%    * `AttackCooldown` (int8): Number of frames required between successive attacks.
%    * `Speed` (int8): Movement speed of the player, controlling how many pixels the player moves per frame.
%    * `Power` (int8): The player's power stat, determining the amount of damage dealt by their attacks.
%
%  ## `Basic Reactions` task log columns ##
%    * `Timestamp` (datetime): The timestamp from performance.now() (ms)
%    * `Frame` (uint32): The current frame index
%    * `AssertionState` (int8): The gamepad assertion state (0 or 1)
%    * `TaskState` (int8): The task state
%    * `AckState` (int8): The acknowledged task state (or vector of zeros
%                           if no socket connection); added in v4 Logs.
%
% See also: fopen, fread, fgetl, typecast, datetime

arguments
    filename
    options.AutoPlot (1,1) logical = false;
    options.DefaultHeader {mustBeTextScalar} = '{"LOG_VERSION":3,"HEADER_SIZE":0,"TASK":"Basic Reaction","SESSION":"default_2025_03_28_log","FILETYPE":"reactions","FRAMESIZE":14,"FIELDS":"Timestamp:Float64,AssertionState:Int8,TaskState:Int8,FrameIndex:Uint32"}';
    options.Verbose (1,1) logical = true;
end
defHeader = jsondecode(options.DefaultHeader);
% Open the file for reading in binary mode
fid = fopen(filename, 'rb');
if fid == -1
    error('Failed to open file: %s', filename);
end

% Read the header size
fseek(fid, 0, 'bof');
headerText = '';
while true
    line = fgetl(fid);
    if line==-1  % We reached the end of the file somehow
        headerEnd = ftell(fid);
        fclose(fid);
        break;
    end
    if ~ismember(line, '=')
        headerEnd = ftell(fid);
        fclose(fid);
        break;
    end
    headerText = strcat(headerText, line, '\n');
end

% Parse the header into a struct
headerLines = strsplit(string(headerText),"\\n");
header = struct();
dataStart = 1;
for i = 1:numel(headerLines)
    keyValue = split(headerLines{i}, '=');
    if length(keyValue) == 2
        dataStart = dataStart + 1;
        key = strtrim(upper(keyValue{1}));
        value = strtrim(keyValue{2});
        if options.Verbose
            fprintf(1,'[HEADER]\t"%s": %s\n',key,value);
        end
        if strcmpi(key(1),'™') % Then something bad happened and there's no header probably.
            header = defHeader;
            break;
        end
        if isnumeric(str2double(value)) && ~isnan(str2double(value))
            header.(key) = str2double(value);  % Convert numeric values
        else
            header.(key) = value;  % Keep strings as is
        end
        if strcmpi(key,'FIELDS')
            if isfield(header,'FILETYPE')
                if strcmpi(header.FILETYPE,'reactions')
                    break;
                end
            end
        end
    end
end
% Validate required header fields
requiredFields = {'LOG_VERSION', 'HEADER_SIZE', 'TASK', 'SESSION', 'FILETYPE', 'FRAMESIZE', 'FIELDS'};
for i = 1:length(requiredFields)
    if ~isfield(header, requiredFields{i})
        if strcmpi(requiredFields{i},'LOG_VERSION')
            if options.Verbose
                warning("Missing required header: LOG_VERSION. Using Default value of 0.");
            end
            header.LOG_VERSION = 0;
        elseif (strcmpi(requiredFields{i}, 'HEADER_SIZE')) && (header.LOG_VERSION==0)
            if options.Verbose
                warning("Missing required header: HEADER_SIZE, but LOG_VERSION==0; set HEADER_SIZE to 0 and proceeding.");
            end
            header.HEADER_SIZE = 0;
        elseif (strcmpi(requiredFields{i}, 'TASK')) && endsWith(filename,'reactions')
            [~,f,~] = fileparts(filename);
            header.TASK = "Basic Reaction";
            header.FILETYPE = "reactions";
            header.SESSION = f;
            header.FRAMESIZE = 14;
            header.FIELDS = "Timestamp:Float64,AssertionState:Int8,TaskState:Int8,FrameIndex:Uint32";
        else
            error('Missing required header field: %s', requiredFields{i});
        end
    end
end

% Parse the fields description
fields = split(header.FIELDS, ',');
fieldSizes = zeros(length(fields),1);
fieldNames = strings(length(fields),1);
fieldEncoding = zeros(length(fields),1);
fieldType = cell(length(fields),1);
offset = 0;
for i = 1:length(fields)
    [name, type] = strtok(fields{i}, ':');
    fieldNames(i) = strtrim(name);
    switch strtrim(type(2:end))
        case 'Float64'
            fieldSizes(i) = 8;
            fieldEncoding(i) = 1;
            fieldType{i} = 'double';
        case 'Int8'
            fieldSizes(i) = 1;
            fieldEncoding(i) = 1;
            fieldType{i} = 'int8';
        case 'Uint8'
            fieldSizes(i) = 1;
            fieldEncoding(i) = 1;
            fieldType{i} = 'uint8';
        case 'Uint32'
            fieldSizes(i) = 4;
            fieldEncoding(i) = -1;
            fieldType{i} = 'uint32';
        case 'Int32'
            fieldSizes(i) = 4;
            fieldEncoding(i) = -1;
            fieldType{i} = 'int32';
        case 'Int16'
            fieldSizes(i) = 2;
            fieldEncoding(i) = -1;
            fieldType{i} = 'int16';
        case 'Uint16'
            fieldSizes(i) = 2;
            fieldEncoding(i) = -1;
            fieldType{i} = 'uint16';
        otherwise
            error('Unsupported field type: %s', type);
    end
    offset = offset + fieldSizes(i);
end

% Ensure FRAMESIZE matches calculated field sizes
if offset ~= header.FRAMESIZE
    if header.LOG_VERSION == 3
        if options.Verbose
            warning('FRAMESIZE in header does not match calculated field sizes.');
        end
        offset = header.FRAMESIZE;
        fieldNames(4) = [];
        fieldSizes(4) = [];
        fieldEncoding(4) = [];
        fieldType(4) = [];
    else
        error('FRAMESIZE in header does not match calculated field sizes.');
    end
end

% Read the binary data
fid = fopen(filename, 'rb');
if header.LOG_VERSION==0
    fseek(fid, headerEnd, 'bof');
else
    fseek(fid, header.HEADER_SIZE, 'bof');
end
fileData = fread(fid, '*uint8');  % Read as unsigned 8-bit integers

% Ensure file size is a multiple of the entry size
if mod(numel(fileData), offset) ~= 0
    error('Corrupted file: File size is not a multiple of the entry size.');
end

% Calculate the number of entries
numEntries = numel(fileData) / header.FRAMESIZE;

% Preallocate arrays for efficiency
logDataStruct = struct();
for i = 1:length(fieldNames)
    logDataStruct.(fieldNames{i}) = zeros(numEntries, 1);
end

% Parse the binary data
if options.Verbose
    fprintf(1,'Parsing %s-type server binary log...000%%\n', header.FILETYPE);
end
for i = 1:numEntries
    offset = (i - 1) * header.FRAMESIZE;

    for j = 1:length(fieldNames)
        fieldSize = fieldSizes(j);
        if fieldEncoding(j) > 0
            byteOrder = 1:fieldSize;
        else
            byteOrder = fieldSize:-1:1;
        end
        dataBytes = fileData(offset + byteOrder);
        value = typecast(dataBytes, fieldType{j});
        logDataStruct.(fieldNames{j})(i) = value;
        offset = offset + fieldSize;
    end
    if options.Verbose
        fprintf(1,'\b\b\b\b\b%03d%%\n', round(100*i/numEntries));
    end
end

if isfield(logDataStruct,'Timestamp')
    logDataStruct.Timestamp = datetime(logDataStruct.Timestamp ./ 1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    logDataStruct.Timestamp.TimeZone = 'America/New_York';
    logDataStruct.Timestamp.Format = 'dd-MMM-uuuu HH:mm:ss.SSSSSS';
end

% Convert to MATLAB table
logData = struct2table(logDataStruct);
logData = table2timetable(logData);

switch header.FILETYPE
    case 'reactions'
        if ~isfield(header,'LOG_VERSION')
            header.LOG_VERSION = 0;
        end
        [trialData, logData] = parseReactionLogs(logData, header.LOG_VERSION);
        if isempty(trialData)
            if options.Verbose
                warning("No +enum package detected on current PATH. No trialized log data available.\n");
            end
        else
            if options.AutoPlot
                fig = figure('Color','w','Name','Auto-Plot of Reactions Trials', ...
                    'WindowState','maximized');
                ax = axes(fig,'NextPlot','add','FontName','Tahoma');
                yyaxis(ax,'left');
                set(ax,'NextPlot','add','FontName','Tahoma',...
                    'ColorOrder', [0 0 0], ...
                    'YColor','k',...
                    'YTick',[4 5],...
                    'YTickLabel',["DE-ASSERTED", "ASSERTED"], ...
                    'YLim',[-3.5, 5.5]);
                plot(ax, logData.Timestamp, logData.AssertionState+4);
                yyaxis(ax,'right');
                set(ax,...
                    'NextPlot','add','FontName','Tahoma',...
                    'YColor',[0.65 0.65 0.65],...
                    'ColorOrder', [0.65 0.65 0.65], ...
                    'YTick',-3:4,...
                    'YTickLabel', strrep(string(enum.BasicReactionState(-3:4)),'_','\_'), ...
                    'YLim',[-3.5, 5.5]);
                plot(ax, logData.Timestamp, logData.TaskState);
                title(ax, header.TASK, strrep(header.SESSION,'_','\_'), ...
                    'FontName','Tahoma');
            end
        end
    case 'survivor'
        trialData = [];
        if options.Verbose
            fprintf(1,'No trialized-handling set up for survivor-type binary server logs (yet?)\n');
        end
    otherwise
        fprintf(1,'No additional processing considered for fileType: "%s"\n', header.FILETYPE);
end
logData.Properties.UserData = header;


fclose(fid);

    function [trialData, logData] = parseReactionLogs(logData, logVersion)
        %PARSEREACTIONLOGS Convert log timestamped events into trialized rows.
        %
        % Syntax:
        %   [trialData, logData] = parseReactionLogs(logData, logVersion);
        %
        % Description:
        %   This function processes a table of log data with timestamped events and converts it into a trial-based
        %   format. The output `trialData` contains key timing and outcome metrics for each trial, while the input
        %   `logData` is converted into a timetable with updated task state enumeration for easier processing.
        %
        % Inputs:
        %   logData - A table containing log data with the following expected columns:
        %             - `Timestamp`: Timestamps of each event (datetime).
        %             - `TaskState`: Task state at each timestamp (integer or categorical).
        %   logVersion - Version of the logs
        %
        % Outputs:
        %   trialData - A table containing trialized data with the following columns:
        %               - `trial_counter`  : Trial number.
        %               - `t_trial`        : Start time of each trial.
        %               - `t_ready`        : Time of the READY state onset.
        %               - `t_pre`          : Time of the pre-assertion state onset.
        %               - `t_assert_hat`   : Predicted assertion cue time.
        %               - `t_assert`       : Actual assertion reaction time.
        %               - `t_deassert_hat` : Predicted deassertion cue time.
        %               - `t_deassert`     : Actual deassertion reaction time.
        %               - `t_total`        : End time of each trial.
        %               - `tau_hold`       : Duration of the assertion hold phase (seconds).
        %               - `tau_hold_hat`   : Predicted hold duration (seconds).
        %               - `tau_assert`     : Time from cue to assertion reaction (seconds).
        %               - `tau_deassert`   : Time from cue to deassertion reaction (seconds).
        %               - `trial_outcome`  : Logical indicating trial success (true if completed, false otherwise).
        %   logData   - The input log data converted to a timetable and with task states enumerated.
        %
        % Notes:
        %   - The function uses the `findNextStateOnset` subfunction to locate the next occurrence of a specific task
        %     state within the log data.
        %   - Task states are enumerated using the `enum.BasicReactionState` enumeration for improved readability.
        %   - Trials are segmented between `IDLE` states, with key state transitions used to calculate timing metrics.
        %   - The function assumes the input log data is sorted by timestamp.
        %
        % Example:
        %   % Load log data and convert to trials
        %   logData = readtable('reaction_logs.csv');
        %   [trialData, logData] = convertReactionLogsToTrials(logData);
        %
        %   % Display trialized data
        %   disp(trialData);
        %
        % See also: table2timetable, enum.BasicReactionState
        
        trialData = [];
        testEnum = what('enum');
        if isempty(testEnum)
            logData = [];
            return;
        end
        logData.TaskState = enum.BasicReactionState(logData.TaskState);
        if logVersion > 4
            logData.AckState = enum.BasicReactionState(logData.AckState);
        elseif logVersion > 3
            logData.AckState = enum.BasicReactionState(logData.AckState-2); % oops
        end

        iTrial = [];
        iReady = [];

        nextTrial = findNextStateOnset(1,logData.TaskState,enum.BasicReactionState.IDLE);
        while ~isempty(nextTrial)
            iTrial = [iTrial; nextTrial]; %#ok<*AGROW>
            tmp = findNextStateOnset(nextTrial,logData.TaskState,enum.BasicReactionState.READY);
            if isempty(tmp)
                break;
            end
            iReady = [iReady; tmp];
            nextTrial = findNextStateOnset(tmp, logData.TaskState, enum.BasicReactionState.IDLE);
        end
        t_trial = logData.Timestamp(iTrial);
        t_ready = logData.Timestamp(iReady);
        t_assert_hat = NaT(size(t_trial),'TimeZone',logData.Timestamp.TimeZone,'Format', logData.Timestamp.Format);
        t_assert = NaT(size(t_trial),'TimeZone',logData.Timestamp.TimeZone,'Format', logData.Timestamp.Format);
        t_pre = NaT(size(t_trial),'TimeZone',logData.Timestamp.TimeZone,'Format', logData.Timestamp.Format);
        t_deassert_hat = NaT(size(t_trial),'TimeZone',logData.Timestamp.TimeZone,'Format', logData.Timestamp.Format);
        t_deassert = NaT(size(t_trial),'TimeZone',logData.Timestamp.TimeZone,'Format', logData.Timestamp.Format);
        t_total = NaT(size(t_trial),'TimeZone',logData.Timestamp.TimeZone,'Format', logData.Timestamp.Format);
        tau_hold = nan(size(t_trial));
        tau_hold_hat = nan(size(t_trial));
        tau_assert = nan(size(t_trial));
        tau_deassert = nan(size(t_trial));
        trial_outcome = false(size(t_trial));
        trial_counter = (1:numel(trial_outcome))';
        for ii = 1:numel(t_trial)
            if ii == numel(t_trial)
                t_total(ii) = logData.Timestamp(end);
            else
                t_total(ii) = logData.Timestamp(iTrial(ii+1)-1);
            end
            iNext = findNextStateOnset(iTrial(ii),logData.TaskState,enum.BasicReactionState.WAIT_ASSERTION_CUE);
            if ~isempty(iNext)
                if logData.Timestamp(iNext) < t_total(ii)
                    t_pre(ii) = logData.Timestamp(iNext);
                else
                    continue;
                end
            end
            iNext = findNextStateOnset(iTrial(ii),logData.TaskState,enum.BasicReactionState.WAIT_ASSERTION_REACTION);
            if ~isempty(iNext)
                if logData.Timestamp(iNext) < t_total(ii)
                    t_assert_hat(ii) = logData.Timestamp(iNext);
                else
                    continue;
                end
            end
            iNext = findNextStateOnset(iTrial(ii),logData.TaskState,enum.BasicReactionState.HOLD_ASSERTION);
            if ~isempty(iNext)
                if logData.Timestamp(iNext) < t_total(ii)
                    t_assert(ii) = logData.Timestamp(iNext);
                    tau_assert(ii) = seconds(t_assert(ii) - t_assert_hat(ii));
                else
                    continue;
                end
            end

            iNext = findNextStateOnset(iTrial(ii),logData.TaskState,enum.BasicReactionState.WAIT_DEASSERTION_REACTION);
            if ~isempty(iNext)
                if logData.Timestamp(iNext) < t_total(ii)
                    t_deassert_hat(ii) = logData.Timestamp(iNext);
                    tau_hold_hat(ii) = seconds(t_deassert_hat(ii) - t_assert_hat(ii));
                else
                    continue;
                end
            else
                break;
            end

            iNext = findNextStateOnset(iNext,logData.TaskState,enum.BasicReactionState.TIMEOUT);
            if ~isempty(iNext)
                if logData.Timestamp(iNext) <= t_total(ii)
                    t_deassert(ii) = logData.Timestamp(iNext);
                    tau_deassert(ii) = seconds(t_deassert(ii) - t_deassert_hat(ii));
                    tau_hold(ii) = seconds(t_deassert(ii) - t_assert(ii));
                    trial_outcome(ii) = true;
                else
                    continue;
                end
            end
        end
        n = min([numel(trial_counter), numel(t_trial), numel(t_ready), numel(t_pre), numel(t_assert_hat), numel(t_assert), numel(t_deassert_hat), numel(t_deassert), numel(t_total), numel(tau_hold), numel(tau_hold_hat), numel(tau_assert), numel(tau_deassert), numel(trial_outcome)]);
        if n == 0
            trialData = [];
            return;
        end
        trialData = table(trial_counter(1:n), t_trial(1:n), t_ready(1:n), t_pre(1:n), t_assert_hat(1:n), t_assert(1:n), t_deassert_hat(1:n), t_deassert(1:n), t_total(1:n), tau_hold(1:n), tau_hold_hat(1:n), tau_assert(1:n), tau_deassert(1:n), trial_outcome(1:n), ...
            'VariableNames', {'trial_counter', 't_trial', 't_ready', 't_pre', 't_assert_hat', 't_assert', 't_deassert_hat', 't_deassert', 't_total', 'tau_hold', 'tau_hold_hat', 'tau_assert', 'tau_deassert', 'trial_outcome'});

        function iStart = findNextStateOnset(iBeginSearch,taskState,targetState)
            iSearch = iBeginSearch;
            if isempty(iSearch) || isempty(taskState)
                iStart = [];
                return;
            end
            while ((taskState(iSearch)~=targetState) && (iSearch < numel(taskState)))
                iSearch = iSearch + 1;
            end
            if iSearch == numel(taskState)
                iStart = [];
            else
                iStart = iSearch;
            end
        end

    end

end


