--↔
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
    --self.presentationControl:setIcon(hs.image.imageFromName("NSSecurity"))
    self.presentationControl:setTitle("Presentation")
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

function obj.get_left_frame(percent)
    local factor = percent/100
    local fakeBodyFrame = obj.get_body_frame(obj.screenFrame, 100)
    local x = fakeBodyFrame["x"]
    local y = obj.slideHeaderFrame["y"] + obj.slideHeaderFrame["h"] + 10
    local w = fakeBodyFrame["w"] * factor - 5
    local h = fakeBodyFrame["h"]
    return {x=x, y=y, w=w, h=h}
end

function obj.get_right_frame(percent)
    local factor = percent/100
    local fakeBodyFrame = obj.get_body_frame(obj.screenFrame, 100)
    local x = fakeBodyFrame["x"] + (fakeBodyFrame["w"] *(1-factor)) + 5
    local y = obj.slideHeaderFrame["y"] + obj.slideHeaderFrame["h"] + 10
    local w = fakeBodyFrame["w"] * factor - 5
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
    elseif place == "lefthalf" then
        codeViewRect = obj.get_left_frame(50)
    elseif place == "body" then
        codeViewRect = obj.get_body_frame(obj.screenFrame, 100)
    end

    slideView:appendElements({action="fill",
                              type="rectangle",
                              frame=codeViewRect,
                              fillColor=hs.drawing.color.x11.white},
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
            webViewRect = obj.get_right_frame(33)
        elseif place == "righthalf" then
            webViewRect = obj.get_right_frame(50)
        elseif place == "lefthalf" then
            webViewRect = obj.get_left_frame(50)
        elseif place == "body" then
            webViewRect = obj.get_body_frame(obj.screenFrame, 100)
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
        ["header"] = "Hammerspoon - Chris Jones",
        ["body"] = [[
 • Ng on IRC
 • cmsj everywhere else
 • Work at Red Hat on OpenStack


 • Any Mac users in?
 • Anyone used Objective C?
 • Anyone used Lua?
]],
        ["enterFn"] = function()
            obj.makeimageview(obj.slideView, "hammerspoon", "righthalf", "hammerspoon.png")
        end,
        ["bodyWidth"] = 50,
    },
    {
        ["header"] = "Agenda",
        ["body"] = [[We will cover:
 • A little Apple history
 • How Hammerspoon came to exist
 • What can it do?
 • How Hammerspoon works
 • Questions?
]],
    },
    {
        ["header"] = "A little Apple history",
        ["body"] = [[First party:
 • 1991 - Apple Events (System 7)
 • 1993 - AppleScript (System 7.1.1)
 • 2005 - Automator (OS X 10.4)
 • 2007 - ScriptingBridge (OS X 10.5)

Third party:
 • 1991 onwards - AppleScript libraries, many utilities
 • 2014 - Hammerspoon is forked from Mjolnir]]
    },
