local utils = require("libs/utils")
local logger = require("libs/logger")
local commands = {}

local TELEPORT_HEIGHT_OFFSET = 500
local IDENTITY_QUAT = { X = 0, Y = 0, Z = 0, W = 0 }

local function teleportTo(char, location)
    local palUtility = utils.getPalUtilities()
    if not (palUtility and palUtility:IsValid()) then return false end

    palUtility:TeleportAroundLoccation(char, location, IDENTITY_QUAT)
    return true
end

local function headLocation(char)
    local palUtility = utils.getPalUtilities()
    if not (palUtility and palUtility:IsValid()) then return nil end

    local loc = { X = 0, Y = 0, Z = 0 }
    if not palUtility:TryGetHeadWorldPosition(char, loc) then return nil end

    loc.Z = loc.Z + TELEPORT_HEIGHT_OFFSET
    return loc
end

function commands.handleGoto(state, rest)
    local pc = state:GetPlayerController()
    if not rest or rest == "" then
        utils.sendPersonalAnnounce(pc, "Usage: !goto <x> <y> <z> or !goto <player>")
        return
    end

    local char = pc.Pawn
    if not (char and char:IsValid()) then
        utils.sendPersonalAnnounce(pc, "Could not find your character.")
        return
    end

    local x, y, z = rest:match("^([%-%.%d]+)[,%s]+([%-%.%d]+)[,%s]+([%-%.%d]+)$")
    if x then
        local location = { X = tonumber(x), Y = tonumber(y), Z = tonumber(z) + TELEPORT_HEIGHT_OFFSET }
        if not teleportTo(char, location) then
            utils.sendPersonalAnnounce(pc, "PalUtility not ready yet.")
            return
        end

        logger.logTeleport(utils.GetPlayerName(state), utils.GetPlayerId(state),
            string.format("%.0f, %.0f, %.0f", tonumber(x), tonumber(y), tonumber(z)))
        utils.sendPersonalAnnounce(pc, "Teleported.")
        return
    end

    local targetState, name = utils.findPlayerByName(rest)
    if not targetState then
        utils.sendPersonalAnnounce(pc, "Player not found.")
        return
    end

    local targetPC = targetState:GetPlayerController()
    local targetChar = targetPC and targetPC.Pawn
    if not (targetChar and targetChar:IsValid()) then
        utils.sendPersonalAnnounce(pc, "Could not find that player's character.")
        return
    end

    local location = headLocation(targetChar)
    if not location or not teleportTo(char, location) then
        utils.sendPersonalAnnounce(pc, "Unable to reach that player.")
        return
    end

    logger.logTeleport(utils.GetPlayerName(state), utils.GetPlayerId(state), "Player: " .. name)
    utils.sendPersonalAnnounce(pc, "Teleported to " .. name)
end

function commands.handleGetPos(state)
    local pc = state:GetPlayerController()
    local char = pc.Pawn
    if not (char and char:IsValid()) then
        utils.sendPersonalAnnounce(pc, "Could not find your character.")
        return
    end

    local loc = char:K2_GetActorLocation()
    utils.sendPersonalAnnounce(pc, string.format("Your position: %.0f, %.0f, %.0f", loc.X, loc.Y, loc.Z))
end

function commands.handlePlayerGetPos(state, rest)
    local pc = state:GetPlayerController()
    if not rest or rest == "" then
        utils.sendPersonalAnnounce(pc, "Usage: !getpos <PlayerName>")
        return
    end

    local targetState, name = utils.findPlayerByName(rest)
    if not targetState then
        utils.sendPersonalAnnounce(pc, "Player not found.")
        return
    end

    local targetPC = targetState:GetPlayerController()
    local targetChar = targetPC and targetPC.Pawn
    if not (targetChar and targetChar:IsValid()) then
        utils.sendPersonalAnnounce(pc, "Could not find that player's character.")
        return
    end

    local loc = targetChar:K2_GetActorLocation()
    utils.sendPersonalAnnounce(pc, string.format("%s's position: %.0f, %.0f, %.0f", name, loc.X, loc.Y, loc.Z))
end

function commands.handleBring(state, rest)
    local pc = state:GetPlayerController()
    if not rest or rest == "" then
        utils.sendPersonalAnnounce(pc, "Usage: !bring <player>")
        return
    end

    local adminChar = pc.Pawn
    if not (adminChar and adminChar:IsValid()) then
        utils.sendPersonalAnnounce(pc, "Could not find your character.")
        return
    end

    local targetState, name = utils.findPlayerByName(rest)
    if not targetState then
        utils.sendPersonalAnnounce(pc, "Player not found.")
        return
    end

    local targetPC = targetState:GetPlayerController()
    local targetChar = targetPC and targetPC.Pawn
    if not (targetChar and targetChar:IsValid()) then
        utils.sendPersonalAnnounce(pc, "Could not find that player's character.")
        return
    end

    local location = headLocation(adminChar)
    if not location or not teleportTo(targetChar, location) then
        utils.sendPersonalAnnounce(pc, "Unable to get your position.")
        return
    end

    utils.sendPersonalAnnounce(pc, "Brought " .. name .. " to you.")
    utils.sendPersonalAnnounce(targetPC, "You have been brought to " .. utils.GetPlayerName(state))
end

function commands.handleBringAll(state, rest)
    local pc = state:GetPlayerController()
    local adminChar = pc.Pawn
    if not (adminChar and adminChar:IsValid()) then
        utils.sendPersonalAnnounce(pc, "Could not find your character.")
        return
    end

    local location = headLocation(adminChar)
    if not location then
        utils.sendPersonalAnnounce(pc, "Unable to get your position.")
        return
    end

    local count = 0
    for _, targetState in ipairs(FindAllOf("PalPlayerState") or {}) do
        if targetState and targetState:IsValid() then
            local targetPC = targetState:GetPlayerController()
            if targetPC and targetPC:IsValid() and targetPC ~= pc then
                local targetChar = targetPC.Pawn
                if targetChar and targetChar:IsValid() and teleportTo(targetChar, location) then
                    count = count + 1
                end
            end
        end
    end

    utils.sendPersonalAnnounce(pc, "Brought " .. count .. " players to you.")
end

function commands.handleUnstuck(state)
    local pc = state:GetPlayerController()
    if pc and pc:IsValid() then
        pc:TeleportToSafePoint_ToServer(true)
        utils.sendPersonalAnnounce(pc, "You have been teleported to a safe point!")
    end
end

return commands
