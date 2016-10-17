-- Seed the RNG
math.randomseed(os.time())

-- Capture the hostname, so we can make this config behave differently across my Macs
hostname = hs.host.localizedName()

-- Ensure the IPC command line client is available
hs.ipc.cliInstall()

-- Watchers and other useful objects
configFileWatcher = nil
wifiWatcher = nil
screenWatcher = nil
usbWatcher = nil
caffeinateWatcher = nil
appWatcher = nil

mouseCircle = nil
mouseCircleTimer = nil

statusletTimer = nil
firewallStatusText = nil
firewallStatusDot = nil
cccStatusText = nil
cccStatusDot = nil
arqStatusText = nil
arqStatusDot = nil

officeMotionWatcher = nil
officeMotionWatcherID = nil

-- Define some keyboard modifier variables
-- (Node: Capslock bound to cmd+alt+ctrl+shift via Seil and Karabiner)
hyper = {"⌘", "⌥", "⌃", "⇧"}

-- Define monitor names for layout purposes
display_imac = "iMac"
display_monitor = "Thunderbolt Display"

-- Define audio device names for headphone/speaker switching
headphoneDevice = "Turtle Beach USB Audio"
speakerDevice = "Audioengine 2_  "

-- Defines for WiFi watcher
homeSSID = "chrul" -- My home WiFi SSID
lastSSID = hs.wifi.currentNetwork()

-- Defines for screen watcher
lastNumberOfScreens = #hs.screen.allScreens()

-- Defines for caffeinate watcher
shouldUnmuteOnScreenWake = nil

-- Defines for window grid
hs.grid.GRIDWIDTH = 8
hs.grid.GRIDHEIGHT = 8
hs.grid.MARGINX = 0
hs.grid.MARGINY = 0

-- Defines for window maximize toggler
frameCache = {}

-- Define window layouts
--   Format reminder:
--     {"App name", "Window name", "Display Name", "unitrect", "framerect", "fullframerect"},
iTunesMiniPlayerLayout = {"iTunes", "MiniPlayer", display_imac, nil, nil, hs.geometry.rect(0, -48, 400, 48)}
internal_display = {
    {"IRC",               nil,          display_imac, hs.layout.maximized, nil, nil},
    {"Reeder",            nil,          display_imac, hs.layout.left30,    nil, nil},
    {"Safari",            nil,          display_imac, hs.layout.maximized, nil, nil},
    {"OmniFocus",         nil,          display_imac, hs.layout.maximized, nil, nil},
    {"Mail",              nil,          display_imac, hs.layout.maximized, nil, nil},
    {"Microsoft Outlook", nil,          display_imac, hs.layout.maximized, nil, nil},
    {"HipChat",           nil,          display_imac, hs.layout.maximized, nil, nil},
    {"1Password",         nil,          display_imac, hs.layout.maximized, nil, nil},
    {"Calendar",          nil,          display_imac, hs.layout.maximized, nil, nil},
    {"Messages",          nil,          display_imac, hs.layout.maximized, nil, nil},
    {"Evernote",          nil,          display_imac, hs.layout.maximized, nil, nil},
    {"iTunes",            "iTunes",     display_imac, hs.layout.maximized, nil, nil},
    iTunesMiniPlayerLayout,
}

dual_display = {
    {"IRC",               nil,          display_monitor, hs.geometry.unitrect(0, 0.5, 3/8, 0.5), nil, nil},
    {"Reeder",            nil,          display_monitor, hs.geometry.unitrect(0.75, 0, 0.25, 0.95),   nil, nil},
    {"Safari",            nil,          display_imac,    hs.geometry.unitrect(0.5, 0, 0.5, 6/8),    nil, nil},
    {"OmniFocus",         "RedHat",     display_monitor, hs.geometry.unitrect(3/8, 0, 3/8, 0.5),   nil, nil},
    {"OmniFocus",         "Forecast",   display_monitor, hs.geometry.unitrect(3/8, 0.5, 3/8, 0.5),   nil, nil},
    {"Mail",              nil,          display_imac,    hs.geometry.unitrect(0, 0.5, 0.5, 0.5),   nil, nil},
    {"Microsoft Outlook", nil,          display_imac,    hs.geometry.unitrect(0, 0, 0.5, 0.5),    nil, nil},
    {"HipChat",           nil,          display_monitor, hs.geometry.unitrect(0, 0, 3/8, 0.25), nil, nil},
    {"Messages",          nil,          display_monitor, hs.geometry.unitrect(0, 0, 3/8, 0.25), nil, nil},
}

