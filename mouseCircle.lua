print("Loading mouseCircle")

local mouseCircle = {}
mouseCircle.__index = mouseCircle

mouseCircle.circle = nil
mouseCircle.timer = nil

function mouseCircle:start()
    print("Starting mouseCircle")
    return self
end

function mouseCircle:show()
    circle = self.circle
    timer = self.timer

    if circle then
        circle:delete()
        if timer then
            timer:stop()
        end
    end

    mousepoint = hs.mouse.getAbsolutePosition()

    circle = hs.drawing.circle(hs.geometry.rect(mousepoint.x-40, mousepoint.y-40, 80, 80))
    circle:setStrokeColor({["red"]=1,["blue"]=0,["green"]=0,["alpha"]=1})
    circle:setFill(false)
    circle:setStrokeWidth(5)
    circle:bringToFront(true)
    circle:show(0.5)
    self.circle = circle

    self.timer = hs.timer.doAfter(3, function()
        self.circle:hide(0.5)
        hs.timer.doAfter(0.6, function() self.circle:delete() end)
    end)
end


return mouseCircle
