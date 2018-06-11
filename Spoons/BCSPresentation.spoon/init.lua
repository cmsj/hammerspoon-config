local obj = { __gc = true }
setmetatable(obj, obj)
obj.__gc = function(t)
    t:endPresentation()
end

-- Metadata
obj.name = "BCSPresentation"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/presentation"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

function obj:init()
    -- Preload the modules we're going to need
    require("hs.chooser")
    require("hs.webview")
    require("hs.drawing")
    -- Create a menubar object to initiate the presentation
    self.presentationControl = hs.menubar.new()
    --presentationControl:setIcon(hs.image.imageFromName(hs.image.systemImageNames["EnterFullScreenTemplate"]))
    self.presentationControl:setIcon(hs.image.imageFromName("NSComputer"))
    self.presentationControl:setMenu({{ title = "Start Presentation", fn = obj.setupPresentation }})
end

-- Storage for persistent screen objects
obj.presentationControl = nil
obj.presentationScreen = nil
obj.screenFrame = nil
obj.slideBackground = nil
obj.slideHeader = nil
obj.slideBody = nil
obj.slideFooter = nil
obj.slideModal = nil

-- Configuration for persistent screen objects
obj.slideHeaderFont = nil
obj.slideHeaderSize = nil
obj.slideBodyFont = nil
obj.slideBodySize = nil
obj.slideFooterFont = nil
obj.slideFooterSize = nil

-- Metadata for slide progression
obj.startSlide = 1
obj.currentSlide = 0

-- Storage for transient screen objects
obj.refs = {}

function obj.get_right_frame(frame)
    local x = frame["x"] + ((frame["w"] - 100)*0.66) + 10
    local y = obj.slideHeader:frame()["y"] + obj.slideHeader:frame()["h"] + 10
    local w = ((frame["w"] - 100)*0.33) - 10
    local h = obj.slideBody:frame()["h"]
    return x, y, w, h
end

function obj.get_body_frame(frame)
    local x = frame["x"] + 50
    local y = obj.slideHeader:frame()["y"] + obj.slideHeader:frame()["h"] + 10
    local w = (frame["w"] - 100)
    local h = (frame["h"] / 10) * 8 - (frame["h"] / 12)
    return x, y, w, h
end

function obj.makecodeview(name, place, code)
    if obj.refs[name] then
        return obj.refs[name]
    else
        print("Creating codeview "..name)
        local frame = obj.screenFrame
        local codeViewRect
        if place == "right" then
            codeViewRect = hs.geometry.rect(obj.get_right_frame(frame))
        elseif place == "body" then
            codeViewRect = hs.geometry.rect(obj.get_body_frame(frame))
        end
        local codeView = hs.drawing.text(codeViewRect, code)
        codeView:setTextFont("SF Mono")
        codeView:setTextSize(obj.slideBodySize)
        codeView:setTextColor(hs.drawing.color.x11.black)
        codeView:setFillColor(hs.drawing.color.x11.white)
        obj.refs[name] = codeView
        return codeView
    end
end

function obj.makewebview(name, place, url, html)
    if obj.refs[name] then
        return obj.refs[name]
    else
        print("Creating webview "..name)
        local frame = obj.screenFrame
        local webViewRect
        if place == "right" then
            webViewRect = hs.geometry.rect(obj.get_right_frame(frame))
        elseif place == "body" then
            webViewRect = hs.geometry.rect(obj.get_body_frame(frame))
        end
        local webview = hs.webview.new(webViewRect)
        webview:setLevel(hs.drawing.windowLevels["normal"]+1)
        if url then
            webview:url(url)
        elseif html then
            webview:html(html)
        else
            webview:html("NO CONTENT!")
        end
        obj.refs[name] = webview
        return webview
    end
end

