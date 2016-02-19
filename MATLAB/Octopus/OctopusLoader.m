% Easy class definition for the OctopusLoader - massively simplifies
% dealing with data streams
% ARL 2016/02/19

classdef OctopusLoader
    properties
        OInfo
        initialised = 0;
    end
    methods
        % class instantiation
        function obj = OctopusLoader(pth, file_stem)
            if nargin == 2 && ischar(pth) && ischar(file_stem)
                obj.OInfo = Octopus_stack_info(pth, file_stem);
                obj.initialised = 1;
            else
                error('OctopusLoader: file path and stem must be supplied');
            end
        end
        
        % methods to get frames
        function varargout = get_frame(obj, frame_number)
            if true(obj.initialised)
                [frame, header] = Octopus_get_frame(obj.OInfo, frame_number);
                varargout{1} = frame;
                if nargout == 2
                    varargout{2} = header;
                end 
            else
                error('OctopusLoader: data stream not loaded');
            end
        end
                
    end
end