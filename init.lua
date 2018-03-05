-- Enable this to do live debugging in ZeroBrane Studio
-- local ZBS = "/Applications/ZeroBraneStudio.app/Contents/ZeroBraneStudio"
-- package.path = package.path .. ";" .. ZBS .. "/lualibs/?/?.lua;" .. ZBS .. "/lualibs/?.lua"
-- package.cpath = package.cpath .. ";" .. ZBS .. "/bin/?.dylib;" .. ZBS .. "/bin/clibs53/?.dylib"
-- require("mobdebug").start()

--hs.crash.throwObjCException("lolception", "This was deliberate")
-- Print out more logging for me to see
require("hs.crash")
hs.crash.crashLogToNSLog = false

hs.window.animationDuration = 0.1
-- Trace all Lua code
function lineTraceHook(event, data)
    lineInfo = debug.getinfo(2, "Snl")
    print("TRACE: "..(lineInfo["short_src"] or "<unknown source>")..":"..(lineInfo["linedefined"] or "<??>"))
end
--debug.sethook(lineTraceHook, "l")

-- Seed the RNG
math.randomseed(os.time())

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
officeMotionWatcher = nil

-- Watchables
audiodeviceWatchable = nil

-- Other useful objects
streamDeck = nil

-- Load Seal - This is a pretty simple implementation of something like Alfred
hs.loadSpoon("Seal")
spoon.Seal:loadPlugins({"apps", "viscosity", "screencapture", "safari_bookmarks", "calc", "urls"})
spoon.Seal:bindHotkeys({show={{"cmd"}, "Space"}})
spoon.Seal:start()

-- I always end up losing my mouse pointer, particularly if it's on a monitor full of terminals.
-- This draws a bright red circle around the pointer for a few seconds
hs.loadSpoon("MouseCircle")
spoon.MouseCircle:bindHotkeys({show={hyper, "d"}})

-- Replace Caffeine.app with 18 lines of Lua :D
hs.loadSpoon("Caffeine")
spoon.Caffeine:bindHotkeys({toggle={hyper, "c"}})
spoon.Caffeine:start()

-- Draw pretty rounded corners on all screens
hs.loadSpoon("RoundedCorners")
spoon.RoundedCorners:start()

-- Load various modules from ~/.hammerspoon/ depending on which machine this is
if (hostname == "pixukipa") then
    -- I like to have some little traffic light coloured dots in the bottom right corner of my screen
    -- to show various status items. Like Geeklet
    statuslets = require("statuslets"):start()

    -- If the Philips Hue Motion Sensor in my office detects movement, make sure my iMac screens are awake
    officeMotionWatcher = require("officeMotion"):init()
else
    statuslets = nil
    officeMotionWatcher = nil

    -- Display a menubar item to indicate if the Internet is reachable
    reachabilityMenuItem = require("reachabilityMenuItem"):start()
end

-- Define monitor names for layout purposes
display_imac = "iMac"
display_monitor = "Thunderbolt Display"

-- Define audio device names for headphone/speaker switching
headphoneDevice = "Turtle Beach USB Audio"
speakerDevice = "Audioengine 2+  "

-- Defines for WiFi watcher
homeSSID = "chrul" -- My home WiFi SSID
lastSSID = hs.wifi.currentNetwork()

-- Defines for screen watcher
lastNumberOfScreens = #hs.screen.allScreens()

-- Defines for caffeinate watcher
shouldUnmuteOnScreenWake = nil

-- Defines for window grid
if (hostname == "pixukipa") then
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
            informativeText='Default output device:'..hs.audiodevice.defaultOutputDevice():name()
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
                streamDeck:setButtonImage(5, appIcon)
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
        if officeMotionWatcher then
            officeMotionWatcher:start()
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

        if officeMotionWatcher then
            officeMotionWatcher:stop()
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
                mount volume "smb://smbarchive@gnubert.local/media"
                mount volume "smb://smbarchive@gnubert.local/archive"
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
hyperfns['z'] = function() toggle_application("Reeder") end
hyperfns['w'] = function() toggle_application("IRC") end

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

