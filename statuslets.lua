print("Loading statuslets")
local obj = {}
obj.__index = obj

obj.timer = nil

obj.cccText = nil
obj.cccDot = nil

obj.arqText = nil
obj.arqDot = nil

obj.updateText = nil
obj.updateDot = nil
obj.updateCounter = nil

obj.sleepText = nil
obj.sleepDot = nil

if hs.canvas.drawingWrapper then
    hs.canvas.drawingWrapper(true)
end

function obj:render()
    -- Destroy existing Statuslets
    if self.cccText then self.cccText:delete() end
    if self.cccDot then self.cccDot:delete() end
    if self.arqText then self.arqText:delete() end
    if self.arqDot then self.arqDot:delete() end
    if self.updateText then self.updateText:delete() end
    if self.updateDot then self.updateDot:delete() end
    if self.sleepText then self.sleepText:delete() end
    if self.sleepDot then self.sleepDot:delete() end

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
    self.cccText = hs.drawing.text(hs.geometry.rect(statusText_x,
                                                     statusText_y - statusTextHeight + 1,
                                                     statusTextWidth,
                                                     statusTextHeight), "CCC:")
    self.arqText = hs.drawing.text(hs.geometry.rect(statusText_x + 6,
                                                     statusText_y,
                                                     statusTextWidth,
                                                     statusTextHeight), "Arq:")
    self.updateText = hs.drawing.text(hs.geometry.rect(statusText_x - 2,
                                                     statusText_y - (statusTextHeight*2) + 1,
                                                     statusTextWidth,
                                                     statusTextHeight), "Brew:")
    self.sleepText = hs.drawing.text(hs.geometry.rect(statusText_x - 55,
                                                      statusText_y - (statusTextHeight*2) + 1,
                                                      statusTextWidth + 5,
                                                      statusTextHeight), "Sleep:")

    self.cccDot = hs.drawing.circle(hs.geometry.rect(statusDot_x,
                                                      statusDot_y - statusTextHeight + 3,
                                                      statusDotWidth,
                                                      statusDotWidth))
    self.arqDot = hs.drawing.circle(hs.geometry.rect(statusDot_x,
                                                      statusDot_y + 3,
                                                      statusDotWidth,
                                                      statusDotWidth))
    self.updateDot = hs.drawing.circle(hs.geometry.rect(statusDot_x,
                                                      statusDot_y - (statusTextHeight*2) + 3,
                                                      statusDotWidth,
                                                      statusDotWidth))
    self.sleepDot = hs.drawing.circle(hs.geometry.rect(statusDot_x - 50,
                                                       statusDot_y - (statusTextHeight*2) + 3,
                                                       statusDotWidth,
                                                       statusDotWidth))

    -- Finally, configure the rendering style of the text/circle objects, clamp them to the desktop, and show them
    self.cccText:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setTextSize(11):sendToBack():show(0.5)
    self.arqText:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setTextSize(11):sendToBack():show(0.5)
    self.updateText:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setTextSize(11):sendToBack():show(0.5)
    self.sleepText:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setTextSize(11):sendToBack():show(0.5)

    self.cccDot:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setFillColor(hs.drawing.color.osx_yellow):setStroke(false):sendToBack():show(0.5)
    self.arqDot:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setFillColor(hs.drawing.color.osx_yellow):setStroke(false):sendToBack():show(0.5)
    self.updateDot:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setFillColor(hs.drawing.color.osx_yellow):setStroke(false):sendToBack():show(0.5)
    self.sleepDot:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setFillColor(hs.drawing.color.osx_yellow):setStroke(false):sendToBack():show(0.5)

    return self
end

function obj.statusletCallbackCCC(code, stdout, stderr)
    local color

    if code == 0 then
        color = hs.drawing.color.osx_green
    else
        color = hs.drawing.color.osx_red
    end

    obj.cccDot:setFillColor(color)
end

function obj.statusletCallbackArq(code, stdout, stderr)
    local color

    if code == 0 then
        color = hs.drawing.color.osx_green
    else
        color = hs.drawing.color.osx_red
    end

    obj.arqDot:setFillColor(color)
end

function obj.statusletCallbackUpdate(code, stdout, stderr)
    local color

    print("Software update code: "..code)
    if code == 0 then
        color = hs.drawing.color.osx_green
    else
        color = hs.drawing.color.osx_red
    end

    obj.updateDot:setFillColor(color)
end

function obj.statusletCallbackSleep()
    local allAssertions = hs.caffeinate.currentAssertions()
    local canSleep = true

    for pid,assertions in pairs(allAssertions) do
        for _,value in pairs(assertions) do
            if value["AssertType"] == "PreventUserIdleSystemSleep" then
                canSleep = false
            end
        end
    end

    if canSleep then
        color = hs.drawing.color.osx_green
    else
        color = hs.drawing.color.osx_red
    end

    obj.sleepDot:setFillColor(color)
end

function obj:update(force)
    hs.task.new("/usr/bin/grep", self.statusletCallbackCCC, {"-q", os.date("%d/%m/%Y"), os.getenv("HOME").."/.cccLast"}):start()
    hs.task.new("/usr/bin/grep", self.statusletCallbackArq, {"-q", os.date("%d/%m/%Y"), os.getenv("HOME").."/.arqLast"}):start()
    if force or self.updateCounter > 11 then
        -- Only do this check about every hour
        print("Checking software update status...")
        hs.task.new("/bin/bash", self.statusletCallbackUpdate, {"/Users/cmsj/bin/check_updates.sh"}):start()
        self.updateCounter = 0
    else
        self.updateCounter = self.updateCounter + 1
    end
    self.statusletCallbackSleep()

    return self
end

-- Render our statuslets, trigger a timer to update them regularly, and do an initial update
function obj:start()
    self:render()
    self.updateCounter = 0
    self.timer = hs.timer.new(hs.timer.minutes(5), function() obj:update() end)
    self.timer:start()
    self:update(true)
    return self
end

function obj:stop()
    self.timer:stop()
    self.cccDot:delete()
    self.cccText:delete()
    self.arqDot:delete()
    self.arqText:delete()
    self.updateDot:delete()
    self.updateText:delete()
    return self
end

return obj

