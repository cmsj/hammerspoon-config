-- Enable this to do live debugging in ZeroBrane Studio
-- local ZBS = "/Applications/ZeroBraneStudio.app/Contents/ZeroBraneStudio"
-- package.path = package.path .. ";" .. ZBS .. "/lualibs/?/?.lua;" .. ZBS .. "/lualibs/?.lua"
-- package.cpath = package.cpath .. ";" .. ZBS .. "/bin/?.dylib;" .. ZBS .. "/bin/clibs53/?.dylib"
-- require("mobdebug").start()

--hs.console.consoleFont("Liga SFMono Nerd Font")

-- Print out more logging for me to see
require("hs.crash")
hs.crash.crashLogToNSLog = false

-- Store for all of the hyper key bindings
hyperfns = {}

-- Pull in private.lua which isn't in this repo because it contains work related stuff
require("private")

-- Make all our animations really fast
hs.window.animationDuration = 0.1

-- Trace all Lua code
function lineTraceHook(event, data)
    lineInfo = debug.getinfo(2, "Snl")
    print("TRACE: "..(lineInfo["short_src"] or "<unknown source>")..":"..(lineInfo["linedefined"] or "<??>"))
end
-- Uncomment the following line to enable tracing
--debug.sethook(lineTraceHook, "l")

-- Capture the hostname, so we can make this config behave differently across my Macs
hostname = hs.host.localizedName()

-- Ensure the IPC command line client is available
hs.ipc.cliInstall()

-- Define some keyboard modifier variables
-- (Node: Capslock bound to cmd+alt+ctrl+shift via Seil and Karabiner)
hyper = {"⌘", "⌥", "⌃", "⇧"}

-- Watchers
configFileWatcher = nil
wifiWatcher = nil
screenWatcher = nil
usbWatcher = nil
caffeinateWatcher = nil
appWatcher = nil

-- Watchables
audiodeviceWatchable = nil

-- Other useful objects
streamDeck = nil
miniDeck = nil
--krbRefresherTimer = nil
--krbRefresherTask = nil
officeMotionActivityID = nil

-- Load SpoonInstall, so we can easily load our other Spoons
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true
Install=spoon.SpoonInstall

-- Control brightness for all compatible displays, using the keyboard brightness keys
Install:andUse("AllBrightness", {start=false})
spoon.AllBrightness.referenceScreen = hs.screen.find("LG UltraFine")
spoon.AllBrightness:start()

-- Direct URLs automatically based on patterns
Install:andUse("URLDispatcher",
  {
    config = {
      url_patterns = work_url_patterns,
      app_patterns = work_app_patterns,
      default_handler = "com.apple.Safari"
    },
    start = true
  }
)

-- Load Seal - This is a pretty simple implementation of something like Alfred
Install:andUse("Seal",
  {
    hotkeys = {
        show = { {"cmd"}, "Space" }
    },
    fn = function(s)
        s:loadPlugins({"apps", "vpn", "screencapture", "safari_bookmarks", "calc", "useractions", "pasteboard", "filesearch"})
        s.plugins.pasteboard.historySize=4000
        s.plugins.useractions.actions = useractions_actions
        s.toolbar:addItems({
            id = "test1",
            selectable = true,
            image = hs.image.imageFromName("NSTouchBarGoUpTemplate"),
            label = "Hide toolbar",
            fn = function(toolbar, chooser, item, eventName)
                s.toolbar:visible(false)
            end
        })
--        s:toggleToolbar()
    end,
    start = true
  }
)

-- I always end up losing my mouse pointer, particularly if it's on a monitor full of terminals.
-- This draws a bright red circle around the pointer for a few seconds
Install:andUse("MouseCircle", { hotkeys = { show = { hyper, "d" }}})

-- Replace Caffeine.app with 18 lines of Lua :D
Install:andUse("Caffeine", { hotkeys = { toggle = { hyper, "c" }}, start = true})

