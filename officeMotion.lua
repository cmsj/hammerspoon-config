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

function obj:start()
    self.timer = hs.timer.doAfter(10, function()
        print("Starting officeMotion watcher")
        self.id:start()
    end)
end

function obj:stop()
    print("Stopping officeMotion watcher")
    self.id:stop()
end

function obj:callback()

return obj
