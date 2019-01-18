--- === StreamDeckAudioDeviceCycle ===
---
--- Sets up a button on an Elgato Stream Deck to cycle audio devices
---
--- Notes:
---  * This Spoon requires an hs.watchable to be running on hs.audiodevice.watcher.setCallback():
---   ```lua
---   audiodevicewatchable = hs.watchable.new("audiodevice", true)
---   function audiodeviceDeviceCallback(event)
---     audiodeviceWatchable["event"] = event
---   end
---   hs.audiodevice.watcher.setCallback(audiodeviceDeviceCallback)
---   hs.audiodevice.watcher.start()
---  ```
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "StreamDeckAudioDeviceCycle"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.deck = nil
obj.button = nil

--- StreamDeckAudioDeviceCycle.devices
--- Variable
--- This is a list of devices you want to be able to cycle through, in the form:
---  ```lua
---  {
---    {name="USB audio CODEC", image="headphones.png"},
---    {name="Audioengine 2+  ", image="speakers.png"},
---    {name="bosies", image="bluetooth.png"},
---  }
obj.devices = {}
obj.imageCache = {}
obj.audiodeviceWatcher = nil

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

function obj.setOutputDevice(name)
    local device = hs.audiodevice.findOutputByName(name)
    if device then
        device:setDefaultOutputDevice()
    end
end

function obj.setDeviceImage(name)
    local image = obj.imageCache[name]
    if image then
        obj.deck:setButtonImage(obj.button, image)
    end
end

function obj.audiodeviceDeviceCallback(watcher, path, key, old, new)
    print("audiodevice callback: path:"..path.." key:"..key.." old:"..(old or "nil").." new:"..new)
    if new == "dOut" then
        print("Default output device changed, updating Stream Deck")
        obj:render()
        watcher:change("event", "") -- Clear the event so we receive this notification again next time
    end
end

function obj:init()
end

--- StreamDeckAudioDeviceCycle:start(deck, button)
--- Method
--- Starts StreamDeckAudioDeviceCycle
---
--- Parameters:
---  * deck - An hs.streamdeck object
---  * button - A number from 1 to 15 representing the button to use
---
--- Returns:
---  * The StreamDeckAudioDeviceCycle object
function obj:start(deck, button, state)
    self.deck = deck
    self.button = button

    for name,imagePath in pairs(self.devices) do
        self.imageCache[name] = hs.image.imageFromPath(self.spoonPath..imagePath)
    end

    self.audiodeviceWatcher = hs.watchable.watch("audiodevice", "event", self.audiodeviceDeviceCallback)

    self:render()

    return self
end

--- StreamDeckAudioDeviceCycle:stop()
--- Method
--- Stops StreamDeckAudioDeviceCycle
---
--- Parameters:
---  * None
---
--- Returns:
---  * The StreamDeckAudioDeviceCycle object
function obj:stop()
    self.audiodeviceWatcher:release()
    return self
end

function obj:render()
    self.setDeviceImage(hs.audiodevice.defaultOutputDevice():name())
    return self
end

--- StreamDeckAudioDeviceCycle:cycle()
--- Method
--- Cycle to the next audio device in `devices`
---
--- Parameters:
---  * None
---
--- Returns:
---  * The StreamDeckAudioDeviceCycle object
function obj:cycle()
    print("Going to the next device TODO")
end

return obj

