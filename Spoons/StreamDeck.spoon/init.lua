--- === Stream Deck ===
---
--- Control your Elgato Stream Deck
---
--- Note: This Spoon assumes it has complete control of all connected Decks - if you have other software that is also controlling them, you may see unexpected behaviour.
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/StreamDeck.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/StreamDeck.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "StreamDeck"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.logger = hs.logger.new("StreamDeck.spoon", "debug")
obj.decks = {}

--- StreamDeck:init(config)
--- Method
--- Initialise a StreamDeck Spoon
---
--- Parameters:
---  * config - A table containing the configuration for one or more Stream Deck devices. Table keys should be the serial numbers of the devices, and the values should be tables containing information for each button of that device.
---
--- Returns:
---  * None
---
--- Notes:
---  * Each configured deck's table should have button numbers as the keys, with the value being a table containing the following keys:
---   * image - An hs.image object to display on the button
---   * callback - A function to call when the button is pressed. The function should accept three arguments:
---    * deck - The hs.streamdeck object that was pressed
---    * button - The button number that was pressed
---    * isDown - A boolean indicating whether the button was pressed or released
---
--- Example:
--- ```
--- {
---     ["12345678"] = {
---         [1] = {
---             image = hs.image.imageFromPath("/path/to/image.png"),
---             callback = function(deck, button, isDown)
---                 print("Button "..button.." was pressed: "..tostring(isDown))
---             end
---         },
---         [2] = {
---             image = hs.image.imageFromPath("/path/to/another/image.png"),
---             callback = function(deck, button, isDown)
---                 print("Button "..button.." was pressed: "..tostring(isDown))
---             end
---         }
---     }
--- }
--- ```
function obj:init(config)
    self.deckConfig = config
end

function obj:start()
    hs.streamdeck.init(function(isConnect, deck)
        self:deckConnectCallback(isConnect, deck)
    end)
end

function obj:stop()
    for _, deck in ipairs(self.decks) do
        self.logger.df("Stopping deck: "..deck:serialNumber())
        deck:buttonCallback(nil)
    end
    self.logger.df("Stopping discovery")
    hs.streamdeck.discoveryCallback(nil)
end

function obj:deckConnectCallback(isConnect, deck)
    if isConnect then
        local serialNumber = deck:serialNumber()
        self.logger.f("Stream Deck connected: "..serialNumber)
        deck:reset()
        deck:buttonCallback(function(deckObj, button, isDown)
            self.logger.f("(outer) Button "..button.." on deck "..deckObj:serialNumber().." was pressed: "..tostring(isDown))
            self:deckButtonCallback(deckObj, button, isDown)
        end)
        self.decks[serialNumber] = deck

        if self.deckConfig[serialNumber] then
            self.logger.f("Setting up deck: "..serialNumber)
            self:setupDeck(serialNumber)
        end
    else
        self.logger.f("Stream Deck disconnected: "..deck:serialNumber())
        self.decks[deck:serialNumber()] = nil
    end
end

function obj:deckButtonCallback(deck, button, isDown)
    self.logger.f("(inner) Button "..button.." on deck "..deck:serialNumber().." was pressed: "..tostring(isDown))
    local deckConfig = self.deckConfig[deck:serialNumber()]
    if deckConfig == nil then
        self.logger.f("No configuration for deck: "..deck:serialNumber())
        return
    end

    local buttonConfig = deckConfig[button]
    if buttonConfig == nil then
        self.logger.f("No configuration for button: "..button.." on deck: "..deck:serialNumber())
        return
    end

    if buttonConfig.callback == nil or type(buttonConfig.callback) ~= "function" then
        self.logger.f("No callback (or value is not a function) for button: "..button.." on deck: "..deck:serialNumber())
        return
    end

    buttonConfig.callback(deck, button, isDown)
end

function obj:getDeck(serialNumber)
    return self.decks[serialNumber]
end

function obj:setupDeck(serialNumber)
    local deck = self:getDeck(serialNumber)
    local deckConfig = self.deckConfig[serialNumber]
    for button, buttonConfig in pairs(deckConfig) do
        deck:setButtonImage(button, buttonConfig.image)
    end
end

return obj