-- Helper functions

-- Replace Caffeine.app with 18 lines of Lua :D
caffeine = hs.menubar.new()

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

-- Draw little text/dot pairs in the bottom right corner of the primary display, to indicate firewall/backup status of my machine
function renderStatuslets()
    if (hostname ~= "pixukipa") then
        return
    end
    -- Destroy existing Statuslets
    if firewallStatusText then firewallStatusText:delete() end
    if firewallStatusDot then firewallStatusDot:delete() end
    if cccStatusText then cccStatusText:delete() end
    if cccStatusDot then cccStatusDot:delete() end
    if arqStatusText then arqStatusText:delete() end
    if arqStatusDot then arqStatusDot:delete() end

    -- Defines for statuslets - little coloured dots in the corner of my screen that give me status info, see:
    -- https://www.dropbox.com/s/3v2vyhi1beyujtj/Screenshot%202015-03-11%2016.13.25.png?dl=0
    local initialScreenFrame = hs.screen.allScreens()[1]:fullFrame()

    -- Start off by declaring the size of the text/circle objects and some anchor positions for them on screen
    local statusDotWidth = 10
    local statusTextWidth = 30
    local statusTextHeight = 15
    local statusText_x = initialScreenFrame.x + initialScreenFrame.w - statusDotWidth - statusTextWidth
    local statusText_y = initialScreenFrame.y + initialScreenFrame.h - statusTextHeight
    local statusDot_x = initialScreenFrame.x + initialScreenFrame.w - statusDotWidth
    local statusDot_y = statusText_y

    -- Now create the text/circle objects using the sizes/positions we just declared (plus a little fudging to make it all align properly)
    firewallStatusText = hs.drawing.text(hs.geometry.rect(statusText_x + 5,
                                                          statusText_y - (statusTextHeight*2) + 2,
                                                          statusTextWidth,
                                                          statusTextHeight), "FW:")
    cccStatusText = hs.drawing.text(hs.geometry.rect(statusText_x,
                                                     statusText_y - statusTextHeight + 1,
                                                     statusTextWidth,
                                                     statusTextHeight), "CCC:")
    arqStatusText = hs.drawing.text(hs.geometry.rect(statusText_x + 4,
                                                     statusText_y,
                                                     statusTextWidth,
                                                     statusTextHeight), "Arq:")

    firewallStatusDot = hs.drawing.circle(hs.geometry.rect(statusDot_x,
                                                           statusDot_y - (statusTextHeight*2) + 4,
                                                           statusDotWidth,
                                                           statusDotWidth))
    cccStatusDot = hs.drawing.circle(hs.geometry.rect(statusDot_x,
                                                      statusDot_y - statusTextHeight + 3,
                                                      statusDotWidth,
                                                      statusDotWidth))
    arqStatusDot = hs.drawing.circle(hs.geometry.rect(statusDot_x,
                                                      statusDot_y + 2,
                                                      statusDotWidth,
                                                      statusDotWidth))

    -- Finally, configure the rendering style of the text/circle objects, clamp them to the desktop, and show them
    firewallStatusText:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setTextSize(11):sendToBack():show(0.5)
    cccStatusText:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setTextSize(11):sendToBack():show(0.5)
    arqStatusText:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setTextSize(11):sendToBack():show(0.5)

    firewallStatusDot:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setFillColor(hs.drawing.color.osx_yellow):setStroke(false):sendToBack():show(0.5)
    cccStatusDot:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setFillColor(hs.drawing.color.osx_yellow):setStroke(false):sendToBack():show(0.5)
    arqStatusDot:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setFillColor(hs.drawing.color.osx_yellow):setStroke(false):sendToBack():show(0.5)
