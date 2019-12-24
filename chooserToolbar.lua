local chooser = require("hs.chooser")
local toolbar = require("hs.webview.toolbar")
local canvas  = require("hs.canvas")
local inspect = require("hs.inspect")
local stext   = require("hs.styledtext")

local module = {}

local list1, list2, list3 = {}, {}, {}

for i = 1, 10, 1 do
    table.insert(list1, { text = string.char(96 + i) } )
    table.insert(list2, { text = tostring(i) })
    table.insert(list3, { text = string.char(64 + i) })
end

local changeChooserEntries = function(list, bar, parent, item)
    parent:choices(list)
    parent:query("")
    bar:selectedItem(item)
end

local toolbarItems = {
    {
        id         = "choice1",
        selectable = true,
        label      = "Lower Case",
        image      = canvas.new{ h = 50, w = 50 }:appendElements{
                            {
                                type = "rectangle",
                                strokeColor = { white = 1 },
                                fillColor   = { red   = .5 },
                            }, {
-- vertical centering is hard without putting the text into a local variable, finding its bounding box
-- with hs.canvas:minimumTextSize, then calculating the proper frame based on canvas dimensions... this
-- is "close enough" for this example...
                                frame = { h = 50, w = 50, x = 0, y = -6 },
                                text = stext.new("a", {
                                    font = { name = ".AppleSystemUIFont", size = 50 },
                                    paragraphStyle = { alignment = "center" }
                                }),
                                type = "text",
                            }
                    }:imageFromCanvas(),
        fn         = function(...) changeChooserEntries(list1, ...) end,
    },
    {
        id         = "choice2",
        selectable = true,
        label      = "Numeric",
        image      = canvas.new{ h = 50, w = 50 }:appendElements{
                            {
                                type = "rectangle",
                                strokeColor = { white = 1 },
                                fillColor   = { green = .5 },
                            }, {
                                frame = { h = 50, w = 50, x = 0, y = -6 },
                                text = stext.new("1", {
                                    font = { name = ".AppleSystemUIFont", size = 50 },
                                    paragraphStyle = { alignment = "center" }
                                }),
                                type = "text",
                            }
                    }:imageFromCanvas(),
        fn         = function(...) changeChooserEntries(list2, ...) end,
    },
    {
        id         = "choice3",
        selectable = true,
        label      = "Upper Case",
        image      = canvas.new{ h = 50, w = 50 }:appendElements{
                            {
                                type = "rectangle",
                                strokeColor = { white = 1 },
                                fillColor   = { blue  = .5 },
                            }, {
                                frame = { h = 50, w = 50, x = 0, y = -6 },
                                text = stext.new("A", {
                                    font = { name = ".AppleSystemUIFont", size = 50 },
                                    paragraphStyle = { alignment = "center" }
                                }),
                                type = "text",
                            }
                    }:imageFromCanvas(),
        fn         = function(...) changeChooserEntries(list3, ...) end,
    },
    {
        id         = "hide",
        selectable = false,
        label      = "Hide",
        image      = canvas.new{ h = 50, w = 50 }:appendElements{
                           {
                                frame = { h = 50, w = 50, x = 0, y = -6 },
                                text = stext.new("🚫", {
                                    font = { name = ".AppleSystemUIFont", size = 50 },
                                    paragraphStyle = { alignment = "center" }
                                }),
                                type = "text",
                            }
                    }:imageFromCanvas(),
        fn         = function(bar, parent, item) bar:visible(false) end,
    },
    {
        id         = "remove",
        selectable = false,
        label      = "Remove",
        image      = canvas.new{ h = 50, w = 50 }:appendElements{
                           {
                                frame = { h = 50, w = 50, x = 0, y = -6 },
                                text = stext.new("☠", {
                                    font = { name = ".AppleSystemUIFont", size = 50 },
                                    paragraphStyle = { alignment = "center" }
                                }),
                                type = "text",
                            }
                    }:imageFromCanvas(),
        fn         = function(bar, parent, item) parent:attachedToolbar(nil) end,
    },
    {
        id         = "titleBar",
        selectable = false,
        label      = "Adjust",
        image      = canvas.new{ h = 50, w = 50 }:appendElements{
                           {
                                frame = { h = 50, w = 50, x = 0, y = -6 },
                                text = stext.new("🔼", {
                                    font = { name = ".AppleSystemUIFont", size = 50 },
                                    paragraphStyle = { alignment = "center" }
                                }),
                                type = "text",
                            }
                    }:imageFromCanvas(),
        fn         = function(bar, parent, item)
                         bar:inTitleBar(not bar:inTitleBar())
                         if bar:inTitleBar() then
                             textToDisplay = "🔽"
                         else
                             textToDisplay = "🔼"
                         end
                         bar:modifyItem{
                             id = "titleBar",
                             image = canvas.new{ h = 50, w = 50 }:appendElements{
                                 {
                                     frame = { h = 50, w = 50, x = 0, y = -6 },
                                     text = stext.new(textToDisplay, {
                                         font = { name = ".AppleSystemUIFont", size = 50 },
                                         paragraphStyle = { alignment = "center" }
                                     }),
                                     type = "text",
                                 }
                             }:imageFromCanvas(),
                         }
                     end,
    },
}

local _toolbar = toolbar.new("chooserToolbarTest")
                        :addItems(toolbarItems)
                        :canCustomize(true)
                        :setCallback(function(...)
                                          print("+++ Oops! You better assign me something to do!")
                                     end)

local _chooser = chooser.new(function(...)
    print("Chooser results = " .. inspect(table.pack(...), { newline = " ", indent = "" }))
end):attachedToolbar(_toolbar)

changeChooserEntries(list1, _toolbar, _chooser, "choice1")

module._toolbar = _toolbar
module._chooser = _chooser

module.show = function() _chooser:show() end
module.attach = function() _chooser:attachedToolbar(_toolbar) end

return module
