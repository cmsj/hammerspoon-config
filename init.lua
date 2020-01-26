-- Enable this to do live debugging in ZeroBrane Studio
-- local ZBS = "/Applications/ZeroBraneStudio.app/Contents/ZeroBraneStudio"
-- package.path = package.path .. ";" .. ZBS .. "/lualibs/?/?.lua;" .. ZBS .. "/lualibs/?.lua"
-- package.cpath = package.cpath .. ";" .. ZBS .. "/bin/?.dylib;" .. ZBS .. "/bin/clibs53/?.dylib"
-- require("mobdebug").start()

-- Print out more logging for me to see
require("hs.crash")
hs.crash.crashLogToNSLog = false

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
krbRefresherTimer = nil
krbRefresherTask = nil
officeMotionActivityID = nil

-- Load SpoonInstall, so we can easily load our other Spoons
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.use_syncinstall = true
Install=spoon.SpoonInstall

-- Direct URLs automatically based on patterns
Install:andUse("URLDispatcher",
  {
    config = {
      url_patterns = work_url_patterns,
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
        s:loadPlugins({"apps", "vpn", "screencapture", "safari_bookmarks", "calc", "useractions", "pasteboard"})
        s.plugins.pasteboard.historySize=4000
        s.plugins.useractions.actions = {
            ["Red Hat Bugzilla"] = { url = "https://bugzilla.redhat.com/show_bug.cgi?id=${query}", icon="favicon", keyword="bz" },
            ["Launchpad Bugs"] = { url = "https://launchpad.net/bugs/${query}", icon="favicon", keyword="lp" },
        }
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

-- Load various modules from ~/.hammerspoon/ depending on which machine this is
if (hostname == "fuyo") then
    -- I like to have some little traffic light coloured dots in the bottom right corner of my screen
    -- to show various status items. Like Geeklet
    statuslets = require("statuslets"):start()

    -- If the Philips Hue Motion Sensor in my office detects movement, make sure my iMac screens are awake
    hs.loadSpoon("Hue")
    hueTimer = nil
    spoon.Hue.sensorCallback = function(presence, sensor)
        day = tonumber(os.date("%w"))
        if day > 5 or day < 1 then
            print("Ignoring motion, it's the weekend")
            return
        end
        hour = tonumber(os.date("%H"))
        if hour < 9 or hour > 18 then
            print("Ignoring motion, it's not working hours")
            return
        end
        if presence then
            print("Motion detected on sensor: " .. sensor .. ". Declaring user activity")
            officeMotionActivityID = hs.caffeinate.declareUserActivity(officeMotionActivityID)
        end
    end
else
    statuslets = nil

    -- Display a menubar item to indicate if the Internet is reachable
    reachabilityMenuItem = require("reachabilityMenuItem"):start()
end

-- Define monitor names for layout purposes
display_imac = "iMac"
display_monitor = "Thunderbolt Display"

-- Define audio device names for headphone/speaker switching
headphoneDevice = "USB audio CODEC"
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
if (hostname == "fuyo") then
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
    {"IRC",               nil,          display_monitor, hs.geometry.unitrect(0, 0.5, 0.375, 0.5), nil, nil},
    {"Reeder",            nil,          display_monitor, hs.geometry.unitrect(0.75, 0, 0.25, 0.5),   nil, nil},
    {"Safari",            nil,          display_imac,    hs.geometry.unitrect(0.5, 0, 0.5, 0.5),    nil, nil},
    {"Kiwi for Gmail",    nil,          display_imac,    hs.geometry.unitrect(0.5, 0.5, 0.5, 0.5), nil, nil},
    {"Trello",            nil,          display_imac,    hs.geometry.unitrect(0.5, 0.5, 0.5, 0.5), nil, nil},
    {"Mail",              nil,          display_imac,    hs.geometry.unitrect(0, 0.5, 0.5, 0.5),   nil, nil},
    {"Messages",          nil,          display_monitor, hs.geometry.unitrect(0, 0, 0.375, 0.25), nil, nil},
    {"Fantastical",       nil,          display_monitor, hs.geometry.unitrect(0.375, 0, 5/8, 0.5), nil, nil},
    {"Freeter",           nil,          display_monitor, hs.geometry.unitrect(0.375, 0.5, 5/8, 0.5), nil, nil},
}

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
    else
        speakers:setDefaultOutputDevice()
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
    hs.task.new("/usr/bin/sudo", function() end, {"/usr/libexec/ApplicationFirewall/socketfilterfw", "--setblockall", "off"})

    -- Mount my NAS
    hs.applescript.applescript([[
        tell application "Finder"
            try
                mount volume "smb://smbarchive@gnubert/media"
                mount volume "smb://smbarchive@gnubert/archive"
            end try
        end tell
    ]])
    if statuslets then
        statuslets:update()
    end
    hs.notify.new({
          title='Hammerspoon',
            informativeText='Mounted volumes, disabled firewall'
        }):send()
end

-- Perform tasks to configure the system for any WiFi network other than my home
function home_departed()
    hs.task.new("/usr/bin/sudo", function() end, {"/usr/libexec/ApplicationFirewall/socketfilterfw", "--setblockall", "on"})
    hs.applescript.applescript([[
        tell application "Finder"
            eject "Data"
        end tell
    ]])
    if statuslets then
        statuslets:update()
    end

    hs.notify.new({
          title='Hammerspoon',
            informativeText='Unmounted volumes, enabled firewall'
        }):send()
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

-- And now for hotkeys relating to Hyper. First, let's capture all of the functions, then we can just quickly iterate and bind them
hyperfns = {}

-- Hotkeys to resize windows absolutely
hyperfns["a"] = function() hs.window.focusedWindow():moveToUnit(hs.layout.left30) end
hyperfns["s"] = function() hs.window.focusedWindow():moveToUnit(hs.layout.right30) end
hyperfns['['] = function() hs.window.focusedWindow():moveToUnit(hs.layout.left50) end
hyperfns[']'] = function() hs.window.focusedWindow():moveToUnit(hs.layout.right50) end
hyperfns['f'] = toggle_window_maximized
hyperfns['r'] = function() hs.window.focusedWindow():toggleFullScreen() end

-- Hotkeys to trigger defined layouts
hyperfns['2'] = function() hs.layout.apply(dual_display) end

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

wifiWatcher = hs.wifi.watcher.new(ssidChangedCallback)
wifiWatcher:start()

usbWatcher = hs.usb.watcher.new(usbDeviceCallback)
usbWatcher:start()

if (hostname == "fuyo") then
    caffeinateWatcher = hs.caffeinate.watcher.new(caffeinateCallback)
    caffeinateWatcher:start()
end

configFileWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
configFileWatcher:start()

-- Make sure we have the right location settings
if hs.wifi.currentNetwork() == "chrul" then
    home_arrived()
else
    home_departed()
end

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
    if button == 12 and not isDown then
        spoon.StreamDeckAudioDeviceCycle:cycle()
    end
    if not isDown then
        audiodeviceWatchable["event"] = "WTF"
    end
end

function streamDeckDiscovery(isConnect, deck)
    --if deck:serialNumber() == "AL15G1A01664" then
    if deck:serialNumber() == "BL44H1B01314" then
        if isConnect then
            print("Stream Deck connected: "..tostring(deck))
            streamDeck = deck
            streamDeck:reset()
            streamDeck:buttonCallback(deckButtonEvent)
            spoon.StreamDeckMicMuter:start(streamDeck, 6)
            spoon.StreamDeckAudioDeviceCycle:start(streamDeck, 5)
        else
            print("Stream Deck disconnected")
            spoon.StreamDeckMicMuter:stop()
            spoon.StreamDeckAudioDeviceCycle:stop()
            streamDeck = nil
        end
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

hs.loadSpoon("StreamDeckMicMuter")
hs.loadSpoon("StreamDeckAudioDeviceCycle")
spoon.StreamDeckAudioDeviceCycle.devices = {
    ["USB audio CODEC"] = "headphone.png",
    ["Audioengine 2+  "] = "speaker.png",
    ["bosies"] = "bluetooth.png",
    ["Chris' AirPods"] = "airpod.png"
}
hs.streamdeck.init(streamDeckDiscovery)

krbRefresherTimer = hs.timer.doEvery(7200, function()
    if krbRefresherTask and krbRefresherTask:isRunning() then
        print("Terminating existing kinit process (which shouldn't be running)")
        krbRefresherTask:terminate()
    end
    print("Refreshing krb tickets. Will refresh again in 2 hours")
    krbRefresherTask = hs.task.new("/usr/bin/kinit", nil, {"-R"}):start()
end)

function karabinerCallback(eventName, params)
    print("Event: "..eventName)
    print(hs.inspect(params))
end

hs.urlevent.bind("karabiner", karabinerCallback)

if hs.console.darkMode() then
    hs.console.outputBackgroundColor({ white = 0 })
    hs.console.consolePrintColor({ white = 1 })
    hs.console.consoleResultColor({ white = 0.8 })
    hs.console.consoleCommandColor({ white = 1 })
end

hs.chooser.globalCallback = nil

--collectgarbage("setstepmul", 1000)
--collectgarbage("setpause", 1)

