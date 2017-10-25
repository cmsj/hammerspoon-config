--- === StreamDeckMicMuter ===
---
--- Sets up a button on an Elgato Stream Deck to mute/unmute all mics
---
--- Notes:
---  * This Spoon uses hs.audiodevice.watcherCallback which means it will conflict with any other Spoons that also use that callback, or your init.lua if you use it there. If this is a problem, please file a bug
local obj = {}
obj.__index = obj

-- Metadata
obj.name = "StreamDeckMicMuter"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.deck = nil
obj.button = nil
obj.imgMuted = nil
obj.imgUnmuted = nil
obj.isMuted = nil
obj.audiodeviceWatcher = nil

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

function obj.setAllDeviceState(state)
    hs.fnutils.each(hs.audiodevice.allInputDevices(), function(device) device:setInputMuted(state) end)
end

function obj.audiodeviceDeviceCallback(watcher, path, key, old, new)
    if new == "dev#" then
        print("Audio devices changed, setting all inputs to: "..(obj.isMuted and "muted" or "unmuted"))
        obj.setAllDeviceState(obj.isMuted)
        watcher:change("event", "") -- Clear the event so we receive this notification again next time
    end
end

function obj.deckButtonCallback(deck, button, isDown)
    if (button == obj.button and isDown == false) then
        obj.setState(not obj.isMuted)
    end
end

function obj:init()
    self.imgMuted = hs.image.imageFromPath(self.spoonPath.."/micMuted.png")
    self.imgUnmuted = hs.image.imageFromPath(self.spoonPath.."/mic.png")
end

--- StreamDeckMicMuter:start(deck, button)
--- Method
--- Starts StreamDeckMicMuter
---
--- Parameters:
---  * deck - An hs.streamdeck object
---  * button - A number from 1 to 15 representing the button to use
---  * state - An optional boolean, true to start muted, false to start unmuted (Defaults to true)
---
--- Returns:
---  * The StreamDeckMicMuter object
---
--- Notes:
---  * This Spoon relies on hs.audiodevice.watcher to track any changes in audiodevices attached to the system, however, only one callback can be attached to hs.audiodevice.watcher, so rather than try and claim exclusive use of it, we expect you to create an hs.watchable proxy in your init.lua, like this:
---   ```lua
---   audiodeviceWatchable = hs.watchable.new("audiodevice")
---   function audiodeviceDeviceCallback(event)
---     audiodeviceWatchable["event"] = event
---   end
---   hs.audiodevice.watcher.setCallback(audiodeviceDeviceCallback)
---   hs.audiodevice.watcher.start()
---   ```
function obj:start(deck, button, state)
    self.deck = deck
    self.button = button

    self.audiodeviceWatcher = hs.watchable.watch("audiodevice", "event", self.audiodeviceDeviceCallback)

    self.isMuted = true
    if type(state) == "boolean" then
        self.isMuted = state
    end
    self.setAllDeviceState(self.isMuted)

    self:render()

    return self
end

--- StreamDeckMicMuter:stop()
--- Method
--- Stops StreamDeckMicMuter
---
--- Parameters:
---  * None
---
--- Returns:
---  * The StreamDeckMicMuter object
function obj:stop()
    self.audiodeviceWatcher.release()
    return self
end

--- StreamDeckMicMuter:setMute(shouldMute)
--- Method
--- Sets the mute/unmute state
---
--- Parameters:
---  * shouldMute - A boolean, true to set mute state, false to unmute
---
--- Returns:
---  * The StreamDeckMicMuter object
function obj:setMute(shouldMute)
    self.isMuted = shouldMute
    self.setAllDeviceState(self.isMuted)
    self:render()
    return self
end

--- StreamDeckMicMuter:toggleMute()
--- Method
--- Toggles the current mute state
---
--- Parameters:
---  * None
---
--- Returns:
---  * The StreamDeckMicMuter object
function obj:toggleMute()
    self:setMute(not self.isMuted)
end

function obj:render()
    if self.isMuted then
        self.deck:setButtonImage(self.button, self.imgMuted)
    else
        self.deck:setButtonImage(self.button, self.imgUnmuted)
    end
    return self
end

return obj
