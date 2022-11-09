classdef TaskMachine < handle
    %TASKMACHINE  Task State Machine object for use with *_Task_Config.yaml
    %   Detailed explanation goes here

    events
        timeout
    end

    properties (Access = public)
        state       (1,1) struct
        target      (1,1) = 0.0
        direction   (1,1) = 1
        transitions       struct
        pars        (1,1) struct
        tlim        (1,1) struct
    end

    properties (GetAccess = public, SetAccess = protected)
        task
        trial_uuid (1,1) string
        subj_uuid  (1,1) string
        n (1,1) struct = struct('successful', 0, 'total', 0, 'overshoot', 0);
        t (1,1) struct = struct();
    end

    properties(Transient,NonCopyable,Access = protected)
        elog (1,1) % Events log
    end

    properties (Access = protected)
        states_         % From config yaml file.

        t_           (1,1) datetime
        target_state_(1,1) struct = struct('T1', false, 'T2', false);
        tlim_        (1,1) struct = struct();
        trials_
        state_index_ (1,1) double = 1  % Current state index
        target_index_ (1,1) double = 1
        next_target_index_ (1,1) double = NaN
        TS_                         % TaskSurface

        ah_          (3,1) cell     % Array of audioplayer handles: [1 - GO | 2 - SUCCESS | 3 - FAIL]
        lh_          (:,1)          % Array of listener handles
        th_          (1,1)          % Timer handle
    end

    methods
        function self = TaskMachine(config_file, varargin)
            %TASKMACHINE  Construct an instance of this class
            %
            % Syntax:
            %   machine = TaskMachine(config_file);
            %
            % Inputs:
            %   config_file - e.g. 'Wrist_Task_Config.yaml'
            %
            % This class handles the task state machine and state metadata.
            clc;
            tmp = io.yaml.loadFile(config_file, "ConvertToArray", true);
            self.elog = mlog.Logger("events");
%             tstart = string(datetime('now','TimeZone','local','Format','uuuu-MM-dd_HH-mm-ss'));
            self.new_subject();
            self.state = tmp.state;
            self.states_ = tmp.states;
            self.pars = tmp.parameters;
            self.target_index_ = randi([1 numel(self.pars.targets)], 1);
            self.target = self.pars.targets(self.target_index_);
            self.task = tmp.task;
            for ii = 1:numel(tmp.states)
                s = tmp.states(ii);
                self.tlim.(s.name) = s.timeout;
            end
            self.th_ = timer('TimerFcn', @(~, ~)self.notify_timeout());
            self.reset_trial_events();
%             self.init_trials_matfile(tstart);
            self.init_audio_handles(44100, 0.250);
            self.add_task_surface(TaskSurface('Hidden', true, 'In_Idle', true, 'In_T1', false, 'In_T2', false, 'In_Ring', false, varargin{:}));
            self.init_all_graphics_parameters();
            self.TS_.setOuterTargetIndex(self.target_index_);
        end

        function add_task_surface(self, TS)
            %ADD_TASK_SURFACE  Adds TaskSurface object child handle for graphics component.
            self.TS_ = TS;
            try %#ok<TRYNC>
                for ii = 1:numel(self.lh_)
                    delete(self.lh_(ii));
                end
            end
            self.lh_ = [ ...
                addlistener(self.TS_, "enter_idle", @self.handle_task_event); ...
                addlistener(self.TS_, "exit_idle",  @self.handle_task_event); ...
                addlistener(self.TS_, "enter_t1",   @self.handle_task_event); ...
                addlistener(self.TS_, "exit_t1",    @self.handle_task_event); ...
                addlistener(self.TS_, "enter_t2",   @self.handle_task_event); ...
                addlistener(self.TS_, "exit_t2",    @self.handle_task_event); ...
                addlistener(self.TS_, "enter_ring", @self.handle_task_event); ...
                addlistener(self.TS_, "exit_ring",  @self.handle_task_event); ...
                addlistener(self,     "timeout",    @self.handle_task_event) ...
             ];
            for ii = 3:8
                self.lh_(ii).Enabled = false;
            end
            self.TS_.Parent.DeleteFcn = @(~,~)self.delete();
            self.TS_.setIdle(1);
        end

        function delete(self)
            %DELETE  Overloaded delete method to ensure child object destruction.

            
            self.trials_.Properties.Writable = false;
            try %#ok<TRYNC> 
                for ii = 1:numel(self.lh_)
                    delete(self.lh_(ii));
                end
            end

            try %#ok<TRYNC>
                delete(self.TS_);
            end

            try %#ok<TRYNC>
                delete(self.th_);
            end
        end

        function fail(self, dest)
            %FAIL  Indicate that this trial was unsuccessful.
            self.play_fail_cue();
            self.increment_total_trials();
