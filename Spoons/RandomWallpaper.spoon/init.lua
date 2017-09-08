--- === RandomWallpaper ===
---
--- Fetch random wallpaper images from Unsplash (http//unsplash.com)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "RandomWallpaper"
obj.version = "1.0"
obj.author = "Chris Jones <cmsj@tenshu.net>"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.timer = nil

--- RandomWallpaper.interval
--- Variable
--- The number of seconds to wait before fetching a new wallpaper. Defaults to 600 (10 minutes)
obj.interval = 600

--- RandomWallpaper:start()
--- Method
--- Starts the random wallpaper updates
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:show()
    circle = self.circle
    timer = self.timer

    if circle then
        circle:delete()
        if timer then
            timer:stop()
        end
    end

    mousepoint = hs.mouse.getAbsolutePosition()

    local color = nil
    if (self.color) then
        color = self.color
    else
        color = {["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1}
    end
    circle = hs.drawing.circle(hs.geometry.rect(mousepoint.x-40, mousepoint.y-40, 80, 80))
    circle:setStrokeColor(color)
    circle:setFill(false)
    circle:setStrokeWidth(5)
    circle:bringToFront(true)
    circle:show(0.5)
    self.circle = circle

    self.timer = hs.timer.doAfter(3, function()
        self.circle:hide(0.5)
        hs.timer.doAfter(0.6, function() self.circle:delete() end)
    end)

    return self
end

return obj
