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
    require("hs.canvas")
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
obj.slideView = nil
obj.numDefaultElements = nil
obj.slideHeaderFrame = nil
obj.slideBodyFrame = nil
obj.slideFooterFrame = nil
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

function obj.setDefaultFontSizes()
    obj.slideHeaderSize = obj.screenFrame["h"] / 15
    obj.slideBodySize   = obj.screenFrame["h"] / 22
    obj.slideFooterSize = obj.screenFrame["h"] / 30
end

function obj.get_right_frame(percent)
    local factor = percent/100
    local fakeBodyFrame = obj.get_body_frame(obj.screenFrame, 100)
    local x = fakeBodyFrame["x"] + (fakeBodyFrame["w"] *(1-factor))
    local y = obj.slideHeaderFrame["y"] + obj.slideHeaderFrame["h"] + 10
    local w = fakeBodyFrame["w"] * factor
    local h = fakeBodyFrame["h"]
    return {x=x, y=y, w=w, h=h}
end

function obj.get_body_frame(frame, percent)
    local factor = percent/100
    local x = frame["x"] + 50
    local y = obj.slideHeaderFrame["y"] + obj.slideHeaderFrame["h"] + 10
    local w = (frame["w"] - 100)*factor
    local h = obj.slideFooterFrame["y"] - y
    return {x=x, y=y, w=w, h=h}
end

function obj.makecodeview(slideView, name, place, code, percent)
    print("Creating codeview "..name)
    local codeViewRect
    if place == "right" then
        codeViewRect = obj.get_right_frame(33)
    elseif place == "righthalf" then
        codeViewRect = obj.get_right_frame(50)
    elseif place == "body" then
        codeViewRect = obj.get_body_frame(obj.screenFrame, 100)
    end

    slideView:appendElements({action="fill",
                              type="rectangle",
                              frame=codeViewRect,
                              fillColor=hs.drawing.color.x11.gainsboro},
                             {action="fill",
                              type="text",
                              frame=codeViewRect,
                              text=code,
                              textSize=obj.slideBodySize*0.5,
                              textFont="SF Mono",
                              textColor=hs.drawing.color.x11.black})
end

function obj.makeimageview(slideView, name, place, imageName, percent)
    print("Creating imageview"..name)
    local imageViewRect
    if place == "right" then
        imageViewRect = obj.get_right_frame(33)
    elseif place == "righthalf" then
        imageViewRect = obj.get_right_frame(50)
    elseif place == "body" then
        imageViewRect = obj.get_body_frame(obj.screenFrame, 100)
    end

    local image = hs.image.imageFromPath(obj.spoonPath .. "/" .. imageName)
    slideView:appendElements({action="fill",
                              type="image",
                              frame=imageViewRect,
                              image=image,
                              imageAnimates=true,
                              imageScaling="scaleProportionally"
                            })
end