-- Draw pretty rounded corners on all screens
Install:andUse("RoundedCorners", { start = true })

-- Install:andUse("ElgatoKeyLight", {
--     config = {
--         matchNames = {
--             "Elgato Key Light Air"
--         }
--     },
--     start = true
-- })

-- -- Configure our Stream Decks
-- Install:andUse("StreamDeck",
--   {
--     config = {
--         deckConfig = {
--             ["BL44H1B01314"] = {
--                 [2] = {
--                     image = hs.image.imageFromAppBundle("com.apple.Safari"),
--                     callback = function(deck, button, isDown)
--                         print("HELLO I AM A BUTTON")
--                     end
--                 }
--             },
--             ["AL15G1A01664"] = {
--                 [1] = {
--                     image = hs.image.imageFromAppBundle("com.obsproject.obs-studio"),
--                     callback = function(deck, button, isDown)
--                         if isDown then
--                             local obs = hs.application.applicationsForBundleID("com.obsproject.obs-studio")
--                             if obs[1] == nil then
--                                 spoon.OBS:start()
--                                 hs.application.launchOrFocus("OBS")
--                                 spoon.ElgatoKeyLight:turnOn("Elgato Key Light Air F220")
--                             else
--                                 obs[1]:kill()
--                                 spoon.ElgatoKeyLight:turnOff("Elgato Key Light Air F220")
--                                 spoon.OBS:stop()
--                             end
--                         end
--                     end
--                 },
--                 [2] = {
--                     image = hs.image.imageFromAppBundle("com.apple.Safari"),
--                     callback = function(deck, button, isDown)
--                         if isDown then
--                             spoon.ElgatoKeyLight:toggle("Elgato Key Light Air F220")
--                         end
--                     end
--                 },
--                 [3] = {
--                     image = hs.image.imageFromAppBundle("com.apple.Facetime"),
--                     callback = function(deck, button, isDown)
--                         if isDown then
--                             spoon.OBS:request("ToggleVirtualCam")
--                         end
--                     end
--                 },
--                 [4] = {
--                     image = hs.image.imageFromAppBundle("com.apple.Music"),
--                     callback = function(deck, button, isDown)
--                         if isDown then
--                             spoon.OBS:request("GetSourceFilter", {
--                                 ["sourceName"] = "SUBSCENE: Logi 4K",
--                                 ["filterName"] = "Freeze"
--                             }, "__id_DO_TOGGLE_FREEZE__")
--                         end
--                     end
--                 }
--             }
--         }
--     },
--     start = true
--   }
-- )

-- -- Configure OBS
-- Install:andUse("OBS",
--   {
--     config = {
--         eventCallback = function(eventType, eventIntent, eventData)
--             if eventType == "SpoonOBSConnected" and spoon.OBS.eventSubscriptions == nil then
--                 spoon.OBS:updateEventSubscriptions(spoon.OBS.eventSubscriptionValues.All)
--                 return
--             end
--             print("OBS event: "..eventType)
--             if eventType == "SpoonRequestResponse" then
--                 if eventData["requestId"] == "__id_DO_TOGGLE_FREEZE__" then
--                     spoon.OBS:request("SetSourceFilterEnabled", {
--                         ["sourceName"] = "SUBSCENE: Logi 4K",
--                         ["filterName"] = "Freeze",
--                         ["filterEnabled"] = not eventData["responseData"]["filterEnabled"]
--                     })
--                 end
--                 -- print("  Data: "..hs.inspect(eventData))
--             end
--         end,
--         host = "localhost",
--         port = 4455
--     },
--     start = false
--   }
-- )

