classdef JSON < dynamicprops
    %JSON Class to access contents of JSON file.
    %
    % Syntax:
    %   params = JSON('params.json');
    %   disp(params.color);
    %   >> "blue"
    
    properties (Hidden, SetAccess=protected, GetAccess=public)
        file
    end
    
    properties (Access=protected)
        exists = false
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
            if exist(self.file, 'file')==0
                self.write(varargin{:});
            else
                self.exists = true;
                self.read(varargin{:});
            end
            
        end
        
        function set_file(self, name)
           %SET_FILE  Change filename
           %   
           % Syntax:
           %    json_obj.set_file('location/new_file.json');
           %
           % See also: Contents, JSON
           [p, f, e] = fileparts(name);
           if isempty(p)
               p = pwd;
           end
           if isempty(e)
               e = '.json';
           end
           name = fullfile(p, strcat(f, e));
           self.file = name;
           if exist(self.file, 'file')==0
               self.exists = false;
               fid = fopen(self.file, 'w');
               fclose(fid);
               fprintf(1, 'Created new (empty) file: <strong>%s</strong>\n\n', self.file); 
               self.exists = true;
           end               
        end
        
        function read(self, varargin)
            %READ  Read the file data into dynamic property fields.
            if ~self.exists
                if exist(self.file, 'file')==0
                    error('JSON:Missing', 'No such file exists: <strong>%s</strong>\n\n', self.file);
                else
                    error('JSON:BadInit', 'File exists (<strong>%s</strong>), but object was initialized when it did not!\n\n', self.file);
                end
            end
            fid = fopen(self.file, 'r');
            raw = fread(fid, inf);
            str = char(raw');
            fclose(fid);
            val = jsondecode(str);
            F = fieldnames(val);
            if any(cellfun(@(C)~ismember(C, F), varargin))
                error('JSON:BadPropertyName', 'All optional inputs must match case and spelling of JSON fields exactly.');
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
                        error('JSON:UnhandledClassSyntax','Unexpected class: %s', class(propVal));
                end
            end
        end
        
        function write(self, varargin)
            %WRITE  Write data from the dynamic properties into a file.
            %
            % Syntax:
            %   json_obj.write()
            %   json_obj.write('Field1', 'Field2', ...); 
            %
            % If no arguments are supplied, then if this is a new object
            % with no file, a new file is created. If the file already
            % exists, then no argument causes this to dump all dynamic
            % properties parsed from the JSON file or added to this object
            % into the file. 
            %
            % If a list of properties is given then only those properties
            % are updated in the file.
            
            if numel(varargin) > 0
                if any(cellfun(@(C)~ismember(C, properties(self)), varargin))
                    error('JSON:BadPropertyName', 'All requested updates must be properties of JSON object!');
                end
                fid = fopen(self.file, 'r');
                raw = fread(fid, inf);
                str = char(raw');
                fclose(fid);
                val = jsondecode(str);
                F = fieldnames(val);
                if any(cellfun(@(C)~ismember(C, F), varargin))
                    error('JSON:BadPropertyName', 'All optional inputs must match case and spelling of JSON fields exactly.');
                end
                for iV = 1:numel(varargin)
                    idx = ismember(F, varargin{iV}); 
                    val.(F{idx}) = self.(varargin{iV});
                end
                s = jsonencode(val, 'PrettyPrint', true);
                fid = fopen(self.file, 'w');
                fprintf(fid, '%s', s);
                fclose(fid);
                
            elseif ~self.exists
                fid = fopen(self.file, 'w');
                fclose(fid);
                fprintf(1, 'Created new (empty) file: <strong>%s</strong>\n\n', self.file); 
                self.exists = true;
            else % Otherwise no arguments: print everything to the file.
                p = properties(self);
                val = struct;
                for iP = 1:numel(p)
                     val.(p{iP}) = self.(p{iP});
                end
                s = jsonencode(val, 'PrettyPrint', true);
                fid = fopen(self.file, 'w');
                fprintf(fid, '%s', s);
                fclose(fid);
            end
        end
    end
end