end


-- Callback function for application events
function applicationWatcher(appName, eventType, appObject)
    if (eventType == hs.application.watcher.activated) then
        if (appName == "Finder") then
            -- Bring all Finder windows forward when one gets activated
            appObject:selectMenuItem({"Window", "Bring All to Front"})
        elseif (appName == "iTunes") then
            -- Ensure the MiniPlayer window is visible and correctly placed, since it likes to hide an awful lot
            state = appObject:findMenuItem({"Window", "MiniPlayer"})
            if state and not state["ticked"] then
                appObject:selectMenuItem({"Window", "MiniPlayer"})
            end
            _animationDuration = hs.window.animationDuration
            hs.window.animationDuration = 0
            hs.layout.apply({ iTunesMiniPlayerLayout })
            hs.window.animationDuration = _animationDuration
        end
    elseif (eventType == hs.application.watcher.launching) then
        if (appName == "Call of Duty: Modern Warfare 3") then
            print("CoD Starting")
            hs.itunes.pause()
            local tbDisplay = hs.screen.findByName("Thunderbolt Display")
            if (tbDisplay) then
                tbDisplay:setPrimary()
            end
        end
    elseif (eventType == hs.application.watcher.terminated) then
        if (appName == "Call of Duty: Modern Warfare 3") then
            print("CoD Stopping")
            local mbDisplay = hs.screen.findByName("Color LCD")
            if (mbDisplay) then
                mbDisplay:setPrimary()
            end
            if hs.screen.findByName("Thunderbolt Display") then
                hs.layout.apply(dual_display)
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
end

-- Callback function for caffeinate events
function caffeinateCallback(eventType)
    if (eventType == hs.caffeinate.watcher.screensDidSleep) then
        if hs.itunes.isPlaying() then
            hs.itunes.pause()
        end
        local output = hs.audiodevice.defaultOutputDevice()
        if output:muted() then
            shouldUnmuteOnScreenWake = false
        else
            shouldUnmuteOnScreenWake = true
        end
        output:setMuted(true)
        hs.timer.doAfter(10, function() officeMotionWatcher:start() end)
    elseif (eventType == hs.caffeinate.watcher.screensDidWake) then
        if shouldUnmuteOnScreenWake then
            hs.audiodevice.defaultOutputDevice():setMuted(false)
        end
        officeMotionWatcher:stop()
    end
end

-- Callback function for changes in screen layout
function screensChangedCallback()
    print("screensChangedCallback")
    newNumberOfScreens = #hs.screen.allScreens()

    -- FIXME: This is awful if we swap primary screen to the external display. all the windows swap around, pointlessly.
    if lastNumberOfScreens ~= newNumberOfScreens then
        if newNumberOfScreens == 1 then
            hs.layout.apply(internal_display)
        elseif newNumberOfScreens == 2 then
            hs.layout.apply(dual_display)
        end
    end

    lastNumberOfScreens = newNumberOfScreens

    renderStatuslets()
    triggerStatusletsUpdate()
end

-- Perform tasks to configure the system for my home WiFi network
function home_arrived()
--    hs.audiodevice.defaultOutputDevice():setVolume(25)

    -- Note: sudo commands will need to have been pre-configured in /etc/sudoers, for passwordless access, e.g.:
    -- cmsj ALL=(root) NOPASSWD: /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall *
    hs.task.new("/usr/bin/sudo", function() end, {"/usr/libexec/ApplicationFirewall/socketfilterfw", "--setblockall", "off"})

    -- Mount my mac mini's DAS
    hs.applescript.applescript([[
        tell application "Finder"
            try
                mount volume "smb://cmsj@servukipa._smb._tcp.local/Data"
            end try
        end tell
    ]])
    triggerStatusletsUpdate()
    hs.notify.new({
          title='Hammerspoon',
            informativeText='Unmuted volume, mounted volumes, disabled firewall'
        }):send()
