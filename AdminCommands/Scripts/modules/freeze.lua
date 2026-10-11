local utils = require("libs/utils")
local commands = {}

local frozen = {}

local function applyFreeze(targetPC, enable)
    if not (targetPC and targetPC:IsValid()) then return false end

    local targetChar = targetPC.Pawn
    if not (targetChar and targetChar:IsValid()) then return false end

    local movement = targetChar:GetPalCharacterMovementComponent()
    if not (movement and movement:IsValid()) then return false end

    if enable then
        movement:StopMovementImmediately()
        movement.bIsDisableInput = true
        movement.bIsDisableMovement = true
        movement.bIsDisableJump = true
        targetPC:SetIgnoreMoveInput(true)
    else
        movement.bIsDisableInput = false
        movement.bIsDisableMovement = false
        movement.bIsDisableJump = false
        movement:SetMovementMode(1, 0)
        targetPC:ResetIgnoreMoveInput()
    end

    return true
end

local function setFrozen(state, rest, enable)
    local pc = state:GetPlayerController()
    local usage = enable and "Usage: !freeze <player>" or "Usage: !unfreeze <player>"

    if not rest or rest == "" then
        utils.sendPersonalAnnounce(pc, usage)
        return
    end

    local targetState, name = utils.findPlayerByName(rest)
    if not targetState then
        utils.sendPersonalAnnounce(pc, "Player not found.")
        return
    end

    local targetUID = utils.GetPlayerId(targetState)
    if not applyFreeze(targetState:GetPlayerController(), enable) then
        utils.sendPersonalAnnounce(pc, "Could not reach that player's character.")
        return
    end

    frozen[targetUID] = enable or nil
    utils.sendPersonalAnnounce(pc, (enable and "Froze " or "Unfroze ") .. name)
end

function commands.handleFreeze(state, rest)
    setFrozen(state, rest, true)
end

function commands.handleUnfreeze(state, rest)
    setFrozen(state, rest, false)
end

function commands.reapply(state)
    if not (state and state:IsValid()) then return end
    if not frozen[utils.GetPlayerId(state)] then return end

    utils.scheduleAfter(1000, function()
        if not (state and state:IsValid()) then return end
        applyFreeze(state:GetPlayerController(), true)
    end)
end

return commands
