print("Loading officeMotion")

local obj = {}
obj.__index = obj

obj.timer = nil
obj.id = nil
obj.watcher = require("hueMotionSensor")
obj.watcher.userCallback = function(presence)
    if presence then
        print("Motion detected, declaring user activity")
        obj.id = hs.caffeinate.declareUserActivity(obj.id)
    end
end

function obj:init()
    self.watcher:init()
    return self
end

function obj:start()
    self.timer = hs.timer.doAfter(30, function()
        print("Starting officeMotion watcher")
        self.watcher:start()
    end)
    return self
end

function obj:stop()
    print("Stopping officeMotion watcher")
    self.timer:stop()
    self.watcher:stop()
    return self
end

return obj

