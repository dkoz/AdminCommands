-- Kick and Ban use `ClientTravelInternal` to remove a player from the server.
-- Better to use Palworld's built in `KickPlayer` and `BanPlayer`. This is just a backup.
-- Original method provided by Mathayus.

local bans = require("libs/bans")
local utils = require("libs/utils")
local logger = require("libs/logger")
local commands = {}

local function disconnect(targetState)
    local targetPC = targetState:GetPlayerController()
    if targetPC and targetPC:IsValid() then
        targetPC:ClientTravelInternal("Void", 0, false, nil)
    end
end

function commands.handleBan(state, rest)
    local pc = state:GetPlayerController()
    if not rest or rest == "" then
        utils.sendPersonalAnnounce(pc, "Usage: !ban <player> [reason]")
        return
    end

    local targetName, reason = rest:match("^(%S+)%s*(.*)$")
    if not targetName then
        utils.sendPersonalAnnounce(pc, "Usage: !ban <player> [reason]")
        return
    end

    local targetState, name = utils.findPlayerByName(targetName)
    if not targetState then
        utils.sendPersonalAnnounce(pc, "Player not found.")
        return
    end

    local targetUID = utils.GetPlayerId(targetState)
    bans.banUid(targetUID, name, reason)
    logger.logBan(utils.GetPlayerName(state), utils.GetPlayerId(state), name, targetUID, reason)
    disconnect(targetState)

    utils.sendPersonalAnnounce(pc, "Banned " .. name .. " [" .. targetUID .. "]")
    utils.sendServerAnnounce(name .. " has been banned.")
end

function commands.handleUnban(state, rest)
    local pc = state:GetPlayerController()
    if not rest or rest == "" then
        utils.sendPersonalAnnounce(pc, "Usage: !unban <UID>")
        return
    end

    local uid = rest:match("^(%S+)")
    if bans.unbanUid(uid) then
        utils.sendPersonalAnnounce(pc, "Unbanned UID: " .. uid)
    else
        utils.sendPersonalAnnounce(pc, "UID not found in ban list.")
    end
end

function commands.handleKick(state, rest)
    local pc = state:GetPlayerController()
    if not rest or rest == "" then
        utils.sendPersonalAnnounce(pc, "Usage: !kick <player> [reason]")
        return
    end

    local targetName, reason = rest:match("^(%S+)%s*(.*)$")
    if not targetName then
        utils.sendPersonalAnnounce(pc, "Usage: !kick <player> [reason]")
        return
    end

    local targetState, name = utils.findPlayerByName(targetName)
    if not targetState then
        utils.sendPersonalAnnounce(pc, "Player not found.")
        return
    end

    logger.logKick(utils.GetPlayerName(state), utils.GetPlayerId(state), name, utils.GetPlayerId(targetState), reason)
    disconnect(targetState)

    utils.sendPersonalAnnounce(pc, "Kicked " .. name)
    utils.sendServerAnnounce(name .. " has been kicked.")
end

function commands.handleSlay(state, rest)
    local pc = state:GetPlayerController()
    if not rest or rest == "" then
        utils.sendPersonalAnnounce(pc, "Usage: !slay <player>")
        return
    end

    local targetState, name = utils.findPlayerByName(rest)
    if not targetState then
        utils.sendPersonalAnnounce(pc, "Player not found.")
        return
    end

    local controller = targetState:GetPlayerController()
    if not (controller and controller:IsValid()) then
        utils.sendPersonalAnnounce(pc, "Could not find valid controller.")
        return
    end

    controller:SelfKillPlayer()
    utils.sendPersonalAnnounce(pc, name .. " has been killed.")
end

return commands
