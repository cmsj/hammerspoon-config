--- === Elgato KeyLight ===
---
--- Control Elgato KeyLight devices
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ElgatoKeyLight.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/ElgatoKeyLight.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "ElgatoKeyLight"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- hs.bonjour browser object
obj.bj = nil
obj.keepSearching = false

obj.logger = nil

obj.serviceName = "_elg._tcp."
obj.serviceDomain = "local."

obj.matchNames = {}
obj.foundLights = {}

--- ElgatoKeyLight.infoPollingInterval
--- Variable
--- A number, in seconds, for how often to poll discovered lights for their current state. Defaults to `5`
obj.infoPollingInterval = 5
obj.infoTimer = nil

--- ElgatoKeyLight:init(matchNames[, serviceName, serviceDomain])
--- Method
--- Initialisation
---
--- Parameters:
---  * matchNames - A table of strings to match against the name of the KeyLight devices to control
---  * serviceName - An optional string containing the Bonjour service name to use, defaults to `_elg._tcp.`
---  * serviceDomain - An optional string containing the Bonjour service domain to use, defaults to `local.`
---
--- Returns:
---  * None
function obj:init(matchNames, serviceName, serviceDomain)
    self.matchNames = matchNames
    if serviceName then self.serviceName = serviceName end
    if serviceDomain then self.serviceDomain = serviceDomain end

    self.logger = hs.logger.new("ElgatoKeyLight", "debug")
    self.bj = hs.bonjour.new()
end

--- ElgatoKeyLight:start([keepSearching])
--- Method
--- Start discovery of KeyLight devices
---
--- Parameters:
---  * keepSearching - An optional boolean, if `true` then the discovery process will continue after the first set of devices is found. Defaults to `false`
---
--- Returns:
---  * None
---
--- Notes:
---  * If `keepSearching` is `true` then the `ElgatoKeyLight:stop()` method can be used to stop the search process
---  * It is recommended to only use `keepSearching` if you are expecting to add new KeyLight devices to the network, you change network frequently, or some other reason why you expect the set of KeyLight devices to change
function obj:start(keepSearching)
    if (type(keepSearching) == "boolean") then
        self.keepSearching = keepSearching
    end
    self.bj:findServices(self.serviceName, self.serviceDomain, self._serviceFound)

    if (self.infoTimer) then self.infoTimer:stop() end
    self.infoTimer = hs.timer.doEvery(self.infoPollingInterval, function()
        for name, info in pairs(obj.foundLights) do
            self._updateLightInfo(name)
        end
    end)
end

--- ElgatoKeyLight:stop()
--- Method
--- Stop discovery of KeyLight devices
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:stop()
    self.logger.df("Stopping discovery and info polling")
    self.bj:stop()
    self.infoTimer:stop()
end

