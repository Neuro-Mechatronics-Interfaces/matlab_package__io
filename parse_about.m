function about = parse_about(SUBJ, YYYY, MM, DD, varargin)
%PARSE_ABOUT  Parse `about.yaml` in notes of raw_data for a given tank.
%
% Syntax:
%   about = io.parse_about(SUBJ, YYYY, MM, DD);
%   about = io.parse_about(__,'Name', value, ...);
%
% Inputs:
%   SUBJ        - Subject name
%   YYYY        - Year (numeric)
%   MM          - Month (numeric)
%   DD          - Day (numeric)
%   varargin    - (Optional) <'Name', value> input argument pairs.
%
% Output:
%   about       - "About" data parsed from the yaml file.
%               -> Returned as a struct with following fields:
%                   'Subject': <"Spencer" or "Rupert">
%                   'SAGA': struct with 
%                           'A' | 'B';  'Potentiometers', and 'Notes' field 
%                       'A' | 'B' are structs with fields:
%                           - 'Type' (indicating the "type of recording 
%                                      setup for that SAGA, e.g. 
%                                      "2Textile" or "8x8_Large") and
%                           - 'Location' (string array indicating location 
%                                   of each array). 
%                       'Potentiometers':
%                           'Unit' (which SAGA tag "A" or "B")
%                           'X' (what is name of 'X' AUX in MID)
%                           'Y' (what is name of 'Y' AUX in MID)
%                       'Notes': String array of arbitrary notes
%                   'Video': struct with
%                       'Folder' : What folder are the videos in
%                       'File': Struct array 1 for each video, with fields
%                           'Name' (name of video file-- no .mkv in this
%                           but all videos are probably .mkv)
%                       'Description' : Brief description of the video
%                       'Starting_Trial': Which "block" (trial) does this
%                       video approximately start with?
%                   'Recordings': struct array with each element having:
%                       'Block' : (starting block for this set of blocks)
%                       'FileType': '.mat' or '.poly5'
%                       'SAGA' : Which SAGA tags were used in this rec
%                       'Task' : Which task is this
%                       'Orientation': What manipulandum orientation was it
%                       'Description': Other notes describing this set of
%                                       blocks.
%                       'Electrode': Manual annotation indicating things
%                       about electrode contacts and any other things
%                       noticed about placement during the recording.
%                       'Sync': What sync strategy was used (e.g. "PHOTO4")
%                           'Bits': First array element is Bit-0 -- what
%                           does a logical-high (so, that bit going to zero
%                           in TMSi convention) indicate?
%                   'Date': Datetime for day of this recording session.
%                   
%
% See also: Contents, io.yaml

pars = struct;
pars.about_file = 'notes/about.yaml';
pars.raw_data_folder = parameters('raw_data_folder');

pars = utils.parse_parameters(pars, varargin{:});

tank = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
fname_in = fullfile(pars.raw_data_folder, SUBJ, tank, pars.about_file);

if exist(fname_in, 'file')==0
    me = MException('io:missing_file:raw', 'No file named "%s" exists.\n\n\t->\tDid you ever create the "about.yaml" file for this session?\t<-\t\n\t\t\t(Once you do, it needs to be put into the file path as shown above)\n\n', fname_in);
    throw(me);
end

about = io.yaml.loadFile(fname_in, "ConvertToArray", true);
about.Date = datetime(YYYY, MM, DD);

end