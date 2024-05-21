function [data, rising, rest_snippets, gesture_snippets, rest_rms, gesture_rms] = load_synchronized_gesture_data(fname,options)
%LOAD_SYNCHRONIZED_GESTURE_DATA  Loads and parses synchronized gesture data
%
% Syntax:
%   [data,rising,rest_snippets,gesture_snippets,rest_rms,gesture_rms] = io.load_synchronized_gesture_data(fname,'Name',value,...);
arguments
    fname {mustBeFile}
    options.NumChannels (1,1) {mustBePositive, mustBeInteger} = 256;
    options.GestureIndex (1,:) {mustBeInteger} = 501:6500;
    options.RestIndex (1,:) {mustBeInteger} = -6500:-501;
    options.RemoveFirstPulse (1,1) logical = true;
end
vec_gesture = options.GestureIndex';
vec_rest = options.RestIndex';
nGesture = numel(vec_gesture);
nRest = numel(vec_rest);
data = load(fname);
rising = struct;
rising.all = utils.parse_sync(data.sync, 0, 'InvertLogic', false);
data.t = (0:(size(data.uni,2)-1))./data.sample_rate;
all_gesture = bitand(data.sync,1)==1;
all_rest = bitand(data.sync,1)==0;
if options.RemoveFirstPulse
    rising.all(1) = []; % Remove sync blip from Prakarsh Gesture GUI
end
rising.rest = rising.all;
mask_rest = rising.all + vec_rest;
i_remove = any(mask_rest<1, 1);
rising.rest(i_remove) = [];
mask_rest(:,i_remove) = [];
rising.gesture = rising.all;
mask_gesture = rising.all + vec_gesture;
i_remove = any((mask_gesture<1)|(mask_gesture > size(data.uni,2)), 1);
mask_gesture(:,i_remove) = [];
rising.gesture(i_remove) = [];
if numel(rising.gesture) > numel(rising.rest)
    rising.gesture(1) = [];
    mask_gesture(:,1) = [];
elseif numel(rising.rest) > numel(rising.gesture)
    rising.rest(end) = [];
    mask_rest(:,end) = [];
end
rest_snippets = nan(nRest, options.NumChannels, numel(rising.rest));
rest_rms = nan(1,options.NumChannels);
gesture_snippets = nan(nGesture, options.NumChannels, numel(rising.gesture));
gesture_rms = nan(1,options.NumChannels);
for iCh = 1:options.NumChannels
    tmp = data.uni(iCh,:);
    rest_snippets(:,iCh,:) = tmp(mask_rest);
    gesture_snippets(:,iCh,:) = tmp(mask_gesture);
    rest_rms(1,iCh) = rms(tmp(all_rest));
    gesture_rms(1,iCh) = rms(tmp(all_gesture));
end

end