if (hostname == "pixukipa") then
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

-- This is some developer debugging stuff. It will cause Hammerspoon to crash if any Lua is being executed on the wrong thread. You probably don't want this in your config :)
-- local function crashifnotmain(reason)
-- --  print("crashifnotmain called with reason", reason) -- may want to remove this, very verbose otherwise
--   if not hs.crash.isMainThread() then
--     print("not in main thread, crashing")
--     hs.crash.crash()
--   end
-- end
-- debug.sethook(crashifnotmain, 'c')

--collectgarbage("setstepmul", 1000)
--collectgarbage("setpause", 1)

--local wfRedshift=hs.window.filter.new({loginwindow={visible=true,allowRoles='*'}},'wf-redshift')
--hs.redshift.start(2000,'20:00','7:00','3h',false,wfRedshift)

function updateWallpaperFromData(data)
    local f = io.open("/Users/cmsj/.hammerspoon/wallpaper.png", "w")
    f:write(data)
    --hs.fnutils.each(hs.screen.allScreens(), function(screen) screen:screen_desktopImageURL("file:///Users/cmsj/.hammerspoon/wallpaper.png") end)
end

function fetchNewWallpaper()
    hs.http.asyncGet("https://api.unsplash.com/photos/random", {Authorization="Client-ID 927e389a0222f70e17988711d2fe665ca82b5c4e8e7caacdb2e17cc515c2eee3"}, function(code,body,headers)
        if code == 200 then
            local url = hs.json.decode(body)["urls"]["raw"]
            print("Fetching image: "..url)
            hs.http.asyncGet(url, nil, function(code,image,headers)
                print("Code: "..code)
                print("Headers: "..hs.inspect(headers))
                print("Body: "..image)
                if code == 200 then
                    updateWallpaperFromData(image)
                end
            end)
        end
    end)
end

--rwp_timer = hs.timer.new(600, function() fetchNewWallpaper() end):start()

function deckButtonEvent(deck, button, isDown)
    print("deckButtonEvent: "..button.." isDown: "..(isDown and "YES" or "NO"))
    if button == 11 and not isDown then
        spoon.StreamDeckMicMuter:toggleMute()
--     elseif isDown then
--         --deck:setButtonColor(button, hs.drawing.color.definedCollections.x11.purple)
--         deck:setButtonImage(button, hs.image.imageFromPath("/Users/cmsj/Desktop/CB0742.06.V1.M1.png"))
--     else
--         deck:setButtonImage(button, hs.image.imageFromName(hs.image.systemImageNames.Folder))
    end
    if not isDown then
        audiodeviceWatchable["event"] = "WTF"
    end
end

function streamDeckDiscovery(isConnect, deck)
    if isConnect then
        print("Stream Deck connected: "..tostring(deck))
        streamDeck = deck
        streamDeck:reset()
        streamDeck:buttonCallback(deckButtonEvent)
        spoon.StreamDeckMicMuter:start(streamDeck, 11)
    else
        print("Stream Deck disconnected")
        spoon.StreamDeckMicMuter:stop()
        streamDeck = nil
    end
end

audiodeviceWatchable = hs.watchable.new("audiodevice", true)
function audiodeviceDeviceCallback(event)
    print("audiodeviceDeviceCallback: "..event)
    -- Force the internal mic to always remain the default input device
    if event == "dIn " then
        print("Forcing default input to Internal Microphone")
        hs.timer.doAfter(2, function() hs.audiodevice.findInputByName("Built-in Microphone"):setDefaultInputDevice() end)
    end
    audiodeviceWatchable["event"] = event
end
hs.audiodevice.watcher.setCallback(audiodeviceDeviceCallback)
hs.audiodevice.watcher.start()

hs.loadSpoon("StreamDeckMicMuter")
hs.streamdeck.init(streamDeckDiscovery)

