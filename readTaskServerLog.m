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
    if ~contains(line, '=')
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
disp(header);
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
addMeta = struct;
offset = 0;
for i = 1:length(fields)
    [name, type] = strtok(fields{i}, ':');
    curName = strtrim(name);
    switch strtrim(type(2:end))
        case 'Float64'
            fieldSizes(i) = 8;
            fieldEncoding(i) = 1;
            fieldType{i} = 'double';
            fieldNames(i) = curName;
        case 'Float32'
            fieldSizes(i) = 4;
            fieldEncoding(i) = 1;
            fieldType{i} = 'single';
            fieldNames(i) = curName;
        case 'Int8'
            fieldSizes(i) = 1;
            fieldEncoding(i) = 1;
            fieldType{i} = 'int8';
            fieldNames(i) = curName;
        case 'Uint8'
            fieldSizes(i) = 1;
            fieldEncoding(i) = 1;
            fieldType{i} = 'uint8';
            fieldNames(i) = curName;
        case 'Uint32'
            fieldSizes(i) = 4;
            fieldEncoding(i) = -1;
            fieldType{i} = 'uint32';
            fieldNames(i) = curName;
        case 'Int32'
            fieldSizes(i) = 4;
            fieldEncoding(i) = -1;
            fieldType{i} = 'int32';
            fieldNames(i) = curName;
        case 'Int16'
            fieldSizes(i) = 2;
            fieldEncoding(i) = -1;

            fieldType{i} = 'int16';
            fieldNames(i) = curName;
        case 'Uint16'
            fieldSizes(i) = 2;
            fieldEncoding(i) = -1;
            fieldType{i} = 'uint16';
            fieldNames(i) = curName;
        otherwise
            addMeta.(curName) = strtrim(type(2:end));
            % error('Unsupported field type: %s', type);
    end
    offset = offset + fieldSizes(i);
end
fmask = fieldSizes == 0;
fieldNames(fmask) = [];
fieldSizes(fmask) = [];
fieldEncoding(fmask) = [];
fieldType(fmask) = [];

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
logData.Properties.UserData = addMeta;

