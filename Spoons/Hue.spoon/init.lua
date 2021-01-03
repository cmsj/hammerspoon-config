--- === Hue ===
---
--- Various useful Philips Hue features
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Hue.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Hue.spoon.zip)
---
--- Note: This only currently works with a single Hue bridge

local obj = {}
obj.__index = obj

obj.name = "Hue"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.ip = nil
obj.username = hs.settings.get("hueBridgeUsername") -- This will store the username the Hue bridge gave us
obj.sensorIDs = nil -- Experiment with not saving this: hs.settings.get("hueBridgeSensorIDs")
obj.apiURLBase = nil
obj.apiURLUser = nil
obj.authTimer = nil
obj.pollingTimer = nil
obj.pollingBeginTimer = nil
obj.pollingInterval = 2
obj.defaultHeaders = {}
obj.defaultHeaders["Accept"] = "application/json"
obj.isGettingIP = false
obj.isGettingUsername = false
obj.isGettingSensors = false
obj.isPollingSensors = {}

--- Hue.sensorCallback
--- Variable
--- A user-supplied callback function that will be called when motion is detected on a sensor
---
--- Parameters:
---  * motionDetected - A boolean - true if motion was detected, otherwise false
---  * sensorID - A string containing the ID of the sensor
---
--- Returns:
---  * None
obj.sensorCallback = nil

function obj:debug(msg)
    print(string.format("DEBUG: Hue: %s", msg))
end

function obj:init()
    hs.timer.doUntil(function() return self:isReadyForPolling() end, function() self:isReadyForPolling() end, 2)
end

function obj:start()
    self.pollingBeginTimer = hs.timer.waitUntil(function() return self:isReadyForPolling() end, function() self:pollingStart() end, 5)
    return self
end

function obj:stop()
    print("Stopping Hue polling")
    if self.pollingBeginTimer then
        self.pollingBeginTimer:stop()
    end
    if self.authTimer then
        self.authTimer:stop()
    end
    if self.pollingTimer then
        self.pollingTimer:stop()
    end
    return self
end

function obj:updateURLs()
    if (self.ip and not self.apiURLBase) then
        self.apiURLBase = string.format("http://%s/api", self.ip)
    end
    if (self.apiURLBase and self.username and not self.apiURLUser) then
        self.apiURLUser = string.format("%s/%s", self.apiURLBase, self.username)
    end
    return self
end

function obj:isReadyForPolling()
    if not self.ip then
        self:getIP()
        return false
    end
    if not self.username then
        self:getAuth()
        return false
    end
    if not self.sensorIDs then
        self:getSensors()
        return false
    end
    self:debug("Sensors are ready for polling.")
    return true
end

function obj:getIP()
    if self.isGettingIP then
        return self
    end
    self.isGettingIP = true
    hs.http.asyncGet("https://www.meethue.com/api/nupnp", nil, function(code, body, headers)
        self.isGettingIP = false
--        print(string.format("Debug: getIP() callback, %d, %s, %s", code, body, hs.inspect(headers)))
        -- FIXME: Handle error codes
        if code == 200 then
            local rawJSON = hs.json.decode(body)[1]
            self.ip = rawJSON["internalipaddress"]
            self:updateURLs()
            self:debug("Bridge discovered at: "..self.ip)
        end
    end)
    return self
end

function obj:getAuth()
    if self.isGettingUsername then
        return self
    end
    self.isGettingUsername = true
    hs.http.asyncPost(self.apiURLBase, '{"devicetype":"Hammerspoon#hammerspoon hammerspoon"}', self.defaultHeaders, function(code, body, headers)
        self.isGettingUsername = false
--        print(string.format("Debug: getAuth() callback, %d, %s, %s", code, body, hs.inspect(headers)))
        -- FIXME: Handle error codes
        if code == 200 then
            local rawJSON = hs.json.decode(body)[1]
            if rawJSON["error"] and rawJSON["error"]["type"] == 101 then
                -- FIXME: Don't spam the user, create a notification, track its lifecycle properly
                hs.notify.show("Hammerspoon", "Hue Bridge authentication", "Please press the button on your Hue bridge")
                return
            end
            if rawJSON["success"] ~= nil then
                self.username = rawJSON["success"]["username"]
                hs.settings.set("hueBridgeUsername", self.username)
                self:updateURLs()
                self:debug("Created username: "..self.username)
            end
        end
    end)
    return self
end

function obj:getSensors()
    if self.isGettingSensors then
        return self
    end
    self.isGettingSensors = true
    hs.http.asyncGet(string.format("%s/sensors", self.apiURLUser), self.defaultHeaders, function(code, body, headers)
        self.isGettingSensors = false
--        print(string.format("Debug: getSensors() callback, %d, %s, %s", code, body, hs.inspect(headers)))
        -- FIXME: Handle error codes
        if code == 200 then
            local rawJSON = hs.json.decode(body)
            self.sensorIDs = {}
            for id,data in pairs(rawJSON) do
                if (data["type"] and data["type"] == "ZLLPresence") then
                    self:debug(string.format("Found sensor: %d (%s)", id, data["name"]))
                    table.insert(self.sensorIDs, id)
                end
            end
            if #self.sensorIDs > 0 then
                --hs.settings.set("hueBridgeSensorIDs", self.sensorIDs)
                self:debug("Found Hue Motion Sensors: "..hs.inspect(self.sensorIDs))
            else
                -- We found no sensors
                self:debug("No Hue Motion Sensors found")
            end
        end
    end)
    return self
end

function obj:getBulbs()
    local code, body, headers = hs.http.get(string.format("%s/lights", self.apiURLUser), self.defaultHeaders)
    if code == 200 then
        return hs.json.decode(body)
    end
end

function obj:pollingStart()
    self.pollingTimer = hs.timer.new(2, function() self:doPoll() end)
    self.pollingTimer:start()
    return self
end

function obj:doPoll()
    for _,sensorID in ipairs(self.sensorIDs) do
        if not self.isPollingSensors[sensorID] then
            self.isPollingSensors[sensorID] = true
            hs.http.asyncGet(string.format("%s/sensors/%s", self.apiURLUser, sensorID), self.defaultHeaders, function(code, body, headers)
                self.isPollingSensors[sensorID] = false
--                print(string.format("Debug: doPoll() callback, %d, %s, %s", code, body, hs.inspect(headers)))
                -- FIXME: Handle error codes
                if code == 200 then
                    local rawJSON = hs.json.decode(body)
                    print(hs.inspect(rawJSON))
                    if rawJSON["state"] then
                        self.sensorCallback(rawJSON["state"]["presence"], sensorID)
                    end
                end
            end)
        end
    end
    return self
end

return obj

