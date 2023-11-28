function bag = load_rosbag(SUBJ, YYYY, MM, DD, BLOCK, options)
%LOAD_ROSBAG Loads data saved in raw_data in .mat format after parsing from .db3 bag files.
%
% Syntax:
%   bag = io.load_rosbag(SUBJ, YYYY, MM, DD, BLOCK, 'Name', value, ...);
%
% Example:
%   bag = io.load_rosbag('Max', 2023, 11, 17, 4); % Loads block-4
%
% Inputs:
%     SUBJ {mustBeTextScalar} % Name of subject
%     YYYY (1,1) double % Year
%     MM (1,1) double % Month
%     DD (1,1) double % Day
%     BLOCK (1,1) double % Block index/key
%
% Options:
%     'Tag' {mustBeTextScalar} = "A"; % "Tag" associated to files
%     'Identifier' {mustBeTextScalar} = "rosbag"; % Identifier for .mat files in raw_data TANK
%     'AboutFile' {mustBeTextScalar} = 'about.yaml';
%     'LoadAbout' (1,1) logical = true;
%     'SagaTag' {mustBeTextScalar} = "Delta";
%     'AnnotationsExtension' {mustBeTextScalar} = "annotations.yaml";
%     'LoadAnnotations' (1,1) logical = true;
%     'RawFolderRoot' {mustBeFolder, mustBeTextScalar} = "R:/NMLShare/raw_data/human";
%     'GeneratedFolderRoot' {mustBeTextScalar} = "R:/NMLShare/generated_data/human/Perturbations"
%     'Verbose' (1,1) logical = true;
%
% See also: Contents

arguments
    SUBJ {mustBeTextScalar} % Name of subject
    YYYY (1,1) double % Year
    MM (1,1) double % Month
    DD (1,1) double % Day
    BLOCK (1,1) double % Block index/key
    options.Tag {mustBeTextScalar} = "A"; % "Tag" associated to files
    options.Identifier {mustBeTextScalar} = "rosbag"; % Identifier for .mat files in raw_data TANK
    options.AboutFile {mustBeTextScalar} = 'about.yaml';
    options.LoadAbout (1,1) logical = true;
    options.SagaTag {mustBeTextScalar} = "Delta";
    options.AnnotationsExtension {mustBeTextScalar} = "annotations.yaml";
    options.LoadAnnotations (1,1) logical = true;
    options.RawFolderRoot {mustBeFolder, mustBeTextScalar} = "R:/NMLShare/raw_data/human";
    options.GeneratedFolderRoot {mustBeTextScalar} = "R:/NMLShare/generated_data/human/Perturbations";
    options.Verbose (1,1) logical = true;
end

TANK = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
tank_folder = fullfile(options.RawFolderRoot, SUBJ, TANK);
output_folder = fullfile(options.GeneratedFolderRoot, SUBJ, TANK, sprintf('%s-%d', options.SagaTag, BLOCK));
if exist(output_folder, 'dir')==0
    mkdir(output_folder);
    if options.Verbose
        fprintf(1,'Created NEW output folder:\n\t->\t%s\n', output_folder);
    end
end

bag = load(fullfile(tank_folder, sprintf('%s_%s_%s_%d.mat', ...
    TANK, options.Identifier, options.Tag, BLOCK)));
bag.meta = struct(...
    'Subject', SUBJ, ...
    'Block', BLOCK, ...
    'Tank', TANK, ...
    'InputFolder', tank_folder, ...
    'OutputFolder', output_folder);
bag.start_time = datetime(bag.start_time);
bag.start_time.TimeZone = 'America/New_York';

% Add in any metadata parsing that is helpful when pulling in the data,
% here, so that it comes in as part of the "bag" struct (i.e. when parsing
% from other files).
if options.LoadAnnotations
    annotations_file = sprintf('%s_%s', TANK, options.AnnotationsExtension);
    annotations_fullfile = fullfile(tank_folder, annotations_file);
    if exist(annotations_fullfile,'file')==0
        bag.annotations = struct.empty();
        warning('No annotations file (%s) detected in data tank <%s>\n', ...
            annotations_file, TANK);
    else
        if options.Verbose
            fprintf(1,'Found annotations file (%s), loading...', annotations_file);
        end
        bag.annotations = io.yaml.loadFile(annotations_fullfile);
        if options.Verbose
            fprintf(1,'complete\n');
            f = fieldnames(bag.annotations);
            for iF = 1:numel(f)
                disp(bag.annotations.(f{iF}));
            end
        end
    end
else
    bag.annotations = struct.empty();
    if options.Verbose
        fprintf(1,'Skipped loading annotations file.\n');
    end
end

if options.LoadAbout
    about_fullfile = fullfile(tank_folder, options.AboutFile);
    if exist(about_fullfile,'file')==0
        bag.about = struct.empty();
        warning('No %s detected in data tank <%s>\n', options.AboutFile, TANK);
    else
        if options.Verbose
            fprintf(1,'Found %s, loading...', options.AboutFile);
        end
        about = io.yaml.loadFile(about_fullfile);
        about_field = sprintf('%s_%s_%d', TANK, options.SagaTag, BLOCK);
        f = fieldnames(about);
        bag.about = struct('Block', "No block-specific notes added.", ...
                           'General', about.General_Notes);
        idx = ismember(f, about_field);
        if sum(idx) == 1
            bag.about.Block = about.(f{idx});
        end
        if options.Verbose
            fprintf(1,'complete\n');
            disp(bag.about);
        end
    end
else
    bag.about = struct.empty();
    if options.Verbose
        fprintf(1,'Skipped loading %s.\n', options.AboutFile);
    end
end

end