--- ElgatoKeyLight:devices()
--- Method
--- Return a table of KeyLight devices found
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of KeyLight devices, each entry is a table containing the the same keys as [ElgatoKeyLight:device](#device)
function obj:devices()
    return self.foundLights
end

--- ElgatoKeyLight:device(name)
--- Method
--- Return a previously discovered KeyLight device by name
---
--- Parameters:
---  * name - The name of the device to return
---
--- Returns:
---  * A table containing the following keys, or `nil` if the device was not found:
---    * addresses - A table of IP addresses for the device
---    * port - The port the device is listening on
---    * displayName - The display name of the device
---    * productName - The product name of the device
---    * firmwareVersion - The firmware version of the device
---    * firmwareBuildNumber - The firmware build number of the device
---    * serialNumber - The serial number of the device
---    * hardwareBoardType - The hardware board type of the device
---    * settings - A table containing the device's settings. Its keys are:
---      * colorChangeDurationMs - A number containing the duration, in milliseconds, of a color change
---      * powerOnBehavior - A boolean, 1 to power up with previous settings, 0 to power up with default settings
---      * powerOnBrightness - A number between 0 and 100, as the brightness to power up with
---      * powerOnTemperature - A number between 143 and 344, as the color temperature to power up with
---      * switchOffDurationMs - A number containing the duration, in milliseconds, of a power off
---      * switchOnDurationMs - A number containing the duration, in milliseconds, of a power on
function obj:device(name)
    return self.foundLights[name]
end

--- ElgatoKeyLight:turnOn(name)
--- Method
--- Turn on a KeyLight device
---
--- Parameters:
---  * name - The name of the device to turn on
---
--- Returns:
---  * None
function obj:turnOn(name)
    local url = self._urlForDevice(name) .. "elgato/lights"
    self.logger.df("Turning on device: %s (%s)", name, url)
    local data = { ["numberOfLights"] = 1, ["lights"] = {{ ["on"] = 1 }}}

    hs.http.asyncPut(url, hs.json.encode(data), nil, function(response, body, headers)
        obj.logger.df("turnOn response: %s, '%s'", response, body)
        obj._updateLightInfo(name, response, body, headers)
    end)
end

--- ElgatoKeyLight:turnOff(name)
--- Method
--- Turn off a KeyLight device
---
--- Parameters:
---  * name - The name of the device to turn off
---
--- Returns:
---  * None
function obj:turnOff(name)
    local url = self._urlForDevice(name) .. "elgato/lights"
    self.logger.df("Turning off device: %s (%s)", name, url)
    local data = { ["numberOfLights"] = 1, ["lights"] = {{ ["on"] = 0 }}}

    hs.http.asyncPut(url, hs.json.encode(data), nil, function(response, body, headers)
        obj.logger.df("turnOff response: %s, '%s'", response, body)
        obj._updateLightInfo(name, response, body, headers)
    end)
end

--- ElgatoKeyLight:setBrightness(name, brightness)
--- Method
--- Set the brightness of a KeyLight device
---
--- Parameters:
---  * name - The name of the device to set the brightness of
---  * brightness - A number between 0 and 100, as the brightness to set
---
--- Returns:
---  * None
function obj:setBrightness(name, brightness)
    local url = self._urlForDevice(name) .. "elgato/lights"
    self.logger.df("Setting brightness for device: %s to %s (%s)", name, brightness, url)
    local data = { ["numberOfLights"] = 1, ["lights"] = {{ ["brightness"] = brightness }}}

    hs.http.asyncPut(url, hs.json.encode(data), nil, function(response, body, headers)
        obj.logger.df("setBrightness response: %s, '%s'", response, body)
        obj._updateLightInfo(name, response, body, headers)
    end)
end

--- ElgatoKeyLight:setTemperature(name, temperature)
--- Method
--- Set the color temperature of a KeyLight device
---
--- Parameters:
---  * name - The name of the device to set the brightness of
---  * temperature - A number between 143 and 344, as the temperature to set, in [Mireds](https://en.wikipedia.org/wiki/Mired)
---
--- Returns:
---  * None
function obj:setTemperature(name, temperature)
    local url = self._urlForDevice(name) .. "elgato/lights"
    self.logger.df("Setting temperature for device: %s to %s (%s)", name, temperature, url)
    local data = { ["numberOfLights"] = 1, ["lights"] = {{ ["temperature"] = temperature }}}

    hs.http.asyncPut(url, hs.json.encode(data), nil, function(response, body, headers)
        obj.logger.df("setTemperature response: %s, '%s'", response, body)
        obj._updateLightInfo(name, response, body, headers)
    end)
end

--- ElgatoKeyLight:updateSetting(name, settingName, newValue)
--- Method
--- Update a setting on a KeyLight device
---
--- Parameters:
---  * name - The name of the device to update the setting on
---  * settingName - The name of the setting to update
---  * newValue - The new value for the setting
---
--- Returns:
---  * None
function obj:updateSetting(name, settingName, newValue)
    local url = self._urlForDevice(name) .. "elgato/lights/settings"
    self.logger.df("Setting setting: %s for device: %s to %s (%s)", settingName, name, newValue, url)
    self.foundLights[name].settings[settingName] = newValue

    print(hs.json.encode(self.foundLights[name].settings))
    hs.http.asyncPut(url, hs.json.encode(self.foundLights[name].settings), nil, function(response, body, headers)
        obj.logger.df("updateSetting response: %s, '%s'", response, body)
        obj._updateLightSettings(name)
    end)
end

--- ElgatoKeyLight:identify(name)
--- Method
--- Identify a KeyLight device by making it flash
---
--- Parameters:
---  * name - The name of the device to identify
---
--- Returns:
---  * None
function obj:identify(name)
    local url = self._urlForDevice(name) .. "elgato/identify"
    self.logger.df("Identifying device: %s (%s)", name, url)

    hs.http.asyncPost(url, nil, nil, function() end)
end

-- Private Methods
function obj._serviceFound(browserObject, domain, isAdvertised, serviceObject, moreExpected)
    obj.logger.df("Found service: %s, isAdvertised: %s, moreExpected: %s, serviceObject:%s", domain, tostring(isAdvertised), tostring(moreExpected), serviceObject:name())
    if (isAdvertised) then
        serviceObject:resolve(0, obj._serviceResolved)
    else
        obj.foundLights[serviceObject:name()] = nil
    end
    if (moreExpected == false and obj.keepSearching == false) then
        obj.bj:stop()
    end
end

function obj._serviceResolved(serviceObject, message)
    local name = serviceObject:name()
    obj.logger.df("Resolved service: %s, message: %s", name, message)

    if (message == "resolved") then
        obj.logger.f("Discovered device: %s, addresses: %s", name, hs.inspect(serviceObject:addresses()))
        obj.foundLights[name] = {}
        obj.foundLights[name]["addresses"] = serviceObject:addresses()
        obj.foundLights[name]["port"] = serviceObject:port()

        obj._updateAccessoryInfo(name)
        obj._updateLightInfo(name)
        obj._updateLightSettings(name)
    end
end

function obj._urlForDevice(name)
    local url = string.format("http://%s:%s/", obj.foundLights[name]["addresses"][1], obj.foundLights[name]["port"])
    return url
end

function obj._updateAccessoryInfo(name)
    obj.logger.df("Updating accessory info for device: %s", name)
    local url = obj._urlForDevice(name) .. "elgato/accessory-info"
    hs.http.asyncGet(url, nil, function(response, body, headers) obj._accessoryInfoCallback(name, response, body, headers) end)
end

function obj._accessoryInfoCallback(name, response, body, headers)
    obj.logger.df("Fetched accessory-info: %s, %s", response, body)
    if (response ~= 200) then
        obj.logger.ef("Failed to fetch accessory-info for device: %s", name)
        return
    end
    local info = hs.json.decode(body)
    obj.foundLights[name]["displayName"] = info["displayName"]
    obj.foundLights[name]["productName"] = info["productName"]
    obj.foundLights[name]["firmwareVersion"] = info["firmwareVersion"]
    obj.foundLights[name]["firmwareBuildNumber"] = info["firmwareBuildNumber"]
    obj.foundLights[name]["serialNumber"] = info["serialNumber"]
    obj.foundLights[name]["hardwareBoardType"] = info["hardwareBoardType"]
end

function obj._updateLightInfo(name)
    obj.logger.df("Updating light info for device: %s", name)
    local url = obj._urlForDevice(name) .. "elgato/lights"
    hs.http.asyncGet(url, nil, function(response, body, headers) obj._lightInfoCallback(name, response, body, headers) end)
end

function obj._lightInfoCallback(name, response, body, headers)
    obj.logger.df("Fetched device info: %s, %s", response, body)
    if (response ~= 200) then
        obj.logger.ef("Failed to fetch state for device: %s", name)

        -- Since we've failed somehow, remove the device from the list and try discovery again
        obj.foundLights[name] = nil
        obj.bj:stop()
        obj:start()
        return
    end
    local info = hs.json.decode(body)["lights"][1]
    obj.foundLights[name]["on"] = info["on"]
    obj.foundLights[name]["brightness"] = info["brightness"]
    obj.foundLights[name]["temperature"] = info["temperature"]
end

function obj._updateLightSettings(name)
    obj.logger.df("Updating light settings for device: %s", name)
    local url = obj._urlForDevice(name) .. "elgato/lights/settings"
    hs.http.asyncGet(url, nil, function(response, body, headers) obj._lightSettingsCallback(name, response, body, headers) end)
end

function obj._lightSettingsCallback(name, response, body, headers)
    obj.logger.df("Fetched device settings: %s, %s", response, body)
    if (response ~= 200) then
        obj.logger.ef("Failed to fetch settings for device: %s", name)

        -- Since we've failed somehow, remove the device from the list and try discovery again
        obj.foundLights[name] = nil
        obj.bj:stop()
        obj:start()
        return
    end
    local info = hs.json.decode(body)
    obj.foundLights[name]["settings"] = info
end

return obj