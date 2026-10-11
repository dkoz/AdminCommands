local commandHandlers = require("libs/handler")
local bans = require("libs/bans")
local utils = require("libs/utils")
local logger = require("libs/logger")
local config = require("config/config")
local serverlogs = require("libs/serverlogs")
local freeze = require("modules/freeze")
local godmode = require("modules/godmode")
local logic = {}

for k in pairs(commandHandlers) do
    print("[AdminCommands] Registered command: " .. k .. "\n")
end

function logic.chatHook(ctx, Message, Category)
    local pc = ctx:get()
    if not (pc and pc:IsValid()) then return end

    local state = pc.PlayerState
    if not (state and state:IsValid()) then return end

    local text = Message:get():ToString()

    serverlogs.ChatLog(state, text, Category:get())

    local prefixPattern = config.commandPrefix:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    local cmd, rest = text:match("^" .. prefixPattern .. "(%S+)%s*(.*)$")
    if not cmd then
        return
    end

    cmd = cmd:lower()

    local entry = commandHandlers[cmd]
    if not entry then
        return
    end

    if entry.admin and not utils.IsPlayerAdmin(state) then
        utils.sendPersonalAnnounce(pc, "You do not have permission.")
        return
    end

    local playerName = utils.GetPlayerName(state)
    local playerUID = utils.GetPlayerId(state)
    logger.logCommand(playerName, playerUID, cmd, rest)

    entry.func(state, rest)
end

function logic.onCharacterInit(ctx)
    local character = ctx and ctx:get()
    if not (character and character:IsValid()) then return end
    local ps = character.PlayerState
    if not (ps and ps:IsValid()) then
        return utils.scheduleAfter(50, function() logic.onCharacterInit(ctx) end)
    end

    serverlogs.ConnectLog(character)

    local uid = utils.GetPlayerId(ps)
    if bans.isUidBanned(uid) then
        local pc = ps:GetPlayerController()
        if pc and pc:IsValid() then
            pc:ClientTravelInternal("Void", 0, false, nil)
        end
        return
    end

    freeze.reapply(ps)
    godmode.reapply(ps)

    if config.motdEnabled then
        local pc = ps:GetPlayerController()
        if pc and pc:IsValid() then
            local name = ps.PlayerNamePrivate and ps.PlayerNamePrivate:ToString() or "Player"
            local lines = config.motdMessage
            if type(lines) ~= "table" then
                lines = { lines }
            end
            for i, line in ipairs(lines) do
                local send = function()
                    utils.sendPersonalAnnounce(pc, string.format(line, name))
                end
                if i == 1 then
                    send()
                else
                    utils.scheduleAfter((i - 1) * 200, send)
                end
            end
        end
    end
end

return logic
