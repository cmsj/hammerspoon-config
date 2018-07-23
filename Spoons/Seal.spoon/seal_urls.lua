local obj = {}
obj.__index = obj
obj.__name = "seal_urls"

obj.providers = {
    rhbz = {
        name = "Red Hat Bugzilla",
        url = "https://bugzilla.redhat.com/show_bug.cgi?id=%s",
    },
    lp = {
        name = "Launchpad Bug",
        url = "https://launchpad.net/bugs/%s",
    },
}

function obj:commands()
    return {up = {
        cmd = "up",
        fn = obj.choicesURLPart,
        name = "URL Part",
        description = "Open a full URL with a search term",
        plugin = obj.__name
        }
    }
end

function obj:bare()
    return obj.choicesBareURL
end

function obj.choicesBareURL(query)
    local choices = {}
    if string.find(query, "://") ~= nil then
        local scheme = string.sub(query, 1, string.find(query, "://") - 1)
        local handlers = hs.urlevent.getAllHandlersForScheme(scheme)
        for _,bundleID in pairs(handlers) do
            local choice = {}
            local bundleInfo = hs.application.infoForBundleID(bundleID)
            if bundleInfo and bundleInfo["CFBundleName"] then
                choice["text"] = "Open URI with "..bundleInfo["CFBundleName"]
                choice["handler"] = bundleID
                choice["scheme"] = scheme
                choice["type"] = "launch"
                choice["url"] = query
                choice["plugin"] = obj.__name
                choice["image"] = hs.image.imageFromAppBundle(bundleID)
                table.insert(choices, choice)
            end
        end
    end
    return choices
end

function obj.choicesURLPart(query)
    print("choicesURLPart for: "..query)
    local choices = {}
    for name,data in pairs(obj.providers) do
        local full_url = string.format(data["url"], query)
        local url_scheme = string.sub(full_url, 1, string.find(full_url, "://") - 1)
        local choice = {}
        choice["text"] = data["name"]
        choice["subText"] = full_url
        choice["plugin"] = obj.__name
        choice["type"] = "launch"
        choice["url"] = full_url
        choice["scheme"] = url_scheme
        table.insert(choices, choice)
    end
    return choices
end

function obj.completionCallback(rowInfo)
    if rowInfo["type"] == "launch" then
        local handler = nil
        if rowInfo["handler"] == nil then
            handler = hs.urlevent.getDefaultHandler(rowInfo["scheme"])
        else
            handler = rowInfo["handler"]
        end
        hs.urlevent.openURLWithBundle(rowInfo["url"], handler)
    end
end

return obj