-- Definitions of the slides
obj.slides = {
    {
        ["header"] = "Hammerspoon",
        ["body"] = [[Staggeringly powerful macOS desktop automation.

Thanks for coming!]],
    },
    {
        ["header"] = "Agenda",
        ["body"] = [[We will cover:
 • History of automation on Apple computers
 • Our journey to creating Hammerspoon
 • How the app works
 • Impressive demos]]
    },
    {
        ["header"] = "History of Apple automation",
        ["body"] = [[Strong history:
 • 1991 - Apple Events (System 7)
   • Foundation of much of what comes later
 • 1993 - AppleScript (System 7.1.1)
   • Becomes de-rigeur for apps
 • 2005 - Automator (OS X 10.4)
   • User applications, Folder Actions, System Services
 • 2007 - ScriptingBridge (OS X 10.5)
   • AppleScript power for JS, Python and Ruby
 • 1991 onwards - Third Parties
   • AppleScritp libraries
   • Keyboard Maestro
   • Many small utilities]]
    },
    {
        ["header"] = "Apple Events",
        ["enterFn"] = function()
            local codeview = obj.makecodeview("appleEventsCodeView", "right", [[typedef FourCharCode DescType;
typedef struct OpaqueAEDataStorageType*  AEDataStorageType;

struct AEDesc {
  DescType            descriptorType;
  AEDataStorage       dataHandle;
};]])
            codeview:show(0.3)
        end,
        ["exitFn"] = function()
            local codeview = obj.refs["appleEventsCodeView"]
            codeview:hide(0.2)
        end,
        ["body"] = [[Very simple type:
• Four character code (e.g. "appa")
• Opaque pointer to arbitrary data]]
    },
    {
        ["header"] = "History",
        ["body"] = [[Hammerspoon is a fork of Mjolnir by Steven Degutis. Mjolnir aims to be a very minimal application, with its extensions hosted externally and managed using a Lua package manager. We wanted to provide a more integrated experience.]]
    },
    {
        ["header"] = "A comparison",
        ["enterFn"] = function()
            local webview = obj.makewebview("comparisonSlideWebview", "body", "https://github.com/sdegutis/mjolnir#mjolnir-vs-other-apps", nil)
            webview:show(0.3)
        end,
        ["exitFn"] = function()
            local webview = obj.refs["comparisonSlideWebview"]
            webview:hide(0.2)
        end,
    },
    {
        ["header"] = "So what is it for",
        ["body"] = [[• Window management
• Reacting to all kinds of events
  • WiFi, USB, path/file changes
• Interacting with applications (menus)
• Drawing custom interfaces on the screen
• URL handling/mangling]]
    },
    {
        ["header"] = "Responding to WiFi events",
        ["enterFn"] = function()
          local webview = obj.makewebview("wifiwatcherSlideWebview", "body", nil, [[<pre>
wifiwatcher = hs.wifi.watcher.new(function()
  print"wifiwatcher fired"
  local network = hs.wifi.currentNetwork()
  if network then
    hs.alert("joined wifi network "..network)
  else
    hs.alert("wifi disconnected")
  end
  if network == "Fibonacci" then
    hs.application.launchOrFocus("Twitter")
  else
    local app = hs.application.get("Twitter")
    if app then
      app:kill9()
    end
  end
end)
wifiwatcher:start()
</pre>]])
          webview:show(0.3)
        end,
        ["exitFn"] = function()
          local webview = obj.refs["wifiwatcherSlideWebview"]
          webview:hide(0.2)
        end
    },
    {
        ["header"] = "Handling URL events",
        ["enterFn"] = function()
            local webview = obj.makewebview("URLSlideWebview", "body", nil, '<img src="https://cloud.githubusercontent.com/assets/353427/9669248/c37c6f26-527d-11e5-9299-41b3cdcb4a04.png">')
            webview:show(0.3)
        end,
        ["exitFn"] = function()
            local webview = obj.refs["URLSlideWebview"]
            webview:hide(0.2)
        end
    },
    {
        ["header"] = "Command line interface",
        ["enterFn"] = function()
            local webview = obj.makewebview("IPCSlideWebview", "body", nil, '<img src="https://cloud.githubusercontent.com/assets/525838/12647663/84e93d26-c5d6-11e5-846f-d7a1b7bcdba9.png">')
            webview:show(0.3)
        end,
        ["exitFn"] = function()
            local webview = obj.refs["IPCSlideWebview"]
            webview:hide(0.2)
        end
    },
    {
        ["header"] = "Other modules",
        ["body"] = [[alert appfinder applescript application audiodevice battery brightness caffeinate chooser drawing eventtap expose geometry grid hints host hotkey http httpserver image itunes javascript layout location menubar messages milight mouse notify pasteboard pathwatcher redshift screen sound spaces speech spotify tabs task timer uielement urlevent usb webview wifi]]
    },
    {
        ["header"] = "LuaSkin",
        ["enterFn"] = function()
            local webview = obj.makewebview("LuaSkinSlideWebview", "body", "https://github.com/Hammerspoon/hammerspoon/issues/749#issuecomment-173610148", nil)
            webview:show(0.3)
        end,
        ["exitFn"] = function()
            local webview = obj.refs["LuaSkinSlideWebview"]
            webview:hide(0.2)
        end
    },
    {
        ["header"] = "Questions?"
    }
}