-- Load various modules from ~/.hammerspoon/ depending on which machine this is
if (hostname == "fuyo" or hostname == "fuyoshi") then
    -- I like to have some little traffic light coloured dots in the bottom right corner of my screen
    -- to show various status items. Like Geeklet
    statuslets = require("statuslets"):start()

    -- If the Philips Hue Motion Sensor in my office detects movement, make sure my Mac's screens are awake
    --hs.loadSpoon("Hue")
    --hueTimer = nil
    --spoon.Hue.sensorCallback = function(presence, sensor)
    --    day = tonumber(os.date("%w"))
    --    if day > 5 or day < 1 then
    --        print("Ignoring motion, it's the weekend")
    --        return
    --    end
    --    hour = tonumber(os.date("%H"))
    --    if hour < 9 or hour > 18 then
    --        print("Ignoring motion, it's not working hours")
    --        return
    --    end
    --    if presence then
    --        print("Motion detected on sensor: " .. sensor .. ". Declaring user activity")
    --        officeMotionActivityID = hs.caffeinate.declareUserActivity(officeMotionActivityID)
    --    end
    --end
else
    statuslets = nil

    -- Display a menubar item to indicate if the Internet is reachable
    reachabilityMenuItem = require("reachabilityMenuItem"):start()
end

-- Define monitor names for layout purposes
display_xdr = "Fake Display XDR"
display_monitor = "LG UltraFine"

-- Define audio device names for headphone/speaker switching
headphoneDevice = "BRIDGE CAST"
speakerDevice = "Audioengine 2+  "
--speakerDevice = "Built-in Output"

-- Defines for WiFi watcher
homeSSID = "chrul" -- My home WiFi SSID
lastSSID = hs.wifi.currentNetwork()

-- Defines for screen watcher
lastNumberOfScreens = #hs.screen.allScreens()

-- Defines for caffeinate watcher
shouldUnmuteOnScreenWake = nil

-- Defines for window grid
if (hostname == "fuyo" or hostname == "fuyoshi") then
    hs.grid.GRIDWIDTH = 8
    hs.grid.GRIDHEIGHT = 8
else
    hs.grid.GRIDWIDTH = 4
    hs.grid.GRIDHEIGHT = 4
end
hs.grid.MARGINX = 0
hs.grid.MARGINY = 0

-- Defines for window maximize toggler
frameCache = {}

-- Define window layouts
--   Format reminder:
--     {"App name", "Window name", "Display Name", "unitrect", "framerect", "fullframerect"},
dual_display = {
    -- {"IRC",               nil,          display_monitor, hs.geometry.unitrect(0, 0.5, 0.375, 0.5), nil, nil},
    -- {"Reeder",            nil,          display_monitor, hs.geometry.unitrect(0.75, 0, 0.25, 0.5),   nil, nil},
    -- {"Safari",            nil,          display_xdr,     hs.geometry.unitrect(0.5, 0, 0.5, 0.5),    nil, nil},
    -- {"Kiwi for Gmail",    nil,          display_xdr,     hs.geometry.unitrect(0.5, 0.5, 0.5, 0.5), nil, nil},
    -- {"Trello",            nil,          display_xdr,     hs.geometry.unitrect(0.5, 0.5, 0.5, 0.5), nil, nil},
    -- {"Mail",              nil,          display_xdr,     hs.geometry.unitrect(0, 0.5, 0.5, 0.5),   nil, nil},
    -- {"Messages",          nil,          display_monitor, hs.geometry.unitrect(0, 0, 0.375, 0.25), nil, nil},
    -- {"Fantastical",       nil,          display_monitor, hs.geometry.unitrect(0.375, 0, 5/8, 0.5), nil, nil},
    -- {"Freeter",           nil,          display_monitor, hs.geometry.unitrect(0.375, 0.5, 5/8, 0.5), nil, nil},
    {"Safari",              nil,        display_xdr,     hs.geometry.unitrect(0, 0, 0.46, 0.535), nil, nil},
    {"Kiwi for Gmail",      "Inbox .*", display_xdr,     hs.geometry.unitrect(0, 0.535, 0.46, 0.465), nil, nil},

    {"Textual IRC Client",  nil,        display_xdr,     hs.geometry.unitrect(0.46, 0, 0.305, 0.305), nil, nil},
    {"Discord",             nil,        display_xdr,     hs.geometry.unitrect(0.46, 0.305, 0.305, 0.505), nil, nil},
    {"Messages",            nil,        display_xdr,     hs.geometry.unitrect(0.46, 0.81, 0.305, 0.2), nil, nil},

    {"iTerm2",              nil,        display_xdr,     hs.geometry.unitrect(0.765, 0.1, 0.235, 0.9), nil, nil},

    {"Slack",               nil,        display_monitor, hs.geometry.unitrect(0, 0, 0.4, 0.6), nil, nil},
    {"Fantastical",         nil,        display_monitor, hs.geometry.unitrect(0, 0.6, 0.4, 0.4), nil, nil},
    {"Google Chrome",       nil,        display_monitor, hs.geometry.unitrect(0.4, 0, 0.6, 1.0), nil, nil},
}

