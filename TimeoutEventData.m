classdef (ConstructOnLoad) TimeoutEventData < event.EventData
    %TIMEOUTEVENTDATA  Issued as part of a timer callback event.
    
    properties
        state   string        % Which state in the io.TaskMachine object are we at?
    end
    
    methods
        function evt = TimeoutEventData(state)
            %TIMEOUTEVENTDATA  Constructor for event data.
            evt.state = state;
        end
    end
end