classdef JSON < dynamicprops
    %JSON Class to access contents of JSON file.
    %   
    % Syntax:
    %   params = JSON('params.json');
    %   disp(params.color);
    %   >> "blue"
    
    properties (SetAccess=protected, GetAccess=public)
        file
    end
    
    methods
        function self = JSON(file, varargin)
            %JSON Construct an instance of the JSON class
            %   
            % Example:
            %   params = JSON('params.json');
            %   disp(params);
            %   >> JSON with properties
            %   >>  file: 'params.json'
            %   >>  colors: [1x1 struct]
            %   >>  default: 'blue'
            %   >>  favorite: [1x1 struct]
            %
            % Example (expand 'colors' and 'favorite'):
            %   params = JSON('params.json', 'colors', 'favorite');
            %   disp(params);
            %   >> JSON with properties
            %   >> file: 'params.json'
            %   >> default: 'blue'
            %   >> blue: '#329ea8'          % from 'colors'
            %   >> red: '#a84432'           % from 'colors'
            %   >> yellow: '#f1f516'        % from 'colors'
            %   >> max: 'red'               % from 'favorite'
            
            self.file = file;
            fid = fopen(self.file, 'r'); 
            raw = fread(fid, inf); 
            str = char(raw'); 
            fclose(fid); 
            val = jsondecode(str);
            F = fieldnames(val);
            if any(cellfun(@(C)~ismember(C, F), varargin))
                error('All optional inputs must match case and spelling of JSON fields exactly.');
            end
            F = reshape(F, 1, numel(F));
            F = setdiff(F, varargin);
            for iF = 1:numel(F)
               self.addprop(F{iF});
               self.(F{iF}) = val.(F{iF});
            end
            for iV = 1:numel(varargin)
               propVal = val.(varargin{iV});
               switch class(propVal)
                   case 'struct'
                       f = fieldnames(propVal);
                       for iF = 1:numel(f)
                          self.addprop(f{iF});
                          self.(f{iF}) = propVal.(f{iF});
                       end                      
                   otherwise
                       error('Unexpected class: %s', class(propVal));
               end
            end            
        end
    end
end