--     {
--         ["header"] = "AppleScript",
--         ["enterFn"] = function()
--             obj.makecodeview(obj.slideView, "appleScriptCodeView", "righthalf", [[tell application "Hammerspoon"
--   execute lua code "hs.reload()"
-- end tell
-- 
-- tell application "Safari"
--     set currentURL to URL of document 1
-- end tell
-- return currentURL]])
--         end,
--         ["bodyWidth"] = 50,
--         ["body"] = [[ • Supposedly simple, natural language
--  • Very powerful despite its awful syntax
--  • High level messages passed to apps via Apple Events
--  • Apps expected to expose their functionality
--  • Apps can expose object hierarchies (e.g. a browser can expose page elements within tabs within windows)]]
--     },
--     {
--         ["header"] = "Receiving AppleScript events",
--         ["enterFn"] = function()
--             obj.makecodeview(obj.slideView, "appleScriptCodeView", "righthalf", [[@implementation executeLua
-- -(id)performDefaultImplementation {
--     // Get the arguments:
--     NSDictionary *args = [self evaluatedArguments];
--     NSString *stringToExecute = [args valueForKey:@""];
--     if (HSAppleScriptEnabled()) {
--         // Execute Lua Code:
--         return executeLua(self, stringToExecute);
--     } else {
--         // Raise AppleScript Error:
--         [self setScriptErrorNumber:-50];
--         [self setScriptErrorString:someErrorMessage];
--         return @"Error";
--     }
-- }
-- @end]])
--         end,
--         ["body"] = [[ • Application defines the commands it accepts (in this case "executeLua") in an XML "dictionary"
--  • Commands are mapped to Objective C interfaces (like protocols/traits in other languages)
--  • Foundation.framework calls the implementation method of the relevant interface
--  • Dictionaries can be browsed by the user using Script Editor.app]],
--         ["bodyWidth"] = 50
--     },
--    {
--        ["header"] = "How Hammerspoon came to exist: Motivation",
--        ["enterFn"] = function()
--            obj.makeimageview(obj.slideView, "keyboardMaestro", "righthalf", "keyboardmaestro.png")
--        end,
--        ["bodyWidth"] = 50,
--        ["body"] = [[ • I was using Keyboard Maestro to automate tasks
-- • Very powerful, can react to lots of system events
-- • Ideal for non-programmer power users
-- • As a programmer, became frustrated with graphical programming
-- • Not open source]]
--    },
--    {
--        ["header"] = "How Hammerspoon came to exist: Circumstance",
--        ["body"] = [[ • Others also wanted something programmable
-- • First notable app was Slate (used JavaScript)
--   • Quickly went unmaintained, never really recovered
-- • Steven Degutis began a series of open source experiments
--   • Hydra, Phoenix, Penknife (used various languages)
-- • Culminated in Mjolnir, simple bridge between Lua and OS X]]
--    },
    {
        ["header"] = "How Hammerspoon came to exist: The Fork",
        ["body"] = [[ • Mjolnir is a very simple Lua ↔ ObjC bridge
 • Shipped with no OS integrations
 • They were supposed to be distributed separately
 • Small group of us disagreed and decided to fork in October 2014
 • Aim was a "batteries included" automation app
 • Started with ~15000 lines of code (13000 being Lua)
 • Now have ~100000 lines of code (37500 being OS integrations)]]
    },
    {
        ["header"] = "So what can it do?",
        ["body"] = [[• Reacting to all kinds of events
  • WiFi, USB, path/file changes,
  • Location, audio devices
  • Keyboard/Mouse/Scroll inputs
  • Application launch/hide/quit
  • Battery, Screen, Speech
• Window management
• Interacting with applications (menus)
• Drawing custom interfaces on the screen
• HTTP client/server
• Raw socket client/server
• URL handling/mangling
• MIDI, SQLite3, Timers, Processes, etc.]],
        ["enterFn"] = function()
            local webview = obj.makewebview("whatCanItDoWebview", "righthalf", "http://www.hammerspoon.org/docs/", nil)
            webview:show(0.3)
            local webviewRect = webview:frame()
            local webviewCentrePoint = hs.geometry.point(webviewRect.x + webviewRect.w/2, webviewRect.y + webviewRect.h/2)
            hs.mouse.setAbsolutePosition(webviewCentrePoint)

            obj.refs["whatCanItDoCounter"] = 100
            obj.refs["whatCanItDoTimer"] = hs.timer.doUntil(function()
                    return obj.refs["whatCanItDoCounter"] <= 0
                end,
                function()
                    obj.refs["whatCanItDoCounter"] = obj.refs["whatCanItDoCounter"] - 1
                    hs.eventtap.event.newScrollEvent({0, -100}, {}, "pixel"):post()
                end,
                0.1):start()
        end,
        ["exitFn"] = function()
            obj.refs["whatCanItDoTimer"]:stop()
            local webview = obj.refs["whatCanItDoWebview"]
            webview:hide(0.2)
        end
    },
    {
        ["header"] = "How does it work?",
        ["body"] = [[• Lua is really easy to embed in C
• Lots of boilerplate
• Ripe for abstraction
• Handles errors with setjmp/longjmp
• We built "LuaSkin"
  • Lua state lifecycle
  • Argument checking
  • Library/Object creation
  • Lua ↔ ObjC type translation (including ObjC objects)
  • Lua errors → ObjC exceptions
        ]],
    },