function obj.makewebview(name, place, url, html)
    if obj.refs[name] then
        return obj.refs[name]
    else
        print("Creating webview "..name)
        local webViewRect
        if place == "right" then
            webViewRect = hs.geometry.rect(obj.get_right_frame(obj.screenFrame))
        elseif place == "body" then
            webViewRect = hs.geometry.rect(obj.get_body_frame(obj.screenFrame))
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

 • Thanks for coming!
 • My name is Chris Jones
   • Working on OpenStack for Red Hat
   • cmsj@tenshu.net
   • @cmsj on GitHub/Twitter/etc
   • Ng on IRC
 • Do we have any Mac users present?
   (this could be very boring if not!)]],
        ["enterFn"] = function()
            obj.makeimageview(obj.slideView, "hammerspoon", "righthalf", "hammerspoon.png")
        end,
        ["bodyWidth"] = 50,
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
   • Now expected that apps are scriptable
 • 2005 - Automator (OS X 10.4)
   • User applications, Folder Actions, System Services
 • 2007 - ScriptingBridge (OS X 10.5)
   • AppleScript power for Objective C, JavaScript, Python and Ruby
 • 1991 onwards - Third Parties
   • AppleScript libraries
   • Many automation/customisation utilities]]
    },
    {
        ["header"] = "AppleScript",
        ["enterFn"] = function()
            obj.makecodeview(obj.slideView, "appleScriptCodeView", "righthalf", [[tell application "Hammerspoon"
  execute lua code "hs.reload()"
end tell
    tell application "Safari"
        set currentURL to URL of document 1
    end tell
    return currentURL]])
        end,
        ["bodyWidth"] = 50,
        ["body"] = [[ • Supposedly simple, natural language
 • Very powerful despite its awful syntax
 • High level messages passed to apps via Apple Events
 • Apps can expose object hierarchies (e.g. a browser can expose page elements within tabs within windows)]]
    },
    {
        ["header"] = "Receiving AppleScript events",
        ["enterFn"] = function()
            obj.makecodeview(obj.slideView, "appleScriptCodeView", "righthalf", [[@implementation executeLua
-(id)performDefaultImplementation {
    // Get the arguments:
    NSDictionary *args = [self evaluatedArguments];
    NSString *stringToExecute = [args valueForKey:@""];
    if (HSAppleScriptEnabled()) {
        // Execute Lua Code:
        return executeLua(self, stringToExecute);
    } else {
        // Raise AppleScript Error:
        [self setScriptErrorNumber:-50];
        [self setScriptErrorString:someErrorMessage];
        return @"Error";
    }
}
@end]])
        end,
        ["body"] = [[ • Application defines the commands it accepts (in this case "executeLua") in an XML "dictionary"
 • Commands are mapped to Objective C interfaces (like protocols/traits in other languages)
 • Foundation.framework calls the implementation method of the relevant interface
 • Dictionaries can be browsed by the user using Script Editor.app]],
        ["bodyWidth"] = 50
    },
    {
        ["header"] = "How Hammerspoon came to exist: Motivation",
        ["enterFn"] = function()
            obj.makeimageview(obj.slideView, "keyboardMaestro", "righthalf", "keyboardmaestro.png")
        end,
        ["bodyWidth"] = 50,
        ["body"] = [[ • I was using Keyboard Maestro to automate tasks
 • Very powerful, can react to lots of system events
 • Ideal for non-programmer power users
 • As a programmer, became frustrated with graphical programming
 • Not open source]]
    },
    {
        ["header"] = "How Hammerspoon came to exist: Circumstance",
        ["body"] = [[ • Others also wanted something programmable
 • First notable app was Slate (used JavaScript)
   • Quickly went unmaintained, never really recovered
 • Steven Degutis began a series of open source experiments
   • Hydra, Phoenix, Penknife (used various languages)
 • Culminated in Mjolnir, simple bridge between Lua and OS X]]
    },
    {
        ["header"] = "How Hammerspoon came to exist: The Fork",
        ["body"] = [[ • Steven wanted to keep Mjolnir small and pure
 • It didn't ship with any OS integrations
 • They were supposed to be distributed separately
 • Small group of us disagreed and decided to fork in October 2014
 • Aim was a "batteries included" automation app
 • Started with ~15000 lines of code (13000 being Lua 5.2.3, 500 being integrations)
 • Now have ~100000 lines of code (15000 being Lua 5.3.4, 37500 being integrations)]]
    },
    {
        ["header"] = "So what can it do?",
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
    self.slideHeaderFrame = {x=frame["x"] + 50, y=frame["y"] + 50, w=frame["w"] - 100, h=frame["h"] / 10}
    self.slideFooterFrame = {x=frame["x"] + 50, y=frame["y"] + frame["h"] - 50 - self.slideFooterSize, w=frame["w"] - 100, h=frame["h"] / 25}
    self.slideBodyFrame = self.get_body_frame(frame, (slideData["bodyWidth"] or 100))

    if not self.slideView then
        self.slideView = hs.canvas.new(frame):level(hs.canvas.windowLevels["normal"] + 1)
    end

    if self.slideView:elementCount() == 0 then
      self.slideView:appendElements({ action="fill",
                                      type="rectangle",
                                      fillColor=hs.drawing.color.hammerspoon.osx_yellow, },
                                    { action="fill",
                                      type="text",
                                      frame=self.slideFooterFrame,
                                      text=("Hammerspoon: Staggeringly powerful macOS desktop automation"),
                                      textColor=hs.drawing.color.x11.black,
                                      textSize=self.slideFooterSize })
      self.slideView:show(1.2)
      self.numDefaultElements = self.slideView:elementCount()
    end

    if self.slideView:elementCount() > self.numDefaultElements then
        print("Removing "..(self.slideView:elementCount() - self.numDefaultElements).." elements")
        for i=self.numDefaultElements+1,self.slideView:elementCount() do
            print(".")
            self.slideView:removeElement(self.numDefaultElements + 1)
        end
    end

    -- Render the header
    self.slideView:appendElements({ action="fill",
                                    type="text",
                                    frame=self.slideHeaderFrame,
                                    text=(slideData["header"] or "Hammerspoon"),
                                    textColor = hs.drawing.color.x11.black,
                                    textSize=self.slideHeaderSize })

    -- Render the body
    --[[
    self.slideView:appendElements({ action="fill",
                                    type="rectangle",
                                    frame=self.slideBodyFrame,
                                    fillColor=hs.drawing.color.x11.white})
    ]]
    self.slideView:appendElements({ action="fill",
                                    type="text",
                                    frame=self.slideBodyFrame,
                                    text=(slideData["body"] or ""),
                                    textColor = hs.drawing.color.x11.black,
                                    textSize=self.slideBodySize })

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

-- Update the current slide
function obj:updateSlide()
    self:renderSlide()
    if self.slides[self.currentSlide] and self.slides[self.currentSlide]["enterFn"] then
        print("running enterFn for slide")
        self.slides[self.currentSlide]["enterFn"]()
    end
end

-- Change font sizes
function obj:resizeFonts(delta)
    self.slideHeaderSize = self.slideHeaderSize + delta
    self.slideBodySize = self.slideBodySize + delta
    self.slideFooterSize = self.slideFooterSize + delta
end

-- Increase font size
function obj:fontBigger()
    self:resizeFonts(1)
    self:updateSlide()
end

-- Decrease font size
function obj:fontSmaller()
    self:resizeFonts(-1)
    self:updateSlide()
end

-- Exit the presentation
function obj:endPresentation()
    hs.caffeinate.set("displayIdle", false, true)

    if self.slides[self.currentSlide] and self.slides[self.currentSlide]["exitFn"] then
        print("running exitFn for slide")
        self.slides[self.currentSlide]["exitFn"]()
    end

    obj.slideView:delete(1.2)
    obj.slideView = nil
    obj.refs = {}

    if obj.slideModal.delete then
        obj.slideModal:delete() -- FIXME: This isn't in the current release of Hammerspoon
    end
    obj.slideModal = nil

    obj.currentSlide = 0
end

-- Prepare the modal hotkeys for the presentation
function obj.setupModal()
    print("setupModal")
    obj.slideModal = hs.hotkey.modal.new({}, nil, nil)

    obj.slideModal:bind({}, "left", function() obj:previousSlide() end)
    obj.slideModal:bind({}, "right", function() obj:nextSlide() end)
    obj.slideModal:bind({}, "escape", function() obj:endPresentation() end)
    obj.slideModal:bind({}, "=", function() obj:fontBigger() end)
    obj.slideModal:bind({}, "-", function() obj:fontSmaller() end)
    obj.slideModal:bind({}, "0", function() obj:setDefaultFontSizes() obj:updateSlide() end)

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

    -- DEBUG OVERRIDE TO 1080p
    obj.screenFrame = hs.geometry.rect(0, 0, 1920, 1080)

    obj.setupModal()

    obj.setDefaultFontSizes()

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