end

-- Perform tasks to configure the system for any WiFi network other than my home
function home_departed()
    hs.audiodevice.defaultOutputDevice():setVolume(0)
    hs.task.new("/usr/bin/sudo", function() end, {"/usr/libexec/ApplicationFirewall/socketfilterfw", "--setblockall", "on"})
    hs.applescript.applescript([[
        tell application "Finder"
            eject "Data"
        end tell
    ]])
    triggerStatusletsUpdate()

    hs.notify.new({
          title='Hammerspoon',
            informativeText='Muted volume, unmounted volumes, enabled firewall'
        }):send()
end

function statusletCallbackFirewall(code, stdout, stderr)
    local color

    if string.find(stdout, "block all non-essential") then
        color = hs.drawing.color.osx_green
    else
        color = hs.drawing.color.osx_red
    end

    firewallStatusDot:setFillColor(color)
end

function statusletCallbackCCC(code, stdout, stderr)
    local color

    if code == 0 then
        color = hs.drawing.color.osx_green
    else
        color = hs.drawing.color.osx_red
    end

    cccStatusDot:setFillColor(color)
end

function statusletCallbackArq(code, stdout, stderr)
    local color

    if code == 0 then
        color = hs.drawing.color.osx_green
    else
        color = hs.drawing.color.osx_red
    end

    arqStatusDot:setFillColor(color)
end

function triggerStatusletsUpdate()
    if (hostname ~= "pixukipa") then
        return
    end
    print("triggerStatusletsUpdate")
    hs.task.new("/usr/bin/sudo", statusletCallbackFirewall, {"/usr/libexec/ApplicationFirewall/socketfilterfw", "--getblockall"}):start()
    hs.task.new("/usr/bin/grep", statusletCallbackCCC, {"-q", os.date("%d/%m/%Y"), os.getenv("HOME").."/.cccLast"}):start()
    hs.task.new("/usr/bin/grep", statusletCallbackArq, {"-q", "Arq.*finished backup", "/var/log/system.log"}):start()
end

-- I always end up losing my mouse pointer, particularly if it's on a monitor full of terminals.
-- This draws a bright red circle around the pointer for a few seconds
function mouseHighlight()
    if mouseCircle then
        mouseCircle:delete()
        if mouseCircleTimer then
            mouseCircleTimer:stop()
        end
    end
    mousepoint = hs.mouse.getAbsolutePosition()
    mouseCircle = hs.drawing.circle(hs.geometry.rect(mousepoint.x-40, mousepoint.y-40, 80, 80))
    mouseCircle:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    mouseCircle:setFill(false)
    mouseCircle:setStrokeWidth(5)
    mouseCircle:bringToFront(true)
    mouseCircle:show(0.5)

    mouseCircleTimer = hs.timer.doAfter(3, function()
        mouseCircle:hide(0.5)
        hs.timer.doAfter(0.6, function() mouseCircle:delete() end)
    end)
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

