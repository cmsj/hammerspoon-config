--- === PhilipsHue ===
---
--- Interact with and control, various features of Hue hardware
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spons/PhilipsHue.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spons/PhilipsHue.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "PhilipsHue"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("PhilipsHue", 'debug')

local bridge = {}
obj.bridge = bridge

bridge.ip = nil
bridge.username = hs.settings.get("hueBridgeUsername")
bridge.apiURLBase = nil
bridge.apiURLUser = nil
bridge.authTimer = nil
bridge.pollingTimer = nil
bridge.pollingBeginTimer = nil
bridge.pollingInterval = 2
bridge.defaultHeaders = {}
bridge.defaultHeaders["Accept"] = "application/json"
bridge.isDiscoveringBridgeIP = false
bridge.isGettingUsername = false
bridge.isGettingSensors = false
bridge.isGettingLights = false
bridge.isPollingSensor = false
bridge.isPollingLights = false
bridge.isFinishedPollingSensor = false
bridge.pollRequests = {}
bridge.sensors = {}
bridge.sensorCallbacks = {}
bridge.lightCallbacks = {}

function obj:init()
  self:doDiscovery()
  return self
end

function obj:start()
    self.pollingBeginTimer = hs.timer.waitUntil(function() return self:doDiscovery() end, function()
        -- Discovery has completed, begin our polling run if we have things to poll
        if #self.bridge.sensors == 0 then
            self.logger.d("Not starting polling, zero sensors discovered")
            return self
        end
        self.pollingTimer = hs.timer.new(2, function() self:doPoll() end):start()
        return self
    end, 5)
    return self
end

function obj:stop()
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

function obj:doDiscovery()
    if not self.bridge.ip then
        self:discoverIP()
        return false
    end
    if not self.bridge.username then
        self:getAuth()
        return false
    end
    if not self.bridge.isFinishedPollingSensor then
        self:discoverSensor()
        return false
    end
    self.logger.d("Discovery complete")
    return true
end

function obj:discoverIP()
    if self.bridge.isDiscoveringBridgeIP then
        -- We're being called from a polling loop, but we're already waiting for our async request to complete
        return self
    end

    self.bridge.isDiscoveringBridgeIP = true
    hs.http.asyncGet("https://www.meethue.com/api/nupnp", nil, function(code, body, headers)
        self.bridge.isDiscoveringBridgeIP = false
        self.logger.df("discoverIP() callback: %d, %s, %s", code, body, hs.inspect(headers))
        if code == 200 then
            local rawJSON = hs.json.decode(body)[1]
            self.bridge.ip = rawJSON["internalipaddress"]
            self:updateURLs()
            self.logger.d("discoverIP(): Bridge discovered at: "..self.bridge.ip)
        end
    end)
    return self
end

function obj:getAuth()
    if self.bridge.isGettingUsername then
      -- We're being called from a polling loop, but we're already waiting for our async request to complete
      return self
    end

    self.bridge.isGettingUsername = true
    hs.http.asyncPost(self.apiURLBase, '{"devicetype":"Hammerspoon#hammerspoon hammerspoon"}', self.defaultHeaders, function(code, body, headers)
        self.bridge.isGettingUsername = false
        self.logger.df("getAuth() callback: %d, %s, %s", code, body, hs.inspect(headers))
        if code == 200 then
            local rawJSON = hs.json.decode(body)[1]
            if rawJSON["error"] and rawJSON["error"]["type"] == 101 then
                self.logger.e("Please press the button on your Hue bridge within 30 seconds")
                return
            end
            if rawJSON["success"] ~= nil then
                self.bridge.username = rawJSON["success"]["username"]
                hs.settings.set("hueBridgeUsername", self.bridge.username)
                self:updateURLs()
                self.logger.d("Created username: "..self.bridge.username)
            end
        end
    end)
    return self
end

function obj:updateURLs()
    if (self.bridge.ip and not self.bridge.apiURLBase) then
        self.bridge.apiURLBase = string.format("http://%s/api", self.bridge.ip)
    end
    if (self.bridge.apiURLBase and self.bridge.username and not self.bridge.apiURLUser) then
        self.bridge.apiURLUser = string.format("%s/%s", self.bridge.apiURLBase, self.bridge.username)
    end
    return self
end

function obj:discoverSensor()
    if self.bridge.isGettingSensors then
        -- We're being called from a polling loop, but we're already waiting for our async request to complete
        return self
    end

    self.bridge.isGettingSensors = true
    hs.http.asyncGet(string.format("%s/sensors", self.bridge.apiURLUser), self.bridge.defaultHeaders, function(code, body, headers) 
        self.bridge.isGettingSensors = false
        --self.logger.df("discoverSensor() callback: %d, %s, %s", code, body, hs.inspect(headers))
        if code == 200 then
            local rawJSON = hs.json.decode(body)
            self.logger.df("discoverSensor(): %s", hs.inspect(rawJSON))
            for id, data in pairs(rawJSON) do
                self.logger.df("Found sensor: %d (%s) (%s)", id, data["name"], data["uniqueid"])
                table.insert(self.bridge.sensors, {id=id, data=data})
            end
            self.bridge.isFinishedPollingSensor = true
        end
    end)
    return self
end

function obj:doPoll()
    if self.bridge.isPollingSensor then
      -- We're being called from a polling loop, but we're already waiting for an async request to complete
      return self
    end

    -- Check to see if we have any queued requests, if not, queue them all
    if #self.bridge.pollRequests == 0 then
        for _,sensor in pairs(self.bridge.sensors) do
            table.insert(self.bridge.pollRequests, {id=sensor["id"], uniqueid=sensor["uniqueID"], url=string.format("%s/sensors/%s", self.bridge.apiURLUser, sensor["id"]), fn=function(code, body, headers)
                self.bridge.isPollingSensor = false
                local sensorUniqueID = self.bridge.pollRequests[1]["uniqueid"]
                table.remove(self.bridge.pollRequests, 1)
                if code == 200 then
                    local rawJSON = hs.json.decode(body)
                    self.logger.df("doPoll() callback: %s\n%s", sensorUniqueID, hs.inspect(rawJSON))
                    if rawJSON["state"] == nil then
                        return
                    end
                    if rawJSON["state"] then
                        for _,sensorCallback in pairs(self.bridge.sensorCallbacks) do
                            if sensorCallback["id"] == sensorUniqueID then
                                -- The sensor generating information has a callback
                                sensorCallback["fn"](sensorUniqueID, rawJSON)
                            end
                        end
                    end
                end
            end})
        end
    end

    -- Submit the next request in the queue
    if #self.bridge.pollRequests > 0 then
        local request = self.bridge.pollRequests[1]
        self.bridge.isPollingSensor = true
        self.logger.df("doPoll(): Polling: %s", request["uniqueid"])
        hs.http.asyncGet(request["url"], self.bridge.defaultHeaders, request["fn"])
    end

    return self
end

return obj