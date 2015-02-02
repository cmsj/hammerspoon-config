-- Ensure the IPC command line client is available
hs.ipc.cliInstall()

-- Things we need to clean up at reload
local configFileWatcher = nil
local appWatcher = nil
local wifiWatcher = nil
local screenWatcher = nil

-- Define some keyboard modifier variables
-- (Node: Capslock bound to cmd+alt+ctrl+shift via Seil and Karabiner)
local alt = {"⌥"}
local hyper = {"⌘", "⌥", "⌃", "⇧"}

-- Define monitor names for layout purposes
local display_laptop = "Color LCD"
local display_monitor = "Thunderbolt Display"

-- Define audio device names for headphone/speaker switching
local headphoneDevice = "USB PnP Sound Device"
local speakerDevice = "Audioengine 2+"

-- Define default brightness for MiLight extension
local brightness = 13
local officeLED = hs.milight.new("10.0.88.255")

-- Defines for WiFi watcher
local homeSSID = "chrul" -- My home WiFi SSID
local lastSSID = hs.wifi.currentNetwork()

-- Defines for screen watcher
local lastNumberOfScreens = #hs.screen.allScreens()

-- Define window layouts
--   Format reminder:
--     {"App name", "Window name", "Display Name", "unitrect", "framerect", "fullframerect"},
local internal_display = {
    {"IRC",               nil,          display_laptop, hs.layout.maximized, nil, nil},
    {"Reeder",            nil,          display_laptop, hs.layout.left30,    nil, nil},
    {"Safari",            nil,          display_laptop, hs.layout.maximized, nil, nil},
    {"OmniFocus",         nil,          display_laptop, hs.layout.maximized, nil, nil},
    {"Mail",              nil,          display_laptop, hs.layout.maximized, nil, nil},
    {"Microsoft Outlook", nil,          display_laptop, hs.layout.maximized, nil, nil},
    {"HipChat",           nil,          display_laptop, hs.layout.maximized, nil, nil},
    {"1Password",         nil,          display_laptop, hs.layout.maximized, nil, nil},
    {"Calendar",          nil,          display_laptop, hs.layout.maximized, nil, nil},
    {"Messages",          nil,          display_laptop, hs.layout.maximized, nil, nil},
    {"Evernote",          nil,          display_laptop, hs.layout.maximized, nil, nil},
    {"iTunes",            "iTunes",     display_laptop, hs.layout.maximized, nil, nil},
    {"iTunes",            "MiniPlayer", display_laptop, nil,       nil, hs.geometry.rect(0, -48, 400, 48)},
}

local dual_display = {
    {"IRC",               nil,          display_laptop,  hs.layout.maximized, nil, nil},
    {"Reeder",            nil,          display_monitor, hs.layout.right50,   nil, nil},
    {"Safari",            nil,          display_monitor, hs.layout.left50,    nil, nil},
    {"OmniFocus",         nil,          display_monitor, hs.layout.right50,   nil, nil},
    {"Mail",              nil,          display_laptop,  hs.layout.maximized, nil, nil},
    {"Microsoft Outlook", nil,          display_monitor, hs.layout.maximized, nil, nil},
    {"HipChat",           nil,          display_monitor, hs.layout.right50,   nil, nil},
    {"1Password",         nil,          display_monitor, hs.layout.right50,   nil, nil},
    {"Calendar",          nil,          display_monitor, hs.layout.maximized, nil, nil},
    {"Messages",          nil,          display_laptop,  hs.layout.maximized, nil, nil},
    {"Evernote",          nil,          display_monitor, hs.layout.right50,   nil, nil},
    {"iTunes",            "iTunes",     display_laptop,  hs.layout.maximized, nil, nil},
    {"iTunes",            "MiniPlayer", display_laptop,  nil,       nil, hs.geometry.rect(0, -48, 400, 48)},
}

-- Helper functions

-- NOTE: If you reload your config on a hotkey or a pathwatcher, you should call caffeine:delete() there
local caffeine = hs.menubar.new()
function setCaffeineDisplay(state)
    local result
    if state then
        result = caffeine:setIcon("caffeine-on.pdf")
    else
        result = caffeine:setIcon("caffeine-off.pdf")
    end
end

function caffeineClicked()
    setCaffeineDisplay(hs.caffeinate.toggle("displayIdle"))