-- URL director
-- This makes Hammerspoon take over as the default http/https handler
-- Whenever a URL is opened, Hammerspoon will draw all of the app icons which can handle URLs and let the user choose where to direct the URL
--hs.urlevent.httpCallback = function(scheme, host, params, fullURL)
--    print("URL Director: "..fullURL)
--
--    local screen = hs.screen.mainScreen():frame()
--    local handlers = hs.urlevent.getAllHandlersForScheme(scheme)
--    local numHandlers = #handlers
--    local modalKeys = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
--                       "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
--                       "A", "S", "D", "F", "G", "H", "J", "K", "L",
--                       "Z", "X", "C", "V", "B", "N", "M"}
--
--    local boxBorder = 10
--    local iconSize = 96
--
--    if numHandlers > 0 then
--        local appIcons = {}
--        local appNames = {}
--        local modalDirector = hs.hotkey.modal.new()
--        local x = screen.x + (screen.w / 2) - (numHandlers * iconSize / 2)
--        local y = screen.y + (screen.h / 2) - (iconSize / 2)
--        local box = hs.drawing.rectangle(hs.geometry.rect(x - boxBorder, y - (boxBorder * 3), (numHandlers * iconSize) + (boxBorder * 2), iconSize + (boxBorder * 5)))
--        box:setFillColor({["red"]=0,["blue"]=0,["green"]=0,["alpha"]=0.5}):setFill(true):show()
--        local header = hs.drawing.text(hs.geometry.rect(x, y - (boxBorder * 2), (numHandlers * iconSize), boxBorder * 2), fullURL)
--        header:setTextStyle({["size"]=12,["color"]={["red"]=1,["blue"]=1,["green"]=1,["alpha"]=1},["alignment"]="center",["lineBreak"]="truncateMiddle"})
--        header:orderAbove(box)
--        header:show()
--
--        local exitDirector = function(bundleID, url)
--            if (bundleID and url) then
--                hs.urlevent.openURLWithBundle(url, bundleID)
--            end
--            for _,icon in pairs(appIcons) do
--                icon:delete()
--            end
--            for _,name in pairs(appNames) do
--                name:delete()
--            end
--            header:delete()
--            box:delete()
--            modalDirector:exit()
--        end
--
--        for num,handler in pairs(handlers) do
--            local appIcon = hs.drawing.appImage(hs.geometry.size(iconSize, iconSize), handler)
--            if appIcon then
--                local appName = hs.drawing.text(hs.geometry.size(iconSize, boxBorder), modalKeys[num].." "..hs.application.nameForBundleID(handler))
--
--                table.insert(appIcons, appIcon)
--                table.insert(appNames, appName)
--
--                appIcon:setTopLeft(hs.geometry.point(x + ((num - 1) * iconSize), y))
--                appIcon:setClickCallback(function() exitDirector(handler, fullURL) end)
--                appIcon:orderAbove(box)
--                appIcon:show()
--
--                appName:setTopLeft(hs.geometry.point(x + ((num - 1) * iconSize), y + iconSize))
--                appName:setTextStyle({["size"]=10,["color"]={["red"]=1,["blue"]=1,["green"]=1,["alpha"]=1},["alignment"]="center",["lineBreak"]="truncateMiddle"})
--                appName:orderAbove(box)
--                appName:show()
--
--                modalDirector:bind({}, modalKeys[num], function() exitDirector(handler, fullURL) end)
--            end
--        end
--
--        modalDirector:bind({}, "Escape", exitDirector)
--        modalDirector:enter()
--    end
--end
--hs.urlevent.setDefaultHandler('http')
--hs.urlevent.setRestoreHandler('http', 'com.apple.Safari')

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

-- Hotkeys to move windows between screens, retaining their position/size relative to the screen
--hs.urlevent.bind('hyperfnleft', function() hs.window.focusedWindow():moveOneScreenWest() end)
--hs.urlevent.bind('hyperfnright', function() hs.window.focusedWindow():moveOneScreenEast() end)

-- Hotkeys to resize windows absolutely
hs.hotkey.bind(hyper, 'a', function() hs.window.focusedWindow():moveToUnit(hs.layout.left30) end)
hs.hotkey.bind(hyper, 's', function() hs.window.focusedWindow():moveToUnit(hs.layout.right70) end)
hs.hotkey.bind(hyper, '[', function() hs.window.focusedWindow():moveToUnit(hs.layout.left50) end)
hs.hotkey.bind(hyper, ']', function() hs.window.focusedWindow():moveToUnit(hs.layout.right50) end)
hs.hotkey.bind(hyper, 'f', toggle_window_maximized)
hs.hotkey.bind(hyper, 'r', function() hs.window.focusedWindow():toggleFullScreen() end)

-- Hotkeys to trigger defined layouts
hs.hotkey.bind(hyper, '1', function() hs.layout.apply(internal_display) end)
hs.hotkey.bind(hyper, '2', function() hs.layout.apply(dual_display) end)

