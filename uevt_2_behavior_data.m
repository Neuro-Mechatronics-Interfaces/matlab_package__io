function behavior_data = uevt_2_behavior_data(SUBJ, YYYY, MM, DD, options)
%UEVT_2_BEHAVIOR_DATA Convert .uevt files to basic behavior data tables
%
% Syntax:
%   behavior_data = io.uevt_2_behavior_data(SUBJ, YYYY, MM, DD, 'Name', value, ...);

arguments
    SUBJ {mustBeTextScalar}
    YYYY (1,1) double
    MM (1,1) double
    DD (1,1) double
    options.GeneratedDataRoot {mustBeTextScalar} = ""
    options.GeneratedDataFile {mustBeTextScalar} = ""
    options.RawDataRoot {mustBeTextScalar} = ""
    options.BehaviorDataVersion (1,1) double {mustBeInteger, mustBePositive} = 1;
end

TANK = sprintf('%s_%04d_%02d_%02d', SUBJ, YYYY, MM, DD);
if strlength(options.GeneratedDataRoot)==0
    gendata_root = parameters('generated_data_folder');
else
    gendata_root = options.GeneratedDataRoot;
end
if strlength(options.GeneratedDataFile) == 0
    fname = fullfile(gendata_root, SUBJ, TANK, sprintf('%s_behavior_data.mat', TANK));
else
    fname = options.GeneratedDataFile;
end
if strlength(options.RawDataRoot) == 0
    rawdata_root = parameters('raw_data_folder');
else
    rawdata_root = options.RawDataRoot;
end

T = struct;
S = struct;

T.PRO = io.load_uevt('Subject',SUBJ,...
    'Year',YYYY,...
    'Month',MM,...
    'Day',DD,...
    'Orientation','PRO');
if ~isempty(T.PRO)
    S.PRO = utils.parse_uevt_trials(T.PRO);
    if ~isempty(S.PRO)
        S.PRO = S.PRO(:,["Orientation", "Target", "Direction", "Outcome", "State", "State_Time"]);
    end
else
    S.PRO = [];
end
T.MID = io.load_uevt('Subject',SUBJ,...
    'Year',YYYY,...
    'Month',MM,...
    'Day',DD,...
    'Orientation','MID');
if ~isempty(T.MID)
    S.MID = utils.parse_uevt_trials(T.MID);
    if ~isempty(S.MID)
        S.MID = S.MID(:,["Orientation", "Target", "Direction", "Outcome", "State", "State_Time"]);
    end
else
    S.MID = [];
end
if ~(isempty(S.MID) && isempty(S.PRO))
    behavior_data = sortrows([S.PRO; S.MID], 'Time', 'ascend');
    behavior_data.Properties.UserData = struct(...
        'Subject', SUBJ, ...
        'Year', YYYY, ...
        'Month', MM, ...
        'Day', DD, ...
        'Tank', TANK, ...
        'File', fname, ...
        'GeneratedDataRoot', gendata_root, ...
        'RawDataRoot', rawdata_root, ...
        'BehaviorDataVersion', options.BehaviorDataVersion);
else
    behavior_data = [];
    return;
end

[p,~,~] = fileparts(fname);
if exist(p, 'dir')==0
    mkdir(p);
end
save(fname, 'behavior_data', '-v7.3');

end