-- Useful helper function for making hs.layout layouts
function createWindowLayout(name)
    local layout = string.format("%s = {\n", name)
    local wins = hs.window.allWindows()
    for _,win in ipairs(wins) do
        local app = win:application():name()
        local winTitle = win:title()
        local screen = win:screen():name()
        local frame = win:frame()
        local row = string.format('{"%s", "%s", "%s", nil, hs.geometry.rect(%i, %i, %i, %i), nil},\n', app, winTitle, screen, frame.x, frame.y, frame.w, frame.h)
        layout = layout .. row
    end
    layout = layout .. "\n}"
    print(layout)
end
-- Helper functions

-- Toggle between speaker and headphone sound devices (useful if you have multiple USB soundcards that are always connected)
function toggle_audio_output()
    local current = hs.audiodevice.defaultOutputDevice()
    local speakers = hs.audiodevice.findOutputByName(speakerDevice)
    local headphones = hs.audiodevice.findOutputByName(headphoneDevice)

    if not speakers or not headphones then
        hs.notify.new({title="Hammerspoon", informativeText="ERROR: Some audio devices missing", ""}):send()
        return
    end

    if current:name() == speakers:name() then
        headphones:setDefaultOutputDevice()
        headphones:setDefaultEffectDevice()
    else
        speakers:setDefaultOutputDevice()
        speakers:setDefaultEffectDevice()
    end
    hs.notify.new({
          title='Hammerspoon',
            informativeText='Default output device: '..hs.audiodevice.defaultOutputDevice():name()
        }):send()
end

-- Toggle an application between being the frontmost app, and being hidden
function toggle_application(_app)
    local app = hs.appfinder.appFromName(_app)
    if not app then
        -- FIXME: This should really launch _app
        return
    end
    local mainwin = app:mainWindow()
    if mainwin then
        if mainwin == hs.window.focusedWindow() then
            mainwin:application():hide()
        else
            mainwin:application():activate(true)
            mainwin:application():unhide()
            mainwin:focus()
        end
    end
end

-- Toggle a window between its normal size, and being maximized
function toggle_window_maximized()
    local win = hs.window.focusedWindow()
    if frameCache[win:id()] then
        win:setFrame(frameCache[win:id()])
        frameCache[win:id()] = nil
    else
        frameCache[win:id()] = win:frame()
        win:maximize()
    end
end

-- Callback function for application events
function applicationWatcher(appName, eventType, appObject)
    if (eventType == hs.application.watcher.activated) then
        if (appName == "Finder") then
            -- Bring all Finder windows forward when one gets activated
            appObject:selectMenuItem({"Window", "Bring All to Front"})
        end
        if streamDeck then
            local app = hs.application.get(appName)
            if app then
                --print("Writing app icon to Stream Deck for: "..app:bundleID())
                local appIcon = hs.image.imageFromAppBundle(app:bundleID())
                streamDeck:setButtonImage(1, appIcon)
            end
        end
    end