-- Draw a slide on the screen, creating persistent screen objects if necessary
function obj:renderSlide(slideNum)
    print("renderSlide")
    if not slideNum then
        slideNum = self.currentSlide
    end
    print("  slide number: "..slideNum)

    local slideData = self.slides[slideNum]
    local frame = self.screenFrame

    if not self.slideBackground then
        self.slideBackground = hs.drawing.rectangle(frame)
        self.slideBackground:setLevel(hs.drawing.windowLevels["normal"])
        self.slideBackground:setFillColor(hs.drawing.color.hammerspoon["osx_yellow"])
        self.slideBackground:setFill(true)
        self.slideBackground:show(0.2)
    end

    if not self.slideHeader then
        self.slideHeader = hs.drawing.text(hs.geometry.rect(frame["x"] + 50,
                                                            frame["y"] + 50,
                                                            frame["w"] - 100,
                                                            frame["h"] / 10),
                                                            "")
        self.slideHeader:setTextColor(hs.drawing.color.x11["black"])
        self.slideHeader:setTextSize(self.slideHeaderSize)
        self.slideHeader:orderAbove(self.slideBackground)
    end

    self.slideHeader:setText(slideData["header"])
    self.slideHeader:show(0.5)

    if not self.slideBody then
        self.slideBody = hs.drawing.text(hs.geometry.rect(frame["x"] + 50,
                                                     self.slideHeader:frame()["y"] + self.slideHeader:frame()["h"] + 10,
                                                     (frame["w"] - 100)*0.66,
                                                     (frame["h"] / 10) * 8),
                                                     "")
        self.slideBody:setTextColor(hs.drawing.color.x11["black"])
        self.slideBody:setTextSize(self.slideBodySize)
        self.slideBody:orderAbove(self.slideBackground)
    end

    self.slideBody:setText(slideData["body"] or "")
    self.slideBody:show(0.5)

    if not self.slideFooter then
        self.slideFooter = hs.drawing.text(hs.geometry.rect(frame["x"] + 50,
                                                            frame["y"] + frame["h"] - 50 - self.slideFooterSize,
                                                            frame["w"] - 100,
                                                            frame["h"] / 25),
                                                            "Hammerspoon: Staggeringly powerful desktop automation")
        self.slideFooter:setTextColor(hs.drawing.color.x11["black"])
        self.slideFooter:setTextSize(self.slideFooterSize)
        self.slideFooter:orderAbove(self.slideBackground)
        self.slideFooter:show(0.5)
    end
end

