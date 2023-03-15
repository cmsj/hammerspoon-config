-- Base Button Class
Button = {}
function Button:__tostring()
   if rawget(self, "type") then  -- only classes have field "type"
      return "Class: "..tostring(self.type)
   else                          -- instances of classes do not have field "type"
      return
         "Type: "..tostring(self.type)
   end
end
function Button:newChildClass(type)
    -- Inspired by https://stackoverflow.com/questions/40004898/child-class-constructor-method-in-lua
    self.__index = self
    return setmetatable({
        type = type or "none",
        parentClass = self,
        __tostring = self.__tostring
    }, self)
end
function Button:new()
    self.__index = self
    local o = {
        titles = {},
        images = {},
        pressFns = {},
        stateIdx = 0
    }
    return setmetatable(o, self)
end
function Button:del()
  -- noop in the base class
  print("ERROR: Button:del() called on base class")
end
function Button:update(deck, buttonNum)
  -- noop in the base class
  print("ERROR: Button:update() called on base class")
end
function Button:pressEvent(deck, buttonMgr, buttonNum, pressed)
  -- noop in the base class
  print("ERROR: Button:pressEvent() called on base class")
end
function Button:setStateIdx(idx)
    self.stateIdx = idx
    self:update()
end



-- Class for buttons with solid colors
ButtonColor = Button:newChildClass("color")
function ButtonColor:new(color)
    local o = ButtonColor.parentClass.new(self)
    o.color = color or hs.drawing.color.black
    return o
end
function ButtonColor:setColor(color)
    self.color = color
end
function ButtonColor:update(deck, buttonNum)
    print("ButtonColor:update for:" .. tostring(buttonNum))
    deck:setButtonColor(buttonNum, self.color)
end
function ButtonColor:pressEvent(deck, buttonMgr, buttonNum, pressed)
    -- FIXME: Something something
end



-- Class for buttons with random colors
ButtonRandomColor = Button:newChildClass("randomColor")
function ButtonRandomColor:new(color)
    local o = ButtonRandomColor.parentClass.new(self)
    o.color = color or {
        alpha = 1,
        red = math.random(),
        green = math.random(),
        blue = math.random()
    }
    return o
end
function ButtonRandomColor:update(deck, buttonNum)
    print("ButtonColor:update for:" .. tostring(buttonNum))
    deck:setButtonColor(buttonNum, self.color)
end
function ButtonRandomColor:pressEvent(deck, buttonMgr, buttonNum, pressed)
    if ~pressed then
        self.color = {
            alpha = 1,
            red = math.random(),
            green = math.random(),
            blue = math.random()
        }
    end
end


-- Class for buttons with images
ButtonImage = Button:newChildClass("image")
function ButtonImage:new(image)
    local o = ButtonImage.parentClass.new(self)
    o.image = image
    return o
end
function ButtonImage:setImage(image)
    self.image = image
end
function ButtonImage:update(deck, buttonNum)
    print("ButtonImage:update for:" .. tostring(buttonNum))
    deck:setButtonImage(buttonNum, self.image)
end



-- Base class for a page of buttons
Page = {}
function Page:__tostring()
    if rawget(self, "type") then  -- only classes have field "type"
       return "Class: "..tostring(self.type)
    else                          -- instances of classes do not have field "type"
       return
          "Type: "..tostring(self.type)
    end
end
function Page:newChildClass(type)
     -- Inspired by https://stackoverflow.com/questions/40004898/child-class-constructor-method-in-lua
     self.__index = self
     return setmetatable({
         type = type or "none",
         parentClass = self,
         __tostring = self.__tostring
     }, self)
end
function Page:new(deck, rows, cols)
    self.__index = self
    local o = {
        rows = rows,
        cols = cols,
        buttons = {}
    }

    for row = 1, rows do
        o.buttons[row] = {}
        for col = 1, cols do
            o.buttons[row][col] = ButtonRandomColor:new() -- FIXME: Put this back at some point: hs.drawing.color.black)
        end
    end

    return setmetatable(o, self)
end
function Page:createButton(row, col, button)
    if (self.buttons[row][col] ~= nil) then
        self.buttons[row][col]:del()
    end
    self.buttons[row][col] = button
end
function Page:getButton(row, col)
    return self.buttons[row][col]
end
function Page:update(deck)
    local i = 1
    for row = 1, self.rows do
        for col = 1, self.cols do
            local button = self:getButton(row, col)
            print(button)
            button:update(deck, i)
            i = i + 1
        end
    end
end
function Page:pressEvent(deck, buttonMgr, buttonNum, pressed)
    local button = self.buttons[buttonNum]
    if button == nil then
        print("ERROR: Button " .. tostring(buttonNum) .. " is nil")
        return
    end
    print(hs.inspect(button))
    button:pressEvent(deck, buttonMgr, buttonNum, pressed)
end
function Page:updateButton(deck, buttonNum)
    self.buttons[buttonNum]:update(deck, buttonNum)
end




-- Class for a Page drawer
PageDrawer = Page:newChildClass("drawer")
function PageDrawer:new(deck, rows, cols)
    local o = PageDrawer.parentClass.new(self, deck, rows, cols)
    o.parentPageIdx = 1
end
function PageDrawer:setParentIdx(idx)
    self.parentPageIdx = idx
end
function PageDrawer:pressEvent(deck, buttonMgr, buttonNum, pressed)
    if pressed and buttonNum == 1 then
        buttonMgr:setPage(self.parentPageIdx)
    else
        self.buttons[buttonNum]:pressEvent(deck, buttonMgr, buttonNum, pressed)
    end
end


-- Class for a button manager for a given deck
-- FIXME: This should stop storing buttons directly, we should have a Page class that stores buttons
ButtonManager = {}
function ButtonManager:new(deck, firstPage)
    local rows, cols = deck:buttonLayout()
    local o = {
        deck = deck,
        buttonSize = deck:imageSize(),
        rows = rows,
        cols = cols,
        pages = {},
        curPageIdx = 1
    }

    table.insert(o.pages, firstPage or Page:new(deck, rows, cols))

    setmetatable(o, self)
    self.__index = self

    return o
end
function ButtonManager:update()
    self.pages[self.curPageIdx]:update(self.deck)
end
function ButtonManager:setPage(idx)
    self.curPageIdx = idx
    self:update()
end
function ButtonManager:getPage(idx)
    return self.pages[idx]
end
function ButtonManager:indexForPage(page)
    for i, p in ipairs(self.pages) do
        if p == page then
            return i
        end
    end
    return nil
end
function ButtonManager:showPage(page)
    local idx = self:indexForPage(page)
    if idx ~= nil then
        self:setPage(idx)
    end
end
function ButtonManager:enableButtonCallback()
    self.deck:buttonCallback(function(deck, buttonNum, pressed)
        self.pages[self.curPageIdx]:pressEvent(deck, self, buttonNum, pressed)
        self.pages[self.curPageIdx]:updateButton(deck, buttonNum)
    end)
end
function ButtonManager:disableButtonCallback()
    self.deck:buttonCallback(nil)
end

--[=====[

require("streamdeck")
deck = hs.streamdeck.getDevice(1)
bm = ButtonManager:new(deck)
page = bm:getPage(1)
page:createButton(1, 3, ButtonImage:new(hs.image.imageFromAppBundle("com.apple.Safari")))
bm:update()
bm:enableButtonCallback()

--]=====]

-- foo = Button:new()
-- foo.titles = {"On", "Off"}
-- foo.pressFns = {function() print("On") foo:setStateIdx(1) end, function() print("Off") foo:setStateIdx(0) end}