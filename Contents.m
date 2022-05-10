% +IO  Handles loading disk file data, repositories, and configurations.
%
% Files
%   batch_import_modules               - Use `repos` struct to init a bunch of git submodules.
%   batch_import_repos                 - Use `repos` struct to clone bunch of git repos.
%   JSON                               - Class to access contents of JSON file.
%   load_sync                          - Loads processed sync data
%   load_tmsi                          - Loads "raw" data block that was saved via TMSiServer MATLAB API
%   load_tmsi_mat                      - Loads "raw" data block that was saved via TMSiServer MATLAB API
%   load_tmsi_potentiometers           - LOAD_TMSI_RAW Loads raw data block
%   load_tmsi_raw                      - Loads raw data block
%   load_tmsi_triggers                 - Loads TMSi sync triggers if they have been parsed
%   parse_polybench_data_manager_notes - Parse notes taken in Polybench Data Manager.
%   read_repos_list                    - Get list of all repos in `.repos` file.
%
% Installer
%   setup                              - Can run this to automatically get dependencies of +io package via git.