%             self.log_trial(0);
            self.reset_trial_events();
            self.handle_state_update(dest, "fail");
        end

        function handle_task_event(self, src, evt)
            %HANDLE_TASK_EVENT  Event listener callback
            e = string(evt.EventName);
            switch e
                case {"enter_idle", "exit_idle"}
                    io.TaskMachine.print_timestamped_message(e);
                    self.handle_idle_state_update();
                case {"enter_t1", "exit_t1", "enter_t2", "exit_t2", "succeed", "fail", "next", "timeout", "exit_ring"}
                    tr = src.transitions;
                    itrig = find(ismember([tr.trigger], e),1, 'first');
                    if isempty(itrig)
                        return;
                    else
                        transition = tr(itrig);
                    end
                    io.TaskMachine.print_timestamped_message(sprintf("event::%s (%s > %s)", e, transition.name, transition.dest));
                    self.(transition.name)(transition.dest);
            end
        end

        function hide_t1(self)
            %HIDE_T1  Hide the primary target
            ts = self.TS_;
            if ~isempty(ts) && isvalid(ts)
                ts.hideT1();
            end
            self.target_state_.T1 = false;
        end
        
        function hide_t2(self)
            %HIDE_T2  Hide the secondary target
            ts = self.TS_;
            if ~isempty(ts) && isvalid(ts)
                ts.hideT2();
            end
            self.target_state_.T2 = false;
        end

        function play_fail_cue(self)
            %PLAY_FAIL_CUE  Play FAIL cue indicating unsuccessful trial.
            play(self.ah_{3});
        end

        function play_go_cue(self)
            %PLAY_GO_CUE  Play GO cue indicating to go to next target.
            play(self.ah_{1});
        end

        function play_success_cue(self)
            %PLAY_SUCCESS_CUE  Play SUCCESS cue indicating unsuccessful trial.
            play(self.ah_{2});
        end

        function new_subject(self, tstart)
            %NEW_SUBJECT  Generate new Subject UUID to associate into logs.
            self.subj_uuid = strrep(string(javaMethod('toString', java.util.UUID.randomUUID)),"-","");
%             self.elog = mlog.Logger(sprintf("%s_%s_events", tstart, self.subj_uuid));
        end

        function next(self, dest)
            %NEXT  Increment to next state.
            self.handle_state_update(dest, "next");
        end

        function notify_timeout(self)
            %NOTIFY_TIMEOUT  Notify that the timer timed out
            evt = io.TimeoutEventData(self.state.CUR);
            notify(self, "timeout", evt);
        end

        function overshoot(self, dest)
            %OVERSHOOT  Increment to overshoot state.
            self.n.overshoot = self.n.overshoot + 1;
            if self.n.overshoot > self.pars.n_overshoots_allowed
                self.fail("t1_pre");
            else
                self.handle_state_update(dest, "overshoot");
            end
        end

        function show_t1(self)
            %SHOW_T1  Show the primary target
            ts = self.TS_;
            if ~isempty(ts) && isvalid(ts)
                ts.showT1();
            end
            self.target_state_.T1 = true;
        end

        function show_t2(self)
            %SHOW_T2  Show the secondary target
            ts = self.TS_;
            if ~isempty(ts) && isvalid(ts)
                ts.showT2();
            end
            self.target_state_.T2 = true;
        end

        function succeed(self, dest)
            %SUCCEED  Transition from successful trial/reward to pre-trial
            self.play_success_cue();
            self.increment_total_trials();
            self.increment_successful_trials();
