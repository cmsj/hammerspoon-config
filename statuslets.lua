print("Loading statuslets")
local obj = {}
obj.__index = statuslets

obj.timer = nil

obj.fwText = nil
obj.fwDot = nil

obj.cccText = nil
obj.cccDot = nil

obj.arqText = nil
obj.arqDot = nil

function obj:render()
    -- Destroy existing Statuslets
    if self.fwText then self.fwText:delete() end
    if self.fwDot then self.fwDot:delete() end
    if self.cccText then self.cccText:delete() end
    if self.cccDot then self.cccDot:delete() end
    if self.arqText then self.arqText:delete() end
    if self.arqDot then self.arqDot:delete() end

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
    self.fwText = hs.drawing.text(hs.geometry.rect(statusText_x + 5,
                                                          statusText_y - (statusTextHeight*2) + 2,
                                                          statusTextWidth,
                                                          statusTextHeight), "FW:")
    self.cccText = hs.drawing.text(hs.geometry.rect(statusText_x,
                                                     statusText_y - statusTextHeight + 1,
                                                     statusTextWidth,
                                                     statusTextHeight), "CCC:")
    self.arqText = hs.drawing.text(hs.geometry.rect(statusText_x + 4,
                                                     statusText_y,
                                                     statusTextWidth,
                                                     statusTextHeight), "Arq:")

    self.fwDot = hs.drawing.circle(hs.geometry.rect(statusDot_x,
                                                           statusDot_y - (statusTextHeight*2) + 4,
                                                           statusDotWidth,
                                                           statusDotWidth))
    self.cccDot = hs.drawing.circle(hs.geometry.rect(statusDot_x,
                                                      statusDot_y - statusTextHeight + 3,
                                                      statusDotWidth,
                                                      statusDotWidth))
    self.arqDot = hs.drawing.circle(hs.geometry.rect(statusDot_x,
                                                      statusDot_y + 2,
                                                      statusDotWidth,
                                                      statusDotWidth))

    -- Finally, configure the rendering style of the text/circle objects, clamp them to the desktop, and show them
    self.fwText:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setTextSize(11):sendToBack():show(0.5)
    self.cccText:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setTextSize(11):sendToBack():show(0.5)
    self.arqText:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setTextSize(11):sendToBack():show(0.5)

    self.fwDot:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setFillColor(hs.drawing.color.osx_yellow):setStroke(false):sendToBack():show(0.5)
    self.cccDot:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setFillColor(hs.drawing.color.osx_yellow):setStroke(false):sendToBack():show(0.5)
    self.arqDot:setBehaviorByLabels({"canJoinAllSpaces", "stationary"}):setFillColor(hs.drawing.color.osx_yellow):setStroke(false):sendToBack():show(0.5)
end

function obj.statusletCallbackFirewall(code, stdout, stderr)
    local color

    if string.find(stdout, "block all non-essential") then
        color = hs.drawing.color.osx_green
    else
        color = hs.drawing.color.osx_red
    end

    obj.fwDot:setFillColor(color)
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

function obj:update()
    print("statuslets:update()")
    hs.task.new("/usr/bin/sudo", self.statusletCallbackFirewall, {"/usr/libexec/ApplicationFirewall/socketfilterfw", "--getblockall"}):start()
    hs.task.new("/usr/bin/grep", self.statusletCallbackCCC, {"-q", os.date("%d/%m/%Y"), os.getenv("HOME").."/.cccLast"}):start()
    hs.task.new("/usr/bin/grep", self.statusletCallbackArq, {"-q", "Arq.*finished backup", "/var/log/system.log"}):start()
end

-- Render our statuslets, trigger a timer to update them regularly, and do an initial update
function obj:start()
    self:render()
    self.timer = hs.timer.new(hs.timer.minutes(5), function(self) self:update() end)
    self.timer:start()
    self:update()
    return self
end

return obj