end

-- Callback function for WiFi SSID change events
function ssidChangedCallback()
    newSSID = hs.wifi.currentNetwork()

    print("ssidChangedCallback: old:"..(lastSSID or "nil").." new:"..(newSSID or "nil"))
    if newSSID == homeSSID and lastSSID ~= homeSSID then
        -- We have gone from something that isn't my home WiFi, to something that is
        home_arrived()
    elseif newSSID ~= homeSSID and lastSSID == homeSSID then
        -- We have gone from something that is my home WiFi, to something that isn't
        home_departed()
    end

    lastSSID = newSSID
end

-- Callback function for USB device events
function usbDeviceCallback(data)
    print("usbDeviceCallback: "..hs.inspect(data))
    if (data["productName"] == "ScanSnap S1300i") then
        event = data["eventType"]
        if (event == "added") then
            hs.application.launchOrFocus("ScanSnap Manager")
        elseif (event == "removed") then
            app = hs.appfinder.appFromName("ScanSnap Manager")
            app:kill()
        end
    end
    if (data["productName"] == "Wireless Controller" and data["vendorName"] == "Sony Computer Entertainment") then
        event = data["eventType"]
        if (event == "added") then
            hs.application.launchOrFocus("RemotePlay")
            hs.itunes.pause()
        elseif (event == "removed") then
            app = hs.appfinder.appFromName("PS4 Remote Play")
            app:kill()
        end
    end
    if (data["vendorID"] == 2425 and data["productID"] == 551) then
        event = data["eventType"]
        if (event == "added") then
            print("Kids camera detected")
            -- Choose which kid's camera this is
            chooser = hs.chooser.new(function(choice)
                child = choice["text"]
                dateTime = os.date("!%Y-%m-%d-%T")
                dirName = "/Users/cmsj/Desktop/KidsCameras/"..child.."/"..dateTime
                print("  Making: "..dirName)
                if not hs.fs.mkdir(dirName) then
                    hs.alert("Unable to make directory.\nIMPORT FAILED")
                    return
                end
                -- Call the crummy photo importing app with the directory we just made
                hs.task.new("/Library/QuickTime/V25.app/Contents/MacOS/MyDSC", function(exitCode, stdOut, stdErr)
                    print(string.format("V25.app exited: %d", exitCode))
                    print("stdOut: "..stdOut)
                    print("stdErr: "..stdErr)
                end, {dirName, "-d"}):start()
            end)
            chooser:choices({{["text"] = "Jasper"},{["text"] = "Niklas"}})
            chooser:show()
        end
    end
end

-- Callback function for caffeinate events
function caffeinateCallback(eventType)
    if (eventType == hs.caffeinate.watcher.screensDidSleep) then
        print("screensDidSleep")
        if spoon.Hue then
            hueTimer = hs.timer.doAfter(30, function() spoon.Hue:start() end)
        end

        if hs.itunes.isPlaying() then
            hs.itunes.pause()
        end

        local output = hs.audiodevice.defaultOutputDevice()
        shouldUnmuteOnScreenWake = not output:muted()
        output:setMuted(true)

        spoon.Caffeine:setState(false)
    elseif (eventType == hs.caffeinate.watcher.screensDidWake) then
        print("screensDidWake")
        if shouldUnmuteOnScreenWake then
            hs.audiodevice.defaultOutputDevice():setMuted(false)
        end

        if spoon.Hue then
            hueTimer:stop()
            spoon.Hue:stop()
        end
    elseif (eventType == hs.caffeinate.watcher.screensDidLock) then
        streamDeck:setBrightness(0)
    elseif (eventType == hs.caffeinate.watcher.screensDidUnlock) then
        streamDeck:setBrightness(60)
    end
end

-- Callback function for changes in screen layout
function screensChangedCallback()
    print("screensChangedCallback")
    --hs.layout.apply(dual_display)

    if statuslets then
        statuslets:render()
        statuslets:update()
    end
