local FGuid = require("libs/Fguid")
local config = require("config/config")
local logger = require("libs/logger")
local utils = {}

local PalUtilities

function utils.scheduleAfter(delayMs, fn)
    local ok, err = pcall(ExecuteInGameThreadWithDelay, delayMs, function()
        local callOk, callErr = pcall(fn)
        if not callOk then
            logger.error("[scheduleAfter] " .. tostring(callErr))
        end
    end)
    if not ok then
        logger.error("[scheduleAfter] scheduling failed: " .. tostring(err))
    end
end

utils.scheduleAfter(10000, function()
    PalUtilities = StaticFindObject("/Script/Pal.Default__PalUtility")
end)

function utils.sendPersonalAnnounce(PalPlayerController, Message)
    if not (PalPlayerController and PalPlayerController:IsValid()) then
        return
    end

    utils.scheduleAfter(350, function()
        if not (PalPlayerController and PalPlayerController:IsValid()) then
            return
        end

        local world = FindFirstOf("World")
        local playerState = PalPlayerController.PlayerState
        if not (PalUtilities and PalUtilities:IsValid() and world and world:IsValid() and playerState and playerState:IsValid()) then
            return
        end

        local guidArray = { FGuid.translate(playerState.PlayerUId) }
        PalUtilities:SendSystemToPlayerChat(world, Message, guidArray)
    end)
end

function utils.sendServerAnnounce(message)
    local world = FindFirstOf("World")
    if PalUtilities and PalUtilities:IsValid() and world and world:IsValid() then
        PalUtilities:SendSystemAnnounce(world, message)
    end
end

function utils.BroadcastServerMessage(message)
    local gameStateInstance = FindFirstOf("PalGameStateInGame")
    if gameStateInstance and gameStateInstance:IsValid() then
        gameStateInstance:BroadcastServerNotice(message)
    end
end

function utils.GetPlayerId(ps)
	if ps and ps:IsValid() and ps.PlayerUId then
		return FGuid.toString(ps.PlayerUId)
	end
	return "UnknownID"
end

function utils.GetPlayerName(ps)
	if ps and ps:IsValid() and ps.PlayerNamePrivate then
		return ps.PlayerNamePrivate:ToString()
	end
	return "Unknown"
end

function utils.findPlayerByName(targetName)
    if not targetName or targetName == "" then return nil end

    local wanted = targetName:match("^%s*(.-)%s*$"):lower()
    if wanted == "" then return nil end

    for _, targetState in ipairs(FindAllOf("PalPlayerState") or {}) do
        if targetState and targetState:IsValid() then
            local name = utils.GetPlayerName(targetState)
            if name:lower() == wanted then
                return targetState, name
            end
        end
    end

    return nil
end

function utils.IsPlayerAdmin(state)
    if not (state and state:IsValid()) then
        return false
    end

    local pc = state:GetPlayerController()
    if pc and pc:IsValid() and pc.bAdmin then
        return true
    end

    local uid = utils.GetPlayerId(state)
    local uidNoDashes = uid:gsub("-", "")
    for _, adminUID in ipairs(config.adminUIDs or {}) do
        if uidNoDashes == adminUID then
            return true
        end
    end

    return false
end

function utils.getPalUtilities()
    return PalUtilities
end

return utils
