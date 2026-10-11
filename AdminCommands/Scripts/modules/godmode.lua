local utils = require("libs/utils")
local logger = require("libs/logger")
local commands = {}

local godModeEnabled = {}

local function applyGodMode(pawn, enable)
    if not (pawn and pawn:IsValid()) then return false end

    local paramComp = pawn.CharacterParameterComponent
    if not (paramComp and paramComp:IsValid()) then return false end

    paramComp:SetMuteki(FName("AdminGodMode"), enable)

    local status = pawn.StatusComponent
    if status and status:IsValid() then
        if enable then
            status:AddStatus(45)
            status:AddStatus(41)
        else
            status:RemoveStatus(45)
            status:RemoveStatus(41)
        end
    end

    return true
end

function commands.handleGodMode(state, rest)
    local pc = state:GetPlayerController()
    local uid = utils.GetPlayerId(state)

    local enable = nil
    if rest and rest:lower() == "on" then
        enable = true
    elseif rest and rest:lower() == "off" then
        enable = false
    elseif not rest or rest == "" then
        enable = not godModeEnabled[uid]
    else
        utils.sendPersonalAnnounce(pc, "Usage: !god on/off")
        return
    end

    if not applyGodMode(pc.Pawn, enable) then
        utils.sendPersonalAnnounce(pc, "God Mode: Character parameter component not available.")
        return
    end

    godModeEnabled[uid] = enable or nil

    if enable then
        utils.sendPersonalAnnounce(pc, "God Mode enabled! You are invincible.")
    else
        utils.sendPersonalAnnounce(pc, "God Mode disabled! You are mortal again.")
    end

    logger.logCommand(utils.GetPlayerName(state), uid, "god", enable and "on" or "off")
end

function commands.reapply(state)
    if not (state and state:IsValid()) then return end
    if not godModeEnabled[utils.GetPlayerId(state)] then return end

    utils.scheduleAfter(1000, function()
        if not (state and state:IsValid()) then return end

        local pc = state:GetPlayerController()
        if pc and pc:IsValid() then
            applyGodMode(pc.Pawn, true)
        end
    end)
end

return commands