end

-- Perform tasks to configure the system for my home WiFi network
function home_arrived()
    -- Note: sudo commands will need to have been pre-configured in /etc/sudoers, for passwordless access, e.g.:
    -- cmsj ALL=(root) NOPASSWD: /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall *
    --hs.task.new("/usr/bin/sudo", function() end, {"/usr/libexec/ApplicationFirewall/socketfilterfw", "--setblockall", "off"})

    -- Mount my NAS
    hs.applescript.applescript([[
        tell application "Finder"
            try
                mount volume "smb://smbarchive@GNUBERT._smb._tcp.local/media"
                mount volume "smb://smbarchive@GNUBERT._smb._tcp.local/archive"
            end try
        end tell
    ]])
    if statuslets then
        statuslets:update()
    end
    hs.notify.new({
          title='Hammerspoon',
            informativeText='Mounted volumes'
        }):send()
end

-- Perform tasks to configure the system for any WiFi network other than my home
function home_departed()
--    hs.task.new("/usr/bin/sudo", function() end, {"/usr/libexec/ApplicationFirewall/socketfilterfw", "--setblockall", "on"})
    if statuslets then
        statuslets:update()
    end
end

-- Rather than switch to Safari, copy the current URL, switch back to the previous app and paste,
-- This is a function that fetches the current URL from Safari and types it
function typeCurrentSafariURL()
    script = [[
    tell application "Safari"
        set currentURL to URL of document 1
    end tell

    return currentURL
    ]]
    ok, result = hs.applescript(script)
    if (ok) then
        hs.eventtap.keyStrokes(result)
    end
end

-- Reload config
function reloadConfig(paths)
    doReload = false
    for _,file in pairs(paths) do
        if file:sub(-4) == ".lua" then
            print("A lua file changed, doing reload")
            doReload = true
        end
    end
    if not doReload then
        print("No lua file changed, skipping reload")
        return
    end

    hs.reload()
end

-- Hotkeys to resize windows absolutely
hyperfns["a"] = function() hs.window.focusedWindow():moveToUnit(hs.layout.left30) end
hyperfns["s"] = function() hs.window.focusedWindow():moveToUnit(hs.layout.right30) end
hyperfns['['] = function() hs.window.focusedWindow():moveToUnit(hs.layout.left50) end
hyperfns[']'] = function() hs.window.focusedWindow():moveToUnit(hs.layout.right50) end
hyperfns['f'] = toggle_window_maximized
hyperfns['r'] = function() hs.window.focusedWindow():toggleFullScreen() end

-- Hotkeys to trigger defined layouts
hyperfns['2'] = function() hs.layout.apply(dual_display, string.match) end

-- Hotkeys to interact with the window grid
hyperfns['g'] = hs.grid.show
hyperfns['Left'] = hs.grid.pushWindowLeft
hyperfns['Right'] = hs.grid.pushWindowRight
hyperfns['Up'] = hs.grid.pushWindowUp
hyperfns['Down'] = hs.grid.pushWindowDown

-- Application hotkeys
hyperfns['e'] = function() toggle_application("iTerm2") end
hyperfns['q'] = function() toggle_application("Safari") end
hyperfns['z'] = function() toggle_application("Kiwi for Gmail") end
hyperfns['w'] = function() toggle_application("Textual IRC Client") end

-- Misc hotkeys
hyperfns['y'] = hs.toggleConsole
hyperfns['h'] = hs.hints.windowHints
hyperfns['n'] = function() hs.task.new("/usr/bin/open", nil, {os.getenv("HOME")}):start() end
hyperfns['§'] = toggle_audio_output
hyperfns['m'] = function()
        device = hs.audiodevice.defaultInputDevice()
        device:setMuted(not device:muted())
    end
