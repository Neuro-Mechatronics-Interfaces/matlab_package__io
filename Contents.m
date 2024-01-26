% +IO  Handles loading disk file data, repositories, and configurations.
%
% Classes
%   JSON                                 - Class to access contents of JSON file.
%   TimeoutEventData                     - Issued as part of a timer callback event.
% 
% Primary Functions
%   load_data                            - API access-point for loading TMSi or Intan HD-EMG data. 
%   load_tmsi                            - API access-point for `load_tmsi_mat` or `load_tmsi_raw`. 
%   load_spikes                          - Load spikes that have been exported via batch pipeline.
%
% Exporters
%   configure                            - Write and return configuration JSON object for a given session
%   write_wrist_xy_2_sto                 - Write data from wrist task into .sto format for OpenSim.
%
% General Utility
%   load_muscle_map                      - Loads JSON muscle map object.
%   load_sync                            - Loads processed sync data.
%   new                                  - Open new m-file with both documented and dynamical headers
%   parse_about                          - Parse `about.yaml` in notes of raw_data for a given tank.
%   quick_selector_gui                   - Blocking function to manually select key experiment parameters (for constructor).
%
% GUIs
%   quick_selector_gui                   - Blocking function to manually select key experiment parameters (for constructor).
% 
% Impedance-Handling
%   load_impedance                       - Load impedance if it's been parsed in generated_data
%   load_nanoz                           - Loads electrode impedances table struct for NanoZ measurements.
%   process_raw_impedances               - Process impedances from "raw" format.
%
% Intan-Specific
%   convert_intan_data_2_tmsi_format     - Convert Intan data to TMSi format
%   load_intan                           - Reader entry point for INTAN data files.
%   read_Intan_RHD2000_file              - Reads Intan RHD data format files into MATLAB.
%
% LSL-Specific
%   load_xdf                             - Import an XDF file.
%
% Message-Capture
%   load_uevt                            - Load .uevt file (which contains wrist task behavior events)
%   pcap2matlab                          - Imports network protocol analyzer capabilties into MATLAB.
%   read_events                          - Reads in "events-export.csv" file for a given session.
%
% Microdrive-Specific
%   load_trec_depth                      - Loads timetable with TREC drive depth information.
%
% Stimulation-Experiment-Specific
%   load_block_hd_emg                    - Loads processed data block
%   load_block_simulation                - Loads simulated field data associated with a given experimental block.
%   load_percept_data                    - Load percept yaml data for a given subject collected using perceptMapper variant for N3 analyses.
%
% ROS2-Specific
%   load_rosbag                          - Loads data saved in raw_data in .mat format after parsing from .db3 bag files.
%
% TMSi-Specific
%   convert_intan_data_2_tmsi_format     - Convert Intan data to TMSi format
%   load_align_saga_data                 - Loads data from 2 TMSi-SAGA and aligns samples
%   load_tmsi                            - API access-point for `load_tmsi_mat` or `load_tmsi_raw`. 
%   load_tmsi_channel                    - Loads TMSi channel if it has been parsed
%   load_tmsi_mat                        - Loads "raw" data block that was saved via TMSiServer MATLAB API.
%   load_tmsi_potentiometers             - Loads ISO AUX-1 and ISO AUX-2 (potentiometers).  
%   load_tmsi_raw                        - Loads raw data block.
%   load_tmsi_triggers                   - Loads TMSi sync triggers if they have been parsed.
%   parse_polybench_data_manager_notes   - Parse notes taken in Polybench Data Manager.
% 
% Wrist-Task-Specific
%   load_aligned_target_data             - Loads target-aligned data
%   load_combined                        - Load spikes that have been clustered across all trials and combined with cluster index indicator, as exported via batch pipeline.
%   load_cursor                          - Loads timetable with TREC drive depth information.
%   load_task                            - Load task state machine.
%   load_uevt                            - Load .uevt file (which contains wrist task behavior events)
%   load_wrist_event_table_trial         - Load a wrist center-out task trial from event table.
%   load_wrist_task_parameters           - Import logging parameters for a given subject.
%   load_wrist_task_parsed_logs          - Load parsed position/logs/header data.
%   load_wrist_task_training_summary     - Reads table of training history.
%   load_wrist_task_raw_logs             - Import data from a text file.
%   load_wrist_task_trial_data           - Import data from a trial .txt file.
%   load_wrist_task_trial_logs           - Import data from trial .logs file.
%   parse_cursor                         - Import data from a text file
%   parse_wrist_task_position_parameters - Returns parameters table associated with `Position` timetable.
%   parse_wrist_task_trials              - Return Trial timetable from Logs timetable.
%   parse_wrist_task_txt_header          - Parse header of TrialData.txt file.
%   save_parsed_wrist_task_logs          - Save parsed behavioral logging to generated_data on server.
%   save_wrist_task_trial_data           - Saves trial data to generated data location on server.
%   uevt_2_behavior_data                 - Convert .uevt files to basic behavior data tables
% 
% Installer
%   batch_import_modules                 - Use `repos` struct to init a bunch of git submodules.
%   batch_import_repos                   - Use `repos` struct to clone bunch of git repos.
%   read_repos_list                      - Get list of all repos in `.repos` file.
%   setup                                - Can run this to automatically get dependencies of +io package via git.
