print("Loading officeMotion")

local obj = {}
obj.__index = obj

obj.timer = nil
obj.id = nil
obj.watcher = require("hueMotionSensor")
obj.watcher.userCallback = function(presence)
    day = tonumber(os.date("%w"))
    if day < 1 or day > 5 then
        print("Ignoring motion, it's the weekend")
        return
    end
    hour = tonumber(os.date("%H"))
    if hour > 18 or hour < 9 then
        print("Ignoring motion, it's not working hours")
        return
    end
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
    if self.timer then
        self.timer:stop()
    end
    self.timer = hs.timer.doAfter(30, function()
        print("Starting officeMotion watcher")
        self.watcher:start()
    end)
    return self
end

function obj:stop()
    print("Stopping officeMotion watcher")
    self.timer:stop()
    self.timer = nil
    self.watcher:stop()
    return self
end

return obj