hyperfns['u'] = typeCurrentSafariURL
hyperfns['0'] = function()
        print(configFileWatcher)
        print(wifiWatcher)
        print(screenWatcher)
        print(usbWatcher)
        print(caffeinateWatcher)
    end
hyperfns['v'] = function()
        spoon.Seal:toggle("pb")
    end

for _hotkey, _fn in pairs(hyperfns) do
    hs.hotkey.bind(hyper, _hotkey, _fn)
end

hs.urlevent.bind('hypershiftleft', function() hs.grid.resizeWindowThinner(hs.window.focusedWindow()) end)
hs.urlevent.bind('hypershiftright', function() hs.grid.resizeWindowWider(hs.window.focusedWindow()) end)
hs.urlevent.bind('hypershiftup', function() hs.grid.resizeWindowShorter(hs.window.focusedWindow()) end)
hs.urlevent.bind('hypershiftdown', function() hs.grid.resizeWindowTaller(hs.window.focusedWindow()) end)

-- Type the current clipboard, to get around web forms that don't let you paste
-- (Note: I have Fn-v mapped to F17 in Karabiner)
hs.urlevent.bind('fnv', function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)

-- Create and start our callbacks
appWatcher = hs.application.watcher.new(applicationWatcher):start()

screenWatcher = hs.screen.watcher.new(screensChangedCallback)
screenWatcher:start()

-- wifiWatcher = hs.wifi.watcher.new(ssidChangedCallback)
-- wifiWatcher:start()

usbWatcher = hs.usb.watcher.new(usbDeviceCallback)
usbWatcher:start()

if (hostname == "fuyo" or hostname == "fuyoshi") then
    caffeinateWatcher = hs.caffeinate.watcher.new(caffeinateCallback)
    caffeinateWatcher:start()
end

configFileWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
configFileWatcher:start()

-- Make sure we have the right location settings
-- if hs.wifi.currentNetwork() == "chrul" then
--     home_arrived()
-- else
--     home_departed()
-- end

-- Finally, show a notification that we finished loading the config successfully
hs.notify.new({
      title='Hammerspoon',
        informativeText='Config loaded'
    }):send()

function deckButtonEvent(deck, button, isDown)
    print("deckButtonEvent: "..button.." isDown: "..(isDown and "YES" or "NO"))
    if button == 6 and not isDown then
        spoon.StreamDeckMicMuter:toggleMute()
--     elseif isDown then
--         --deck:setButtonColor(button, hs.drawing.color.definedCollections.x11.purple)
--         deck:setButtonImage(button, hs.image.imageFromPath("/Users/cmsj/Desktop/CB0742.06.V1.M1.png"))
--     else
--         deck:setButtonImage(button, hs.image.imageFromName(hs.image.systemImageNames.Folder))
    end
    if button == 5 and not isDown then
        spoon.StreamDeckAudioDeviceCycle:cycle()
    end
    if not isDown then
        audiodeviceWatchable["event"] = "WTF"
    end
end

function streamDeckDiscovery(isConnect, deck)
    --if deck:serialNumber() == "AL15G1A01664" then
    print("Stream Deck discovered, serial: '"..tostring(deck:serialNumber()).."', firmware: '"..tostring(deck:firmwareVersion()).."'")
    if deck:serialNumber() == "BL44H1B01314" then
        if isConnect then
            print("Stream Deck connected: "..tostring(deck))
            streamDeck = deck
            streamDeck:reset()
            streamDeck:buttonCallback(deckButtonEvent)
            spoon.StreamDeckMicMuter:start(streamDeck, 6, false)
            spoon.StreamDeckAudioDeviceCycle:start(streamDeck, 5)
        else
            print("Stream Deck disconnected")
            spoon.StreamDeckMicMuter:stop()
            spoon.StreamDeckAudioDeviceCycle:stop()
            streamDeck = nil
        end
    else
        print("  Not a Deck we want to configure")
    end
end