--    {
--        ["header"] = "Lua vs LuaSkin - Lifecycle",
--        ["enterFn"] = function()
--            obj.makecodeview(obj.slideView, "LuaVsLuaSkinILeft", "lefthalf", [[lua_State *createLua() {
--    lua_State *L = luaL_newstate();
--    luaL_openlibs();
--    luaL_loadfile(L, "~/.hammerspoon/init.lua");
--    lua_pcall(L, 0, 0, 0);
--    return L;
--}
--
--void destroyLua(lua_State *L) {
--    lua_close(L);
--    L = NULL;
--}
--]])
--            obj.makecodeview(obj.slideView, "LuaVsLuaSkinIRight", "righthalf", [[LuaSkin *createLua() {
--    return [LuaSkin shared];
--}
--
--void destroyLua(LuaSkin *skin) {
--    [skin destroyLuaState];
--}
--]])
--        end,
--    },
    {
        ["header"] = "Lua vs LuaSkin - Argument checking",
        ["enterFn"] = function()
            obj.makecodeview(obj.slideView, "LuaVsLuaSkinArgCheckLeft", "lefthalf", [[static int foo(lua_State *L) {
    if (lua_type(L, 1) != LUA_TINTEGER && \
        lua_type(L, 1) != LUA_TSTRING) {
        luaL_error(L, "argument 1 must be an integer or a string");
    }
    if (lua_type(L, 2) != LUA_TSTRING && \
        lua_type(L, 2) != LUA_TBOOLEAN) {
        luaL_error(L, "argument 2 must be a string or a boolean");
    }
]])
            obj.makecodeview(obj.slideView, "LuaVsLuaSkinArgCheckRight", "righthalf", [[LuaSkin *skin = [LuaSkin shared];
[skin argcheck:LS_TINTEGER|LS_TSTRING, LS_TSTRING|LS_TBOOLEAN, LS_TBREAK];
]])
        end,
    },
--    {
--        ["header"] = "Lua vs LuaSkin - Library creation",
--        ["enterFn"] = function()
--            obj.makecodeview(obj.slideView, "LuaVsLuaSkinLibCreationLeft", "lefthalf", [[luaL_Reg lib[] = {
--    {"someUsefulThing", someCFunction},
--    {NULL, NULL}
--};
--
--luaL_Reg lib_meta[] = {
--    {"__gc", someCleanupFunction},
--    {NULL, NULL}
--};
--
--luaL_newlib(L, lib);
--luaL_newlib(L, lib_meta);
--lua_setmetatable(L, -2);
--]])
--            obj.makecodeview(obj.slideView, "LuaVsLuaSkinLibCreationRight", "righthalf", [[luaL_Reg lib[] = {
--    {"someUsefulThing", someCFunction},
--    {NULL, NULL}
--};
--
--luaL_Reg lib_meta[] = {
--    {"__gc", someCleanupFunction},
--    {NULL, NULL}
--};
--
--LuaSkin *skin = [LuaSkin shared];
--[skin registerLibrary:lib metaFunctions:lib_meta];
--]])
--        end,
--    },
    {
        ["header"] = "Lua vs LuaSkin - Object creation",
        ["enterFn"] = function()
            obj.makecodeview(obj.slideView, "LuaVsLuaSkinObjCreationLeft", "lefthalf", [[luaL_Reg obj[] = {
    {"methodA", someCFunction},
    {"methodB", otherCFunction},
    {NULL, NULL}
};

luaL_newlib(L, obj);
lua_pushvalue(L, -1);
lua_setfield(L, -2, "__index");
lua_pushstring(L, "objectName");
lua_setfield(L, -2, "__type");
lua_pushstring(L, "objectName");
lua_setfield(L, -2, "__name");
lua_setfield(L, LUA_REGISTRYINDEX, "objectName");
]])
            obj.makecodeview(obj.slideView, "LuaVsLuaSkinObjCreationRight", "righthalf", [[luaL_Reg obj[] = {
    {"methodA", someCFunction},
    {"methodB", otherCFunction},
    {NULL, NULL}
};

LuaSkin *skin = [LuaSkin shared];
[skin registerObject:"objectName" objectFunctions:obj];
]])
        end
    },
    {
        ["header"] = "Lua vs LuaSkin - Type translation",
        ["enterFn"] = function()
            obj.makecodeview(obj.slideView, "LuaVsLuaSkinTypeTransLeft", "lefthalf", [[NSString *obj = @"hello world";
size_t size = [obj lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
lua_pushlstring(L, obj.UTF8String, size);

NSString *foo = [NSString stringWithUTF8String:lua_tostring(L, 1)];

NSArray *list = @[@"hi", @(42), [SomeClass newClass] ];
for (int i=0; i < list.allKeys; i++) {
    id obj = [list objectAtIndex:i];

    if ([obj isKindOfClass:[NSNull class] ])
        lua_pushnil(L);
    else if ([obj isKindOfClass:[NSNumber class] ])
        lua_pushinteger(L, [(NSNumber *)obj intValue]);
    else if ([obj isKindOfClass:[NSArray class] ]) {
        // Oh no, we need to recurse
        lua_pushSOMETHING(L, I_HATE_MY_LIFE);
    }
    // Repeat for every type of class and cry
}
]])
            obj.makecodeview(obj.slideView, "LuaVsLuaSkinTypeTransRight", "righthalf", [[NSString *obj = @"hello world";
[skin pushNSObject:obj];

NSString *foo = [skin toNSObjectAtIndex:1];

NSArray *list = @[@"hi", @(42), [SomeClass newClass] ];
[skin pushNSObject:list];
]])
        end
    },
--     {
--         ["header"] = "Lua vs LuaSkin Part 2",
--         ["exitFn"] = function()
--             local webview = obj.refs["LuaVsLuaSkinIILeft"]
--             webview:hide(0.1)
--         end,
--         ["enterFn"] = function()
--             local webview = obj.makewebview("LuaVsLuaSkinIILeft", "lefthalf", nil, [[<html><head><style>
-- pre {
--     width: 100%;
--     font-size: 28px;
-- }
-- </style></head>
-- <body><pre>luaL_Reg lib[] = {{"new", new}, {NULL, NULL}};
-- luaL_Reg obj[] = {{"inc", inc}, {NULL, NULL}};
-- void main() {
--     lua_State *L = luaL_newstate(); luaL_openlibs();
--     luaL_newlib(L, lib);
--     luaL_newlib(L, obj);
--     lua_pushvalue(L, -1);
--     lua_setfield(L, -2, "__index");
--     lua_setfield(L, LUA_REGISTRYINDEX, "counter");
-- }
-- static int new(lua_State *L) {
--     if (lua_type(L, 1) != LUA_TINTEGER) {
--         lua_pushnil(L);
--         return;
--     }
--     int *c_ptr = lua_newuserdata(L, sizeof(int));
--     *c_ptr = lua_tointeger(L, 1);
--     luaL_getmetatable(L, "counter");
--     lua_setmetatable(L, -2);
--     return 1;
-- }
-- static int inc(lua_State *L) {
--     luaL_checktype(L, 1, LUA_TUSERDATA);
--     int *c_ptr = luaL_checkudata(L, 1, "counter");
--     if (!c_ptr) luaL_typerror(L, 1, "counter");
--     (*c_ptr)++;
--     return 0;
-- }
-- </pre></body></html>]])
--             webview:show(0.1)
--             obj.makecodeview(obj.slideView, "LuaVsLuaSkinIIRight", "righthalf", [[luaL_Reg lib[] = {{"new", new}, {NULL, NULL}};
-- luaL_Reg obj[] = {{"inc", inc}, {NULL, NULL}};
-- void main() {
--     LuaSkin *skin = [LuaSkin shared];
--     [skin registerLibrary:lib metaFunctions:nil];
--     [skin registerObject:"counter" objectFunctions:obj];
-- }
-- static int new(lua_State *L) {
--     LuaSkin *skin = [LuaSkin shared];
--     [skin checkArgs:LS_TINTEGER, LS_TBREAK];
--     Counter *c = [SomeCounterClass newClass];
--     c.value = lua_tointeger(L, 1);
--     [skin pushNSObject:c];
--     return 1;
-- }
-- static int inc(lua_State *L) {
--     LuaSkin *skin = [LuaSkin shared];
--     [skin checkArgs:LS_TUSERDATA, "counter", LS_TBREAK];
--     Counter *c = get_object(Counter, L, 1, "counter");
--     c.value++;
--     return 0;
-- }
-- ]])
--         end,
--     },
    {
        ["header"] = "LuaSkin - Custom object translation",
        ["enterFn"] = function()
            obj.makeimageview(obj.slideView, "streamdeck", "body", "streamdeck.jpg")
        end,
    },
    {
        ["header"] = "LuaSkin - Custom object translation",
        ["enterFn"] = function()
            obj.makecodeview(obj.slideView, "luaSkinPart2", "body", [[
static int pushHSStreamDeckDevice(lua_State *L, id obj) {
    HSStreamDeckDevice *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSStreamDeckDevice *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, "hs.streamdeck");
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSStreamDeckDeviceFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared];
    HSStreamDeckDevice *value;
    if (luaL_testudata(L, idx, "hs.streamdeck")) {
        value = get_objectFromUserdata(__bridge HSStreamDeckDevice, L, idx, "hs.streamdeck");
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", "hs.streamdeck",
                        lua_typename(L, lua_type(L, idx))] ];
    }
    return value;
}
]])
        end,
    },
    {
        ["header"] = "LuaSkin - Custom object translation",
        ["enterFn"] = function()
            obj.makecodeview(obj.slideView, "luaSkinPart3", "body", [[
static int streamdeck_setButtonImage(lua_State *L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, "hs.streamdeck", LS_TNUMBER, LS_TUSERDATA, "hs.image", LS_TBREAK];

    HSStreamDeckDevice *device = [skin luaObjectAtIndex:1 toClass:"HSStreamDeckDevice"];

    [device setImage:[skin luaObjectAtIndex:3 toClass:"NSImage"] forButton:(int)lua_tointeger(skin.L, 2)];

    lua_pushvalue(skin.L, 1);
    return 1;
}
]])
        end,
    },
    {
        ["header"] = "Questions?",
        ["body"] = [[


Resources:
  • http://www.hammerspoon.org/
  • https://github.com/Hammerspoon/
  • #hammerspoon on Freenode
]],
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
    hs.mouse.setAbsolutePosition(hs.geometry.point(obj.screenFrame.x + obj.screenFrame.w, obj.screenFrame.y + obj.screenFrame.h/2))
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
