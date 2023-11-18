# +io #
Matlab package for input/output conventional consistency.

## Install ##
Once this has been added as a submodule to a given repository, you can then run io.setup to install other required repos:  
(From the command window)  
```(matlab)
io.setup;
```
You should be in the repository folder that is the parent repo of this submodule, which should be added as a MATLAB package (i.e. with the leading `+` in the name of the submodule folder). For example, add it to your repository as:  
```(matlab)
git submodule add git@github.com:Neuro-Mechatronics-Interfaces/matlab_package__io.git +io
```
This will add the folder with the correct package name.

## Contents ##

### Classes ###  
 + [`JSON`](JSON.m) - Class to access contents of JSON file.  

### Primary Functions ###  
 + [`load_data`](load_data.m) - API access-point for loading TMSi or Intan HD-EMG data.  
 + [`load_tmsi`](load_tmsi.m) - API access-point for `load_tmsi_mat` or `load_tmsi_raw`.  

### Exporters ###  
 + [`configure`](configure.m) - Write and return configuration JSON object for a given session.  
 + [`write_wrist_xy_2_sto`](write_wrist_xy_2_sto.m) - Write data from wrist task into .sto format for OpenSim.  

### General Utility ###  
 + [`load_muscle_map`](load_muscle_map.m) - Loads JSON muscle map object.  
 + [`load_sync`](load_sync.m) - Loads processed sync data.  
 + [`new`](new.m) - Open new m-file with both documented and dynamical headers.  
 + [`parse_about`](parse_about.m) - Parse `about.yaml` in notes of raw_data for a given tank.  
 + [`quick_selector_gui`](quick_selector_gui.m) - Blocking function to manually select key experiment parameters (for constructor).  

### GUIs ###  
 + [`quick_selector_gui`](quick_selector_gui.m) - Blocking function to manually select key experiment parameters (for constructor).  

### Impedance-Handling ###  
 + [`load_impedance`](load_impedance.m) - Load impedance if it's been parsed in generated_data.  
 + [`process_raw_impedances`](process_raw_impedances.m) - Process impedances from "raw" format.  

### Intan-Specific ###  
 + [`convert_intan_data_2_tmsi_format`](convert_intan_data_2_tmsi_format.m) - Convert Intan data to TMSi format.  
 + [`load_intan`](load_intan.m) - Reader entry point for INTAN data files.  
 + [`read_Intan_RHD2000_file`](read_Intan_RHD2000_file.m) - Reads Intan RHD data format files into MATLAB.  

### LSL-Specific ###  
 + [`load_xdf`](load_xdf.m) - Import an XDF file.  

### Loaders for Message-Capture Logs ###  
 + [`load_uevt`](load_uevt.m) - Load .uevt file (which contains wrist task behavior events).  
 + [`pcap2matlab`](pcap2matlab.m) - Imports network protocol analyzer capabilties into MATLAB.  
 + [`read_events`](read_events.m) - Reads in "events-export.csv" file for a given session.  

### Microdrive-Specific ###  
 + [`load_trec_depth`](load_trec_depth.m) - Loads timetable with TREC drive depth information.  

### Stimulation-Experiment-Specific ###  
 + [`load_block_hd_emg`](load_block_hd_emg.m) - Loads processed data block.  
 + [`load_block_simulation`](load_block_simulation.m) - Loads simulated field data associated with a given experimental block.  
 + [`load_percept_data`](load_percept_data.m) - Load percept yaml data for a given subject collected using perceptMapper variant for N3 analyses.  

### TMSi-Specific ###  
 + [`convert_intan_data_2_tmsi_format`](convert_intan_data_2_tmsi_format.m) - Convert Intan data to TMSi format.  
 + [`load_align_saga_data`](load_align_saga_data.m) - Loads data from 2 TMSi-SAGA and aligns samples.  
 + [`load_tmsi`](load_tmsi.m) - API access-point for `load_tmsi_mat` or `load_tmsi_raw`.  
 + [`load_tmsi_channel`](load_tmsi_channel.m) - Loads TMSi channel if it has been parsed.  
 + [`load_tmsi_mat`](load_tmsi_mat.m) - Loads "raw" data block that was saved via TMSiServer MATLAB API.  
 + [`load_tmsi_potentiometers`](load_tmsi_potentiometers.m) - Loads ISO AUX-1 and ISO AUX-2 (potentiometers).  
 + [`load_tmsi_raw`](load_tmsi_raw.m) - Loads raw data block.  
 + [`load_tmsi_triggers`](load_tmsi_triggers.m) - Loads TMSi sync triggers if they have been parsed.  
 + [`parse_polybench_data_manager_notes`](parse_polybench_data_manager_notes.m) - Parse notes taken in Polybench Data Manager.  

### Wrist-Task-Specific ###  
 + [`load_aligned_target_data`](load_aligned_target_data.m) - Loads target-aligned data.  
 + [`load_task`](load_task.m) - Load task state machine.  
 + [`load_uevt`](load_uevt.m) - Load .uevt file (which contains wrist task behavior events).  
 + [`load_wrist_event_table_trial`](load_wrist_event_table_trial.m) - Load a wrist center-out task trial from event table.  
 + [`load_wrist_task_parameters`](load_wrist_task_parameters.m) - Import logging parameters for a given subject.  
 + [`load_wrist_task_parsed_logs`](load_wrist_task_parsed_logs.m) - Load parsed position/logs/header data.  
 + [`load_wrist_task_training_summary`](load_wrist_task_training_summary.m) - Reads table of training history.  
 + [`load_wrist_task_raw_logs`](load_wrist_task_raw_logs.m) - Import data from a text file.  
 + [`load_wrist_task_trial_data`](load_wrist_task_trial_data.m) - Import data from a trial .txt file.  
 + [`load_wrist_task_trial_logs`](load_wrist_task_trial_logs.m) - Import data from trial .logs file.  
 + [`parse_wrist_task_position_parameters`](parse_wrist_task_position_parameters.m) - Returns parameters table associated with `Position` timetable.  
 + [`parse_wrist_task_trials`](parse_wrist_task_trials.m) - Return Trial timetable from Logs timetable.  
 + [`parse_wrist_task_txt_header`](parse_wrist_task_txt_header.m) - Parse header of TrialData.txt file.  
 + [`save_parsed_wrist_task_logs`](save_parsed_wrist_task_logs.m) - Save parsed behavioral logging to generated_data on server.  
 + [`save_wrist_task_trial_data`](save_wrist_task_trial_data.m) - Saves trial data to generated data location on server.  
 + [`TimeoutEventData`](TimeoutEventData.m) - Issued as part of a timer callback event.  

### Installer ###  
 + [`batch_import_modules`](batch_import_modules.m) - Use `repos` struct to init a bunch of git submodules.  
 + [`batch_import_repos`](batch_import_repos.m) - Use `repos` struct to clone bunch of git repos.  
 + [`read_repos_list`](read_repos_list.m) - Get list of all repos in `.repos` file.  
 + [`setup`](setup.m) - Can run this to automatically get dependencies of +io package via git.  