audiodeviceWatchable = hs.watchable.new("audiodevice", true)
function audiodeviceDeviceCallback(event)
    print("audiodeviceDeviceCallback: "..event)
    -- Force the internal mic to always remain the default input device
--    if event == "dIn " then
--        print("Forcing default input to Internal Microphone")
--        hs.timer.doAfter(2, function() hs.audiodevice.findInputByName("Built-in Microphone"):setDefaultInputDevice() end)
--    end
    audiodeviceWatchable["event"] = event
end
hs.audiodevice.watcher.setCallback(audiodeviceDeviceCallback)
hs.audiodevice.watcher.start()

--hs.loadSpoon("StreamDeckMicMuter")
--hs.loadSpoon("StreamDeckAudioDeviceCycle")
-- spoon.StreamDeckAudioDeviceCycle.devices = {
--     ["BRIDGE CAST"] = "headphone.png",
--     ["Audioengine 2+  "] = "speaker.png",
--     ["bosies"] = "bluetooth.png",
--     ["Chris' AirPods"] = "airpod.png"
-- }
-- hs.streamdeck.init(streamDeckDiscovery)

-- krbRefresherTimer = hs.timer.doEvery(7200, function()
--     if krbRefresherTask and krbRefresherTask:isRunning() then
--         print("Terminating existing kinit process (which shouldn't be running)")
--         krbRefresherTask:terminate()
--     end
--     print("Refreshing krb tickets. Will refresh again in 2 hours")
--     krbRefresherTask = hs.task.new("/usr/bin/kinit", nil, {}):start()
-- end)

function karabinerCallback(eventName, params)
    print("Event: "..eventName)
    print(hs.inspect(params))
end

hs.urlevent.bind("karabiner", karabinerCallback)

function movieMode(value)
    local xdr = 1.0
    local lg = 0.0
    if value == false then
        xdr = 0.2
        lg = 0.2
    end

    hs.screen.find("XDR"):setBrightness(xdr)
    hs.screen.find("LG"):setBrightness(lg)
end
hs.urlevent.bind('movieModeOn', function() movieMode(true) end)
hs.urlevent.bind('movieModeOff', function() movieMode(false) end)

if hs.console.darkMode() then
    hs.console.outputBackgroundColor({ white = 0 })
    hs.console.consolePrintColor({ white = 1 })
    hs.console.consoleResultColor({ white = 0.8 })
    hs.console.consoleCommandColor({ white = 1 })
end

hs.chooser.globalCallback = nil

--collectgarbage("setstepmul", 1000)
--collectgarbage("setpause", 1)

-- function streamDeckTest()
--     local colors = {}
--     local colorn = 0
--     for k,v in pairs(hs.drawing.color.x11) do
--         colorn = colorn + 1
--         colors[colorn]=k
--     end

--     for num=1,hs.streamdeck.numDevices() do
--         local device = hs.streamdeck.getDevice(num)
--         local columns, rows = device:buttonLayout()
--         for button=1,rows*columns do
--             device:setButtonColor(button, hs.drawing.color.x11[colors[button]])
--         end

--         device:buttonCallback(function(deck, button, isDown)
--             print("Button: "..button.." on: "..tostring(deck))
--         end)
--     end

--     hs.timer.usleep(2000000)

--     local function ends_with(str, ending)
--         return ending == "" or str:sub(-#ending) == ending
--     end

-- --    local icons = {}
-- --    local iconn = 0
-- --    for k,v in pairs(hs.image.additionalImageNames.platinum) do
-- --        if not ends_with(k, "Template") then
-- --            iconn = iconn + 1
-- --            icons[iconn]=k
-- --        end
-- --    end

--     for num=1,hs.streamdeck.numDevices() do
--         local device = hs.streamdeck.getDevice(num)
--         local columns, rows = device:buttonLayout()
--         for button=1,rows*columns do
--             device:setButtonImage(button, hs.image.imageFromName(hs.image.additionalImageNames.platinum[1]))
--         end
--     end
-- end
