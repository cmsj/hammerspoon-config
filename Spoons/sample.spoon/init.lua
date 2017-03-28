-- Note that Lua comments start with -- and Hammerspoon documentation strings
-- start with ---

--- === Sample Spoon ===
---
--- Provides an example of how to structure Spoons with a contrived example
--- that monotonically increases a counter every second

-- Create a table to be our object
local obj = {}
obj.__index = obj

-- Add some metadata. These values should be considered as mandatory
obj.name = "Sample Spoon"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/hammerspoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Define a function that will help us locate ourself
-- This isn't mandatory, but it's strongly encouraged that you include this
-- function and use it to set obj.spoonPath
local function script_path()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*/)")
end
obj.spoonPath = script_path()


-- Initialisation function
-- This is optional, depending on whether your Spoon needs to do any initial
-- setup work

--- sample:init([incValue])
--- Method
--- Sets up the Spoon
---
--- Parameters:
---  * incValue - an amount to increment the value by. Defaults to 1
---
--- Returns:
---  * None
function obj:init(incValue)
    self.someValue = 1234
    self.incValue = incValue or 1
end


-- Function to start work
-- This is optional, and is for users to call at the point where they want
-- your Spoon to begin doing its work, if relevant.

--- sample:start()
--- Method
--- Starts the counter
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:start()
    -- Create a timer object that will call one of our useful functions
    -- every second
    self.timer = hs.timer.new(1, function()
        obj:incrementValue()
    end)
    self.timer:start()
end


-- Function to stop work
-- This is optional, and should generally do the opposite of :start()

--- sample:stop()
--- Method
--- Stops the counter
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:stop()
    self.timer:stop()
end

-- Function to increase the counter value.
-- Technically all information in a Spoon is public, but we're not going to
-- document this function because users should use our timer and wait for the
-- value to increase!
function obj:incrementValue()
    self.someValue = self.someValue + self.incValue
end

-- Another useful function. This time we'll make it public by documenting it
--- sample:getValue()
--- Method
--- Gets the counter value
---
--- Parameters:
---  * None
---
--- Returns:
---  * The current counter value
function obj:getValue()
    return self.someValue
end


-- Add a __tostring method. This is optional, but can be very helpful for
-- users to identify what this object is
function obj.__tostring(self)
    return "This is the Sample Spoon. Its current value is: "..self.someValue
end

-- Set the metatable for our object
-- If you have specified a __tostring, or wish to add a __gc, this is the
-- place to do it
setmetatable(obj, {__tostring=obj.__tostring})

-- Finally, return our object to Hammerspoon.
-- This isn't necessarily mandatory, depending on the behaviour of your
-- Spoon, e.g. if you unconditionally do some work when your Spoon's init.lua
-- is loaded, or you insert yourself into the global tables.
-- But in most cases you would be encouraged to encapsulate your work in an
-- object and return it here.
return obj
