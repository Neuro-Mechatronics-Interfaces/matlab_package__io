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
git submodule add git@github.com:m053m716/-io.git +io
```
This will add the folder with the correct package name.

## Contents ##

### Classes ###
Wrapper classes to encapsulate specific file formats or data-types to make them easier to work with in MATLAB.  


  `JSON`                               - Class to access contents of JSON file.  

### Functions ###
General-purpose utility functions for this repository.   

  `batch_import_modules`               - Use `repos` struct to init a bunch of git submodules.  
  `batch_import_repos`                 - Use `repos` struct to clone bunch of git repos.  
  `load_sync`                          - Loads processed sync data.  
  `read_repos_list`                    - Get list of all repos in `.repos` file.  

### TMSi-Specific ###  
Functions for loading data from TMSi `poly5` files or associated processed MATLAB files.  


  `load_tmsi`                          - API access point for `load_tmsi_mat` or `load_tmsi_raw`.  
  `load_tmsi_mat`                      - Loads "raw" data block that was saved via TMSiServer MATLAB API.  
  `load_tmsi_potentiometers`           - Loads ISO AUX-1 and ISO AUX-2 (potentiometers).  
  `load_tmsi_raw`                      - Loads raw data block.  
  `load_tmsi_triggers`                 - Loads TMSi sync triggers if they have been parsed.  
  `parse_polybench_data_manager_notes` - Parse notes taken in Polybench Data Manager.  

### Wrist-Task-Specific ###
These most-likely only work if run specifically from a submodule initialized in the `NHP_Center_Out` repository.  


  `load_wrist_task_parameters`         - Import logging parameters for a given subject.  
  `load_wrist_task_training_summary`   - Reads table of training history.  
  `load_wrist_task_raw_logs`           - Import data from a text file.  
  `load_wrist_task_trial_data`         - Import data from a trial .txt file.  
  `load_wrist_task_trial_logs`         - Import data from trial .logs file.  
  `parse_wrist_task_position_parameters` - Returns parameters table associated with `Position` timetable.  
  `parse_wrist_task_trials`            - Return Trial timetable from Logs timetable.  
  `parse_wrist_task_txt_header`        - Parse header of TrialData.txt file.  
  `save_parsed_wrist_task_logs`        - Save parsed behavioral logging to generated_data on server.  
  `save_wrist_task_trial_data`         - Saves trial data to generated data location on server.  

### Installer ###
  `setup`                              - Run this to automatically get dependencies of +io package via git.  