%             self.log_trial(1);
            self.reset_trial_events();
            self.handle_next_target_graphics();
            self.handle_state_update(dest, "succeed");
        end
        
    end

    methods (Access = protected)
        function handle_state_update(self, dest, transition)
            %HANDLE_STATE_UPDATE  Updates state and executes "on_enter" callbacks
 
            stop(self.th_);
            self.state.PREV_ = self.state.PREV;
            self.state.PREV = self.state.CUR;
            self.state.CUR = dest;

            self.log_event(transition);
            self.state_index_ = find(strcmpi([self.states_.name], string(dest)),1,'first');
            s = self.states_(self.state_index_);
            self.transitions = s.transitions;
            ts = self.TS_;
            if ~isempty(ts) && isvalid(ts)
                ts.transitions = s.transitions;
            end

            % Evaluate any "on_enter" methods for this state.
            if ~isa(s.on_enter, 'io.yaml.Null')
                for ii = 1:numel(s.on_enter)
                    self.(s.on_enter(ii))();
                end
            end
            
            % Finally, set the new timeout and start timer.
            if isinf(self.tlim_.(dest))
                io.TaskMachine.print_timestamped_message(sprintf("state::%s (timeout   inf)", dest));
            else
                tlim_state = round(self.tlim_.(dest),3);
                self.th_.StartDelay = tlim_state;
                start(self.th_);
                io.TaskMachine.print_timestamped_message(sprintf("state::%s (timeout %5.3f)", dest, tlim_state));
            end
                
        end

        function handle_idle_state_update(self)
            %HANDLE_IDLE_STATE_UPDATE  Updates state specifically for IDLE
            in_idle = strcmpi(self.state.CUR, 'idle');
            if in_idle
                self.state.CUR = self.state.PREV;
                self.state.PREV = self.state.PREV_;
                ts = self.TS_;
                self.state_index_ = find(strcmpi([self.states_.name], self.state.CUR),1,'first');
                if ~isempty(ts) && isvalid(ts)
                    if self.target_state_.T2
                        ts.showT2();
                    end
                    if self.target_state_.T1
                        ts.showT1();
                    end
                    ts.showCursor();
                end
                for ii = 3:8
                    self.lh_(ii).Enabled = true;
                end
                % Evaluate any "on_enter" methods for this state.
                s = self.states_(self.state_index_);
                self.transitions = s.transitions;
                ts = self.TS_;
                if ~isempty(ts) && isvalid(ts)
                    ts.transitions = s.transitions;
                end
                if ~isa(s.on_enter, 'io.yaml.Null')
                    for ii = 1:numel(s.on_enter)
                        self.(s.on_enter(ii))();
                    end
                end
                if ~isinf(self.tlim_.(self.state.CUR))
                    start(self.th_);
                end
            else
                for ii = 3:8
                    self.lh_(ii).Enabled = false;
                end
                stop(self.th_);
                self.state.PREV_ = self.state.PREV;
                self.state.PREV = self.state.CUR;
                self.state.CUR = 'idle';
                self.state_index_ = find(strcmpi([self.states_.name], self.state.CUR),1,'first');
                ts = self.TS_;
                if ~isempty(ts) && isvalid(ts)
                    if self.target_state_.T2
                        ts.hideT2();
                    end
                    if self.target_state_.T1
                        ts.hideT1();
                    end
                    ts.hideCursor();
                end
                
            end
        end

        function handle_next_target_graphics(self)
            %HANDLE_NEXT_TRIAL_GRAPHICS  Toggle task direction and update target locations.
            self.direction = 1 - self.direction;
            if self.direction > 0 % Only change target for "CENTER > OUT" trials
                tgts = self.pars.targets;
                if isnan(self.next_target_index_)
                    self.target_index_ = randi([1 numel(tgts)], 1);
                else
                    self.target_index_ = self.next_target_index_;
                end
                self.target = tgts(self.target_index_);
            end
            if ~isempty(self.TS_) && isvalid(self.TS_)
                ts = self.TS_;
                ts.Direction  = self.direction;
                % Set Outer_Ring_Target_ property then set position of 
                % T1 and T2 according to Direction and Outer_Ring_Target_ 
                % properties of TaskSurface:
                ts.setOuterTargetIndex(self.target_index_); 
            end
        end

        function increment_total_trials(self)
            %INCREMENT_TOTAL_TRIALS  Increment the total trial count.
            self.n.total = self.n.total + 1;
        end

        function increment_successful_trials(self)
            %INCREMENT_SUCCESSFUL_TRIALS  Increment the total trial count.
            self.n.successful = self.n.successful + 1;
        end

        function init_all_graphics_parameters(self)
            %INIT_ALL_GRAPHICS_PARAMETERS  Initialize all graphics parameters for the TaskSurface
            ts = self.TS_;
            if ~isempty(ts) && isvalid(ts)
                ts.setParameter(fieldnames(self.pars), struct2cell(self.pars));
            end            
        end

        function init_audio_handles(self, fs, tone_duration)
            %INIT_AUDIO_HANDLES  Initializes the audio player for tone cues
            %
            % Syntax:
            %   self.init_audio_handles(fs, tone_duration);
            %   
            % Inputs:
            %   fs            - Tone sampling frequency.
            %   tone_duration - Duration to play each tone pulse.
            try %#ok<TRYNC> 
                for ii = 1:numel(self.ah_)
                    delete(self.ah_{ii});
                end
            end
            t_samples = (0:(1/fs):(tone_duration - 1/fs))';
            amp = 0.20;
            A880 = [amp.*sin(2.*pi.*880.*t_samples), amp.*cos(2.*pi.*880.*t_samples)];   % 1 - GO
            A1760 = [amp.*sin(2.*pi.*1760.*t_samples), amp.*cos(2.*pi.*1760.*t_samples)]; % 2 - SUCCESS
            A440 = [amp.*sin(2.*pi.*440.*t_samples), amp.*cos(2.*pi.*440.*t_samples)];   % 3 - FAIL
            self.ah_ = { audioplayer(A880 , fs);
                         audioplayer(A1760, fs);
                         audioplayer(A440 , fs) };
        end

        function init_trials_matfile(self, tstart)
            %INIT_TRIALS_MATFILE  Initialize matfile for storing trials table
            fname = fullfile(pwd, "logs", sprintf("%s_%s_trials.mat", tstart, self.subj_uuid));
            trial_constraints = struct2table(self.tlim_);
            for ii = 1:numel(trial_constraints.Properties.VariableNames)
                trial_constraints.Properties.VariableNames{ii} = strcat(trial_constraints.Properties.VariableNames{ii}, '_timeout');
            end
            trials = [struct2table(self.t), trial_constraints];
            trials.start = cell(1,1);
            trials.duration_ms = cell(1,1);
            trials.target = cell(1,1);
            trials.direction = cell(1,1);
            trials.outcome = cell(1,1);
            trials.uuid = cell(1,1);
            trials(1,:) = [];
            save(fname, 'trials', '-v7.3');
            self.trials_ = matfile(fname, 'Writable', true);
        end

        function log_event(self, transition)
            %LOG_EVENT  Logs an event with current timestamp.
            self.elog.info(sprintf("%s :: TYPE=%s :: PREV=%s :: CUR=%s", self.subj_uuid, transition, self.state.PREV, self.state.CUR));
            self.t.(self.state.CUR){1}(end+1) = datetime('now','TimeZone','local','Format','uuuu-MM-dd HH:mm:ss.SSS');
        end

        function log_trial(self, outcome)
            %LOG_TRIAL  Logs a trial with current timestamp.
            trial_constraints = struct2table(self.tlim_);
            for ii = 1:numel(trial_constraints.Properties.VariableNames)
                trial_constraints.Properties.VariableNames{ii} = strcat(trial_constraints.Properties.VariableNames{ii}, '_timeout');
            end
            trial = [struct2table(self.t), trial_constraints];
            trial.start = self.t_;
            trial.duration_ms = milliseconds(datetime('now','TimeZone','local') - self.t_);
            trial.target = self.target;
            trial.direction = self.direction;
            trial.outcome = outcome;
            trial.uuid = self.trial_uuid;
            self.trials_.trials = [self.trials_.trials; trial];
        end
        
        function reset_trial_events(self)
            %RESET_TRIAL_EVENTS  Reset events associated with entering each state
            for ii = 1:numel(self.states_)
                name = self.states_(ii).name;
                self.t.(name) = cell(1,1);
                to = self.tlim.(name);
                if to.en
                    switch to.mode
                        case "exp"
                            self.tlim_.(name) = io.TaskMachine.exponential_random(to.min, to.max);
                        case "fixed"
                            self.tlim_.(name) = to.value;
                    end
                else
                    self.tlim_.(name) = inf;
                end
            end
            self.n.overshoot = 0;
            ts = self.TS_;
            if ~isempty(ts) && isvalid(ts)
                ts.In_T1 = false;
                ts.In_T2 = false;
            end
            self.t_ = datetime('now','TimeZone','local','Format','uuuu-MM-dd HH:mm:ss.SSS');
            self.trial_uuid = strrep(string(javaMethod('toString', java.util.UUID.randomUUID)),"-","");
        end
    end

    methods (Static)
        function timeout = exponential_random(min_val, max_val)
            %EXPONENTIAL_RANDOM  Return exponential random bounded value
            beta = (max_val - min_val) / 7.0; % CDF includes +/ 3.5 SD
            timeout = min(max_val, min_val + exprnd(beta));
        end

        function print_timestamped_message(msg)
            %PRINT_TIMESTAMPED_MESSAGE  Print timestamped message to Command Window.
            fprintf(1,"%s::<strong>%s</strong>\n", string(datetime('now', 'TimeZone', 'local', 'Format', 'HH:mm:ss.SSS')), msg);
        end
    end
end