-- Move one slide forward
function obj:nextSlide()
    if self.currentSlide < #self.slides then
        if self.slides[self.currentSlide] and self.slides[self.currentSlide]["exitFn"] then
            print("running exitFn for slide")
            self.slides[self.currentSlide]["exitFn"]()
        end

        self.currentSlide = self.currentSlide + 1
        self:renderSlide()

        if self.slides[self.currentSlide] and self.slides[self.currentSlide]["enterFn"] then
            print("running enterFn for slide")
            self.slides[self.currentSlide]["enterFn"]()
        end
    end
end

-- Move one slide back
function obj:previousSlide()
    if self.currentSlide > 1 then
        if self.slides[self.currentSlide] and self.slides[self.currentSlide]["exitFn"] then
            print("running exitFn for slide")
            self.slides[self.currentSlide]["exitFn"]()
        end

        self.currentSlide = self.currentSlide - 1
        self:renderSlide()

        if self.slides[self.currentSlide] and self.slides[self.currentSlide]["enterFn"] then
            print("running enterFn for slide")
            self.slides[self.currentSlide]["enterFn"]()
        end
    end
end

-- Exit the presentation
function obj:endPresentation()
    hs.caffeinate.set("displayIdle", false, true)
    if self.slides[self.currentSlide] and self.slides[self.currentSlide]["exitFn"] then
        print("running exitFn for slide")
        self.slides[self.currentSlide]["exitFn"]()
    end
    self.slideHeader:hide(0.5)
    self.slideBody:hide(0.5)
    self.slideFooter:hide(0.5)
    self.slideBackground:hide(1)

    hs.timer.doAfter(1, function()
        self.slideHeader:delete()
        self.slideBody:delete()
        self.slideFooter:delete()
        self.slideBackground:delete()
        self.slideModal:exit()
    end)
end

-- Prepare the modal hotkeys for the presentation
function obj.setupModal()
    print("setupModal")
    obj.slideModal = hs.hotkey.modal.new({}, nil, nil)

    obj.slideModal:bind({}, "left", function() obj:previousSlide() end)
    obj.slideModal:bind({}, "right", function() obj:nextSlide() end)
    obj.slideModal:bind({}, "escape", function() obj:endPresentation() end)

    obj.slideModal:enter()
end

-- Callback for when we've chosen a screen to present on
function obj.didChooseScreen(choice)
    if not choice then
        print("Chooser cancelled")
        return
    end
    print("didChooseScreen: "..choice["text"])
    obj.presentationScreen = hs.screen.find(choice["uuid"])
    if not obj.presentationScreen then
        hs.notify.show("Unable to find that screen, using primary screen")
        obj.presentationScreen = hs.screen.primaryScreen()
    else
        print("Found screen")
    end
    obj.screenFrame = obj.presentationScreen:fullFrame()

    -- DEBUG
    obj.screenFrame = hs.geometry.rect(0, 0, 1920, 1080)

    obj.setupModal()

    local frame = obj.screenFrame
    obj.slideHeaderSize = frame["h"] / 15
    obj.slideBodySize   = frame["h"] / 22
    obj.slideFooterSize = frame["h"] / 30

    obj:nextSlide()
end

-- Prepare a table of screens for hs.chooser
function obj.screensToChoices()
    print("screensToChoices")
    local choices = hs.fnutils.map(hs.screen.allScreens(), function(screen)
        local name = screen:name()
        local id = screen:id()
        local image = screen:snapshot()
        local mode = screen:currentMode()["desc"]

        return {
            ["text"] = name,
            ["subText"] = mode,
            ["uuid"] = id,
            ["image"] = image,
        }
    end)

    return choices
end

-- Initiate the hs.chosoer for choosing a screen to present on
function obj.chooseScreen()
    print("chooseScreen")
    local chooser = hs.chooser.new(obj.didChooseScreen)
    chooser:choices(obj.screensToChoices)
    chooser:show()
end

-- Prepare the presentation
function obj.setupPresentation()
    print("setupPresentation")
    if #obj.slides == 0 then
        hs.alert("No slides defined")
        return
    end
    hs.caffeinate.set("displayIdle", true, true)
    obj.chooseScreen()
end

return obj
