print("Loading seal")

local obj = {}
obj.__index = obj

obj.chooser = nil
obj.hotkeyShow = nil
obj.plugins = {}
obj.commands = {}
obj.queryChangedTimer = nil

function obj:init(plugins)
    print("Initialising seal")
    self.chooser = hs.chooser.new(self.completionCallback)
    self.chooser:choices(self.choicesCallback)
    self.chooser:queryChangedCallback(self.queryChangedCallback)

    for k,plugin_name in pairs(plugins) do
        print("  Loading seal plugin: " .. plugin_name)
        plugin = require("seal_"..plugin_name)
        table.insert(obj.plugins, plugin)
        for cmd,cmdInfo in pairs(plugin:commands()) do
            print("Adding command: "..cmd)
            obj.commands[cmd] = cmdInfo
        end
    end
    return self
end

function obj:start(modifiers, hotkey)
    print("Starting seal")
    if hotkey then
        self.hotkeyShow = hs.hotkey.bind(modifiers, hotkey, function() obj:show() end)
    end
    return self
end

function obj:stop()
    print("Stopping seal")
    self.chooser:hide()
    if self.hotkeyShow then
        self.hotkeyShow:disable()
    end
    return self
end

function obj:show()
    self.chooser:show()
    return self
end

function obj.completionCallback(rowInfo)
    if rowInfo == nil then
        return
    end
    if rowInfo["type"] == "plugin_cmd" then
        obj.chooser:query(rowInfo["cmd"])
        return
    end
    for k,plugin in pairs(obj.plugins) do
        if plugin.__name == rowInfo["plugin"] then
            plugin.completionCallback(rowInfo)
            break
        end
    end
end

function obj.choicesCallback()
    -- TODO: Sort each of these clusters of choices, alphabetically
    choices = {}
    query = obj.chooser:query()
    cmd = nil
    query_words = {}
    if query == "" then
        return choices
    end
    for word in string.gmatch(query, "%S+") do
        if cmd == nil then
            cmd = word
        else
            table.insert(query_words, word, #query_words + 1)
        end
    end
    query_words = table.concat(query_words, " ")
    -- First get any direct command matches
    for command,cmdInfo in pairs(obj.commands) do
        cmd_fn = cmdInfo["fn"]
        if cmd:lower() == command:lower() then
            fn_choices = cmd_fn(query_words)
            if fn_choices ~= nil then
                for j,choice in pairs(fn_choices) do
                    table.insert(choices, choice)
                end
            end
        end
    end
    -- Now get any bare matches
    for k,plugin in pairs(obj.plugins) do
        bare = plugin:bare()
        if bare then
            for i,choice in pairs(bare(query)) do
                table.insert(choices, choice)
            end
        end
    end
    -- Now add in any matching commands
    -- TODO: This only makes sense to do if we can select the choice without dismissing the chooser, which requires changes to HSChooser
    for command,cmdInfo in pairs(obj.commands) do
        if string.match(command, query) and #query_words == 0 then
            choice = {}
            choice["text"] = cmdInfo["name"]
            choice["subText"] = cmdInfo["description"]
            choice["type"] = "plugin_cmd"
            table.insert(choices,choice)
        end
    end

    return choices
end

function obj.queryChangedCallback(query)
    if obj.queryChangedTimer then
        obj.queryChangedTimer:stop()
    end
    obj.queryChangedTimer = hs.timer.doAfter(0.5, function() obj.chooser:refreshChoicesCallback() end)
end

return obj