-- Hotkeys to interact with the window grid
hs.hotkey.bind(hyper, 'g', hs.grid.show)
hs.hotkey.bind(hyper, 'Left', hs.grid.pushWindowLeft)
hs.hotkey.bind(hyper, 'Right', hs.grid.pushWindowRight)
hs.hotkey.bind(hyper, 'Up', hs.grid.pushWindowUp)
hs.hotkey.bind(hyper, 'Down', hs.grid.pushWindowDown)

hs.urlevent.bind('hypershiftleft', function() hs.grid.resizeWindowThinner(hs.window.focusedWindow()) end)
hs.urlevent.bind('hypershiftright', function() hs.grid.resizeWindowWider(hs.window.focusedWindow()) end)
hs.urlevent.bind('hypershiftup', function() hs.grid.resizeWindowShorter(hs.window.focusedWindow()) end)
hs.urlevent.bind('hypershiftdown', function() hs.grid.resizeWindowTaller(hs.window.focusedWindow()) end)

-- Application hotkeys
hs.hotkey.bind(hyper, 'e', function() toggle_application("iTerm2") end)
hs.hotkey.bind(hyper, 'q', function() toggle_application("Safari") end)
hs.hotkey.bind(hyper, 'z', function() toggle_application("Reeder") end)
hs.hotkey.bind(hyper, 'w', function() toggle_application("IRC") end)

-- Misc hotkeys
hs.hotkey.bind(hyper, 'y', hs.toggleConsole)
hs.hotkey.bind(hyper, 'n', function() hs.task.new("/usr/bin/open", nil, {os.getenv("HOME")}):start() end)
hs.hotkey.bind(hyper, 'c', caffeineClicked)
hs.hotkey.bind(hyper, 'Escape', toggle_audio_output)
hs.hotkey.bind(hyper, 'm', function()
    device = hs.audiodevice.defaultInputDevice()
    device:setMuted(not device:muted())
end)
hs.hotkey.bind(hyper, 'd', mouseHighlight)
hs.hotkey.bind(hyper, 'u', typeCurrentSafariURL)
hs.hotkey.bind(hyper, '0', function()
    print(configFileWatcher)
    print(wifiWatcher)
    print(screenWatcher)
    print(usbWatcher)
    print(caffeinateWatcher)
end)

-- Type the current clipboard, to get around web forms that don't let you paste
-- (Note: I have Fn-v mapped to F17 in Karabiner)
hs.urlevent.bind('fnv', function() hs.eventtap.keyStrokes(hs.pasteboard.getContents()) end)

-- Create and start our callbacks
appWatcher = hs.application.watcher.new(applicationWatcher):start()

screenWatcher = hs.screen.watcher.new(screensChangedCallback)
screenWatcher:start()

wifiWatcher = hs.wifi.watcher.new(ssidChangedCallback)
wifiWatcher:start()

if (hostname == "pixukipa") then
    usbWatcher = hs.usb.watcher.new(usbDeviceCallback)
    usbWatcher:start()

    caffeinateWatcher = hs.caffeinate.watcher.new(caffeinateCallback)
    caffeinateWatcher:start()
end

-- Render our statuslets, trigger a timer to update them regularly, and do an initial update
renderStatuslets()
statusletTimer = hs.timer.new(hs.timer.minutes(5), triggerStatusletsUpdate)
statusletTimer:start()
triggerStatusletsUpdate()

configFileWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
configFileWatcher:start()

-- Make sure we have the right location settings
if hs.wifi.currentNetwork() == "chrul" then
    home_arrived()
else
    home_departed()
end

-- Start the office motion sensor
officeMotionWatcher = require("hueMotionSensor")
officeMotionWatcher.userCallback = function(presence)
    if presence then
        print("Motion detected in Office, declaring user activity")
        officeMotionWatcherID = hs.caffeinate.declareUserActivity(officeMotionWatcherID)
    end
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

collectgarbage("setstepmul", 1000)
collectgarbage("setpause", 1)

--local wfRedshift=hs.window.filter.new({loginwindow={visible=true,allowRoles='*'}},'wf-redshift')
--hs.redshift.start(2000,'20:00','7:00','3h',false,wfRedshift)