end

if caffeine then
    caffeine:setClickCallback(caffeineClicked)
    setCaffeineDisplay(hs.caffeinate.get("displayIdle"))
end

-- Toggle between speaker and headphone sound devices (useful if you have multiple USB soundcards that are always connected)
function toggle_audio_output()
    local current = hs.audiodevice.defaultOutputDevice()
    local speakers = hs.audiodevice.findOutputByName(speakerDevice)
    local headphones = hs.audiodevice.findOutputByName(headphoneDevice)

    if not speakers or not headphones then
        hs.notify.show("Hammerspoon", "", "ERROR: Some audio devices missing", "")
        return
    end

    if current:name() == speakers:name() then
        headphones:setDefaultOutputDevice()
    else
        speakers:setDefaultOutputDevice()
    end
    hs.notify.show("Hammerspoon", "Default output device:", hs.audiodevice.defaultOutputDevice():name(), "")
end

-- Toggle Skype between muted/unmuted, whether it is focused or not
function toggleSkypeMute()
    local skype = hs.appfinder.appFromName("Skype")
    if not skype then
        return
    end

    local lastapp = nil
    if not skype:isFrontmost() then
        lastapp = hs.application.frontmostApplication()
        skype:activate()
    end

    if not skype:selectMenuItem({"Conversations", "Mute Microphone"}) then
        skype:selectMenuItem({"Conversations", "Unmute Microphone"})
    end

    if lastapp then
        lastapp:activate()
    end
end

-- Toggle an application between being the frontmost app, and being hidden
function toggle_application(_app)
    local app = hs.appfinder.appFromName(_app)
    if not app then
        -- FIXME: This should really launch _app
        return
    end
    local mainwin = app:mainWindow()
    if mainwin == hs.window.focusedWindow() then
        mainwin:application():hide()
    else
        mainwin:application():activate(true)
        mainwin:application():unhide()
        mainwin:focus()
    end
end

-- Callback function for application events
function applicationWatcher(appName, eventType, appObject)
    if (eventType == hs.application.watcher.activated) then
        if (appName == "Finder") then
            -- Bring all Finder windows forward when one gets activated
            appObject:selectMenuItem({"Window", "Bring All to Front"})
        end
    end
end

-- Callback function for WiFi SSID change events
function ssidChangedCallback()
    newSSID = hs.wifi.currentNetwork()

    if newSSID == homeSSID and lastSSID ~= homeSSID then
        -- We have gone from something that isn't my home WiFi, to something that is
        home_arrived()
    elseif newSSID ~= homeSSID and lastSSID == homeSSID then
        -- We have gone from something that is my home WiFi, to something that isn't
        home_departed()
    end

    lastSSID = newSSID
end

-- Callback function for changes in screen layout
function screensChangedCallback()
    newNumberOfScreens = #hs.screen.allScreens()

    if lastNumberOfScreens ~= newNumberOfScreens then
        if newNumberOfScreens == 1 then
            hs.layout.apply(internal_display)
        elseif newNumberOfScreens == 2 then
            hs.layout.apply(dual_display)
        end
    end

    lastNumberOfScreens = newNumberOfScreens
end

-- Perform tasks to configure the system for my home WiFi network
function home_arrived()
    hs.audiodevice.defaultOutputDevice():setVolume(25)
    os.execute("sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off")
    hs.applescript.applescript([[
        tell application "Finder"
            try
                mount volume "smb://cmsj@servukipa._smb._tcp.local/Data"
            end try
        end tell
    ]])
    hs.applescript.applescript([[
        tell application "GeekTool Helper"
            refresh all
        end tell
    ]])

    hs.notify.show("Hammerspoon", "", "Unmuted volume, mounted volumes, disabled firewall", "")
end

-- Perform tasks to configure the system for any WiFi network other than my home
function home_departed()
    hs.audiodevice.defaultOutputDevice():setVolume(0)
    os.execute("sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on")
    hs.applescript.applescript([[
        tell application "Finder"
            eject "Data"
        end tell
    ]])
    hs.applescript.applescript([[
        tell application "GeekTool Helper"
            refresh all
        end tell
    ]])

    hs.notify.show("Hammerspoon", "", "Muted volume, unmounted volumes, enabled firewall", "")