switch header.FILETYPE
    case 'reactions'
        if ~isfield(header,'LOG_VERSION')
            header.LOG_VERSION = 0;
        end

        [trialData, logData] = parseReactionLogsByTask(logData, header);
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
        logData.Properties.UserData = header;
    case 'survivor'
        trialData = [];
        if options.Verbose
            fprintf(1,'No trialized-handling set up for survivor-type binary server logs (yet?)\n');
        end
        logData.Properties.UserData = header;
    case 'typing'
        % ---------------------------------------------------
        % Typing task binary log — parsed frame-by-frame
        % No trialization yet; return per-keystroke records
        % ---------------------------------------------------
        if options.Verbose
            fprintf('[Typing] Parsed %d frames.\n', height(logData));
        end

        % WordChar fields
        wordCharMask = startsWith(fieldNames, "WordChar");

        if any(wordCharMask)
            wcNames = fieldNames(wordCharMask);
            nChars = numel(wcNames);
            nRows  = height(logData);

            % Extract matrix
            wordMatrix = zeros(nRows, nChars, 'uint8');
            for k = 1:nChars
                wordMatrix(:, k) = logData.(wcNames{k});
            end

            % Decode each row into a word
            wordCell = cell(nRows,1);

            for i = 1:nRows
                codes = wordMatrix(i,:);

                % Valid: 0–25 are letters; 26 is space; 255 means unused
                valid = codes ~= 255;

                codes = codes(valid);

                letters = repmat(' ', 1, numel(codes));  % allocate

                for j = 1:numel(codes)
                    c = codes(j);
                    if c <= 25
                        letters(j) = char(c + 65);   % 'A'..'Z'
                    elseif c == 26
                        letters(j) = ' ';            % space
                    else
                        letters(j) = '';             % unexpected
                    end
                end

                wordCell{i} = letters;
            end

            logData.Word = wordCell;
            logData(:,wcNames) = [];
        end


        % Add a "WordComplete" flag from IsWordEnd
        if isfield(logData, "IsWordEnd")
            logData.WordComplete = logical(logData.IsWordEnd);
        else
            logData.WordComplete = false(height(logData),1);
        end

        stimCodes = logData.Stimulus;
        respCodes = logData.Response;
        logData.Stimulus = char(stimCodes + 65);
        logData.Stimulus(stimCodes==26) = repmat(' ',nnz(stimCodes==26),1);
        logData.Response = char(respCodes + 65);
        logData.Response(respCodes==26) = repmat(' ',nnz(respCodes==26),1);

        % Version-specific cleanup
        logVersion = header.LOG_VERSION;

        if logVersion < 3
            % Remove all frame logs (RT == -1)
            logData.WordComplete = stimCodes==26;
            if any(strcmp("RTms", fieldNames))
                badRows = logData.RTms == -1;
                goodRows = find(~badRows);
                logData.Word(goodRows) = logData.Word(goodRows-1);
                logData(badRows, :) = [];
            end
        else
            logData.WordComplete = logData.IsWordEnd;
        end
        logData.IsWordEnd = [];

        % TrialData not implemented yet (you may add word-level trialization later)
        trialData = [];

        % Save header metadata
        logData.Properties.UserData = header;
        logData.Properties.UserData.TotalWords = nnz(logData.WordComplete);
        logData.Properties.UserData.WPM = logData.Properties.UserData.TotalWords / minutes(logData.Timestamp(end)-logData.Timestamp(1));
        if options.Verbose
            fprintf('[Typing] Added decoded word strings and WordComplete flags.\n');
        end

    case 'fitts'
        % ---------------------------------------------------
        % Fitts task binary log — frame-by-frame decoded with no
        % additional "trialization" (beyond DB summary tables)
        % ---------------------------------------------------
        if options.Verbose
            fprintf('[Fitts] Parsed %d frames (%.2f seconds).\n', ...
                height(logData), ...
                seconds(logData.Timestamp(end) - logData.Timestamp(1)));
        end

        % Add useful derived columns
        logData.dx = logData.CursorX - logData.TargetX;
        logData.dy = logData.CursorY - logData.TargetY;

        logData.r = sqrt(logData.dx.^2 + logData.dy.^2);

        logData.Properties.UserData = header;
        logData.TrialState = enum.FittsTaskState(logData.TrialState);
        logData.Properties.UserData = header;
        trialData = parseFittsLogToTrials(logData);
    otherwise
        logData.Properties.UserData = header;
        fprintf(1,'No additional processing considered for fileType: "%s"\n', header.FILETYPE);
end


