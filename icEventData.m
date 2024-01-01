classdef icEventData < event.EventData
    properties
        SelectedUuid
        icFileObject
        fileBrowserDetailModel
        UserData
    end

    methods
        function obj = icEventData(icFileObject)
            obj.icFileObject = icFileObject;
        end
    end
end
