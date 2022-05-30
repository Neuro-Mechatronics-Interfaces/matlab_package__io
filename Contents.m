% +IO  Handles loading disk file data, repositories, and configurations.
%
% Classes
%   JSON                               - Class to access contents of JSON file.
% 
% Functions
%   batch_import_modules               - Use `repos` struct to init a bunch of git submodules.
%   batch_import_repos                 - Use `repos` struct to clone bunch of git repos.
%   load_muscle_map                    - Loads JSON muscle map object.
%   load_sync                          - Loads processed sync data.
%   read_repos_list                    - Get list of all repos in `.repos` file.
% 
% TMSi-Specific
%   load_tmsi                          - API access-point for `load_tmsi_mat` or `load_tmsi_raw`. 
%   load_tmsi_mat                      - Loads "raw" data block that was saved via TMSiServer MATLAB API.
%   load_tmsi_potentiometers           - Loads ISO AUX-1 and ISO AUX-2 (potentiometers).  
%   load_tmsi_raw                      - Loads raw data block.
%   load_tmsi_triggers                 - Loads TMSi sync triggers if they have been parsed.
%   parse_polybench_data_manager_notes - Parse notes taken in Polybench Data Manager.
% 
% Wrist-Task-Specific
%   load_wrist_task_parameters              - Import logging parameters for a given subject.
%   load_wrist_task_parsed_logs             - Load parsed position/logs/header data.
%   load_wrist_task_training_summary        - Reads table of training history.
%   load_wrist_task_raw_logs                - Import data from a text file.
%   load_wrist_task_trial_data              - Import data from a trial .txt file.
%   load_wrist_task_trial_logs              - Import data from trial .logs file.
%   parse_wrist_task_position_parameters    - Returns parameters table associated with `Position` timetable.
%   parse_wrist_task_trials                 - Return Trial timetable from Logs timetable.
%   parse_wrist_task_txt_header             - Parse header of TrialData.txt file.
%   save_parsed_wrist_task_logs             - Save parsed behavioral logging to generated_data on server.
%   save_wrist_task_trial_data              - Saves trial data to generated data location on server.
% 
% Installer
%   setup                              - Can run this to automatically get dependencies of +io package via git.