end

-- Reload config automatically
function reloadConfig()
    configFileWatcher:stop()
    configFileWatcher = nil

    appWatcher:stop()
    appWatcher = nil

    screenWatcher:stop()
    screenWatcher = nil

    wifiWatcher:stop()
    wifiWatcher = nil

    caffeine:delete()

    hs.reload()
end

-- Hotkeys to move windows between screens
hs.hotkey.bind(hyper, 'Left', function() hs.window.focusedWindow():moveOneScreenWest() end)
hs.hotkey.bind(hyper, 'Right', function() hs.window.focusedWindow():moveOneScreenEast() end)

-- Hotkeys to resize windows absolutely
hs.hotkey.bind(hyper, 'a', function() hs.window.focusedWindow():moveToUnit(hs.layout.left30) end)
hs.hotkey.bind(hyper, 's', function() hs.window.focusedWindow():moveToUnit(hs.layout.right70) end)
hs.hotkey.bind(hyper, '[', function() hs.window.focusedWindow():moveToUnit(hs.layout.left50) end)
hs.hotkey.bind(hyper, ']', function() hs.window.focusedWindow():moveToUnit(hs.layout.right50) end)
hs.hotkey.bind(hyper, 'f', function() hs.window.focusedWindow():maximize() end)
hs.hotkey.bind(hyper, 'r', function() hs.window.focusedWindow():toggleFullScreen() end)

-- Hotkeys to trigger defined layouts
hs.hotkey.bind(hyper, '1', function() hs.layout.apply(internal_display) end)
hs.hotkey.bind(hyper, '2', function() hs.layout.apply(dual_display) end)

-- Application hotkeys
hs.hotkey.bind(hyper, '`', function() hs.application.launchOrFocus("iTerm") end)
hs.hotkey.bind(hyper, 'q', function() toggle_application("Safari") end)
hs.hotkey.bind(hyper, 'z', function() toggle_application("Reeder") end)
hs.hotkey.bind(hyper, 'w', function() toggle_application("IRC") end)

-- Lighting hotkeys
hs.hotkey.bind({}, 'f5', function()
    brightness = brightness - 1
    brightness = officeLED:zoneBrightness(1, brightness)
    officeLED:zoneBrightness(2, brightness - 3)
end)
hs.hotkey.bind({}, 'f6', function()
    brightness = brightness + 1
    brightness = officeLED:zoneBrightness(1, brightness)
    officeLED:zoneBrightness(2, brightness - 3)
end)
hs.hotkey.bind(hyper, 'f5', function() brightness = officeLED:zoneBrightness(0, hs.milight.minBrightness) end)
hs.hotkey.bind(hyper, 'f6', function() brightness = officeLED:zoneBrightness(0, hs.milight.maxBrightness) end)

-- Misc hotkeys
hs.hotkey.bind(hyper, 'y', hs.toggleConsole)
hs.hotkey.bind(hyper, 'n', function() os.execute("open ~") end)
hs.hotkey.bind(hyper, 'c', caffeineClicked)
hs.hotkey.bind(hyper, 'Escape', toggle_audio_output)
hs.hotkey.bind(hyper, 'm', toggleSkypeMute)
-- Can't use this until we fix https://github.com/Hammerspoon/hammerspoon/issues/203
--hs.hotkey.bind({}, 'F17', function() hs.eventtap.keyStrokes({}, hs.pasteboard.getContents()) end)

-- Create and start our callbacks
configFileWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
configFileWatcher:start()

appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()

screenWatcher = hs.screen.watcher.new(screensChangedCallback)
screenWatcher:start()

wifiWatcher = hs.wifi.watcher.new(ssidChangedCallback)
wifiWatcher:start()

-- Finally, show a notification that we finished loading the config successfully
hs.notify.show("Hammerspoon", "", "Config loaded", "")

-- This is some developer debugging stuff. It will cause Hammerspoon to crash if any Lua is being executed on the wrong thread. You probably don't want this in your config :)
local function crashifnotmain(reason)
--  print("crashifnotmain called with reason", reason) -- may want to remove this, very verbose otherwise
  if not hs.crash.isMainThread() then
    print("not in main thread, crashing")
    hs.crash.crash()
  end
end
debug.sethook(crashifnotmain, 'c')
