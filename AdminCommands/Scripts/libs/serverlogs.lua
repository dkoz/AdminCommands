local utils = require("libs/utils")
local logger = require("libs/logger")
local FGuid = require("libs/Fguid")
local palData = require("enums/paldata")

local serverlogs = {}

local palUtility = nil
local playerNames = {}
local playerUIDs = {}

local function GetPalUtility()
    if not palUtility or not palUtility:IsValid() then
        palUtility = StaticFindObject("/Script/Pal.Default__PalUtility")
    end
    return palUtility
end

local function GetOwnerController(ent)
    if not ent or not ent:IsValid() then return nil end
    if ent:IsA("/Script/Engine.PlayerController") then return ent end

    GetPalUtility()
    if palUtility and palUtility:IsValid() and palUtility:IsOtomo(ent) then
        local trainer = palUtility:GetTrainerPlayerController_ForServer(ent)
        if trainer and trainer:IsValid() then return trainer end
    end

    if ent.GetOwner then
        local owner = ent:GetOwner()
        if owner and owner:IsValid() and owner:IsA("/Script/Engine.PlayerController") then return owner end
    end

    if palUtility and palUtility:IsValid() and palUtility.GetRidePal then
        local ridePal = palUtility:GetRidePal(ent)
        if ridePal and ridePal:IsValid() then return GetOwnerController(ridePal) end
    end

    if ent.PlayerState and ent.PlayerState:IsValid() and ent.PlayerState.GetPlayerController then
        local controller = ent.PlayerState:GetPlayerController()
        if controller and controller:IsValid() then return controller end
    end

    return nil
end

function serverlogs.ChatLog(playerState, messageText, category)
    local senderName = utils.GetPlayerName(playerState)
    local senderUID = utils.GetPlayerId(playerState)

    local categoryText = "Undefined"
    if category == 1 then
        categoryText = "Global"
    elseif category == 3 then
        categoryText = "Say"
    elseif category == 2 then
        categoryText = "Guild"
    end

    logger.logChat(senderName, senderUID, categoryText, messageText)
end

function serverlogs.DeathLog(deadInfo)
    local victim = deadInfo and deadInfo.SelfActor
    local attacker = deadInfo and deadInfo.LastAttacker
    if not (victim and victim:IsValid()) then return end
    if not (victim.PlayerState and victim.PlayerState:IsValid()) then return end

    local victimName = utils.GetPlayerName(victim.PlayerState)
    local victimUID = utils.GetPlayerId(victim.PlayerState)

    local attackerName, attackerUID = nil, nil
    if attacker and attacker:IsValid() then
        local ownerController = GetOwnerController(attacker)
        if ownerController and ownerController:IsValid() and ownerController.PlayerState and ownerController.PlayerState:IsValid() then
            attackerName = utils.GetPlayerName(ownerController.PlayerState)
            attackerUID = utils.GetPlayerId(ownerController.PlayerState)
        end
    end

    logger.logDeath(victimName, victimUID, attackerName, attackerUID)
end

function serverlogs.ConnectLog(character)
    if not (character and character:IsValid() and character.PlayerState and character.PlayerState:IsValid()) then return end

    local name = utils.GetPlayerName(character.PlayerState)
    local uid = utils.GetPlayerId(character.PlayerState)
    local key = character:GetFullName()

    playerNames[key] = name
    playerUIDs[key] = uid

    logger.logConnect(name, uid)
end

function serverlogs.DisconnectLog(character)
    if not (character and character:IsValid()) then return end

    local key = character:GetFullName()
    local name = playerNames[key] or "Unknown"
    local uid = playerUIDs[key] or "UnknownID"

    logger.logDisconnect(name, uid)

    playerNames[key] = nil
    playerUIDs[key] = nil
end

function serverlogs.CaptureLog(sphere)
    if not sphere or not sphere:IsValid() then return end

    local trainer = {}
    sphere:FindOwnerPlayer(trainer)
    if not trainer.Player or not trainer.Player.Controller or not trainer.Player.Controller:IsValid() then
        return
    end

    local playerState = trainer.Player.Controller.PlayerState
    if not playerState or not playerState:IsValid() then return end

    local playerName = utils.GetPlayerName(playerState)
    local playerUID = utils.GetPlayerId(playerState)

    local palName = "Pal"
    local handle = sphere.targetHandle
    if handle and handle:IsValid() then
        local individual = handle:TryGetIndividualParameter()
        if individual and individual:IsValid() then
            local internalId = individual:GetCharacterID():ToString()
            palName = palData[internalId] or internalId
        end
    end

    logger.logCapture(playerName, playerUID, palName)
end

function serverlogs.onDeadCharacter(_, event)
    local deathData = event:get()
    serverlogs.DeathLog(deathData)
end

function serverlogs.onPlayerEndPlay(ctx)
    local player = ctx:get()
    serverlogs.DisconnectLog(player)
end

function serverlogs.onCaptureSuccess(ctx)
    if not logger.logging.capture then return end
    local sphere = ctx:get()
    serverlogs.CaptureLog(sphere)
end

return serverlogs
