local obj = {}
obj.__index = obj
obj.__name = "seal_apps"

function obj:commands()
    return {kill = {
        cmd = "kill",
        fn = obj.choicesKillCommand,
        plugin = obj.__name,
        name = "Kill",
        description = "Kill an application"
        }
    }
end

function obj:bare()
    return self.choicesRunningApps
end

function obj.choicesRunningApps(query)
    local choices = {}
    if query == nil then
        return choices
    end
    local apps = hs.application.runningApplications()
    for k,app in pairs(apps) do
        local name = app:name()
        if string.match(name:lower(), query:lower()) and app:mainWindow() then
            local choice = {}
            choice["text"] = name.." (Running)"
            choice["subText"] = app:path().." PID: "..app:pid()
            if app:bundleID() then
                choice["image"] = hs.image.imageFromAppBundle(app:bundleID())
                choice["bundleID"] = app:bundleID()
            end
            choice["pid"] = app:pid()
            choice["path"] = app:path()
            choice["uuid"] = obj.__name.."__"..(app:bundleID() or name)
            choice["plugin"] = obj.__name
            choice["type"] = "running"
            table.insert(choices, choice)
        end
    end
    return choices
end

function obj.choicesKillCommand(query)
    local choices = {}
    if query == nil then
        return choices
    end
    local apps = hs.application.runningApplications()
    for k, app in pairs(apps) do
        local name = app:name()
        if string.match(name:lower(), query:lower()) and app:mainWindow() then
            local choice = {}
            choice["text"] = "Kill "..name
            choice["subText"] = app:path().." PID: "..app:pid()
            choice["pid"] = app:pid()
            choice["plugin"] = obj.__name
            choice["type"] = "kill"
            table.insert(choices, choice)
        end
    end
    return choices
end

function obj.choicesSomeCommand(query)
    return {}
end

function obj.completionCallback(rowInfo)
    if rowInfo["type"] == "running" then
        hs.application.get(rowInfo["pid"]):activate(true)
    elseif rowInfo["type"] == "kill" then
        hs.application.get(rowInfo["pid"]):kill()
    end
end

return obj
