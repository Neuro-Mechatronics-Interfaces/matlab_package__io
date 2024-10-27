function channelOrder = textile_8x8_uni2grid_mapping(swapped_cables)
%TEXTILE_8x8_UNI2GRID_MAPPING  Return remap for UNI01-UNI64 to 8x8 GRID
%
% Syntax:
%   channelOrder = textile_8x8_uni2grid_mapping();
%   channelOrder = textile_8x8_uni2grid_mapping(swapped_cables);
%
% Inputs:
%   swapped_cables - (optional; default: false) -- Set true to return
%                    corrected mapping if Cable for Grid-1 was connected to 
%                    Grid-2 and vis versa.
%
% Example 1:
%   data = TMSiSAGA.Poly5.read('data.poly5');
%   uni = data.samples(1:64,:); % Or 2:65 if CREF is present on channel 1 (based on hardware referencing)
%   uni = uni(io.textile_8x8_uni2grid_mapping(),:); % Now order is like it would be with standard 8x8 grids. 
%
% Example 2:
%   data = TMSiSAGA.Poly5.read('data__swapped_cables_accidentally.poly5');
%   uni = data.samples(1:64,:); % Or 2:65 if CREF is present on channel 1 (based on hardware referencing)
%   uni = uni(io.textile_8x8_uni2grid_mapping(true),:); % Now order is like it would be with standard 8x8 grids.
%
% See also: Contents, TMSiSAGA.Poly5

arguments
    swapped_cables (1,1) logical = true;
end
if swapped_cables
    channelOrder = [64	60	56	52	51	50	49	48	63	59	55	47	46	45	44	43	62	58	54	42	41	40	39	38	61	57	53	37	36	35	34	33	4	8	12	28	29	30	31	32	3	7	11	23	24	25	26	27	2	6	10	18	19	20	21	22	1	5	9	13	14	15	16	17];
else
    channelOrder = [17	16	15	14	13	9	5	1	22	21	20	19	18	10	6	2	27	26	25	24	23	11	7	3	32	31	30	29	28	12	8	4	33	34	35	36	37	53	57	61	38	39	40	41	42	54	58	62	43	44	45	46	47	55	59	63	48	49	50	51	52	56	60	64];
end

end