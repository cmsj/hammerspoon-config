-- This is a bunch of code to use a Philips Hue Motion Sensor as a trigger for doing work

hueBridge = {}

hueBridge.ip = nil
hueBridge.username = hs.settings.get("hueBridgeUsername") -- This will store the username the Hue bridge gave us
hueBridge.sensorID = hs.settings.get("hueBridgeSensorID")
hueBridge.apiURLBase = nil
hueBridge.apiURLUser = nil
hueBridge.authTimer = nil
hueBridge.pollingTimer = nil
hueBridge.pollingBeginTimer = nil
hueBridge.pollingInterval = 2
hueBridge.defaultHeaders = {}
hueBridge.defaultHeaders["Accept"] = "application/json"
hueBridge.sensorChooser = nil
hueBridge.isGettingIP = false
hueBridge.isGettingUsername = false
hueBridge.isGettingSensors = false
hueBridge.isPollingSensor = false
hueBridge.userCallback = nil

function hueBridge:debug(msg)
    print(string.format("DEBUG: hueMotionSensor: %s", msg))
end

function hueBridge:start()
    if not self.userCallback then
        print("ERROR: No userCallback has been set")
        return self
    end
    self.pollingBeginTimer = hs.timer.waitUntil(function() return self:isReadyForPolling() end, function() self:pollingStart() end, 5)
    return self
end

function hueBridge:stop()
    if self.pollingBeginTimer then
        self.pollingBeginTimer:stop()
    end
    if self.authTimer then
        self.authTimer:stop()
    end
    if self.pollingTimer then
        self.pollingTimer:stop()
    end
    if self.sensorChooser then
        self.sensorChooser:hide()
    end
    return self
end

function hueBridge:updateURLs()
    if (self.ip and not self.apiURLBase) then
        self.apiURLBase = string.format("http://%s/api", self.ip)
    end
    if (self.apiURLBase and self.username and not self.apiURLUser) then
        self.apiURLUser = string.format("%s/%s", self.apiURLBase, self.username)
    end
    return self
end

function hueBridge:isReadyForPolling()
    if not self.ip then
        self:getIP()
        return false
    end
    if not self.username then
        self:getAuth()
        return false
    end
    if not self.sensorID then
        self:getSensor()
        return false
    end
    self:debug("Sensor is ready for polling.")
    return true
end

function hueBridge:getIP()
    if self.isGettingIP then
        return self
    end
    self.isGettingIP = true
    hs.http.asyncGet("https://www.meethue.com/api/nupnp", nil, function(code, body, headers)
        self.isGettingIP = false
--        print(string.format("Debug: getIP() callback, %d, %s, %s", code, body, hs.inspect(headers)))
        -- FIXME: Handle error codes
        if code == 200 then
            rawJSON = hs.json.decode(body)[1]
            self.ip = rawJSON["internalipaddress"]
            self:updateURLs()
            self:debug("Bridge discovered at: "..self.ip)
        end
    end)
    return self
end

function hueBridge:getAuth()
    if self.isGettingUsername then
        return self
    end
    self.isGettingUsername = true
    hs.http.asyncPost(self.apiURLBase, '{"devicetype":"Hammerspoon#hammerspoon hammerspoon"}', self.defaultHeaders, function(code, body, headers)
        self.isGettingUsername = false
--        print(string.format("Debug: getAuth() callback, %d, %s, %s", code, body, hs.inspect(headers)))
        -- FIXME: Handle error codes
        if code == 200 then
            rawJSON = hs.json.decode(body)[1]
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

function hueBridge:getSensor()
    if self.isGettingSensors then
        return self
    end
    self.isGettingSensors = true
    hs.http.asyncGet(string.format("%s/sensors", self.apiURLUser), self.defaultHeaders, function(code, body, headers)
        self.isGettingSensors = false
--        print(string.format("Debug: getSensor() callback, %d, %s, %s", code, body, hs.inspect(headers)))
        -- FIXME: Handle error codes
        if code == 200 then
            rawJSON = hs.json.decode(body)
            sensors = {}
            for id,data in pairs(rawJSON) do
                if (data["type"] and data["type"] == "ZLLPresence") then
                    self:debug(string.format("Found sensor: %d (%s)", id, data["name"]))
                    table.insert(sensors, {id=id,data=data})
                end
            end
            if #sensors == 1 then
                self.sensorID = sensors[1]["id"]
                hs.settings.set("hueBridgeSensorID", self.sensorID)
                self:debug("Found Hue Motion Sensor: "..self.sensorID)
            elseif #sensors > 1 then
                -- FIXME: Implement a chooser here
            else
                -- We found no sensors
                hs.notify.show("Hammerspoon", "Hue Motion Detection", "No compatible sensors found. Terminating")
                self:stop()
            end
        end
    end)
    return self
end

function hueBridge:pollingStart()
    self.pollingTimer = hs.timer.new(2, function() self:doPoll() end)
    self.pollingTimer:start()
end

function hueBridge:doPoll()
    if self.isPollingSensor then
        return self
    end
    self.isPollingSensor = true
    hs.http.asyncGet(string.format("%s/sensors/%s", self.apiURLUser, self.sensorID), self.defaultHeaders, function(code, body, headers)
        self.isPollingSensor = false
--        print(string.format("Debug: doPoll() callback, %d, %s, %s", code, body, hs.inspect(headers)))
        -- FIXME: Handle error codes
        if code == 200 then
            rawJSON = hs.json.decode(body)
            if rawJSON["state"] then
                self.userCallback(rawJSON["state"]["presence"])
            end
        end
    end)
    return self
end

return hueBridge