fclose(fid);

    function [trialData, logData] = parseReactionLogsByTask(logData, header)

        task = string(header.TASK);
        switch task
            case "Even More Basic Reaction"
                [trialData, logData] = parseEvenMoreBasicReaction(logData, header.LOG_VERSION);
            case "Even More Basic Reaction 2Choice"
                [trialData, logData] = parseEvenMoreBasicReaction2Choice(logData, header.LOG_VERSION);
            case "Basic Reaction"
                [trialData, logData] = parseBasicReaction(logData, header.LOG_VERSION);
            case "Basic Reaction 2Choice"
                [trialData, logData] = parseBasicReaction2Choice(logData, header.LOG_VERSION);
            otherwise
                error("Unexpected value for header.TASK: %s", task);
        end
    end

    function [trialData, logData] = parseEvenMoreBasicReaction(logData, logVersion)

        testEnum = what('enum');
        if isempty(testEnum)
            trialData = [];
            return;
        end

        logData.TaskState = enum.EvenMoreBasicReactionState(logData.TaskState);

        if ismember("AckState", logData.Properties.VariableNames)
            logData.AckState = enum.EvenMoreBasicReactionState(logData.AckState);
        end

        % ---- Detect trials by READY onset ----
        isReady = logData.TaskState == enum.EvenMoreBasicReactionState.READY;
        iReady = find(diff([false; isReady]) == 1);

        nTrials = numel(iReady);
        if nTrials == 0
            trialData = [];
            return;
        end

        % Preallocate
        t_trial  = logData.Timestamp(iReady);
        t_cue    = NaT(nTrials,1,'TimeZone',logData.Timestamp.TimeZone);
        t_assert = NaT(nTrials,1,'TimeZone',logData.Timestamp.TimeZone);
        outcome  = false(nTrials,1);

        assertion_rising = strfind(logData.AssertionState',[0 1]) + 1;

        for ik = 1:nTrials
            idxStart = iReady(ik);
            if ik < nTrials
                idxEnd = iReady(ik+1)-1;
            else
                idxEnd = height(logData);
            end

            seg = logData(idxStart:idxEnd,:);

            % ---- Cue time ----
            idxCue = find(seg.TaskState == enum.EvenMoreBasicReactionState.CUE,1);
            if ~isempty(idxCue)
                t_cue(ik) = seg.Timestamp(idxCue);
            end

            % ---- Assertion ----
            idxAssert = assertion_rising(assertion_rising > idxStart & assertion_rising <= idxEnd);
            if ~isempty(idxAssert)
                t_assert(ik) = logData.Timestamp(idxAssert(1));
                outcome(ik) = true;
            end
        end

        tau_react = seconds(t_assert - t_cue);

        trialData = table( ...
            (1:nTrials)', ...
            t_trial, ...
            t_cue, ...
            t_assert, ...
            tau_react, ...
            outcome, ...
            'VariableNames', { ...
            'trial_counter', ...
            't_trial', ...
            't_cue', ...
            't_assert', ...
            'tau_reaction', ...
            'success' ...
            });
        % ---- Error classification ---------------------------------------------
        hasCue    = ~isnat(trialData.t_cue);
        hasAssert = ~isnat(trialData.t_assert);
        
        trialData.type_I_error  = hasAssert & ~hasCue;
        trialData.type_II_error = hasCue & ~hasAssert;
        
        % Optional: enforce mutual exclusivity
        trialData.type_I_error  = logical(trialData.type_I_error);
        trialData.type_II_error = logical(trialData.type_II_error);


    end

    function [trialData, logData] = parseEvenMoreBasicReaction2Choice(logData, logVersion)
    
        testEnum = what('enum');
        if isempty(testEnum)
            trialData = [];
            return;
        end
    
        % Enumerate task state
        logData.TaskState = enum.EvenMoreBasicReactionState(logData.TaskState);
    
        % AckState stores intended target (0 or 1)
        if ismember("AckState", logData.Properties.VariableNames)
            intendedTargetAll = logData.AckState;
        else
            error("AckState missing — required for 2Choice parsing.");
        end
    
        % ---- Detect trials by READY onset ------------------------------------
        isReady = logData.TaskState == enum.EvenMoreBasicReactionState.READY;
        iReady  = find(diff([false; isReady]) == 1);
    
        nTrials = numel(iReady);
        if nTrials == 0
            trialData = [];
            return;
        end
    
        % ---- Preallocate -----------------------------------------------------
        t_trial   = logData.Timestamp(iReady);
        t_cue     = NaT(nTrials,1,'TimeZone',logData.Timestamp.TimeZone);
        t_resp    = NaT(nTrials,1,'TimeZone',logData.Timestamp.TimeZone);
    
        selected_target = nan(nTrials,1);
        intended_target = nan(nTrials,1);
    
        success        = false(nTrials,1);
        wrong_choice   = false(nTrials,1);
    
        % AssertionState: 0 = none, 1 = left, 2 = right
        hasResponse = logData.AssertionState > 0;
    
        for k = 1:nTrials
    
            idxStart = iReady(k);
            if k < nTrials
                idxEnd = iReady(k+1)-1;
            else
                idxEnd = height(logData);
            end
    
            seg = logData(idxStart:idxEnd,:);
    
            % Intended target (constant per trial)
            intended_target(k) = seg.AckState(1);
    
            % ---- Cue time ----------------------------------------------------
            idxCue = find(seg.TaskState == enum.EvenMoreBasicReactionState.CUE, 1);
            if ~isempty(idxCue)
                t_cue(k) = seg.Timestamp(idxCue);
            end
    
            % ---- First response (anywhere in trial) --------------------------
            idxResp = find(hasResponse(idxStart:idxEnd), 1, 'first');
            if ~isempty(idxResp)
                t_resp(k) = seg.Timestamp(idxResp);
                selected_target(k) = seg.AssertionState(idxResp) - 1; % map {1,2}→{0,1}
            end
    
            % ---- Outcome classification -------------------------------------
            if ~isnat(t_cue(k)) && ~isnat(t_resp(k))
                % Response after cue
                if selected_target(k) == intended_target(k)
                    success(k) = true;
                else
                    wrong_choice(k) = true;
                end
            end
        end
    
        % ---- Timing ----------------------------------------------------------
        tau_reaction = seconds(t_resp - t_cue);
    
        % ---- Error types -----------------------------------------------------
        hasCue    = ~isnat(t_cue);
        hasResp   = ~isnat(t_resp);
    
        type_I_error  = hasResp & ~hasCue;    % early click
        type_II_error = hasCue  & ~hasResp;   % missed response
    
        % ---- Assemble table --------------------------------------------------
        trialData = table( ...
            (1:nTrials)', ...
            t_trial, ...
            t_cue, ...
            t_resp, ...
            tau_reaction, ...
            intended_target, ...
            selected_target, ...
            success, ...
            wrong_choice, ...
            type_I_error, ...
            type_II_error, ...
            'VariableNames', { ...
                'trial_counter', ...
                't_trial', ...
                't_cue', ...
                't_response', ...
                'tau_reaction', ...
                'intended_target', ...
                'selected_target', ...
                'success', ...
                'wrong_choice', ...
                'type_I_error', ...
                'type_II_error' ...
            });
    
    end

    function [trialData, logData] = parseBasicReaction2Choice(logData, ~)
    
        testEnum = what('enum');
        if isempty(testEnum)
            trialData = [];
            return;
        end
    
        % Enumerate task states
        logData.TaskState = enum.BasicReactionState(logData.TaskState);
    
        % AckState encodes intended target (0 or 1)
        if ismember("AckState", logData.Properties.VariableNames)
            intendedAll = logData.AckState;
        else
            error("AckState missing — required for BasicReaction2Choice parsing.");
        end
    
        % ---- Detect trials by READY onset -------------------------------------
        isReady = logData.TaskState == enum.BasicReactionState.READY;
        iReady  = find(diff([false; isReady]) == 1);
    
        nTrials = numel(iReady);
        if nTrials == 0
            trialData = [];
            return;
        end
    
        % ---- Preallocate ------------------------------------------------------
        t_trial  = logData.Timestamp(iReady);
        t_cue    = NaT(nTrials,1,'TimeZone',logData.Timestamp.TimeZone);
        t_resp   = NaT(nTrials,1,'TimeZone',logData.Timestamp.TimeZone);
    
        intended_target = nan(nTrials,1);
        selected_target = nan(nTrials,1);
    
        success        = false(nTrials,1);
        wrong_choice   = false(nTrials,1);
    
        % AssertionState: 0 = none, 1 = left, 2 = right
        hasResponse = logData.AssertionState > 0;
    
        % ---- Trial loop -------------------------------------------------------
        for k = 1:nTrials
    
            idxStart = iReady(k);
            if k < nTrials
                idxEnd = iReady(k+1) - 1;
            else
                idxEnd = height(logData);
            end
    
            seg = logData(idxStart:idxEnd,:);
    
            % Intended target is constant per trial
            intended_target(k) = seg.AckState(1);
    
            % ---- Cue time (ASSERT state onset) --------------------------------
            idxCue = find(seg.TaskState == enum.BasicReactionState.ASSERT, 1);
            if ~isempty(idxCue)
                t_cue(k) = seg.Timestamp(idxCue);
            end
    
            % ---- First response anywhere in trial -----------------------------
            idxResp = find(hasResponse(idxStart:idxEnd), 1, 'first');
            if ~isempty(idxResp)
                t_resp(k) = seg.Timestamp(idxResp);
                selected_target(k) = seg.AssertionState(idxResp) - 1; % {1,2}→{0,1}
            end
    
            % ---- Outcome classification --------------------------------------
            if ~isnat(t_cue(k)) && ~isnat(t_resp(k))
                % Response after cue
                if selected_target(k) == intended_target(k)
                    success(k) = true;
                else
                    wrong_choice(k) = true;
                end
            end
        end
    
        % ---- Timing -----------------------------------------------------------
        tau_reaction = seconds(t_resp - t_cue);
    
        % ---- Error types ------------------------------------------------------
        hasCue  = ~isnat(t_cue);
        hasResp = ~isnat(t_resp);
    
        type_I_error  = hasResp & ~hasCue;   % early click
        type_II_error = hasCue  & ~hasResp;  % missed response
    
        % ---- Assemble table ---------------------------------------------------
        trialData = table( ...
            (1:nTrials)', ...
            t_trial, ...
            t_cue, ...
            t_resp, ...
            tau_reaction, ...
            intended_target, ...
            selected_target, ...
            success, ...
            wrong_choice, ...
            type_I_error, ...
            type_II_error, ...
            'VariableNames', { ...
                'trial_counter', ...
                't_trial', ...
                't_cue', ...
                't_response', ...
                'tau_reaction', ...
                'intended_target', ...
                'selected_target', ...
                'success', ...
                'wrong_choice', ...
                'type_I_error', ...
                'type_II_error' ...
            });
    
    end


    function [trialData, logData] = parseBasicReaction(logData, logVersion)
        %PARSEBASICREACTION Convert log timestamped events into trialized rows.
        %
        % Syntax:
        %   [trialData, logData] = parseBasicReaction(logData, logVersion);
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
        assertion_rising = strfind(logData.AssertionState',[0 1])+1;
        assertion_falling = strfind(logData.AssertionState',[1 0])+1;
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
                    iAssert = find(logData.Timestamp(assertion_rising) > t_trial(ii),1,'first');
                    t_assert(ii) = logData.Timestamp(assertion_rising(iAssert));
                    iDeassert = find(logData.Timestamp(assertion_falling) > t_assert(ii), 1, 'first');
                    t_deassert(ii) = logData.Timestamp(assertion_falling(iDeassert));
                    tau_hold(ii) = seconds(t_deassert(ii) - t_assert(ii));
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
                    iDeassert = find(logData.Timestamp(assertion_falling) > t_assert(ii), 1, 'first');
                    t_deassert(ii) = logData.Timestamp(assertion_falling(iDeassert));
                    tau_hold(ii) = seconds(t_deassert(ii) - t_assert(ii));
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
        t_deassert(n) = t_total(n);
        tau_hold(n) = seconds(t_deassert(n) - t_assert(n));
        tau_deassert(n) = seconds(t_deassert(n) - t_deassert_hat(n));
        trial_outcome(n) = true;
        cur_hold = tau_hold_hat(end);
        for ii = n:-1:1
            if isnan(tau_hold_hat(ii))
                tau_hold_hat(ii) = cur_hold;
            else
                cur_hold = tau_hold_hat(ii);
            end
        end
        trialData = table(trial_counter(1:n), t_trial(1:n), t_ready(1:n), t_pre(1:n), t_assert_hat(1:n), t_assert(1:n), t_deassert_hat(1:n), t_deassert(1:n), t_total(1:n), tau_hold(1:n), tau_hold_hat(1:n), tau_assert(1:n), tau_deassert(1:n), trial_outcome(1:n), ...
            'VariableNames', {'trial_counter', 't_trial', 't_ready', 't_pre', 't_assert_hat', 't_assert', 't_deassert_hat', 't_deassert', 't_total', 'tau_hold', 'tau_hold_hat', 'tau_assert', 'tau_deassert', 'trial_outcome'});
        trialData = fix_final_success_trials(trialData);

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

        function E = fix_final_success_trials(E)

            mask = isnan(E.tau_deassert) & ~isnat(E.t_deassert_hat);
            E.t_deassert(mask) = E.t_total(mask);
            E.tau_deassert(mask) = seconds(E.t_deassert(mask) - E.t_deassert_hat(mask));
            E.tau_hold(mask) = seconds(E.t_deassert(mask) - E.t_assert(mask));
            E.trial_outcome(mask) = true;
            E.tau_mean = (E.tau_assert + E.tau_deassert)/2;
            E.tau_total = seconds(E.t_total - E.t_trial);
            E = movevars(E,["tau_mean","tau_total"], 'After', 'tau_deassert');
        end

    end

    function trialTbl = parseFittsLogToTrials(logData)
        %PARSEFITTSTASKLOG Convert Fitts continuous-frame log into trialized rows.
        %
        % Inputs:
        %   logData : timetable produced by readTaskServerLog() for fileType="fitts"
        %             with fields:
        %               Timestamp (datetime)
        %               TrialIndex (int16/int32)
        %               TrialState (enum.FittsTaskState)
        %               CursorX, CursorY, TargetX, TargetY
        %               IR_Inst, IR_EMA
        %
        % Outputs:
        %   trialTbl : table with one row per trial:
        %       TrialIndex
        %       EnterTime
        %       ExitTime
        %       TerminalState    (last state in that trial, enum.FittsTaskState)
        %       ExitState        (last non-ERROR state before first ERROR, or
        %                         TerminalState if no ERROR, or UNKNOWN)
        %       Success          (true if any ACQUIRED state)
        %       MovementOnset
        %       MovementLatency
        %       DialInTime
        %       Bits
        %       BitsPerSecond
        %       MeanIR
        %       NFrames

        if isempty(logData)
            trialTbl = table();
            return;
        end

        % ---- Identify trials by TrialIndex changes --------------------------------
        TI = logData.TrialIndex;
        trialBreaks = find([true; diff(TI) ~= 0]);
        nTrials = numel(trialBreaks);

        trialRows = struct([]);

        % ---- Workspace-normalized velocity for movement onset ----------------------
        dt = seconds(diff(logData.Timestamp));
        dt = [dt(1); dt];   % pad leading sample
        vx = gradient(logData.CursorX) ./ dt;
        vy = gradient(logData.CursorY) ./ dt;
        v  = sqrt(vx.^2 + vy.^2);

        % Normalize to [0,1] to make a robust threshold
        VEL_THRESH = 0.15;   % relative velocity threshold
        ABS_MIN_VEL = 5;   % px/s absolute threshold to avoid noise

        % ---- Trial Loop -------------------------------------------------------------
        for k = 1:nTrials
            idxStart = trialBreaks(k);
            if k < nTrials
                idxEnd = trialBreaks(k+1) - 1;
            else
                idxEnd = height(logData);
            end

            seg = logData(idxStart:idxEnd,:);

            % enum.FittsTaskState array
            states = seg.TrialState;

            % ----- Terminal state (last state recorded) -----------------------------
            terminalState = states(end);

            % ----- ExitState (last non-ERROR before first ERROR) --------------------
            % If there is an ERROR, look at the last state *before* ERROR.
            % If no ERROR, ExitState = TerminalState.
            % If only ERROR and nothing else, ExitState = UNKNOWN.
            exitState = terminalState;

            idxError = find(states == enum.FittsTaskState.ERROR, 1, 'first');
            if ~isempty(idxError)
                % Look back to last non-ERROR state before this ERROR
                if idxError > 1
                    prevIdx = find(states(1:idxError-1) ~= enum.FittsTaskState.ERROR, ...
                        1, 'last');
                    if ~isempty(prevIdx)
                        exitState = states(prevIdx);
                    else
                        exitState = enum.FittsTaskState.UNKNOWN;
                    end
                else
                    % ERROR is first state in this trial
                    exitState = enum.FittsTaskState.UNKNOWN;
                end
            end

            % ----- Success flag -----------------------------------------------------
            success = any(states == enum.FittsTaskState.ACQUIRED);

            %% ----- Movement onset (trial-relative velocity normalization) -----
            % Compute per-trial velocity
            dt_seg = seconds(diff(seg.Timestamp));
            dt_seg = [dt_seg(1); dt_seg];

            vx_seg = gradient(seg.CursorX) ./ dt_seg;
            vy_seg = gradient(seg.CursorY) ./ dt_seg;
            v_seg  = sqrt(vx_seg.^2 + vy_seg.^2);

            % Trial-relative normalization (robust to slow/fast trials)
            v_min = min(v_seg);
            v_max = max(v_seg);
            vNorm = (v_seg - v_min) / max(eps, (v_max - v_min));

            % Logical vector marking likely movement
            isMoving_seg = (vNorm > VEL_THRESH) & (v_seg > ABS_MIN_VEL);

            movementIdx = find(isMoving_seg, 1, 'first');

            if isempty(movementIdx)
                % ---- Fallback #1: first transition from NOT_STARTED→MOVING_TO_TARGET ----
                idxTrans = find(states == enum.FittsTaskState.MOVING_TO_TARGET, 1, 'first');
                if ~isempty(idxTrans)
                    movementIdx = idxTrans;
                else
                    % ---- Fallback #2: cannot determine movement onset ----
                    movementOnset   = NaT;
                    movementLatency = NaN;
                end
            end

            if ~isempty(movementIdx)
                movementOnset   = seg.Timestamp(movementIdx);
                movementLatency = seconds(movementOnset - seg.Timestamp(1));
            end


            % ----- Dial-in time (movement onset → first ACQUIRED) -------------------
            if success
                idxAcquire = find(states == enum.FittsTaskState.ACQUIRED, 1, 'first');
                tAcquire   = seg.Timestamp(idxAcquire);
                if ~isnat(movementOnset)
                    dialInTime = seconds(tAcquire - movementOnset);
                else
                    dialInTime = NaN;
                end
            else
                dialInTime = NaN;
            end

            % ----- Throughput metrics ----------------------------------------------
            % Integrate IR_Inst over the trial duration
            tRel = seconds(seg.Timestamp - seg.Timestamp(1));
            bits = trapz(tRel, seg.IR_Inst);
            dur  = seconds(seg.Timestamp(end) - seg.Timestamp(1));
            bps  = bits / max(dur, eps);

            meanIR = mean(seg.IR_EMA, 'omitnan');

            % ----- Pack into struct row --------------------------------------------
            trialRows(k).TrialIndex       = seg.TrialIndex(1);
            trialRows(k).EnterTime        = seg.Timestamp(1);
            trialRows(k).ExitTime         = seg.Timestamp(end);
            trialRows(k).TerminalState    = terminalState;
            trialRows(k).ExitState        = exitState;
            trialRows(k).Success          = success;

            trialRows(k).MovementOnset    = movementOnset;
            trialRows(k).MovementLatency  = movementLatency;
            trialRows(k).DialInTime       = dialInTime;

            trialRows(k).Bits             = bits;
            trialRows(k).BitsPerSecond    = bps;
            trialRows(k).MeanIR           = meanIR;

            trialRows(k).NFrames          = height(seg);
        end

        % Convert to table
        trialTbl = struct2table(trialRows);

        % Sometimes if it's the first time the Task is run on loading the
        % page, initialization is weird and we get this unknown state error
        % if trialTbl.ExitState(1) == enum.FittsTaskState.UNKNOWN
        %     trialTbl(1,:) = [];
        % end
        trialTbl(1,:) = [];
        trialTbl.TrialDuration = seconds(trialTbl.ExitTime - trialTbl.EnterTime);

    end
end


